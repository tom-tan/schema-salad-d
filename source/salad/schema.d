module salad.schema;

import dyaml;

import salad.meta;
import salad.type;
import salad.util;

import sumtype;

struct Schema
{
    string base;
    string[string] namespaces;
    string[] schemas;
    SumType!(SaladRecordSchema, SaladEnumSchema, Documentation)[] graph;

    this(in Node node) @trusted
    {
        import std.algorithm : map;
        import std.array : array, assocArray;
        import std.typecons : tuple;

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
              .as!Schema
              .assertNotThrown("Failed to load "~dir);
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SaladRecordSchema
class SaladRecordSchema
{
    string name;
    enum type = "record";
    Optional!bool inVocab;
    Optional!(SaladRecordField[]) fields;
    Optional!string doc;
    Optional!string docParent;
    Either!(None, string, string[]) docChild;
    Optional!string docAfter;
    Either!(None, string, JsonldPredicate) jsonldPredicate;
    Optional!bool documentRoot;
    @("abstract") Optional!bool abstract_;
    Either!(None, string, string[]) extends;
    Optional!(SpecializeDef[]) specialize;

    this(in Node node) @safe
    in(node.edig("type") == type)
    {
        mixin(Assign!(node, name));
        mixin(Assign!(node, inVocab));
        mixin(Assign!(node, fields));
        mixin(Assign!(node, doc));
        mixin(Assign!(node, docParent));
        mixin(Assign!(node, docChild));
        mixin(Assign!(node, docAfter));
        mixin(Assign!(node, jsonldPredicate));
        mixin(Assign!(node, documentRoot));
        mixin(Assign!(node, abstract_));
        mixin(Assign!(node, extends));
        mixin(Assign!(node, specialize));
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SaladRecordField
class SaladRecordField
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
    Either!(None, string, string[]) doc;
    Either!(None, string, JsonldPredicate) jsonldPredicate;
    @("default") Optional!Any default_;

    this(in Node node) @trusted
    {
        mixin(Assign!(node, name));
        mixin(Assign!(node, type)); // unsafe
        mixin(Assign!(node, doc));
        mixin(Assign!(node, jsonldPredicate));
        mixin(Assign!(node, default_));
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#PrimitiveType
class PrimitiveType
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
class Any
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
class RecordSchema
{
    enum type = "record";
    Optional!(RecordField[]) fields;

    this(in Node node) @safe
    in(node.edig("type") == type)
    {
        mixin(Assign!(node, fields));
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#RecordField
class RecordField
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
    Either!(None, string, string[]) doc;

    this(in Node node) @trusted
    {
        mixin(Assign!(node, name));
        mixin(Assign!(node, type)); // unsafe
        mixin(Assign!(node, doc));
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#EnumSchema
class EnumSchema
{
    string[] symbols;
    enum type = "enum";

    this(in Node node) @safe
    in(node.edig("type") == type)
    {
        mixin(Assign!(node, symbols));
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#ArraySchema
class ArraySchema
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

    this(in Node node) @trusted
    in(node.edig("type") == type)
    {
        mixin(Assign!(node, items)); // unsafe
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#JsonldPredicate
class JsonldPredicate
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

    this(in Node node) @safe
    {
        mixin(Assign!(node, _id));
        mixin(Assign!(node, _type));
        mixin(Assign!(node, _container));
        mixin(Assign!(node, identity));
        mixin(Assign!(node, noLinkCheck));
        mixin(Assign!(node, mapSubject));
        mixin(Assign!(node, mapPredicate));
        mixin(Assign!(node, refScope));
        mixin(Assign!(node, typeDSL));
        mixin(Assign!(node, secondaryFilesDSL));
        mixin(Assign!(node, subscope));
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SpecializeDef
class SpecializeDef
{
    string specializeFrom;
    string specializeTo;

    this(in Node node) @safe
    {
        mixin(Assign!(node, specializeFrom));
        mixin(Assign!(node, specializeTo));
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SaladEnumSchema
class SaladEnumSchema
{
    string name;
    string[] symbols;
    enum type = "enum";
    Optional!bool inVocab;
    Either!(None, string, string[]) doc;
    Optional!string docParent;
    Either!(None, string, string[]) docChild;
    Optional!string docAfter;
    Either!(None, string, JsonldPredicate) jsonldPredicate;
    Optional!bool documentRoot;
    Either!(None, string, string[]) extends;

    this(in Node node) @safe
    in(node.edig("type") == type)
    {
        mixin(Assign!(node, name));
        mixin(Assign!(node, symbols));
        mixin(Assign!(node, inVocab));
        mixin(Assign!(node, doc));
        mixin(Assign!(node, docParent));
        mixin(Assign!(node, docChild));
        mixin(Assign!(node, docAfter));
        mixin(Assign!(node, jsonldPredicate));
        mixin(Assign!(node, documentRoot));
        mixin(Assign!(node, extends));
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Documentation
class Documentation
{
    string name;
    enum type = "documentation";
    Optional!bool inVocab;
    Either!(None, string, string[]) doc;
    Optional!string docParent;
    Either!(None, string, string[]) docChild;
    Optional!string docAfter;

    this(in Node node) @safe
    in(node.edig("type") == type)
    {
        mixin(Assign!(node, name));
        mixin(Assign!(node, inVocab));
        mixin(Assign!(node, doc));
        mixin(Assign!(node, docParent));
        mixin(Assign!(node, docChild));
        mixin(Assign!(node, docAfter));
    }
}
