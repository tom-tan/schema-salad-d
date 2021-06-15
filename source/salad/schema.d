module salad.schema;

import dyaml;

import salad.meta;
import salad.type;
import salad.util;

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
                        default: throw new Exception("Invalid data type: "~n.edig("type").as!string);
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
    bool matchSchema(Node node, DocumentSchema[string] docSchema)
    {
        throw new Exception("It should be overridden by its subclass");
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

    override bool matchSchema(Node node, DocumentSchema[string] docSchema)
    {
        if (node.type == NodeType.mapping)
        {
            import std.algorithm : all;

            return fields.match!(
                (SaladRecordField[] srfs) => srfs.all!(s => s.matchSchema(node, docSchema)),
                (None _) => true,
            );
        }
        else
        {
            return false;
        }
    }
/+
    auto load(Node node)
    {
        auto ro = RecordObject;
        ro.schema = this;
        fields.match!(
            (SaladRecordField fs) {
                fs.each!((fschema) {
                    auto name = fschema.name;
                    fschema.type.match!(
                        (PrimitiveType pt) => pt.load(node.edig(name)),
                        (RecordSchema rs) => rs.load(node.edig(name)),
                        (EnumSchema es) => es.load(node.edig(name)),
                        (ArraySchema as) => as.load(node.edig(name)),
                        (string s) => /* definition of s*/,
                        //
                    );
                    if (auto fval = name in node)
                    {
                        switch((*fval).type)
                        {
                        case NodeType.boolean:
                            // enforce(fieldSchema.type == PrimitiveType && type.type == type.Type.boolean)
                            break;
                        case NodeType.integer: break;
                        case NodeType.sequence: break;
                        case NodeType.string: break;
                        case NodeType.mapping: break;
                        case NodeType.null_: break;
                        default: break;
                        }
                    }
                    else
                    {
                        fschema.default_.match!(
                            (Any _) => XXX,
                            (_) {},
                        );
                    }
                });
            },
            (None _) {},
        )
    }+/
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

    override bool matchSchema(Node node, DocumentSchema[string] docSchema)
    {
        if (node.type != NodeType.mapping)
        {
            return false;
        }
        else if (auto f = name in node)
        {
            import std.algorithm : any;

            return type.match!(
                (PrimitiveType pt) => pt.matchSchema(*f, docSchema),
                (RecordSchema rs) => rs.matchSchema(*f, docSchema),
                (EnumSchema es) => es.matchSchema(*f, docSchema),
                (ArraySchema as) => as.matchSchema(*f, docSchema),
                (string s) => s.matchSchema(*f, docSchema),
                rest => rest.any!(s => s.matchSchema(*f, docSchema)),
            );
        }
        else
        {
            return default_.match!(
                (Any _) => true,
                _ => false,
            );
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

    override bool matchSchema(Node node, DocumentSchema[string] docSchema)
    {
        final switch(type) with(Types)
        {
        case null_: return node.type == NodeType.null_;
        case boolean: return node.type == NodeType.boolean;
        case int_: return node.type == NodeType.integer;
        case long_: return node.type == NodeType.integer;
        case float_: return node.type == NodeType.decimal;
        case double_: return node.type == NodeType.decimal;
        case string: return node.type == NodeType.string;
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

    override bool matchSchema(Node node, DocumentSchema[string] docSchema)
    {
        import std.algorithm : all;

        return fields.match!(
            (RecordField[] rf) => node.type == NodeType.mapping
                ? rf.all!(f => f.matchSchema(node, docSchema)) : false,
            _ => true,
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

    override bool matchSchema(Node node, DocumentSchema[string] docSchema)
    {
        if (node.type != NodeType.mapping)
        {
            return false;
        }
        else if (auto f = name in node)
        {
            import std.algorithm : any;

            return type.match!(
                (PrimitiveType pt) => pt.matchSchema(*f, docSchema),
                (RecordSchema rs) => rs.matchSchema(*f, docSchema),
                (EnumSchema es) => es.matchSchema(*f, docSchema),
                (ArraySchema as) => as.matchSchema(*f, docSchema),
                (string s) => s.matchSchema(*f, docSchema),
                rest => rest.any!(s => s.matchSchema(*f, docSchema)),
            );
        }
        else
        {
            return false;
        }
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#EnumSchema
class EnumSchema : DocumentSchema
{
    string[] symbols;
    enum type = "enum";

    mixin genCtor;

    override bool matchSchema(Node node, DocumentSchema[string] docSchema)
    {
        if (node.type == NodeType.string)
        {
            import std.algorithm : canFind;
            return symbols.canFind(node.as!string);
        }
        else
        {
            return false;
        }
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

    override bool matchSchema(Node node, DocumentSchema[string] docSchema)
    {
        if (node.type == NodeType.sequence)
        {
            import std.algorithm : all, any;

            return items.match!(
                (PrimitiveType pt) => node.sequence.all!(n => pt.matchSchema(n, docSchema)),
                (RecordSchema rs) => node.sequence.all!(n => rs.matchSchema(n, docSchema)),
                (EnumSchema es) => node.sequence.all!(n => es.matchSchema(n, docSchema)),
                (ArraySchema as) => node.sequence.all!(n => as.matchSchema(n, docSchema)),
                (string s) => node.sequence.all!(n => s.matchSchema(n, docSchema)),
                rest => node.sequence.all!(n => rest.any!(s => s.matchSchema(n, docSchema))),
            );
        }
        else
        {
            return false;
        }
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
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SpecializeDef
class SpecializeDef : DocumentSchema
{
    string specializeFrom;
    string specializeTo;

    mixin genCtor;
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

    override bool matchSchema(Node node, DocumentSchema[string] docSchema)
    {
        if (node.type == NodeType.string)
        {
            import std.algorithm : canFind;
            return symbols.canFind(node.as!string);
        }
        else
        {
            return false;
        }
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
}

bool matchSchema(string schemaName, Node node, DocumentSchema[string] docSchema)
{
    return docSchema[schemaName].matchSchema(node, docSchema);
}

bool matchSchema(T)(T either, Node node, DocumentSchema[string] docSchema)
if (isEither!T)
{
    return either.match!(
        s => s.matchSchema(node, docSchema),
    );
}
