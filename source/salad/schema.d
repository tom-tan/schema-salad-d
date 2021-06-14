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

interface DocumentSchema{}

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
/+
    auto matchSchema(Node node)
    {
        if (node.type == NodeType.mapping)
        {
            return fields.match!(
                (SaladRecordField[] srfs) => srfs.all!(s => s.matchSchema(node)),
                (None _) => true,
            );
        }
        else
        {
            return false;
        }
    }+/
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

/+
    bool matchSchema(Node node)
    in(node.type == NodeType.mapping)
    {
        if (auto f = name in node)
        {
            return type.match!(
                (PritiveType pt) => pt.matchSchema(*f),
                (RecordSchema rs) => rs.matchSchema(*f),
                (EnumSchema es) => es.matchSchema(*f),
                (ArraySchema as) => as.matchSchema(*f),
                (string s) => true, // TODO: 
                rest => zip(),
            );
        }
        else
        {
            return default_.match!(
                (Any _) => true,
                _ => false,
            );
        }
    }+/
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
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#EnumSchema
class EnumSchema : DocumentSchema
{
    string[] symbols;
    enum type = "enum";

    mixin genCtor;
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
