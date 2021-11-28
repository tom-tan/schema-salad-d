/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.meta;

import salad.type;

import dyaml;

import std.meta : Filter;
import std.traits : isInstanceOf;

///
mixin template genCtor()
{
    import dyaml : Node, NodeType;

    this() {}
    this(in Node node) @trusted
    {
        import std.algorithm : endsWith;
        import std.traits : FieldNameTuple;

        alias This = typeof(this);

        static foreach(field; FieldNameTuple!This)
        {
            static if (field.endsWith("_") && !isConstantMember!(This, field))
            {
                // static if (This.stringof == "RecordField")
                //     pragma(msg, Assign!(node, mixin(field)));
                mixin("mixin(Assign!(node, "~field~"));");
            }
        }
    }
}

///
mixin template genToString()
{
    override string toString() const @trusted
    {
        import salad.type : isEither, isOptional, match;
        import std.array : join;
        import std.format : format;
        import std.traits : FieldNameTuple;

        string[] fstrs;

        alias This = typeof(this);

        static foreach(field; FieldNameTuple!This)
        {
            static if (isOptional!(typeof(mixin(field))))
            {
                mixin(field).match!((None _) { },
                                    (rest) { fstrs ~= format!"%s: %s"(field, rest); });
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
UDA for identifier maps
See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Identifier_maps
*/
struct idMap(string subject, string predicate = "") {}
struct IDMap { string subject; string predicate; }
enum bool isIDMap(alias uda) = isInstanceOf!(idMap, uda);
enum bool hasIDMap(alias symbol) = Filter!(isIDMap, __traits(getAttributes, symbol)).length > 0;
template getIDMap(alias value)
{
    import std.traits : TemplateArgsOf;

    static if (isIDMap!value)
    {
        enum getIDMap = IDMap(TemplateArgsOf!value);
    }
    else static if (hasIDMap!value)
    {
        alias uda = Filter!(isIDMap, __traits(getAttributes, value))[0];
        enum getIDMap = IDMap(TemplateArgsOf!uda);
    }
    else
    {
        enum getIDMap = IDMap.init;
    }
}

/**
UDA for DSL for types
See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Domain_Specific_Language_for_types
*/
struct typeDSL{}
enum bool isTypeDSL(alias uda) = is(uda == typeDSL);
enum bool hasTypeDSL(alias symbol) = Filter!(isTypeDSL, __traits(getAttributes, symbol)).length > 0;

/** 
 * UDA for documentRoot
 */
struct documentRoot{}
enum bool isDocumentRoot(alias uda) = is(uda == documentRoot);
enum bool hasDocumentRoot(alias symbol) = Filter!(isDocumentRoot, __traits(getAttributes, symbol)).length > 0;

enum hasIdentifier(T) = __traits(compiles, { auto id = T.init.identifier(); });

///
template DocumentRootType(alias module_)
{
    import std.meta : allSatisfy, staticMap;
    import std.traits : fullyQualifiedName;

    alias StrToType(string T) = __traits(getMember, module_, T);
    alias syms = staticMap!(StrToType, __traits(allMembers, module_));
    alias RootTypes = Filter!(hasDocumentRoot, syms);
    static if (RootTypes.length > 0)
    {
        static assert(allSatisfy!(hasIdentifier, RootTypes));
        alias DocumentRootType = SumType!RootTypes;
    }
    else
    {
        import std.format : format;
        import std.traits : moduleName;
        static assert(false, format!"No schemas with `documentRoot: true` in module `%s`"(moduleName!module_));
    }
}

///
template IdentifierType(alias module_)
{
    import std.meta : allSatisfy, staticMap;
    import std.traits : fullyQualifiedName;

    alias StrToType(string T) = __traits(getMember, module_, T);
    alias syms = staticMap!(StrToType, __traits(allMembers, module_));
    alias IDTypes = Filter!(hasIdentifier, syms);

    static if (IDTypes.length > 0)
    {
        alias IdentifierType = SumType!IDTypes;
    }
    else
    {
        static assert(false, "No schemas with identifier field");
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

enum isConstantMember(T, string M) = is(typeof(mixin("T.init."~M)) == immutable string);

///
template Assign(alias node, alias field)
{
    import std.format : format;

    enum typeDSL = hasTypeDSL!field;
    enum idMap = getIDMap!field;

    alias T = typeof(field);

    enum param = field.stringof[0..$-1];

    enum ImportList = q"EOS
            import salad.util : edig;
            import std.algorithm : map;
            import std.array : array;
EOS";

    static if (isOptional!T)
    {
        enum Assign = ImportList~format!q"EOS
            if (auto f = "%s" in %s)
            {
                %s
            }
EOS"(param, node.stringof, Assign_!("(*f)", field.stringof, T, typeDSL, idMap));
    }
    else static if (isEither!T)
    {
        enum Assign = ImportList~Assign_!(format!`%s.edig("%s")`(node.stringof, param), field.stringof, T, typeDSL, idMap);
    }
    else
    {
        enum Assign = ImportList~Assign_!(format!`%s.edig("%s")`(node.stringof, param), field.stringof, T, typeDSL, idMap);
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
    enum exp = Assign!(n, strVariable_).stripLeftAll;
    static assert(exp == q"EOS
        import salad.util : edig;
        import std.algorithm : map;
        import std.array : array;
        strVariable_ = n.edig("strVariable").as!string;
EOS".stripLeftAll, exp);

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
        import salad.util : edig;
        import std.algorithm : map;
        import std.array : array;
        if (auto f = "param" in n)
        {
            param_ = (*f).as!bool;
        }
EOS".stripLeftAll, exp);

    mixin(exp);
    assert(param_.tryMatch!((bool b) => b)
                 .assertNotThrown);
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
        import salad.util : edig;
        import std.algorithm : map;
        import std.array : array;
        if (auto f = "params" in n)
        {
            params_ = (*f).sequence.map!((a)
            {
                int ret;
                ret = a.as!int;
                return ret;
            }).array;
        }
EOS".stripLeftAll, exp);

    mixin(exp);
    assert(params_.tryMatch!((int[] arr) => arr)
                  .assertNotThrown == [1, 2, 3]);
}

template Assign_(string node, string field, T, bool typeDSL = false, IDMap idMap = IDMap.init)
if (!isSumType!T)
{
    import std.format : format;
    import std.traits : isArray, isSomeString;

    static if (!isSomeString!T && isArray!T)
    {
        import std.range : ElementType, empty;
        import std.string : chomp;

        enum AssignBase = format!q"EOS
            %s = %s.sequence.map!((a) {
                %s ret;
                %s
                return ret;
            }).array;
EOS"(field, node, (ElementType!T).stringof, Assign_!("a", "ret", ElementType!T)).chomp;

        static if (idMap.subject.empty)
        {
            enum Assign_ = AssignBase;
        }
        else
        {
            static if (idMap.predicate.empty)
            {
                enum Trans = format!q"EOS
                    Node a_ = a.value;
                    a_.add("%s", a.key);
                    %s ret;
                    %s
                    return ret;
EOS"(idMap.subject, (ElementType!T).stringof, Assign_!("a_", "ret", ElementType!T));
            }
            else
            {
                enum Trans = format!q"EOS
                    Node a_;
                    a_.add("%1$s", a.key);
                    if (a.value.type == NodeType.mapping && "%2$s" in a.value)
                    {
                        foreach(kv; a.value.mapping)
                        {
                            a_.add(kv.key, kv.value);
                        }
                    }
                    else
                    {
                        a_.add("%2$s", a.value);
                    }
                    return %3$s;
EOS"(idMap.subject, idMap.predicate, ctorStr!(ElementType!T)("a_"));
            }

            enum Assign_ = format!q"EOS
                if (%2$s.type == NodeType.sequence)
                {
                    %3$s
                }
                else
                {
                    %1$s = %2$s.mapping.map!((a) {
                        %4$s
                    }).array;
                }
EOS"(field, node, AssignBase, Trans);
        }
    }
    else
    {
        static assert(idMap == IDMap.init);
        enum Assign_ = format!"%s = %s;"(field, ctorStr!T(node));
    }
}

template Assign_(string node, string field, T, bool typeDSL = false, IDMap idMap = IDMap.init)
if (isSumType!T)
{
    import std.format : format;
    static if (isOptional!T && T.Types.length == 2)
    {
        enum Assign_ = Assign_!(node, field, T.Types[1], typeDSL, idMap);
    }
    else static if (isEither!T && T.Types.length == 1)
    {
        enum Assign_ = Assign_!(node, field, T[0], typeDSL, idMap);
    }
    else
    {
        import std.traits : isSomeString;

        static if (isOptional!T)
        {
            alias Types = T.Types[1..$];
        }
        else static if (isEither!T)
        {
            alias Types = T.Types;
        }
        static if (typeDSL && Filter!(isSomeString, Types).length > 0)
        {
            enum Pre = format!q"EOS
                Node n;
                if (%1$s.type == NodeType.string)
                {
                    import std.algorithm : endsWith;
                    auto s = %1$s.as!string;
                    if (s.endsWith("[]?"))
                    {
                        n.add("null");
                        n.add([
                            "type": "array",
                            "items": s[0..$-3],
                        ]);
                    }
                    else if (s.endsWith("[]"))
                    {
                        n.add([
                            "type": "array",
                            "items": s[0..$-2],
                        ]);
                    }
                    else if (s.endsWith("?"))
                    {
                        n.add("null");
                        n.add(s[0..$-1]);
                    }
                    else
                    {
                        n = Node(s);
                    }
                }
                else
                {
                    n = %1$s;
                }
EOS"(node);
        }
        else
        {
            enum Pre = format!q"EOS
                Node n = %s;
EOS"(node);
        }
        enum Assign_ = format!q"EOS
            {
                %s
                %s = (%s)(n);
            }
EOS"(Pre, field, DispatchFun!(T, Types));
    }
}

template DispatchFun(RetType, Types...)
{
    import std.format : format;
    import std.meta : anySatisfy, Filter, staticMap;
    import std.traits : isArray, isIntegral, isSomeString;

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

    enum isRecord(T) = is(T == class) && !__traits(compiles, T.Types);
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

    static if (Filter!(isIntegral, Types).length == 0)
    {
        enum NumStatement = "";
    }
    else
    {
        enum NumStatement = format!q"EOS
                if (a.type == NodeType.integer)
                {
                    return %s(a.as!int);
                }
EOS"(RetType.stringof);
    }

    static assert(Types.length == 
        ArrayTypes.length + RecordTypes.length + EnumTypes.length + (hasString ? 1 : 0) + Filter!(isIntegral, Types).length,
        format!"Internal error: Params: %s (%s) but Array: %s, Record: %s, Enum: %s, hasString: %s, Integer: %s"(
            Types.stringof, Types.length, ArrayTypes.stringof, RecordTypes.stringof, EnumTypes.stringof,
            hasString, Filter!(isIntegral, Types).stringof
        ));

    import std.algorithm : filter, joiner;
    import std.array : array;
    import std.functional : not;
    import std.range : empty;
    enum FunBody = [
        ArrayStatement,
        RecordStatement,
        EnumStatement,
        NumStatement,
        `throw new DocumentException("Unknown node type in DispatchFun", a);`
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
        import std.meta : ApplyLeft, staticMap, templateNot;
        import std.traits : FieldNameTuple;

        enum ConstantMembersOf(T) = Filter!(ApplyLeft!(isConstantMember, T), FieldNameTuple!T);
        enum RecordTypeName = ConstantMembersOf!(RecordTypes[0])[0];
        enum isDispatchable(T) = ConstantMembersOf!T.length != 0 && ConstantMembersOf!T[0] == RecordTypeName;
        alias NonDispatchableRecords = Filter!(templateNot!isDispatchable, RecordTypes);
        static assert(NonDispatchableRecords.length <= 1,
                      "There are too many non-dispatchable record candidates: "~NonDispatchableRecords.stringof);

        static if (NonDispatchableRecords.length == 0)
        {
            enum DefaultCaseStr = format!q"EOS
            default: throw new DocumentException("Unknown record type: "~a.edig("%1$s").as!string, a.edig("%1$s"));
EOS"(RecordTypeName[0..$-1]);
        }
        else
        {
            enum DefaultCaseStr = format!q"EOS
            default: return %s(%s);
EOS"(RetType.stringof, ctorStr!(NonDispatchableRecords[0])("a"));
        }

        enum RecordCaseStr(T) = format!q"EOS
            case "%s": return %s(%s);
EOS"(mixin("(new T)."~RecordTypeName), RetType.stringof, ctorStr!T("a"));

        enum RecordDispatchStatement = format!q"EOS
            if (a.type == NodeType.mapping)
            {
                switch(a.edig("%1$s").as!string)
                {
                %2$s
                %3$s
                }
            }
EOS"(RecordTypeName[0..$-1],
     [staticMap!(RecordCaseStr, Filter!(isDispatchable, RecordTypes))].joiner("").array,
     DefaultCaseStr);
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
        enum DefaultStr = `throw new DocumentException("Unknown symbol value: "~a.as!string, a);`;
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
