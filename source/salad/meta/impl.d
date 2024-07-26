/**
 * This module provides mixins and functions to implement parsers for each definition.
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.meta.impl;

import salad.context : LoadingContext;
import salad.primitives : Any, SchemaBase;
import salad.meta.uda;
import salad.type;

import std.meta : ApplyLeft, Filter;
import std.traits : hasStaticMember, isArray, isScalarType, isSomeString, Unqual;

import dyaml;

enum isSaladRecord(T) = is(Unqual!T : SchemaBase) && !is(Unqual!T : Any) && !__traits(compiles, T.Symbol);
enum isSaladEnum(T) = is(Unqual!T : SchemaBase) && !is(Unqual!T : Any) && __traits(compiles, T.Symbol);

enum defaultSaladVersion = "v1.1";

///
mixin template genCtor_(string saladVersion_)
{
    private import dyaml : Node, NodeType;
    private import salad.context : LoadingContext;
    private import salad.meta.impl : isSaladRecord, isSaladEnum;

    static assert(is(typeof(this) : SchemaBase));

    enum saladVersion = saladVersion_;

    this() @safe
    {
        import salad.meta.impl : hasIdentifier;
        import std.traits : FieldNameTuple, getSymbolsByUDA, hasUDA;

        alias This = typeof(this);

        super();
        static if (hasIdentifier!This)
        {
            identifier = "";
        }

        static if (isSaladRecord!This)
        {
            Node unused = (Node[string]).init;
            static foreach (field; FieldNameTuple!This)
            {
                import salad.meta.uda : defaultValue;
                static if (hasUDA!(__traits(getMember, this, field), defaultValue))
                {
                    import dyaml : YAMLNull;
                    import salad.meta.impl : Assign, as_;
                    import std : endsWith, format;
                    static assert(
                        field.endsWith("_"),
                        format!"Bug in the generated parser: Invalid field name with @defaultValue: %s.%s"(
                            This.stringof, field,
                        )
                    );
                    mixin(Assign!(unused, __traits(getMember, this, field), LoadingContext.init));
                }
            }
        }
    }

    static if (isSaladRecord!(typeof(this)))
    {
        this(Node node, in LoadingContext context = LoadingContext.init) @trusted
        {
            import dyaml : Mark;
            import salad.exception : docEnforce;
            import salad.meta.impl : Assign, as_, hasIdentifier, StaticMembersOf;
            import salad.meta.uda : LinkResolver;
            import salad.util : edig;
            import salad.type : None, Optional, SumType;
            import std.algorithm : endsWith;
            import std.container : make, RedBlackTree;
            import std.conv : to;
            import std.format : format;
            import std.range : empty;
            import std.traits : getSymbolsByUDA, FieldNameTuple, hasUDA;

            alias This = typeof(this);

            auto rest = make!(RedBlackTree!string)(node.mappingKeys!string);

            static foreach(m; StaticMembersOf!This)
            {
                static if (m.endsWith("_"))
                {
                    auto val = docEnforce(
                        m[0..$-1] in node,
                        format!"Missing field `%s` in %s"(m[0..$-1], This.stringof),
                        node.startMark,
                    );
                    docEnforce(
                        __traits(getMember, this, m) == val.as!string,
                        format!"Conflict the value of %s.%s (Expected: %s, Actual: %s)"(
                            This.stringof, m[0..$-1], __traits(getMember, this, m), val.as!string
                        ),
                        node.startMark,
                    );
                    rest.removeKey(m[0..$-1]);
                }
            }

            static if (hasIdentifier!This)
            {
                mixin(Assign!(node, getSymbolsByUDA!(This, id)[0], context));
                rest.removeKey(getSymbolsByUDA!(This, id)[0].stringof[5..$-1]);

                identifier = (() {
                    import salad.resolver : resolveIdentifier;
                    import std.traits : Unqual;
                    auto i = getSymbolsByUDA!(This, id)[0];
                    alias idType = Unqual!(typeof(i));
                    static assert(is(idType == string) || is(idType == Union!(None, string)));
                    static if (is(idType == string))
                    {
                        return i.resolveIdentifier(context);
                    }
                    else
                    {
                        import salad.type : match;

                        return i.match!(
                            (string s) => s.resolveIdentifier(context),
                            none => "",
                        );
                    }
                })();

                static immutable idFieldName = getSymbolsByUDA!(This, id)[0].stringof;

                auto con = LoadingContext(
                    identifier.empty ? context.baseURI : identifier,
                    context.fileURI,
                    context.namespaces.to!(string[string]),
                    context.subscope,
                    context.schemas.dup,
                );
            }
            else
            {
                static immutable idFieldName = "";
                auto con = context;
            }

            super(node.startMark, con);

            static foreach (field; FieldNameTuple!This)
            {
                static if (field.endsWith("_") && field != idFieldName~"_")
                {
                    mixin(Assign!(node, __traits(getMember, this, field), con));
                    rest.removeKey(field[0..$-1]);
                }
            }

            foreach(f; rest[])
            {
                import salad.primitives : Any;
                import salad.resolver : resolveLink;
                import std : canFind, format;

                if (["$base", "$namespaces", "$schemas", "$graph"].canFind(f))
                {
                    continue;
                }

                docEnforce(
                    f.canFind(":"),
                    format!"Invalid field found: `%s` in %s"(f, This.stringof),
                    node.startMark,
                );
                auto resolved = f.resolveLink(con);
                extension_fields[resolved] = node[f].as_!Any(con);
            }
        }
    }
    else static if (isSaladEnum!(typeof(this)))
    {
        this(Node node, in LoadingContext context = LoadingContext.init) @safe
        {
            import dyaml : Mark;
            import salad.exception : docEnforce;
            import std.algorithm : canFind;
            import std.format : format;
            import std.traits : EnumMembers;

            docEnforce(node.type == NodeType.string,
                format!"Invalid type for %s: string is expected"(typeof(this).stringof),
                node.startMark);
            auto val = node.as!string;
            docEnforce([EnumMembers!Symbol].canFind(val),
                format!"Invalid value for %s: `%s`"(typeof(this).stringof, val),
                node.startMark);
            super(node.startMark, context);
            value = cast(Symbol)val;
        }

        this(string value) @safe
        {
            this(Node(value));
        }
    }
}

///
mixin template genIdentifier()
{
    private import std.traits : getSymbolsByUDA;

    static if (getSymbolsByUDA!(typeof(this), id).length == 1)
    {
        string identifier;
    }
}

///
mixin template genOpEq()
{
    bool opEquals(string s) const @nogc nothrow pure @safe
    {
        return value == s;
    }
}

enum hasIdentifier(T) = __traits(compiles, { auto id = T.init.identifier; });

enum isDefinedField(string F) = F[$-1] == '_';
enum StaticMembersOf(T) = Filter!(ApplyLeft!(hasStaticMember, T), Filter!(isDefinedField, __traits(derivedMembers, T)));

///
template Assign(alias node, alias field, alias context, string file = __FILE__, size_t line = __LINE__)
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

    static if (hasUDA!(field, link))
    {
        enum lresolver = getUDAs!(field, link)[0].resolver;
    }
    else
    {
        enum lresolver = LinkResolver.none;
    }

    alias T = typeof(field);

    enum param = field.stringof[0..$-1];

    static if (isOptional!T)
    {
        enum Assign = format!q"EOS
            #line %s "%s"
            if (auto f = "%s" in %s)
            {
                if (f.type == NodeType.null_)
                {
                    %s = None();
                }
                else
                {
                    %s = (*f).as_!(%s, %s, %s, LinkResolver.%s, %s)(%s);
                }
            }
EOS"(line, file, param, node.stringof, field.stringof, field.stringof,
    T.stringof, hasUDA!(field, typeDSL), idMap_, lresolver, hasUDA!(field, secondaryFilesDSL), context.stringof);
    }
    else static if (hasUDA!(field, defaultValue))
    {
        enum defValue = getUDAs!(field, defaultValue)[0].value;
        enum Assign = format!q"EOS
            #line %s "%s"
            {
                import dyaml : YAMLNull;

                Node f = YAMLNull();
                if (auto f_ = "%s" in %s)
                {
                    f = *f_;
                }
                if (f.type == NodeType.null_)
                {
                    import dyaml : Loader;
                    import std : assertNotThrown;
                    f = Loader.fromString(q"<%s>").load.assertNotThrown("Bug in the generated parser");
                }
                %s = f.as_!(%s, %s, %s, LinkResolver.%s, %s)(%s);
            }
EOS"(line, file, param, node.stringof, defValue,
field.stringof, T.stringof, hasUDA!(field, typeDSL), idMap_, lresolver, hasUDA!(field, secondaryFilesDSL),
context.stringof);
    }
    else
    {
        enum Assign = format!q"EOS
            #line %s "%s"
            %s = %s.edig("%s").as_!(%s, %s, %s, LinkResolver.%s, %s)(%s);
EOS"(line, file, field.stringof, node.stringof, param,
T.stringof, hasUDA!(field, typeDSL), idMap_, lresolver, hasUDA!(field, secondaryFilesDSL), context.stringof);
    }
}

version(unittest)
{
    auto stripLeftAll(string str) nothrow pure @safe
    {
        import std.algorithm : map;
        import std.array : array, join;
        import std.string : split, stripLeft;
        return str.split("\n").map!stripLeft.join("\n");
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

    mixin(Assign!(n, strVariable_, con));
    assert(strVariable_ == "string value");
}

/// optional of non-array type
@safe unittest
{
    import std.exception : assertNotThrown;

    enum fieldName = "param";
    Node n = [fieldName: true];
    Union!(None, bool) param_;
    LoadingContext con;

    mixin(Assign!(n, param_, con));
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
    Union!(None, int[]) params_;
    LoadingContext con;

    mixin(Assign!(n, params_, con));
    assert(params_.tryMatch!((int[] arr) => arr)
                  .assertNotThrown == [1, 2, 3]);
}

T as_(T, bool typeDSL = false, idMap idMap_ = idMap.init,
      LinkResolver lresolver = LinkResolver.none, bool secondaryFilesDSL = false)
     (Node node, in LoadingContext context) @trusted
        if (is(T : SchemaBase))
{
    import salad.resolver : resolveDirectives;
    auto resolved = resolveDirectives(node, context);
    static if (is(T : Any))
    {
        enum saladVersion = defaultSaladVersion;
    }
    else
    {
        enum saladVersion = T.saladVersion;
    }
    auto expanded = expandDSL!(saladVersion, typeDSL, secondaryFilesDSL)(resolved.node);
    return new T(expanded, resolved.context);
}

T as_(T, bool typeDSL = false, idMap idMap_ = idMap.init, 
      LinkResolver lresolver = LinkResolver.none, bool secondaryFilesDSL = false)
     (Node node, in LoadingContext context) @trusted
        if (isScalarType!T || isSomeString!T)
{
    import salad.resolver : resolveDirectives, resolveIdentifier, resolveLink;
    auto resolved = resolveDirectives(node, context);
    auto ret = resolved.node.as!T;
    static if (isSomeString!T && lresolver == LinkResolver.link)
    {
        return ret.resolveLink(resolved.context);
    }
    else static if (isSomeString!T && lresolver == LinkResolver.id)
    {
        return ret.resolveIdentifier(resolved.context);
    }
    else
    {
        return ret;
    }
}

T as_(T, bool typeDSL = false, idMap idMap_ = idMap.init,
      LinkResolver lresolver = LinkResolver.none, bool secondaryFilesDSL = false)
     (Node node, in LoadingContext context) @trusted
        if (!isSomeString!T && isArray!T)
{
    import std.array : appender;
    import std.range : empty, ElementType;
    import salad.exception : docEnforce;
    import salad.resolver : resolveDirectives;

    auto resolved = resolveDirectives(node, context);

    static if (idMap_.subject.empty)
    {
        docEnforce(
            resolved.node.type == NodeType.sequence,
            "Sequence is expected but it is not",
            resolved.node.startMark
        );
        auto app = appender!T;
        foreach (elem; resolved.node.sequence)
        {
            alias E = ElementType!T;
            auto r = resolveDirectives(elem, resolved.context);
            if (r.node.type == NodeType.sequence)
            {
                import std.algorithm : map;
                import std.range : array;
                app.put(r.node.as_!(T, typeDSL, idMap.init, lresolver, secondaryFilesDSL)(r.context));
            }
            else
            {
                app.put(r.node.as_!(E, typeDSL, idMap.init, lresolver, secondaryFilesDSL)(r.context));
            }
        }
        return app[];
    }
    else
    {
        // map notation
        docEnforce(resolved.node.type == NodeType.sequence || resolved.node.type == NodeType.mapping,
            "Sequence or mapping is expected but it is not", resolved.node.startMark);
        if (resolved.node.type == NodeType.sequence)
        {
            return resolved.node.as_!(T, typeDSL, idMap.init, LinkResolver.none, secondaryFilesDSL)(resolved.context);
        }

        auto app = appender!T;
        foreach (kv; resolved.node.mapping)
        {
            auto key = kv.key.as!string;
            auto r = resolveDirectives(kv.value, resolved.context);
            auto value = r.node;
            auto newContext = r.context;
            Node elem;
            static if (idMap_.predicate.empty)
            {
                docEnforce(value.type == NodeType.mapping, "It must be a mapping", kv.value.startMark);
                elem = value;
            }
            else
            {
                if (value.type == NodeType.mapping)
                {
                    elem = value;
                }
                else
                {
                    elem.add(idMap_.predicate, value);
                }
            }
            alias E = ElementType!T;
            docEnforce(idMap_.subject !in elem, "Duplicated field", kv.key.startMark);
            elem.add(idMap_.subject, key);
            app.put(elem.as_!E(newContext));
        }
        return app[];
    }
}

T as_(T, bool typeDSL = false, idMap idMap_ = idMap.init,
      LinkResolver lresolver = LinkResolver.none, bool secondaryFilesDSL = false)
     (Node node, in LoadingContext context) @trusted
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
        return T(r.node.as_!(Types[0], typeDSL, idMap_, lresolver, secondaryFilesDSL)(r.context));
    }
    else
    {
        import std.meta : Filter;
        import salad.meta.impl : isSaladEnum, isSaladRecord;
        import salad.exception : DocumentException;

        enum isSchemaBase(T) = is(T : SchemaBase);

        auto r = resolveDirectives(node, context);

        alias Schemas = Filter!(isSchemaBase, Types);
        static if (Schemas.length > 0)
        {
            enum saladVersion = Schemas[0].saladVersion;
        }
        else
        {
            enum saladVersion = defaultSaladVersion;
        }
        auto expanded = expandDSL!(saladVersion, typeDSL, secondaryFilesDSL)(r.node);

        // dispatch
        import std.meta : anySatisfy;

        enum isAny(T) = is(T == Any);
        enum hasAny = anySatisfy!(isAny, Types);

        enum isNonStringArray(T) = !isSomeString!T && isArray!T;
        alias ArrayTypes = Filter!(isNonStringArray, Types);
        static if (ArrayTypes.length > 0)
        {
            static assert(ArrayTypes.length == 1, "Type `T[] | U[] | ...` is not supported yet");
            if (expanded.type == NodeType.sequence)
            {
                return T(expanded.as_!(ArrayTypes[0], typeDSL, idMap.init, lresolver, secondaryFilesDSL)(r.context));
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
                    enum DispatchFieldValue(T) = __traits(getMember, T, DispatchFieldName);
                    switch (id.as!string)
                    {
                        static foreach (RT; DispatchableRecords)
                        {
                            case DispatchFieldValue!RT: return T(expanded.as_!RT(r.context));
                        }
                    default:
                        static if (hasAny)
                        {
                            return T(expanded.as_!Any(r.context));
                        }
                        else
                        {
                            import std.format : format;
                            import std.meta : staticMap;

                            enum DispatchFieldValues = staticMap!(DispatchFieldValue, DispatchableRecords);
                            throw new DocumentException(
                                format!"Unknown %s field: `%s` (canditates: %-(`%s`%|, %))"(
                                    DispatchFieldName[0..$-1], id.as!string, [DispatchFieldValues],
                                ),
                                expanded.edig(DispatchFieldName[0 .. $ - 1]).startMark
                            );
                        }
                    }
                }
                else
                {
                    static if (NonDispatchableRecords.length == 1)
                    {
                        return T(expanded.as_!(NonDispatchableRecords[0])(r.context));
                    }
                    else static if (hasAny)
                    {
                        return T(expanded.as_!Any(r.context));
                    }
                    else
                    {
                        throw new DocumentException("Unknown record type", expanded.startMark);
                    }
                }
            }
        }

        import std.meta : Filter, staticMap;

        alias EnumTypes = Filter!(isSaladEnum, Types);
        enum hasString = anySatisfy!(isSomeString, Types);
        static if (EnumTypes.length > 0 || hasString)
        {                
            if (expanded.type == NodeType.string)
            {
                import salad.resolver : resolveIdentifier, resolveLink;
                import std.algorithm : canFind;
                import std.traits : EnumMembers;

                auto value = expanded.as!string;
                switch (value)
                {
                    static foreach(RT; EnumTypes)
                    {
                        static foreach(m; EnumMembers!(RT.Symbol))
                        {
                            case m: return T(expanded.as_!RT(r.context));
                        }
                    }
                    static if (hasString)
                    {
                        static if (lresolver == LinkResolver.link)
                        {
                            default: return T(value.resolveLink(r.context));
                        }
                        else static if (lresolver == LinkResolver.id)
                        {
                            default: return T(value.resolveIdentifier(r.context));
                        }
                        else
                        {
                            default: return T(value);
                        }
                    }
                    else
                    {
                        default: throw new DocumentException("Unknown symbol value: "~value, expanded.startMark);
                    }
                }
            }
        }

        import std.traits : isIntegral;
        alias IntTypes = Filter!(isIntegral, Types);
        static if (IntTypes.length > 0)
        {
            if (expanded.type == NodeType.integer)
            {
                import std.traits : CommonType;
                return T(expanded.as!(CommonType!IntTypes));
            }
        }

        import std.traits : isFloatingPoint;
        alias DecimalTypes = Filter!(isFloatingPoint, Types);
        static if (DecimalTypes.length > 0)
        {
            if (expanded.type == NodeType.decimal)
            {
                import std.traits : CommonType;
                return T(expanded.as!(CommonType!DecimalTypes));
            }
        }

        import std.traits : isBoolean;
        alias BooleanTypes = Filter!(isBoolean, Types);
        static assert(BooleanTypes.length <= 1);
        static if (BooleanTypes.length == 1)
        {
            if (expanded.type == NodeType.boolean)
            {
                return T(expanded.as!bool);
            }
        }

        import std.format : format;

        static if (hasAny)
        {
            return T(expanded.as!Any);
        }
        else
        {
            throw new DocumentException(
                format!"Unknown node type for type %s: %s"(T.stringof, expanded.type),
                expanded.startMark
            );
        }

        static assert(Types.length ==
                ArrayTypes.length + RecordTypes.length + EnumTypes.length +
                    (hasString ? 1 : 0) +
                    IntTypes.length + DecimalTypes.length + BooleanTypes.length + (hasAny ? 1 : 0),
                format!"Internal error: %s (%s) but Array: %s, Record: %s, Enum: %s, hasString: %s, Integer: %s, Decimal: %s, Boolean: %s, hasAny: %s"( // @suppress(dscanner.style.long_line)
                    Types.stringof, Types.length, ArrayTypes.stringof, RecordTypes.stringof, EnumTypes.stringof,
                    hasString, IntTypes.stringof, DecimalTypes.stringof, BooleanTypes.stringof, hasAny,
                ));
    }
}


///
auto expandDSL(string saladVersion, bool typeDSL, bool secondaryFilesDSL)(Node node)
{
    static if (typeDSL)
    {
        Node expanded;
        if (node.type == NodeType.string)
        {
            import std.algorithm : canFind, endsWith, map;
            import std.array : array, split;
            import std.conv : to;
            import std.experimental.logger;

            auto s = node.as!string;

            // auto vers = saladVersion[1..$].split(".").map!(to!int).array;
            // auto mark = node.startMark;
            // sharedLog.warningf(
            //     vers < [1, 3] && s.canFind("[][]"),
            //     "[nested-array] Using nested array with syntax sugar (e.g., `%s`) has a portability issue.",
            //     s,
            // );

            if (s.endsWith("[]?"))
            {
                expanded.add("null");
                Node n;
                n.add("type", "array");
                n.add("items", s[0 .. $ - 3]);
                expanded.add(n);
            }
            else if (s.endsWith("[]"))
            {
                expanded.add("type", "array");
                expanded.add("items", s[0 .. $ - 2]);
            }
            else if (s.endsWith("?"))
            {
                expanded.add("null");
                expanded.add(s[0 .. $ - 1]);
            }
            else
            {
                expanded = Node(node);
            }
        }
        else
        {
            expanded = Node(node);
        }
        return expanded;
    }
    else static if (secondaryFilesDSL)
    {
        Node expanded;
        if (node.type == NodeType.string)
        {
            import std.algorithm : endsWith;

            auto pattern = node.as!string;
            if (pattern.endsWith("?"))
            {
                pattern = pattern[0 .. $ - 1];
                expanded.add("required", false);
            }
            expanded.add("pattern", pattern);
        }
        else
        {
            expanded = Node(node);
        }
        return expanded;
    }
    else
    {
        return Node(node);
    }
}
