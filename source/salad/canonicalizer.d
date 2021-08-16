module salad.canonicalizer;

///
mixin template Canonicalize(Base, FieldCanonicalizer...)
{
    import dyaml : Node;

    import std.algorithm : endsWith;
    import std.format : format;
    import std.meta : AliasSeq, Stride;
    import std.traits : isCallable, FieldNameTuple, Fields, Parameters, ReturnType, fullyQualifiedName;

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
            mixin(ReturnType!(ConvFuns[findIndex(fname)]).stringof ~ " " ~ fname ~ ";");
        }
        else
        {
            mixin(FTypes[idx].stringof~" "~fname~";");
        }
    }

    this() {}

    this(Base base)
    {
        canonicalize(base);
    }

    this(in Node node)
    {
        auto base = new Base(node);
        canonicalize(base);
    }

    final void canonicalize(Base base)
    {
        static foreach(fname; FNames)
        {
            static if (findIndex(fname) != -1)
            {
                {
                    alias conv = ConvFuns[findIndex(fname)];
                    mixin("this."~fname~"= conv(base."~fname~");");
                }
            }
            else
            {
                mixin("this."~fname~" = base."~fname~";");
            }
        }
    }
}

unittest
{
    import std.conv : to;
    import dyaml : Node, Loader;

    static class C
    {
        int foo_;
        string str_;

        this(Node node)
        {
            foo_ = node["foo"].as!int;
            str_ = node["str"].as!string;
        }
    }

    static class Foo
    {
        mixin Canonicalize!(C,
                            "foo", (int i) => i.to!string,
                            "str", (string s) => 0);
    }

    enum ymlStr = q"EOS
foo: 10
str: "string"
EOS";

    auto foo = Loader.fromString(ymlStr).load.as!Foo;
    assert(foo.foo_ == "10");
    assert(foo.str_ == 0);
}
