module salad.meta;

import salad.type;

import dyaml;

///
mixin template genCtor()
{
    import dyaml : Node, NodeType;

    this() {}
    this(in Node node) @trusted
    {
        import salad.util : edig;
        import std.algorithm : endsWith, map;
        import std.array : array;
        import std.format : format;
        import std.traits : FieldNameTuple;

        alias This = typeof(this);

        static foreach(field; FieldNameTuple!This)
        {
            static assert(field.endsWith("_"),
                          format!"Field name should end with `_` (%s.%s)"(This.stringof, field));
            mixin("mixin(Assign!(node, "~field~"));");
        }
    }
}

///
mixin template genToString()
{
    override string toString() @trusted
    {
        import std.conv : to;
        import std.array : join;
        import std.format : format;
        import std.traits : FieldNameTuple;

        string[] fstrs;

        alias This = typeof(this);

        static foreach(field; FieldNameTuple!This)
        {
            static if (isOptional!(typeof(mixin(field))))
            {
                mixin(field).match!((None _) { return; },
                                    (rest) { fstrs ~= format!"%s: %s"(field, rest); return; });
            }
            else static if (isEither!(typeof(mixin(field))))
            {
                mixin(field).match!(f => fstrs ~= format!"%s: %s"(field, f));
            }
            else
            {
                fstrs ~= format!"%s: %s"(field, mixin(field));
            }
        }
        return format!"%s(%s)"(This.stringof, fstrs.join(", "));
    }
}

/**
Returns: a string to construct `T` with a parameter whose variable name is `param`
Note: Use this function instead of `param.as!T` to prevent circular references
*/
string ctorStr(T)(string param)
{
    import std.format : format;
    static if (is(T == class))
    {
        return format!"new %1$s(%2$s)"(T.stringof, param);
    }
    else
    {
        return format!"%2$s.as!%1$s"(T.stringof, param);
    }
}

///
template Assign(alias node, alias field)
{
    import std.format : format;

    alias Attrs = __traits(getAttributes, field);
    alias T = typeof(field);

    enum param = field.stringof[0..$-1];

    static if (isOptional!T)
    {
        enum Assign = format!q"EOS
            if (auto f = "%s" in %s)
            {
                %s
            }
EOS"(param, node.stringof, Assign_!("(*f)", field.stringof, T));
    }
    else static if (isEither!T)
    {
        enum Assign = Assign_!(format!`%s.edig("%s")`(node.stringof, param), field.stringof, T);
    }
    else
    {
        enum Assign = Assign_!(format!`%s.edig("%s")`(node.stringof, param), field.stringof, T);
    }
}

version(unittest)
{
    auto stripLeftAll(string str) @safe
    {
        import std.algorithm : joiner, map;
        import std.array : array;
        import std.string : split, stripLeft;
        return str.split.map!stripLeft.joiner("\n").array;
    }
}

///
@safe unittest
{
    import salad.util : edig;

    enum fieldName = "strVariable";
    Node n = [ fieldName: "string value" ];
    string strVariable_;
    enum exp = Assign!(n, strVariable_);
    static assert(exp == `strVariable_ = n.edig("strVariable").as!string;`, exp);

    mixin(exp);
    assert(strVariable_ == "string value");
}

/// optional of non-array type
@safe unittest
{
    import std.exception : assertNotThrown;

    enum fieldName = "param";
    Node n = [ fieldName: true ];
    Optional!bool param_;
    enum exp = Assign!(n, param_).stripLeftAll;
    static assert(exp == q"EOS
        if (auto f = "param" in n)
        {
            param_ = (*f).as!bool;
        }
EOS".stripLeftAll, exp);

    mixin(exp);
    assertNotThrown(param_.tryMatch!((bool b) => assert(b)));
}

/// optional of array type
unittest
{
    import std.algorithm : map;
    import std.array : array;
    import std.exception : assertNotThrown;

    enum fieldName = "params";
    Node n = [ fieldName: [1, 2, 3] ];
    Optional!(int[]) params_;
    enum exp = Assign!(n, params_).stripLeftAll;
    static assert(exp == q"EOS
        if (auto f = "params" in n)
        {
            params_ = (*f).sequence.map!(a => a.as!int).array;
        }
EOS".stripLeftAll, exp);

    mixin(exp);
    assertNotThrown(params_.tryMatch!((int[] arr) => assert(arr == [1, 2, 3])));
}

template Assign_(string node, string field, T)
if (!isSumType!T)
{
    import std.format : format;
    import std.traits : isArray, isSomeString;

    static if (!isSomeString!T && isArray!T)
    {
        import std.range : ElementType;
        import std.string : chomp;

        enum Assign_ = format!q"EOS
            %s = %s.sequence.map!(a => %s).array;
EOS"(field, node, ctorStr!(ElementType!T)("a")).chomp;
    }
    else
    {
        enum Assign_ = format!"%s = %s;"(field, ctorStr!T(node));
    }
}

template Assign_(string node, string field, T)
if (isSumType!T)
{
    import std.format : format;
    static if (isOptional!T && T.Types.length == 2)
    {
        enum Assign_ = Assign_!(node, field, T.Types[1]);
    }
    else static if (isEither!T && T.Types.length == 1)
    {
        enum Assign_ = Assign_!(node, field, T[0]);
    }
    else
    {
        static if (isOptional!T)
        {
            alias Types = T.Types[1..$];
        }
        else static if (isEither!T)
        {
            alias Types = T.Types;
        }
        enum Assign_ = format!q"EOS
            {
                %s = (%s)(%s);
            }
EOS"(field, DispatchFun!(T, Types), node);
    }
}

template DispatchFun(RetType, Types...)
{
    import std.format : format;
    import std.meta : anySatisfy, Filter, staticMap;
    import std.traits : isArray, isSomeString;

    enum isNonStringArray(T) = !isSomeString!T && isArray!T;
    alias ArrayTypes = Filter!(isNonStringArray, Types);
    static if (ArrayTypes.length == 0)
    {
        enum ArrayStatement = "";
    }
    else
    {
        enum ArrayStatement = ArrayDispatchStatement!(RetType, ArrayTypes);
    }

    // TODO: field name `type` can be changed
    enum isRecord(T) = is(T == class) && !__traits(compiles, T.init.type_ = "");
    alias RecordTypes = Filter!(isRecord, Types);
    static if (RecordTypes.length == 0)
    {
        enum RecordStatement = "";
    }
    else
    {
        enum RecordStatement = RecordDispatchStatement!(RetType, RecordTypes);
    }

    enum isEnum(T) = is(T == class) && is(T.Types == enum);
    alias EnumTypes = Filter!(isEnum, Types);
    enum hasString = anySatisfy!(isSomeString, Types);
    static if (EnumTypes.length == 0)
    {
        static if (hasString)
        {
            enum EnumStatement = format!q"EOS
                if (a.type == NodeType.string)
                {
                    return %s(a.as!string);
                }
EOS"(RetType.stringof);
        }
        else
        {
            enum EnumStatement = "";
        }
    }
    else
    {
        enum EnumStatement = EnumDispatchStatement!(RetType, hasString, EnumTypes);
    }

    static assert(Types.length == 
        ArrayTypes.length + RecordTypes.length + EnumTypes.length + (hasString ? 1 : 0),
        format!"Internal error: Params: %s (%s) but Array: %s, Record: %s, Enum: %s and hasString: %s"(
            Types.stringof, Types.length, ArrayTypes.stringof, RecordTypes.stringof, EnumTypes.stringof,
            hasString
        ));

    import std.algorithm : filter, joiner;
    import std.array : array;
    import std.functional : not;
    import std.range : empty;
    enum FunBody = [
        ArrayStatement,
        RecordStatement,
        EnumStatement,
        `throw new Exception("");`
    ].filter!(not!empty).joiner("else ").array;

    enum DispatchFun = format!q"EOS
        (a) { %s }
EOS"(FunBody);
}

template ArrayDispatchStatement(RetType, ArrayTypes...)
{
    static if (ArrayTypes.length == 1)
    {
        import std.format : format;
        import std.range : ElementType;
        alias T = ElementType!(ArrayTypes[0]);
        static if (isEither!T)
        {
            enum ArrayDispatchStatement = format!q"EOS
                if (a.type == NodeType.sequence)
                {
                    return %s(a.sequence.map!(
                        %s
                    ).array);
                }
EOS"(RetType.stringof, DispatchFun!(T, T.Types));
        }
        else
        {
            enum ArrayDispatchStatement = format!q"EOS
                if (a.type == NodeType.sequence)
                {
                    return %s(a.sequence.map!(a => %s).array);
                }
EOS"(RetType.stringof, ctorStr!T("a"));
        }
    }
    else
    {
        // It is not used in CWL
        static assert(false, "It is not supported");
    }
}

template RecordDispatchStatement(RetType, RecordTypes...)
{
    import std.format : format;

    static if (RecordTypes.length == 1)
    {
        enum RecordDispatchStatement = format!q"EOS
            if (a.type == NodeType.mapping)
            {
                return %s(%s);
            }
EOS"(RetType.stringof, ctorStr!(RecordTypes[0])("a"));
    }
    else
    {
        import std.algorithm : joiner;
        import std.array : array;
        import std.meta : staticMap;

        enum RecordCaseStr(T) = format!q"EOS
            case "%s": return %s(%s);
EOS"(T.type_, RetType.stringof, ctorStr!T("a"));

        enum RecordDispatchStatement = format!q"EOS
            if (a.type == NodeType.mapping)
            {
                switch(a.edig("type").as!string)
                {
                %1$s
                default: throw new Exception("");
                }
            }
EOS"([staticMap!(RecordCaseStr, RecordTypes)].joiner("").array);
    }
}

template EnumDispatchStatement(RetType, bool hasString, EnumTypes...)
{
    import std.algorithm : joiner, map;
    import std.array : array;
    import std.format : format;
    import std.meta : staticMap;
    import std.traits : EnumMembers;

    enum EnumCaseStr(T) = format!q"EOS
        case %s: return %s(a.as!%s);
EOS"([EnumMembers!(T.Types)].map!(m => format!`"%s"`(cast(string)m))
                            .joiner(", ")
                            .array,
     RetType.stringof, T.stringof);
    static if (hasString)
    {
        enum DefaultStr = format!q"EOS
            return %s(value);
EOS"(RetType.stringof);
    }
    else
    {
        enum DefaultStr = `throw new Exception("");`;
    }
    enum EnumDispatchStatement = format!q"EOS
        if (a.type == NodeType.string)
        {
            auto value = a.as!string;
            switch(value)
            {
            %1$s
            default:
            %2$s
            }
        }
EOS"([staticMap!(EnumCaseStr, EnumTypes)].joiner("").array, DefaultStr);
}
