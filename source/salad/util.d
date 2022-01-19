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

// dig for CWL object
auto dig(alias K, U, T, idMap idMap_ = idMap.init)(T t, U default_ = U.init)
if (!is(T: Node))
{
    static assert(is(typeof(K) == string) || is(typeof(K) == string[]));
    static if (is(typeof(K) == string))
    {
        return dig!([K])(t, default_);
    }
    else
    {
        import std.traits : getUDAs, hasMember, hasStaticMember, hasUDA, isArray;
        import salad.type : isEither, isOptional, isSumType, match, None;

        static if (K.length == 0)
        {
            static if (isSumType!T)
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
        else static if (hasStaticMember!(T, K[0]~"_"))
        {
            auto field = mixin("t."~K[0]~"_");
            return dig!(K[1..$], U, typeof(field))(field, default_);
        }
        else static if (hasMember!(T, K[0]~"_"))
        {
            auto field = mixin("t."~K[0]~"_");
            static if (hasUDA!(mixin("t."~K[0]~"_"), idMap))
            {
                enum nextIDMap = getUDAs!(mixin("t."~K[0]~"_"), idMap)[0];
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
                others => others.dig!(K, U)(default_),
            );
        }
        else static if (isEither!T)
        {
            import std.meta : ApplyRight, ApplyLeft, Filter, staticMap;
            static if (hasUDA!(mixin("t."~K[0]~"_"), idMap))
            {
                enum nextIDMap = getUDAs!(mixin("t."~K[0]~"_"), idMap)[0];
            }
            else
            {
                enum nextIDMap = idMap.init;
            }
            alias TS = Filter!(ApplyRight!(hasMember, K[0]~"_"), T.Types);
            alias ddig = ApplyRight!(ApplyLeft!(ApplyLeft!(dig, K[1..$]), U), nextIDMap);
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
                import std.typecons : tuple;
                auto f = mixin("e."~idMap_.subject~"_");
                static if (isSumType!(typeof(f)))
                {
                    auto k = f.tryMatch!((string s) => s);
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

/// enforceDig
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
