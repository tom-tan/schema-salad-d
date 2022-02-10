/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.canonicalizer;

///
mixin template genCanonicalizeBody(Base, FieldCanonicalizer...)
{
private:
    import dyaml : Node;

    import salad.context : LoadingContext;
    import salad.meta : genIdentifier, id, idMap, StaticMembersOf;

    import std.algorithm : endsWith;
    import std.format : format;
    import std.meta : AliasSeq, Stride;
    import std.traits : isCallable, FieldNameTuple, Fields, getUDAs, hasUDA, Parameters, ReturnType;

    alias FTypes = Fields!Base;
    alias FNames = FieldNameTuple!Base;

    static assert(FieldCanonicalizer.length % 2 == 0);
    static if (FieldCanonicalizer.length == 0)
    {
        alias ConvFuns = AliasSeq!();
    }
    else
    {
        alias ConvFuns = Stride!(2, FieldCanonicalizer[1..$]);
    }

    static auto findIndex(string name)
    {
        import std.algorithm : find;
        import std.range : enumerate;

        auto rng = (cast(string[])[Stride!(2, FieldCanonicalizer)]).enumerate.find!(e => e.value~"_" == name);
        return rng.empty ? -1 : rng.front.index;
    }

    final void canonicalize(Base base)
    {
        static foreach(fname; FNames)
        {
            static if (findIndex(fname) != -1)
            {
                {
                    alias conv = ConvFuns[findIndex(fname)];
                    __traits(getMember, this, fname) = conv(__traits(getMember, base, fname));
                }
            }
            else
            {
                __traits(getMember, this, fname) = __traits(getMember, base, fname);
            }
        }
    }

public:
    static foreach(name; StaticMembersOf!Base)
    {
        mixin("static immutable "~name~" = Base."~name~";");
    }

    static foreach(idx, fname; FNames)
    {
        static assert(fname.endsWith("_"),
                      format!"Field name should end with `_` (%s.%s)"(Base.stringof, fname));
        static if (findIndex(fname) != -1)
        {
            static assert(isCallable!(ConvFuns[findIndex(fname)]),
                          format!"Convert function for `%s` is not callable"(fname));
            static assert(Parameters!(ConvFuns[findIndex(fname)]).length == 1,
                          format!"Convert function for `%s` should have only one parameter"(fname));
            static assert(is(Parameters!(ConvFuns[findIndex(fname)])[0] == FTypes[idx]),
                          format!"A parameter of convert function for `%s` expects %s but actual: %s"(
                                fname, FTypes[idx], Parameters!(ConvFuns[findIndex(fname)])[0]
                          ));
            static if (hasUDA!(__traits(getMember, Base, fname), id))
            {
                mixin("@id "~ReturnType!(ConvFuns[findIndex(fname)]).stringof ~ " " ~ fname ~ ";");
            }
            else static if (hasUDA!(__traits(getMember, Base, fname), idMap))
            {
                mixin("@"~getUDAs!(__traits(getMember, Base, fname), idMap)[0].stringof ~ " " ~
                      ReturnType!(ConvFuns[findIndex(fname)]).stringof ~ " " ~ fname ~ ";");
            }
            else
            {
                mixin(ReturnType!(ConvFuns[findIndex(fname)]).stringof ~ " " ~ fname ~ ";");
            }
        }
        else
        {
            static if (hasUDA!(__traits(getMember, Base, fname), id))
            {
                mixin("@id "~FTypes[idx].stringof~" "~fname~";");
            }
            else static if (hasUDA!(__traits(getMember, Base, fname), idMap))
            {
                mixin("@"~getUDAs!(__traits(getMember, Base, fname), idMap)[0].stringof ~ " " ~
                      FTypes[idx].stringof ~ " " ~ fname ~ ";");
            }
            else
            {
                mixin(FTypes[idx].stringof~" "~fname~";");
            }
        }
    }

    this() {}

    this(Base base)
    {
        canonicalize(base);
    }

    this(in Node node, in LoadingContext context = LoadingContext.init)
    {
        auto base = new Base(node, context);
        canonicalize(base);
    }

    mixin genIdentifier;
}

unittest
{
    import salad.context : LoadingContext;
    import std.conv : to;
    import dyaml : Node, Loader;

    static class C
    {
        int foo_;
        string str_;

        this(Node node, in LoadingContext context = LoadingContext.init)
        {
            foo_ = node["foo"].as!int;
            str_ = node["str"].as!string;
        }
    }

    static class Foo
    {
        mixin genCanonicalizeBody!(
            C,
            "foo", (int i) => i.to!string,
            "str", (string s) => 0,
        );
    }

    enum ymlStr = q"EOS
foo: 10
str: "string"
EOS";

    auto foo = Loader.fromString(ymlStr).load.as!Foo;
    assert(foo.foo_ == "10");
    assert(foo.str_ == 0);
}

unittest
{
    import salad.context : LoadingContext;
    import std.conv : to;
    import dyaml : Node, Loader;

    static class C
    {
        static immutable class_ = "File";
        int foo_;

        this() {}
        this(Node node, in LoadingContext context = LoadingContext.init)
        {
            foo_ = node["foo"].as!int;
        }
    }

    static class Foo
    {
        mixin genCanonicalizeBody!(C, "foo", (int i) => i.to!string);
    }

    enum ymlStr = q"EOS
foo: 10
EOS";

    auto foo = Loader.fromString(ymlStr).load.as!Foo;
    assert(foo.foo_ == "10");
    assert(foo.class_ == "File");
}
