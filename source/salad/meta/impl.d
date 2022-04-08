/**
 * This module provides mixins and functions to implement parsers for each definition.
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.meta.impl;

import salad.context : LoadingContext;
import salad.meta.uda;
import salad.type;

import std.meta : ApplyLeft, Filter;
import std.traits : hasStaticMember, isArray, isScalarType, isSomeString;

import dyaml;

enum isSaladRecord(T) = is(T == class) && !__traits(compiles, T.Symbol);
enum isSaladEnum(T) = is(T == class) && __traits(compiles, T.Symbol);

///
mixin template genCtor()
{
    private import dyaml : Node, NodeType;
    private import salad.context : LoadingContext;
    private import salad.meta.impl : isSaladRecord, isSaladEnum;

    this() pure @nogc nothrow @safe {}

    static if (isSaladRecord!(typeof(this)))
    {
        this(in Node node, in LoadingContext context = LoadingContext.init) @safe
        {
            import salad.meta.impl : Assign, as_;
            import salad.util : edig;
            import salad.type : None, SumType;
            import std.algorithm : endsWith;
            import std.traits : FieldNameTuple;

            alias This = typeof(this);

            static foreach (field; FieldNameTuple!This)
            {
                static if (field.endsWith("_"))
                {
                    mixin(Assign!(node, __traits(getMember, this, field), context));
                }
            }
        }
    }
    else static if (isSaladEnum!(typeof(this)))
    {
        this(in Node node, in LoadingContext context = LoadingContext.init) @trusted
        {
            import salad.exception : docEnforce;
            import std.algorithm : canFind;
            import std.format : format;
            import std.traits : EnumMembers;

            docEnforce(node.type == NodeType.string,
                format!"Invalid type for %s: string is expected"(typeof(this).stringof),
                node);
            auto val = node.as!string;
            docEnforce([EnumMembers!Symbol].canFind(val),
                format!"Invalid value for %s: `%s`"(typeof(this).stringof, val),
                node);
            value_ = cast(Symbol)val;
        }

        this(string value) @safe
        {
            this(Node(value));
        }
    }
}

/**
 * Bugs: It does not work with self recursive classes
 */
version(none) mixin template genToString()
{
    override string toString() const @trusted
    {
        import salad.type : isEither, isOptional, match, None;
        import std.array : join;
        import std.format : format;
        import std.traits : FieldNameTuple;

        string[] fstrs;

        alias This = typeof(this);

        static foreach(field; FieldNameTuple!This)
        {
            static if (isOptional!(typeof(__traits(getMember, this, field))))
            {
                __traits(getMember, this, field).match!(
                    (None _) { },
                    (rest) { fstrs ~= format!"%s: %s"(field, rest); }
                );
            }
            else static if (isEither!(typeof(__traits(getMember, this, field))))
            {
                __traits(getMember, this, field).match!(f => fstrs ~= format!"%s: %s"(field, f));
            }
            else
            {
                fstrs ~= format!"%s: %s"(field, __traits(getMember, this, field));
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
                import salad.type : match;

                return i.match!(
                    (string s) => s,
                    none => "",
                );
            }
        }
    }
}

///
mixin template genOpEq()
{
    bool opEquals(string s) const @nogc nothrow pure @safe
    {
        return value_ == s;
    }
}

enum hasIdentifier(T) = __traits(compiles, { auto id = T.init.identifier(); });

enum isDefinedField(string F) = F[$-1] == '_';
enum StaticMembersOf(T) = Filter!(ApplyLeft!(hasStaticMember, T), Filter!(isDefinedField, __traits(derivedMembers, T)));

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

T as_(T, bool typeDSL = false, idMap idMap_ = idMap.init)(in Node node, in LoadingContext context) @trusted
        if (is(T == class))
{
    import salad.resolver : resolveDirectives;
    auto resolved = resolveDirectives(node, context);
    return new T(resolved.node, resolved.context);
}

T as_(T, bool typeDSL = false, idMap idMap_ = idMap.init)(in Node node, in LoadingContext context) @trusted
        if (isScalarType!T || isSomeString!T)
{
    import salad.resolver : resolveDirectives;
    auto resolved = resolveDirectives(node, context);
    return resolved.node.as!T;
}

T as_(T, bool typeDSL = false, idMap idMap_ = idMap.init)(in Node node, in LoadingContext context) @trusted
        if (!isSomeString!T && isArray!T)
{
    import std.array : appender;
    import std.range : empty, ElementType;
    import salad.exception : docEnforce;
    import salad.resolver : resolveDirectives;

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

                app.put(r.node.as_!T(r.context));
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
    import salad.resolver : resolveDirectives;

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

        alias RecordTypes = Filter!(isSaladRecord, Types);
        static if (RecordTypes.length == 0)
        {
            // nop
        }
        else static if (RecordTypes.length == 1)
        {
            if (expanded.type == NodeType.mapping)
            {
                return T(expanded.as_!(RecordTypes[0])(r.context));
            }
        }
        else
        {
            if (expanded.type == NodeType.mapping)
            {
                import salad.util : edig;
                import std.meta : Filter, templateNot;

                enum isDispatchable(T) = StaticMembersOf!T.length > 0;

                alias DispatchableRecords = Filter!(isDispatchable, RecordTypes);
                alias NonDispatchableRecords = Filter!(templateNot!isDispatchable, RecordTypes);
                static assert(NonDispatchableRecords.length < 2,
                    "There are too many non-dispatchable record candidates: " ~
                        NonDispatchableRecords.stringof);

                enum DispatchFieldName = StaticMembersOf!(DispatchableRecords[0])[0];

                if (auto id = DispatchFieldName[0..$-1] in expanded)
                {
                    switch (id.as!string)
                    {
                        static foreach (RT; DispatchableRecords)
                        {
                            case __traits(getMember, RT, DispatchFieldName): return T(expanded.as_!RT(r.context));
                        }
                    default:
                        throw new DocumentException("Unknown record type: " ~ id.as!string, expanded.edig(
                                DispatchFieldName[0 .. $ - 1]));
                    }
                }
                else
                {
                    static if (NonDispatchableRecords.length == 1)
                    {
                        return T(expanded.as_!(NonDispatchableRecords[0])(r.context));
                    }
                }
            }
        }

        import std.meta : anySatisfy, Filter, staticMap;

        alias EnumTypes = Filter!(isSaladEnum, Types);
        enum hasString = anySatisfy!(isSomeString, Types);
        static if (EnumTypes.length > 0 || hasString)
        {                
            if (expanded.type == NodeType.string)
            {
                import std.algorithm : canFind;
                import std.traits : EnumMembers;

                auto value = expanded.as!string;
                switch (value)
                {
                    static foreach(RT; EnumTypes)
                    {
                        static foreach(m; EnumMembers!(RT.Symbol))
                        {
                            case m: return T(expanded.as_!RT(context));
                        }
                    }
                    static if (hasString)
                    {
                        default: return T(value);
                    }
                    else
                    {
                        default: throw new DocumentException("Unknown symbol value: "~value, expanded);
                    }
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
        import std.format : format;
        static assert(Types.length ==
                ArrayTypes.length + RecordTypes.length + EnumTypes.length +
                    (hasString ? 1 : 0) + Filter!(isIntegral, Types)
                .length,
                format!"Internal error: %s (%s) but Array: %s, Record: %s, Enum: %s, hasString: %s, Integer: %s"(
                    Types.stringof, Types.length, ArrayTypes.stringof, RecordTypes.stringof, EnumTypes.stringof,
                    hasString, Filter!(isIntegral, Types).stringof
                ));
        throw new DocumentException(format!"Unknown node type for type %s: %s"(T.stringof, expanded.type), expanded);
    }
}
