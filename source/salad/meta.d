module salad.meta;

import salad.type;

import dyaml;

import sumtype;

///
template Assign(alias node, alias field)
{
    alias Attrs = __traits(getAttributes, field);
    static if (Attrs.length == 0)
    {
        enum Assign = Assign!(node, field, field.stringof);
    }
    else
    {
        enum Assign = Assign!(node, field, Attrs[0]);
    }
}

///
template Assign(alias node, alias field, string fieldName)
if (!isOptional!(typeof(field)) && !isEither!(typeof(field)))
{
    import std.format : format;
    import std.traits : isArray, isSomeString;

    alias FieldType = typeof(field);

    static if (!isSomeString!FieldType && isArray!FieldType)
    {
        import std.range : ElementType;

        enum Assign = format!q"EOS
            import salad.util : edig;
            import std.algorithm : map;
            import std.array : array;
            %2$s = %1$s.edig("%3$s").sequence.map!(a => a.as!%4$s).array;
EOS"(node.stringof, field.stringof, fieldName, (ElementType!FieldType).stringof);
    }
    else
    {
        enum Assign = format!q"EOS
            import salad.util : edig;
            %2$s = %1$s.edig("%3$s").as!%4$s;
EOS"(node.stringof, field.stringof, fieldName, FieldType.stringof);

    }
}

//
@safe unittest
{
    import std.exception : assertNotThrown;
    import std.string : outdent;

    enum fieldName = "fieldName";
    Node n = [ fieldName: "string value" ];
    string strVariable;
    enum exp = Assign!(n, strVariable, fieldName).outdent;
    static assert(exp == q"EOS
        import salad.util : edig;
        strVariable = n.edig("fieldName").as!string;
EOS".outdent, exp);

    mixin(exp);
    assert(strVariable == "string value");
}

///
template Assign(alias node, alias field, string fieldName)
if (isOptional!(typeof(field)))
{
    import std.format : format;
    import std.traits : isArray, isSomeString;

    alias FieldType = field.Types[1];

    static if (!isSomeString!FieldType && isArray!FieldType)
    {
        import std.range : ElementType;

        enum Assign = format!q"EOS
            if (auto f = "%3$s" in %1$s)
            {
                import std.algorithm : map;
                import std.array : array;
                %2$s = f.sequence.map!(a => a.as!%4$s).array;
            }
EOS"(node.stringof, field.stringof, fieldName, (ElementType!FieldType).stringof);
    }
    else
    {
        enum Assign = format!q"EOS
            if (auto f = "%3$s" in %1$s)
            {
                %2$s = f.as!%4$s;
            }
EOS"(node.stringof, field.stringof, fieldName, FieldType.stringof);
    }
}

// optional of non-array type
@safe unittest
{
    import std.exception : assertNotThrown;
    import std.string : outdent;

    enum fieldName = "fieldName";
    Node n = [ fieldName: true ];
    Optional!bool param;
    enum exp = Assign!(n, param, fieldName).outdent;
    static assert(exp == q"EOS
        if (auto f = "fieldName" in n)
        {
            param = f.as!bool;
        }
EOS".outdent, exp);

    mixin(exp);
    assertNotThrown(param.tryMatch!((bool b) => assert(b)));
}

// optional of array type
unittest
{
    import std.exception : assertNotThrown;
    import std.string : outdent;

    enum fieldName = "fieldName";
    Node n = [ fieldName: [1, 2, 3] ];
    Optional!(int[]) params;
    enum exp = Assign!(n, params, fieldName).outdent;
    static assert(exp == q"EOS
        if (auto f = "fieldName" in n)
        {
            import std.algorithm : map;
            import std.array : array;
            params = f.sequence.map!(a => a.as!int).array;
        }
EOS".outdent, exp);

    mixin(exp);
    assertNotThrown(params.tryMatch!((int[] arr) => assert(arr == [1, 2, 3])));
}

template Assign(alias node, alias field, string fieldName)
if (isEither!(typeof(field)))
{
    import std.format : format;
    alias Types = field.Types;

    static if (is(Types[0] == None))
    {
        enum Assign = format!q"EOS
            if (auto f = "%2$s" in %1$s)
            {
                %3$s = (%4$s)(*f);
            }
EOS"(node.stringof, fieldName, field.stringof,
     DispatchFun!(typeof(field), Types[1..$]));
    }
    else
    {
        enum Assign = format!q"EOS
            {
                auto f = %1$s.edig("%2$s");
                %3$s = (%4$s)(f);
            }
EOS"(node.stringof, fieldName, field.stringof,
     DispatchFun!(typeof(field), Types));
    }
}

template DispatchFun(FieldType, Types...)
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
        enum ArrayStatement = ArrayDispatchStatement!(FieldType, ArrayTypes);
    }

    // TODO: field name `type` can be changed
    enum isRecord(T) = is(T == class) && !__traits(compiles, T.init.type = "");
    alias RecordTypes = Filter!(isRecord, Types);
    static if (RecordTypes.length == 0)
    {
        enum RecordStatement = "";
    }
    else
    {
        enum RecordStatement = RecordDispatchStatement!(FieldType, RecordTypes);
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
EOS"(FieldType.stringof);
        }
        else
        {
            enum EnumStatement = "";
        }
    }
    else
    {
        enum EnumStatement = EnumDispatchStatement!(FieldType, hasString, EnumTypes);
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

template ArrayDispatchStatement(FieldType, ArrayTypes...)
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
                    import std.algorithm : map;
                    import std.array :array;
                    return %1$s(a.sequence.map!(
                        %2$s
                    ).array);
                }
EOS"(FieldType.stringof, DispatchFun!(T, T.Types));
        }
        else
        {
            enum ArrayDispatchStatement = format!q"EOS
                if (a.type == NodeType.sequence)
                {
                    import std.algorithm : map;
                    import std.array :array;
                    return %1$s(a.sequence.map!(a => a.as!%2$s).array);
                }
EOS"(FieldType.stringof, T.stringof);
        }
    }
    else
    {
        // It is not used in CWL
        static assert(false, "It is not supported");
    }
}

template RecordDispatchStatement(FieldType, RecordTypes...)
{
    import std.format : format;

    static if (RecordTypes.length == 1)
    {
        enum RecordDispatchStatement = format!q"EOS
            if (a.type == NodeType.mapping)
            {
                return %1$s(a.as!%2$s);
            }
EOS"(FieldType.stringof, RecordTypes[0].stringof);
    }
    else
    {
        import std.algorithm : joiner;
        import std.array : array;
        import std.meta : staticMap;

        enum RecordCaseStr(T) = format!q"EOS
            case "%1$s": return %2$s(a.as!%3$s);
EOS"(T.type, FieldType.stringof, T.stringof);

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

template EnumDispatchStatement(FieldType, bool hasString, EnumTypes...)
{
    import std.algorithm : joiner, map;
    import std.array : array;
    import std.format : format;
    import std.meta : staticMap;
    import std.traits : EnumMembers;

    enum EnumCaseStr(T) = format!q"EOS
        case %1$s: return %2$s(a.as!%3$s);
EOS"([EnumMembers!(T.Types)].map!(m => format!`"%s"`(cast(string)m))
                            .joiner(", ")
                            .array,
     FieldType.stringof, T.stringof);
    static if (hasString)
    {
        enum DefaultStr = format!q"EOS
            return %1$s(value);
EOS"(FieldType.stringof);
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
