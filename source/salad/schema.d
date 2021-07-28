module salad.schema;

import dyaml;

import salad.ast;
import salad.exception;
import salad.meta;
import salad.type;
import salad.util;

import std.typecons : Tuple;

struct SaladSchema
{
    string base;
    string[string] namespaces;
    string[] schemas;
    Either!(SaladRecordSchema, SaladEnumSchema, Documentation)[] graph;

    this(in Node node) @trusted
    {
        import std.algorithm : map;
        import std.array : array, assocArray;
        import std.typecons : tuple;

        // TODO: load implied context
        base = node.dig("$base", "").as!string;
        namespaces = node.dig("$namespaces", (string[string]).init)
                         .mapping
                         .map!(kv => tuple(kv.key.as!string, kv.value.as!string))
                         .assocArray;
        schemas = node.dig("$schemas", [])
                      .sequence
                      .map!"a.as!string"
                      .array;

        graph = node.dig("$graph", [])
                    .sequence
                    .map!((n) {
                        import std.range : ElementType;

                        alias T = ElementType!(typeof(graph));

                        switch(n.edig("type").as!string)
                        {
                        case "record": return T(n.as!SaladRecordSchema);
                        case "enum": return T(n.as!SaladEnumSchema);
                        case "documentation": return T(n.as!Documentation);
                        default: throw new SchemaException("Invalid data type: "~n.edig("type").as!string, n);
                        }
                    })
                    .array;
    }
}

unittest
{
    import std.file : dirEntries, SpanMode;
    foreach(dir; dirEntries("examples", SpanMode.shallow))
    {
        import std.exception : assertNotThrown;
        Loader.fromFile(dir~"/schema.json")
              .load
              .as!SaladSchema
              .assertNotThrown("Failed to load "~dir);
    }
}

abstract class DocumentSchema
{
    ///
    AST parse(Node node, DocumentSchema[string] docSchema)
    out(result; result)
    {
        assert(false, "It should be overridden by its subclass");
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SaladRecordSchema
class SaladRecordSchema : DocumentSchema
{
    string name;
    enum type = "record";
    Optional!bool inVocab;
    Optional!(SaladRecordField[]) fields;
    Optional!string doc;
    Optional!string docParent;
    Optional!(string, string[]) docChild;
    Optional!string docAfter;
    Optional!(string, JsonldPredicate) jsonldPredicate;
    Optional!bool documentRoot;
    @("abstract") Optional!bool abstract_;
    Optional!(string, string[]) extends;
    Optional!(SpecializeDef[]) specialize;

    mixin genCtor;
    mixin genToString;

    override AST parse(Node node, DocumentSchema[string] docSchema)
    {
        auto ast(T)(T val)
        {
            return new AST(node, "SaladRecordSchema", val);
        }

        schemaEnforce(node.type == NodeType.mapping, "mapping is expected", node);

        return fields.match!(
            (SaladRecordField[] srfs) {
                import std.algorithm : map;

                RecordType ret;
                foreach(fname, value; srfs.map!(s => s.parse_(node, docSchema)))
                {
                    import std.algorithm : canFind;
                    if (fname.canFind(":"))
                    {
                        // extension field
                        ret.extensionFields[fname] = value;
                    }
                    else
                    {
                        ret.fields[fname] = value;
                    }
                }
                return ast(ret);
            },
            (None _) => ast(None()),
        );
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SaladRecordField
class SaladRecordField : DocumentSchema
{
    string name;
    Either!(
        PrimitiveType,
        RecordSchema,
        EnumSchema,
        ArraySchema,
        string,
        Either!(
            PrimitiveType,
            RecordSchema,
            EnumSchema,
            ArraySchema,
            string)[]
    ) type;
    Optional!(string, string[]) doc;
    Optional!(string, JsonldPredicate) jsonldPredicate;
    @("default") Optional!Any default_;

    mixin genCtor;
    mixin genToString;

    Tuple!(string, AST) parse_(Node node, DocumentSchema[string] docSchema)
    {
        auto tpl(T)(T val) 
        {
            import std.typecons : tuple;
            return tuple(name, new AST(node, "SaladRecordField", val));
        }

        schemaEnforce(node.type == NodeType.mapping, "mapping is expected", node);
        if (auto f = name in node)
        {
            return type.match!(
                (PrimitiveType pt) => tpl(pt.parse(*f, docSchema)),
                (RecordSchema rs) => tpl(rs.parse(*f, docSchema)),
                (EnumSchema es) => tpl(es.parse(*f, docSchema)),
                (ArraySchema as) => tpl(as.parse(*f, docSchema)),
                (string s) => tpl(s.parse(*f, docSchema)),
                (rest) {
                    import std.algorithm : filter, map;
                    import std.array : array;
                    import std.format : format;
                    auto ret = rest.map!(s => s.parse(*f, docSchema).speculate)
                                   .array;
                    auto types = ret.map!"a.ast".filter!"a";
                    auto exceptions = ret.map!"a.exception".filter!"a";
                    if (types.empty)
                    {
                        assert(!exceptions.empty);
                        throw new SchemaException(format!"No matching types for `%s`"(name), node, exceptions.front);
                    }
                    // TODO: consider the case of finds.length > 1 (ambiguous candidates)
                    return tpl(types.front);
                },
            );
        }
        else
        {
            try
            {
                throw new SchemaException("any is not supported yet", node);
                // return default_.tryMatch!((Any any) => tpl(this.match(any, docSchema)));
            }
            catch(MatchException e)
            {
                import std.format : format;
                throw new SchemaException(format!"Both of the field value and default value for %s are not provided"(name),
                                          node);
            }
        }
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#PrimitiveType
class PrimitiveType : DocumentSchema
{
    enum Types{
        null_ = "null",
        boolean = "boolean",
        int_ = "int",
        long_ = "long",
        float_ = "float",
        double_ = "double",
        string = "string",
    }

    string type;

    this(in Node node) @safe
    {
        type = node.as!string;
        // enforce
    }

    mixin genToString;

    override AST parse(Node node, DocumentSchema[string] docSchema)
    {
        final switch(type) with(Types)
        {
        case null_:
            schemaEnforce(node.type == NodeType.null_, "null is expected", node);
            return new AST(node, "null", None());
        case boolean:
            schemaEnforce(node.type == NodeType.boolean, "boolean is expected", node);
            return new AST(node, "boolean", node.as!bool);
        case int_:
            schemaEnforce(node.type == NodeType.integer, "integer is expected", node);
            return new AST(node, "integer", node.as!long);
        case long_:
            schemaEnforce(node.type == NodeType.integer, "integer is expected", node);
            return new AST(node, "integer", node.as!long);
        case float_:
            schemaEnforce(node.type == NodeType.decimal, "decimal is expected", node);
            return new AST(node, "float", node.as!real);
        case double_:
            schemaEnforce(node.type == NodeType.decimal, "decimal is expected", node);
            return new AST(node, "float", node.as!real);
        case string:
            schemaEnforce(node.type == NodeType.string, "string is expected", node);
            return new AST(node, "string", node.as!(.string));
        }
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Any
class Any : DocumentSchema
{
    enum Types{
        Any = "Any",
    }

    string type;

    this(in Node node) @safe
    {
        type = node.as!string;
        // enforce
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#RecordSchema
class RecordSchema : DocumentSchema
{
    enum type = "record";
    Optional!(RecordField[]) fields;

    mixin genCtor;
    mixin genToString;

    override AST parse(Node node, DocumentSchema[string] docSchema)
    {
        auto ast(T)(T val)
        {
            return new AST(node, "RecordSchema", val);
        }

        return fields.match!(
            (RecordField[] rf) {
                import std.algorithm : map;

                schemaEnforce(node.type == NodeType.mapping, "mapping is expected", node);

                RecordType ret;
                foreach(fname, value; rf.map!(s => s.parse_(node, docSchema)))
                {
                    import std.algorithm : canFind;
                    if (fname.canFind(":"))
                    {
                        // extension field
                        ret.extensionFields[fname] = value;
                    }
                    else
                    {
                        ret.fields[fname] = value;
                    }
                }
                return ast(ret);
            },
            (None _) => ast(None()),
        );
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#RecordField
class RecordField : DocumentSchema
{
    string name;
    Either!(
        PrimitiveType,
        RecordSchema,
        EnumSchema,
        ArraySchema,
        string,
        Either!(
            PrimitiveType,
            RecordSchema,
            EnumSchema,
            ArraySchema,
            string)[]
    ) type;
    Optional!(string, string[]) doc;

    mixin genCtor;
    mixin genToString;

    Tuple!(string, AST) parse_(Node node, DocumentSchema[string] docSchema)
    {
        import std.format : format;

        auto tpl(T)(T val)
        {
            import std.typecons : tuple;
            return tuple(name, new AST(node, "RecordField", val));
        }

        schemaEnforce(node.type == NodeType.mapping, "mapping is expected", node);
        auto f = schemaEnforce(name in node, format!"field `%s` is not available"(name), node);

        return type.match!(
            (PrimitiveType pt) => tpl(pt.parse(*f, docSchema)),
            (RecordSchema rs) => tpl(rs.parse(*f, docSchema)),
            (EnumSchema es) => tpl(es.parse(*f, docSchema)),
            (ArraySchema as) => tpl(as.parse(*f, docSchema)),
            (string s) => tpl(s.parse(*f, docSchema)),
            (rest) {
                import std.algorithm : filter, map;
                import std.array : array;
                auto ret = rest.map!(s => s.parse(*f, docSchema).speculate)
                               .array;
                auto types = ret.map!"a.ast".filter!"a";
                auto exceptions = ret.map!"a.exception".filter!"a";
                if (types.empty)
                {
                    import std.format : format;
                    assert(!exceptions.empty);
                    throw new SchemaException(format!"No matching types for `%s`"(name), node, exceptions.front);
                }
                // TODO: consider the case of types.length > 1 (ambiguous candidates)
                return tpl(types.front);
            },
        );
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#EnumSchema
class EnumSchema : DocumentSchema
{
    string[] symbols;
    enum type = "enum";

    mixin genCtor;
    mixin genToString;

    override AST parse(Node node, DocumentSchema[string] docSchema)
    {
        import std.algorithm : find;
        import std.format : format;
        import std.range : empty, front;

        schemaEnforce(node.type == NodeType.string, "string is expected", node);
        auto s = node.as!string;
        auto syms = symbols.find(s);
        schemaEnforce(!syms.empty, format!"Unknown symbol `%s`"(s), node);
        return new AST(node, "EnumSchema", syms.front);
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#ArraySchema
class ArraySchema : DocumentSchema
{
    Either!(
        PrimitiveType,
        RecordSchema,
        EnumSchema,
        ArraySchema,
        string,
        Either!(
            PrimitiveType,
            RecordSchema,
            EnumSchema,
            ArraySchema,
            string)[]
    ) items;
    enum type = "array";

    mixin genCtor;
    mixin genToString;

    override AST parse(Node node, DocumentSchema[string] docSchema)
    {
        import std.algorithm : map;
        import std.array : array;

        auto ast(T)(T val)
        {
            return new AST(node, "ArraySchema", val);
        }

        schemaEnforce(node.type == NodeType.sequence, "sequence is expected", node);
        return items.match!(
            (PrimitiveType pt) => ast(node.sequence.map!(n => pt.parse(n, docSchema)).array),
            (RecordSchema rs) => ast(node.sequence.map!(n => rs.parse(n, docSchema)).array),
            (EnumSchema es) => ast(node.sequence.map!(n => es.parse(n, docSchema)).array),
            (ArraySchema as) => ast(node.sequence.map!(n => as.parse(n, docSchema)).array),
            (string s) => ast(node.sequence.map!(n => s.parse(n, docSchema)).array),
            rest => ast(node.sequence.map!((n) {
                import std.algorithm : filter, map;
                import std.format : format;
                auto ret = rest.map!(s => s.parse(n, docSchema).speculate)
                               .array;
                auto types = ret.map!"a.ast".filter!"a";
                auto exceptions = ret.map!"a.exception".filter!"a";
                if (types.empty)
                {
                    assert(!exceptions.empty);
                    throw new SchemaException("No matching element types for array", node, exceptions.front);
                }
                // TODO: consider the case of types.length > 1 (ambiguous candidates)
                return types.front;
            }).array),
        );
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#JsonldPredicate
class JsonldPredicate : DocumentSchema
{
    Optional!string _id;
    Optional!string _type;
    Optional!string _container;
    Optional!bool identity;
    Optional!bool noLinkCheck;
    Optional!string mapSubject;
    Optional!string mapPredicate;
    Optional!int refScope;
    Optional!bool typeDSL;
    Optional!bool secondaryFilesDSL;
    Optional!string subscope;

    mixin genCtor;
    mixin genToString;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SpecializeDef
class SpecializeDef : DocumentSchema
{
    string specializeFrom;
    string specializeTo;

    mixin genCtor;
    mixin genToString;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SaladEnumSchema
class SaladEnumSchema : DocumentSchema
{
    string name;
    string[] symbols;
    enum type = "enum";
    Optional!bool inVocab;
    Optional!(string, string[]) doc;
    Optional!string docParent;
    Optional!(string, string[]) docChild;
    Optional!string docAfter;
    Optional!(string, JsonldPredicate) jsonldPredicate;
    Optional!bool documentRoot;
    Optional!(string, string[]) extends;

    mixin genCtor;
    mixin genToString;

    override AST parse(Node node, DocumentSchema[string] docSchema)
    {
        import std.algorithm : find;
        import std.format : format;
        import std.range : empty, front;

        schemaEnforce(node.type == NodeType.string,
                      format!"string is expected but %s occurs"(node.type), node);
        auto s = node.as!string;
        auto syms = symbols.find(s);
        schemaEnforce(!syms.empty, format!"Unknown symbol `%s`"(s), node);
        return new AST(node, "SaladEnumSchema", syms.front);
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Documentation
class Documentation : DocumentSchema
{
    string name;
    enum type = "documentation";
    Optional!bool inVocab;
    Optional!(string, string[]) doc;
    Optional!string docParent;
    Optional!(string, string[]) docChild;
    Optional!string docAfter;

    mixin genCtor;
    mixin genToString;
}

AST parse(string schemaName, Node node, DocumentSchema[string] docSchema)
{
    return docSchema[schemaName].parse(node, docSchema);
}

AST parse(T)(T either, Node node, DocumentSchema[string] docSchema)
if (isEither!T)
{
    return either.match!(
        s => s.parse(node, docSchema),
    );
}

Tuple!(AST, "ast", Exception, "exception") speculate(lazy AST ast)
{
    try
    {
        return typeof(return)(ast(), null);
    }
    catch(SchemaException e)
    {
        return typeof(return)(null, e);
    }
}
