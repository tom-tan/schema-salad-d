/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.meta;

import salad.type;

import dyaml;

///
mixin template genCtor()
{
    import dyaml : Node, NodeType;
    import salad.context : LoadingContext;

    this() {}
    this(in Node node, in LoadingContext context = LoadingContext.init) @trusted
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
                mixin(Assign!(node, mixin(field), context));
            }
        }
    }
}

/**
 * Bugs: It does not work with self recursive classes
 */
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

///
mixin template genIdentifier()
{
    import std.traits : getSymbolsByUDA;

    static if (getSymbolsByUDA!(typeof(this), id).length == 1)
    {
        auto identifier() const @nogc nothrow pure @safe
        {
            import std.traits : Unqual;
            auto i = getSymbolsByUDA!(typeof(this), id)[0];
            alias idType = Unqual!(typeof(i));
            static assert(is(idType == string) || is(idType == Optional!string));
            static if (is(idType == string))
            {
                return i;
            }
            else
            {
                return i.match!(
                    (string s) => s,
                    none => "",
                );
            }
        }
    }
}

/**
 * UDA for identifier maps
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Identifier_maps
*/
struct idMap { string subject; string predicate = ""; }

/**
 * UDA for DSL for types
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Domain_Specific_Language_for_types
*/
struct typeDSL{}

/** 
 * UDA for documentRoot
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SaladRecordSchema
 */
struct documentRoot{}

/** 
 * UDA for identifier
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Record_field_annotations
 */
struct id{}

enum hasIdentifier(T) = __traits(compiles, { auto id = T.init.identifier(); });

///
template DocumentRootType(alias module_)
{
    import std.meta : allSatisfy, ApplyRight, Filter, staticMap;
    import std.traits : fullyQualifiedName, hasUDA;

    alias StrToType(string T) = __traits(getMember, module_, T);
    alias syms = staticMap!(StrToType, __traits(allMembers, module_));
    alias RootTypes = Filter!(ApplyRight!(hasUDA, documentRoot), syms);
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
    import std.meta : allSatisfy, Filter, staticMap;
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

enum isConstantMember(T, string M) = is(typeof(__traits(getMember, T, M)) == immutable string);

///
template Assign(alias node, alias field, alias context)
{
    import std.format : format;
    import std.traits : getUDAs, hasUDA, select;

    static if (hasUDA!(field, idMap))
    {
        enum idMap_ = getUDAs!(field, idMap)[0];
    }
    else
    {
        enum idMap_ = idMap.init;
    }

    alias T = typeof(field);

    enum param = field.stringof[0..$-1];

    static if (isOptional!T)
    {
        enum Assign = format!q"EOS
            if (auto f = "%s" in %s)
            {
                %s = (*f).as_!(%s, %s, %s)(%s);
            }
EOS"(param, node.stringof, field.stringof, T.stringof, hasUDA!(field, typeDSL), idMap_, context.stringof);
    }
    else
    {
        enum Assign = format!q"EOS
            %s = %s.edig("%s").as_!(%s, %s, %s)(%s);
EOS"(field.stringof, node.stringof, param, T.stringof, hasUDA!(field, typeDSL), idMap_, context.stringof);
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
    LoadingContext con;
    enum exp = Assign!(n, strVariable_, con).stripLeftAll;
    static assert(exp == q"EOS
        strVariable_ = n.edig("strVariable").as_!(string, false, idMap("", ""))(con);
EOS".stripLeftAll, exp);

    mixin(exp);
    assert(strVariable_ == "string value");
}

/// optional of non-array type
@safe unittest
{
    import std.exception : assertNotThrown;

    enum fieldName = "param";
    Node n = [fieldName: true];
    Optional!bool param_;
    LoadingContext con;
    enum exp = Assign!(n, param_, con).stripLeftAll;
    static assert(exp == q"EOS
        if (auto f = "param" in n)
        {
            param_ = (*f).as_!(SumType!(None, bool), false, idMap("", ""))(con);
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
    Node n = [fieldName: [1, 2, 3]];
    Optional!(int[]) params_;
    LoadingContext con;
    enum exp = Assign!(n, params_, con).stripLeftAll;
    static assert(exp == q"EOS
        if (auto f = "params" in n)
        {
            params_ = (*f).as_!(SumType!(None, int[]), false, idMap("", ""))(con);
        }
EOS".stripLeftAll, exp);

    mixin(exp);
    assert(params_.tryMatch!((int[] arr) => arr)
                  .assertNotThrown == [1, 2, 3]);
}

import salad.context : LoadingContext;

import std.typecons : Tuple;

alias ExplicitContext = Tuple!(Node, "node", LoadingContext, "context");

ExplicitContext splitContext(in Node node, string uri)
{
    if (node.type == NodeType.mapping)
    {
        LoadingContext con;
        if (auto base = "$base" in node)
        {
            con.baseURI = base.as!string;
        }
        else
        {
            con.baseURI = uri;
        }

        if (auto ns = "$namespaaces" in node)
        {
            import std.algorithm : map;
            import std.array : assocArray;
            import std.typecons : tuple;

            con.namespaces = ns.mapping
                .map!(a => tuple(a.key.as!string, a.value.as!string))
                .assocArray;
        }

        if (auto s = "$schemas" in node)
        {
            // TODO
            import std.algorithm : map;
            import std.array : array;
            auto schemas = s.sequence.map!(a => a.as!string).array;
        }

        if (auto g = "$graph" in node)
        {
            return typeof(return)(*g, con);
        }
        else
        {
            return typeof(return)(node, con);
        }
    }
    else
    {
        return typeof(return)(node, LoadingContext(uri));
    }
}

ExplicitContext resolveDirectives(in Node node, in LoadingContext context)
{
    if (node.type == NodeType.mapping)
    {
        import salad.resolver : resolveLink;

        if (auto link = "$import" in node)
        {
            import salad.fetcher : fetchNode;

            auto uri = resolveLink(link.as!string, context);
            return splitContext(uri.fetchNode, uri);
        }
        else if (auto link = "$include" in node)
        {
            import salad.fetcher : fetchText;

            auto uri = resolveLink(link.as!string, context);
            auto n = Node(uri.fetchText);
            return typeof(return)(n, cast()context);
        }
    }
    return typeof(return)(cast()node, cast()context);
}

T as_(T, bool typeDSL = false, idMap idMap_ = idMap.init)(in Node node, in LoadingContext context) @trusted
        if (is(T == class))
{
    auto resolved = resolveDirectives(node, context);
    return new T(resolved.node, resolved.context);
}

import std.traits : isScalarType;

T as_(T, bool typeDSL = false, idMap idMap_ = idMap.init)(in Node node, in LoadingContext context) @trusted
        if (isScalarType!T || isSomeString!T)
{
    auto resolved = resolveDirectives(node, context);
    return resolved.node.as!T;
}

import std.traits : isArray, isSomeString;

T as_(T, bool typeDSL = false, idMap idMap_ = idMap.init)(in Node node, in LoadingContext context) @trusted
        if (!isSomeString!T && isArray!T)
{
    import std.array : appender;
    import std.range : empty, ElementType;
    import salad.exception : docEnforce;

    static if (idMap_.subject.empty)
    {
        docEnforce(node.type == NodeType.sequence, "Sequence is expected but it is not", node);
        auto app = appender!T;
        foreach (elem; node.sequence)
        {
            alias E = ElementType!T;
            auto r = resolveDirectives(elem, context);
            if (r.node.type == NodeType.sequence)
            {
                import std.algorithm : map;
                import std.range : array;

                app.put(r.node.sequence.map!(n => n.as_!E(r.context)).array);
            }
            else
            {
                app.put(r.node.as_!E(r.context));
            }
        }
        return app[];
    }
    else
    {
        // map notation
        docEnforce(node.type == NodeType.sequence || node.type == NodeType.mapping,
            "Sequence or mapping is expected but it is not", node);
        if (node.type == NodeType.sequence)
        {
            return node.as_!(T, typeDSL)(context);
        }

        auto app = appender!T;
        foreach (kv; node.mapping)
        {
            auto key = kv.key.as!string;
            auto r = resolveDirectives(kv.value, context);
            auto value = r.node;
            auto newContext = r.context;
            Node elem;
            static if (idMap_.predicate.empty)
            {
                docEnforce(value.type == NodeType.mapping, "It must be a mapping", kv.value);
                elem = cast()value;
            }
            else
            {
                if (value.type == NodeType.mapping)
                {
                    elem = cast()value;
                }
                else
                {
                    elem.add(idMap_.predicate, value);
                }
            }
            alias E = ElementType!T;
            docEnforce(idMap_.subject !in elem, "Duplicated field", kv.key);
            elem.add(idMap_.subject, key);
            app.put(elem.as_!E(newContext));
        }
        return app[];
    }
}

T as_(T, bool typeDSL = false, idMap idMap_ = idMap.init)(in Node node, in LoadingContext context) @trusted
        if (isSumType!T)
{
    static if (isOptional!T)
    {
        alias Types = T.Types[1 .. $];
    }
    else
    {
        alias Types = T.Types;
    }

    static if (Types.length == 1)
    {
        auto r = resolveDirectives(node, context);
        return T(r.node.as_!(Types[0], typeDSL, idMap_)(r.context));
    }
    else
    {
        import std.meta : Filter;
        import salad.exception : DocumentException;

        auto r = resolveDirectives(node, context);
        Node expanded;
        static if (typeDSL && Filter!(isSomeString, Types).length > 0)
        {
            if (r.node.type == NodeType.string)
            {
                import std.algorithm : endsWith;

                auto s = r.node.as!string;
                if (s.endsWith("[]?"))
                {
                    expanded.add("null");
                    expanded.add([
                            "type": "array",
                            "items": s[0 .. $ - 3],
                        ]);
                }
                else if (s.endsWith("[]"))
                {
                    expanded.add([
                            "type": "array",
                            "items": s[0 .. $ - 2],
                        ]);
                }
                else if (s.endsWith("?"))
                {
                    expanded.add("null");
                    expanded.add(s[0 .. $ - 1]);
                }
                else
                {
                    expanded = Node(r.node);
                }
            }
            else
            {
                expanded = Node(r.node);
            }
        }
        else
        {
            expanded = Node(cast()r.node);
        }

        // dispatch
        enum isNonStringArray(T) = !isSomeString!T && isArray!T;
        alias ArrayTypes = Filter!(isNonStringArray, Types);
        static if (ArrayTypes.length > 0)
        {
            static assert(ArrayTypes.length == 1, "Type `T[] | U[] | ...` is not supported yet");
            if (expanded.type == NodeType.sequence)
            {
                return T(expanded.as_!(ArrayTypes[0])(r.context));
            }
        }

        enum isRecord(T) = is(T == class) && !__traits(compiles, T.Types);
        alias RecordTypes = Filter!(isRecord, Types);
        static if (RecordTypes.length == 1)
        {
            if (expanded.type == NodeType.mapping)
            {
                return T(expanded.as_!(RecordTypes[0])(r.context));
            }
        }
        else static if (RecordTypes.length > 0)
        {
            if (expanded.type == NodeType.mapping)
            {
                import salad.util : edig;
                import std.algorithm : joiner;
                import std.array : array;
                import std.meta : ApplyLeft, Filter, staticMap, templateNot;
                import std.traits : FieldNameTuple;

                enum ConstantMembersOf(T) = Filter!(ApplyLeft!(isConstantMember, T), FieldNameTuple!T);
                enum RecordTypeName = ConstantMembersOf!(RecordTypes[0])[0];
                enum isDispatchable(T) = ConstantMembersOf!T.length != 0 && ConstantMembersOf!T[0] == RecordTypeName;
                alias NonDispatchableRecords = Filter!(templateNot!isDispatchable, RecordTypes);

                auto id = expanded.edig(RecordTypeName[0 .. $ - 1]).as!string;
                static foreach (RT; Filter!(isDispatchable, RecordTypes))
                {
                    if (id == mixin("(new RT)." ~ RecordTypeName))
                    {
                        return T(expanded.as_!RT(r.context));
                    }
                }

                static if (NonDispatchableRecords.length == 0)
                {
                    throw new DocumentException("Unknown record type: " ~ id, expanded.edig(
                            RecordTypeName[0 .. $ - 1]));
                }
                else static if (NonDispatchableRecords.length == 1)
                {
                    return T(expanded.as_!(NonDispatchableRecords[0])(r.context));
                }
                else
                {
                    static assert(false,
                        "There are too many non-dispatchable record candidates: " ~
                            NonDispatchableRecords.stringof);
                }
            }
        }

        import std.meta : anySatisfy, Filter, staticMap;

        enum isEnum(T) = is(T == class) && is(T.Types == enum);
        alias EnumTypes = Filter!(isEnum, Types);
        enum hasString = anySatisfy!(isSomeString, Types);
        static if (EnumTypes.length > 0 || hasString)
        {                
            if (expanded.type == NodeType.string)
            {
                import std.algorithm : canFind;
                import std.traits : EnumMembers;

                auto value = expanded.as!string;
                static foreach(RT; EnumTypes)
                {
                    if ([EnumMembers!(RT.Types)].canFind(value))
                    {
                        return T(expanded.as_!RT(context));
                    }
                }
                static if (hasString)
                {
                    return T(value);
                }
                else
                {
                    throw new DocumentException("Unknown symbol value: "~value, expanded);
                }
            }
        }

        import std.traits : isIntegral;
        static if (Filter!(isIntegral, Types).length > 0)
        {
            if (expanded.type == NodeType.integer)
            {
                // TODO: long
                return T(expanded.as!int);
            }
        }

        // TODO: float, double

        static assert(Types.length ==
                ArrayTypes.length + RecordTypes.length + EnumTypes.length + (hasString ? 1 : 0) + Filter!(isIntegral, Types)
                .length,
                format!"Internal error: Params: %s (%s) but Array: %s, Record: %s, Enum: %s, hasString: %s, Integer: %s"(
                    Types.stringof, Types.length, ArrayTypes.stringof, RecordTypes.stringof, EnumTypes.stringof,
                    hasString, Filter!(isIntegral, Types).stringof
                ));
        throw new DocumentException("Unknown node type", expanded);
    }
}
