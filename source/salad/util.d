/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.util;

import dyaml : Node;

import salad.meta.uda : idMap;

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

/// dig for parsed object
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
        import salad.type : isOptional, isSumType, match, None;

        static if (K.length == 0)
        {
            static if (!is(T == U))
            {
                import salad.primitives : Any;
                import salad.type : Union;

                static if (is(T == Union!(None, Any)) || is(T == Union!(None, Any[])))
                {
                    return t.match!(
                        (None _) => default_,
                        others => others.dig!(K, U, typeof(others), idMap_)(default_),
                    );
                }
                else static if (is(T == Any))
                {
                    return t.as!U;
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
        else static if (isSumType!T)
        {
            import std.meta : Filter, staticMap;

            enum canDig(T) = __traits(compiles, T.init.dig!(K, U, T, idMap_));
            alias TS = Filter!(canDig, T.Types);
            alias ddig(T) = dig!(K, U, T, idMap_);
            static if (TS.length == T.Types.length)
            {
                return t.match!(
                    staticMap!(ddig, TS)
                );
            }
            else
            {
                return t.match!(
                    staticMap!(ddig, TS),
                    _ => default_,
                );
            }
        }
        else static if (isArray!T)
        {
            import std.algorithm : map;
            import std.array : assocArray;

            static assert(idMap_ != idMap.init, "dig does not support index access");
            auto aa = () @trusted {
                // use unsafe assocArray but it can be trusted
                return t.map!((e) @safe {
                    import salad.primitives : Any;
                    import salad.type : tryMatch;
                    import std.typecons : tuple;

                    static if (isSumType!(typeof(e)))
                    {
                        import std.meta : anySatisfy;

                        enum isAny(T) = is(T == Any);
                        static if (anySatisfy!(isAny, e.Types))
                        {
                            auto f = e.tryMatch!(
                                (Any any) => any.value[idMap_.subject].as!string,
                                ee => __traits(getMember, ee, idMap_.subject ~ "_"),
                            );
                        }
                        else
                        {
                            auto f = e.tryMatch!(ee => __traits(getMember, ee, idMap_.subject ~ "_"));
                        }
                    }
                    else static if (is(typeof(e) == Any))
                    {
                        auto f = e;
                    }
                    else
                    {
                        auto f = __traits(getMember, e, idMap_.subject ~ "_");
                    }

                    static if (isSumType!(typeof(f)))
                    {
                        auto k = f.tryMatch!((string s) => s);
                    }
                    else static if (is(typeof(e) == Any))
                    {
                        auto k = e.value[idMap_.subject].as!string;
                    }
                    else
                    {
                        auto k = f;
                    }
                    return tuple(k, e);
                }).assocArray;
            }();

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

@safe unittest
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

@safe unittest
{
    import salad.type : None, Union;

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
        Union!(None, E[]) elems_;

        this(E[] elems) { elems_ = elems; }
    }

    auto c = new C([
        new E("foo", 1), new E("bar", 2)
    ]);
    assert(c.dig!(["elems", "foo"], E).val_ == 1);
    assert(c.dig!(["elems", "bar", "val"], int) == 2);
}

@safe unittest
{
    import salad.type : None, SumType, Union;

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
        Union!(None, ElemType[]) elems_;

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
        import salad.type : isOptional, isSumType, tryMatch, None;

        static if (K.length == 0)
        {
            static if (!is(T == U))
            {
                import salad.primitives : Any;
                import salad.type : Union;

                static if (is(T == Union!(None, Any)) || is(T == Union!(None, Any[])))
                {
                    return t.tryMatch!((T.Types[0] val) => edig!(K, U)(val));
                }
                else static if (is(T == Any))
                {
                    return t.as!U;
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
        else static if (isSumType!T)
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
            auto aa = () @trusted {
                // use unsafe assocArray but it can be trusted
                return t.map!((e) @safe {
                    import salad.primitives : Any;
                    import salad.type : isSumType, tryMatch;
                    import std.typecons : tuple;

                    static if (isSumType!(typeof(e)))
                    {
                        auto f = e.tryMatch!(ee => __traits(getMember, ee, idMap_.subject ~ "_"));
                    }
                    else static if (is(typeof(e) == Any))
                    {
                        auto f = e;
                    }
                    else
                    {
                        auto f = __traits(getMember, e, idMap_.subject ~ "_");
                    }

                    static if (isSumType!(typeof(f)))
                    {
                        auto k = f.tryMatch!((string s) => s);
                    }
                    else static if (is(typeof(e) == Any))
                    {
                        auto k = e.value[idMap_.subject].as!string;
                    }
                    else
                    {
                        auto k = f;
                    }
                    return tuple(k, e);
                }).assocArray;
            }();

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

@safe unittest
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

@safe unittest
{
    import salad.type : None, Union;

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
        Union!(None, E[]) elems_;

        this(E[] elems) { elems_ = elems; }
    }

    auto c = new C([
        new E("foo", 1), new E("bar", 2)
    ]);
    assert(c.edig!(["elems", "foo"], E).val_ == 1);
    assert(c.edig!(["elems", "bar", "val"], int) == 2);
}

@safe unittest
{
    import salad.type : None, Union, tryMatch;

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

    alias ElemType = Union!(E1, E2);
    class C
    {
        @idMap("id")
        Union!(None, ElemType[]) elems_;

        this(ElemType[] elems) { elems_ = elems; }
    }

    auto c = new C([
        ElemType(new E1("foo", 1)), ElemType(new E2("bar", "val"))
    ]);
    assert(c.edig!(["elems", "foo"], E1).val_ == 1);
    assert(c.edig!(["elems", "bar"], E2).val_ == "val");
}

@safe unittest
{
    import salad.type : Union;

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

    auto e = Union!(E1, E2)(new E1("foo", 1));
    assert(e.dig!("id", string) == "foo");
}

/**
 * A struct to handle version strings of SALAD.
 * It is similar to Semantic Versioning but the following points are different:
 * - its string starts with `v`, and
 * - it ends with `-dev*` in case of development versions
 * Note: this struct does not handle other suffix such as `-alpha1`
 * See_Also: https://semver.org/
 */
@safe struct SemVer
{
    string ver;

    this(string ver_) pure
    {
        import std : enforce;
        enforce(ver_[0] == 'v');
        ver = ver_;
    }

    int opCmp(string semver) const pure
    {
        auto lhs = ver.toSemVerSeq;
        auto rhs = semver.toSemVerSeq;
        return lhs == rhs ? 0 :
               lhs < rhs ? -1 :
               1;
    }

    int opCmp(SemVer rhs) const pure
    {
        return this.opCmp(rhs.ver);
    }
}

private:

auto toSemVerSeq(string ver) pure @safe
{
    import std : array, empty, enforce, findSplit, format, ifThrown, map, split, to;

    enforce(ver[0] == 'v', format!"Invalid SALAD version that does not start with `v`: `%s`"(ver));
    auto ret = ver[1..$].findSplit("-dev");
    string[] mainVerStrs;
    int devVer;
    if (ret[1].empty) // release version
    {
        mainVerStrs = ret[0].split(".");
        devVer = int.max;
    }
    else
    {
        mainVerStrs = ret[0].split(".");
        devVer = ret[2].to!int.ifThrown(throw new Exception(format!"Invalid development version in the string: `%s` in `%s`"("dev"~ret[2], ver)));
    }
    enforce(mainVerStrs.length == 3, format!"Invalid SALAD version that does not have major, minor and patch versions: `%s`"(ver));
    int[] mainVers = mainVerStrs.map!(to!int).array;
    return mainVers~devVer;
}

pure @safe unittest
{
    assert("v1.2.0".toSemVerSeq == [1, 2, 0, int.max]);
    assert("v1.3.0-dev3".toSemVerSeq == [1, 3, 0, 3]);
    assert("v1.3.0".toSemVerSeq > "v1.3.0-dev3".toSemVerSeq);
}

pure @safe unittest
{
    assert(SemVer("v1.3.0") > SemVer("v1.3.0-dev3"));
    assert(SemVer("v1.3.0") > "v1.3.0-dev3");
    assert("v1.3.0" > SemVer("v1.3.0-dev3"));
}
