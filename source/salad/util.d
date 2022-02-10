/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.util;

import dyaml : Node;

import salad.meta : idMap;

/// dig for node
auto dig(T)(in Node node, string key, T default_)
{
    return dig(node, [key], default_);
}

/// ditto
auto dig(T)(in Node node, string[] keys, T default_)
{
    Node ret = node;
    foreach(k; keys)
    {
        if (auto n = k in ret)
        {
            ret = *n;
        }
        else
        {
            static if (is(T : void[]))
            {
                return Node((Node[]).init);
            }
            else
            {
                return Node(default_);
            }
        }
    }
    return ret;
}

// dig for parsed object
auto dig(alias K, U, T, idMap idMap_ = idMap.init)(T t, U default_ = U.init)
if (!is(T: Node))
{
    static assert(is(typeof(K) == string) || is(typeof(K) == string[]));
    static if (is(typeof(K) == string))
    {
        return dig!([K], U, T, idMap_)(t, default_);
    }
    else
    {
        import std.traits : getUDAs, hasMember, hasStaticMember, hasUDA, isArray;
        import salad.type : isEither, isOptional, isSumType, match, None;

        static if (K.length == 0)
        {
            static if (!is(T == U))
            {
                import salad.primitives : Any;
                import salad.type : Optional;

                static if (is(T == Optional!Any) || is(T == Optional!(Any[])))
                {
                    return t.match!(
                        (None _) => default_,
                        others => others.dig!(K, U, typeof(others), idMap_)(default_),
                    );
                }
                else static if (is(T == Any))
                {
                    return t.value_.as!U(); // TODO
                }
                else static if (isSumType!T)
                {
                    return t.match!(
                        (U u) => u,
                        _ => default_,
                    );
                }
                else
                {
                    return t;
                }
            }
            else
            {
                return t;
            }
        }
        else static if (hasStaticMember!(T, K[0]~"_"))
        {
            auto field = __traits(getMember, t, K[0]~"_");
            return dig!(K[1..$], U, typeof(field))(field, default_);
        }
        else static if (hasMember!(T, K[0]~"_"))
        {
            auto field = __traits(getMember, t, K[0]~"_");
            static if (hasUDA!(__traits(getMember, t, K[0]~"_"), idMap))
            {
                enum nextIDMap = getUDAs!(__traits(getMember, t, K[0]~"_"), idMap)[0];
            }
            else
            {
                enum nextIDMap = idMap.init;
            }
            return dig!(K[1..$], U, typeof(field), nextIDMap)(field, default_);
        }
        else static if (isOptional!T)
        {
            return t.match!(
                (None _) => default_,
                others => others.dig!(K, U, typeof(others), idMap_)(default_),
            );
        }
        else static if (isEither!T)
        {
            import std.meta : Filter, staticMap;

            enum canDig(T) = __traits(compiles, T.init.dig!(K, U, T, idMap_));
            alias TS = Filter!(canDig, T.Types);
            alias ddig(T) = dig!(K, U, T, idMap_);
            return t.match!(
                staticMap!(ddig, TS),
                _ => default_,
            );
        }
        else static if (isArray!T)
        {
            import std.algorithm : map;
            import std.array : assocArray;

            static assert(idMap_ != idMap.init, "dig does not support index access");
            auto aa = t.map!((e) {
                import salad.primitives : Any;
                import salad.type : tryMatch;
                import std.typecons : tuple;

                static if (isEither!(typeof(e)))
                {
                    auto f = e.tryMatch!(ee => __traits(getMember, ee, idMap_.subject~"_"));
                }
                else static if (is(typeof(e) == Any))
                {
                    auto f = e;
                }
                else
                {
                    auto f = __traits(getMember, e, idMap_.subject~"_");
                }

                static if (isSumType!(typeof(f)))
                {
                    auto k = f.tryMatch!((string s) => s);
                }
                else static if (is(typeof(e) == Any))
                {
                    auto k = e.value_[idMap_.subject].as!string;
                }
                else
                {
                    auto k = f;
                }
                return tuple(k, e);
            }).assocArray;

            if (auto v = K[0] in aa)
            {
                return dig!(K[1..$])(*v, default_);
            }
            else
            {
                return default_;
            }
        }
        else
        {
            return default_;
        }
    }
}

unittest
{
    class C
    {
        static immutable class_ = "foo";
        int val_ = 10;
    }

    auto c = new C;
    assert(c.dig!("val", int) == 10);
    assert(c.dig!("class", string) == "foo");
}

unittest
{
    import salad.type : Optional;

    class E
    {
        string id_;
        int val_;
        this(string id, int val)
        {
            id_ = id;
            val_ = val;
        }
    }

    class C
    {
        @idMap("id")
        Optional!(E[]) elems_;

        this(E[] elems) { elems_ = elems; }
    }

    auto c = new C([
        new E("foo", 1), new E("bar", 2)
    ]);
    assert(c.dig!(["elems", "foo"], E).val_ == 1);
    assert(c.dig!(["elems", "bar", "val"], int) == 2);
}

unittest
{
    import salad.type : Optional, SumType;

    class E1
    {
        string id_;
        int val_;
        this(string id, int val)
        {
            id_ = id;
            val_ = val;
        }
    }

    class E2
    {
        string id_;
        string val_;
        this(string id, string val)
        {
            id_ = id;
            val_ = val;
        }
    }

    alias ElemType = SumType!(E1, E2);
    class C
    {
        @idMap("id")
        Optional!(ElemType[]) elems_;

        this(ElemType[] elems) { elems_ = elems; }
    }

    auto c = new C([
        ElemType(new E1("foo", 1)), ElemType(new E2("bar", "val"))
    ]);
    assert(c.dig!(["elems", "foo"], E1).val_ == 1);
    assert(c.dig!(["elems", "bar"], E2).val_ == "val");
}

/// enforceDig for Node
auto edig(Ex = Exception)(in Node node, string key, string msg = "")
{
    return edig!Ex(node, [key], msg);
}

/// ditto
auto edig(Ex = Exception)(in Node node, string[] keys, string msg = "")
{
    Node ret = node;
    foreach(k; keys)
    {
        if (auto n = k in ret)
        {
            ret = *n;
        }
        else
        {
            import std.format : format;
            import std.range : empty;
            msg = msg.empty ? format!"No such field: %s"(k) : msg;
            throw new Ex(msg);
        }
    }
    return ret;
}


/// enforceDig for parseed object
U edig(alias K, U, T, idMap idMap_ = idMap.init)(T t)
if (!is(T: Node))
{
    static assert(is(typeof(K) == string) || is(typeof(K) == string[]));
    static if (is(typeof(K) == string))
    {
        return edig!([K], U, T, idMap_)(t);
    }
    else
    {
        import std.traits : getUDAs, hasMember, hasStaticMember, hasUDA, isArray;
        import salad.type : isEither, isOptional, isSumType, tryMatch, None;

        static if (K.length == 0)
        {
            static if (!is(T == U))
            {
                import salad.primitives : Any;
                import salad.type : Optional;

                static if (is(T == Optional!Any) || is(T == Optional!(Any[])))
                {
                    return t.tryMatch!((T.Types[0] val) => edig!(K, U)(val));
                }
                else static if (is(T == Any))
                {
                    return t.value_.as!U(); // TODO
                }
                else static if (isSumType!T)
                {
                    return t.tryMatch!((U u) => u);
                }
                else
                {
                    return t;
                }
            }
            else
            {
                return t;
            }
        }
        else static if (hasStaticMember!(T, K[0]~"_"))
        {
            auto field = __traits(getMember, t, K[0]~"_");
            return edig!(K[1..$], U)(field);
        }
        else static if (hasMember!(T, K[0]~"_"))
        {
            auto field = __traits(getMember, t, K[0]~"_");
            static if (hasUDA!(__traits(getMember, t, K[0]~"_"), idMap))
            {
                enum nextIDMap = getUDAs!(__traits(getMember, t, K[0]~"_"), idMap)[0];
            }
            else
            {
                enum nextIDMap = idMap.init;
            }
            return edig!(K[1..$], U, typeof(field), nextIDMap)(field);
        }
        else static if (isOptional!T)
        {
            import std.meta : Filter, staticMap;

            enum canDig(T) = __traits(compiles, T.init.edig!(K, U, T, idMap_));
            alias TS = Filter!(canDig, T.Types[1..$]);
            alias ddig(T) = edig!(K, U, T, idMap_);
            return t.tryMatch!(
                staticMap!(ddig, TS)
            );
        }
        else static if (isEither!T)
        {
            import std.meta : Filter, staticMap;

            enum canDig(T) = __traits(compiles, T.init.edig!(K, U, T, idMap_));
            alias TS = Filter!(canDig, T.Types);
            alias ddig(T) = edig!(K, U, T, idMap_);
            return t.tryMatch!(
                staticMap!(ddig, TS)
            );
        }
        else static if (isArray!T)
        {
            import std.algorithm : map;
            import std.array : assocArray;

            static assert(idMap_ != idMap.init, "dig does not support index access");
            auto aa = t.map!((e) {
                import salad.primitives : Any;
                import salad.type : isSumType, tryMatch;
                import std.typecons : tuple;

                static if (isEither!(typeof(e)))
                {
                    auto f = e.tryMatch!(ee => __traits(getMember, ee, idMap_.subject~"_"));
                }
                else static if (is(typeof(e) == Any))
                {
                    auto f = e;
                }
                else
                {
                    auto f = __traits(getMember, e, idMap_.subject~"_");
                }

                static if (isSumType!(typeof(f)))
                {
                    auto k = f.tryMatch!((string s) => s);
                }
                else static if (is(typeof(e) == Any))
                {
                    auto k = e.value_[idMap_.subject].as!string;
                }
                else
                {
                    auto k = f;
                }
                return tuple(k, e);
            }).assocArray;

            if (auto v = K[0] in aa)
            {
                return edig!(K[1..$], U)(*v);
            }
            else
            {
                throw new Exception("");
            }
        }
        else
        {
            throw new Exception("");
        }
    }
}

unittest
{
    class C
    {
        static immutable class_ = "foo";
        int val_ = 10;
    }

    auto c = new C;
    assert(c.edig!("val", int) == 10);
    assert(c.edig!("class", string) == "foo");
}

unittest
{
    import salad.type : Optional;

    class E
    {
        string id_;
        int val_;
        this(string id, int val)
        {
            id_ = id;
            val_ = val;
        }
    }

    class C
    {
        @idMap("id")
        Optional!(E[]) elems_;

        this(E[] elems) { elems_ = elems; }
    }

    auto c = new C([
        new E("foo", 1), new E("bar", 2)
    ]);
    assert(c.edig!(["elems", "foo"], E).val_ == 1);
    assert(c.edig!(["elems", "bar", "val"], int) == 2);
}

unittest
{
    import salad.type : Either, Optional, tryMatch;

    class E1
    {
        string id_;
        int val_;
        this(string id, int val)
        {
            id_ = id;
            val_ = val;
        }
    }

    class E2
    {
        string id_;
        string val_;
        this(string id, string val)
        {
            id_ = id;
            val_ = val;
        }
    }

    alias ElemType = Either!(E1, E2);
    class C
    {
        @idMap("id")
        Optional!(ElemType[]) elems_;

        this(ElemType[] elems) { elems_ = elems; }
    }

    auto c = new C([
        ElemType(new E1("foo", 1)), ElemType(new E2("bar", "val"))
    ]);
    assert(c.edig!(["elems", "foo"], E1).val_ == 1);
    assert(c.edig!(["elems", "bar"], E2).val_ == "val");
}

auto diff(Node lhs, Node rhs)
{
    import dyaml : NodeType;

    import std.format;
    
    alias Entry = Diff.Entry;

    if (lhs.type != rhs.type)
    {
        return Diff([Entry(lhs, rhs, format!"Different node type: (%s, %s)"(lhs.type, rhs.type))]);
    }

    Entry[] result;
    if (lhs.tag != rhs.tag)
    {
        result ~= Entry(lhs, rhs, format!"Different node tag: (%s, %s)"(lhs.tag, rhs.tag));
    }

    switch(lhs.type)
    {
    case NodeType.mapping:
        import std.algorithm : map, schwartzSort, setDifference;
        import std.array : array;

        auto lmap = lhs.mapping.array.schwartzSort!"a.key";
        auto rmap = rhs.mapping.array.schwartzSort!"a.key";
        if (lmap.length != rmap.length)
        {
            result ~= Entry(lhs, rhs, format!"Different #node mapping entries: (%s, %s)"(lmap.length, rmap.length));
        }
        auto l_r = setDifference!"a.key < b.key"(lmap, rmap);
        if (!l_r.empty)
        {
            result ~= Entry(lhs, rhs, format!"lhs has extra mapping entries: (%s)"(l_r.map!"a.key".array));
        }

        auto r_l = setDifference!"a.key < b.key"(rmap, lmap);
        if (!r_l.empty)
        {
            result ~= Entry(lhs, rhs, format!"rhs has extra mapping entries: (%s)"(r_l.map!"a.key".array));
        }

        if(l_r.empty && r_l.empty)
        {
            import std.algorithm : joiner, map;
            import std.range : zip;
            result ~= zip(lmap, rmap).map!(a => diff(a[0].value, a[1].value).entries).joiner.array;
        }
        break;
    case NodeType.sequence:
        import std.array : array;

        auto lhsArr = lhs.sequence.array;
        auto rhsArr = rhs.sequence.array;
        if (lhsArr.length != rhsArr.length)
        {
            result ~= Entry(lhs, rhs, format!"Different node length: (%s, %s)"(lhs.length, rhs.length));
        }
        else
        {
            import std.algorithm : joiner, map;
            import std.range : zip;
            result ~= zip(lhsArr, rhsArr).map!(a => diff(a[0], a[1]).entries).joiner.array;
        }
        break;
    case NodeType.boolean:
        auto lhsbool = lhs.as!bool;
        auto rhsbool = rhs.as!bool;
        if (lhsbool != rhsbool)
        {
            result ~= Entry(lhs, rhs, format!"Different boolean value: (%s, %s)"(lhsbool, rhsbool));
        }
        break;
    case NodeType.integer:
        auto lhsint = lhs.as!int;
        auto rhsint = rhs.as!int;
        if (lhsint != rhsint)
        {
            result ~= Entry(lhs, rhs, format!"Different integer value: (%s, %s)"(lhsint, rhsint));
        }
        break;
    case NodeType.decimal:
        import std.math : isClose;
        auto lhsreal = lhs.as!real;
        auto rhsreal = rhs.as!real;
        if (lhsreal.isClose(rhsreal))
        {
            result ~= Entry(lhs, rhs, format!"Different decimal value: (%s, %s)"(lhsreal, rhsreal));
        }
        break;
    case NodeType.string:
        auto lhsstr = lhs.as!string;
        auto rhsstr = rhs.as!string;
        if (lhsstr != rhsstr)
        {
            result ~= Entry(lhs, rhs, format!"Different string value: (\"%s\", \"%s\")"(lhsstr, rhsstr));
        }
        break;
    default:
        // nop
        break;
    }
    return Diff(result);
}

struct Diff
{
    struct Entry
    {
        Node lhs, rhs;
        string message;

        string toString() const pure @safe
        {
            import std.format : format;
            import std.range : empty;
            auto mark = lhs.startMark.name.empty ? rhs.startMark : lhs.startMark;
            return format!"%s:%s:%s: %s"(mark.name, mark.line+1, mark.column,
                                         message);
        }
    }

    Entry[] entries;

    string toString() const pure @safe
    {
        import std.algorithm : joiner, map;
        import std.array : array;
        import std.conv : to;

        return entries.map!(to!string).joiner("\n").array.to!string;
    }
}
