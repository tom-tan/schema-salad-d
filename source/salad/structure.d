module salad.structure;

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

unittest
{
    enum schemaStr = q"EOS
    {
      "$namespaces": {
        "acid": "http://example.com/acid#"
      },
      "$graph": [{
        "name": "ExampleType",
        "type": "record",
        "fields": [{
          "name": "base",
          "type": "string",
          "jsonldPredicate": "http://example.com/base"
        }]
      }]
    }
EOS";

    auto schema = Loader.fromString(schemaStr)
                        .load
                        .as!Schema;

    enum example = q"EOS
    {
      "base": "one",
      "form": {
        "http://example.com/base": "two",
        "http://example.com/three": "three",
      },
      "acid:four": "four"
    }
EOS";

    enum expected = q"EOS
    {
      "base": "one",
      "form": {
        "base": "two",
        "http://example.com/three": "three",
      },
      "http://example.com/acid#four": "four"
    }
EOS";
}


/// See_Also: https://www.commonwl.org/v1.0/SchemaSalad.html#SaladRecordSchema
class SaladRecordSchema
{
    string name;
    enum type = "record";
    Optional!bool inVocab;
    Optional!(SaladRecordField[]) fields;
    Optional!string doc;
    Optional!string docParent;
    Optional!string docChild;
    Optional!string docAfter;
    SumType!(None, string, JsonldPredicate) jsonldPredicate;
    Optional!bool documentRoot;
    @("abstract") Optional!bool abstract_;
    Optional!(string[]) extends;
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
        // mixin(Assign!(node, jsonldPredicate));
        // pragma(msg, Assign!(node, jsonldPredicate));
        mixin(Assign!(node, documentRoot));
        mixin(Assign!(node, abstract_));
        mixin(Assign!(node, extends));
        mixin(Assign!(node, specialize));
        if (auto f = "jsonldPredicate" in node)
        {
            jsonldPredicate = ((a)
            {
                if (a.type == NodeType.mapping)
                {
                    return SumType!(None, string, JsonldPredicate)(a.as!JsonldPredicate);
                }
                else if (a.type == NodeType.string)
                {
                    return SumType!(None, string, JsonldPredicate)(a.as!string);
                }
                else throw new Exception("");
            })(*f);
        }
    }
}

/// See_Also: https://www.commonwl.org/v1.0/SchemaSalad.html#SaladRecordField
class SaladRecordField
{
    string name;
    SumType!(
        PrimitiveType,
        RecordSchema,
        EnumSchema,
        ArraySchema,
        string,
        SumType!(
            PrimitiveType,
            RecordSchema,
            EnumSchema,
            ArraySchema,
            string)[]
    ) type;
    Optional!string doc;
    SumType!(None, string, JsonldPredicate) jsonldPredicate;

    this(in Node node) @trusted
    {
        mixin(Assign!(node, name));
        mixin(Assign!(node, type)); // unsafe
        mixin(Assign!(node, doc));
        mixin(Assign!(node, jsonldPredicate));
    }
}

/// See_Also: https://www.commonwl.org/v1.0/SchemaSalad.html#PrimitiveType
class PrimitiveType
{
    enum Types{
        null_ = "null",
        boolean = "boolean",
        int_ = "int",
        long_ = "long",
        float_ = "float",
        double_ = "double",
        string_ = "string",
    }

    string type;

    this(in Node node) @safe
    {
        type = node.as!string;
        // enforce
    }
}

/// See_Also: https://www.commonwl.org/v1.0/SchemaSalad.html#Any
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

/// See_Also: https://www.commonwl.org/v1.0/SchemaSalad.html#RecordSchema
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

/// See_Also: https://www.commonwl.org/v1.0/SchemaSalad.html#RecordField
class RecordField
{
    string name;
    SumType!(
        PrimitiveType,
        RecordSchema,
        EnumSchema,
        ArraySchema,
        string,
        SumType!(
            PrimitiveType,
            RecordSchema,
            EnumSchema,
            ArraySchema,
            string)[]
    ) type;
    Optional!string doc;

    this(in Node node) @trusted
    {
        mixin(Assign!(node, name));
        mixin(Assign!(node, type)); // unsafe
        mixin(Assign!(node, doc));
    }
}

/// See_Also: https://www.commonwl.org/v1.0/SchemaSalad.html#EnumSchema
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

/// See_Also: https://www.commonwl.org/v1.0/SchemaSalad.html#ArraySchema
class ArraySchema
{
    SumType!(
        PrimitiveType,
        RecordSchema,
        EnumSchema,
        ArraySchema,
        string,
        SumType!(
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

/// See_Also: https://www.commonwl.org/v1.0/SchemaSalad.html#JsonldPredicate
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
    }
}

/// See_Also: https://www.commonwl.org/v1.0/SchemaSalad.html#SpecializeDef
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

/// See_Also: https://www.commonwl.org/v1.0/SchemaSalad.html#SaladEnumSchema
class SaladEnumSchema
{
    string[] symbols;
    enum type = "enum";
    Optional!string doc;
    Optional!string docParent;
    Optional!string docChild;
    Optional!string docAfter;
    SumType!(None, string, JsonldPredicate) jsonldPredicate;
    Optional!bool documentRoot;
    Optional!(string[]) extends;

    this(in Node node) @safe
    in(node.edig("type") == type)
    {
        mixin(Assign!(node, symbols));
        mixin(Assign!(node, doc));
        mixin(Assign!(node, docParent));
        mixin(Assign!(node, docChild));
        mixin(Assign!(node, docAfter));
        mixin(Assign!(node, jsonldPredicate));
        mixin(Assign!(node, documentRoot));
        mixin(Assign!(node, extends));
    }
}

/// See_Also: https://www.commonwl.org/v1.0/SchemaSalad.html#Documentation
class Documentation
{
    string name;
    enum type = "documentation";
    Optional!bool inVocab;
    Optional!string doc;
    Optional!string docParent;
    Optional!string docChild;
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
