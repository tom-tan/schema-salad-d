/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.parser;

import dyaml : Node;

import salad.ast;
import salad.exception;
import salad.resolver;
import salad.schema;
import salad.type;

struct Parser
{
    ///
    this(SaladSchema s)
    {
        import std.algorithm : filter, map;
        import std.array : array, assocArray;
        import std.exception : enforce;
        import std.range : empty;
        import std.typecons : tuple;

        schema = s;
        auto defs = s.graph
                     .filter!(ds => ds.match!(
                        (SaladRecordSchema _) => true,
                        (SaladEnumSchema _) => true,
                        _ => false,
                     ))
                     .array;
        auto docRoots = defs.map!(ds => ds.match!((Documentation _) => null,
                                                  s => s.documentRoot_ ? cast(DocumentSchema)s : null))
                            .map!(a => cast(SaladRecordSchema)a,
                                  a => cast(SaladEnumSchema)a)
                            .array;
        docRecordRoots = docRoots.map!"a[0]".filter!"a".array;
        docEnumRoots = docRoots.map!"a[1]".filter!"a".array;
        enforce(!docRecordRoots.empty || !docEnumRoots.empty, "No root candidates for given schema");
    }

    AST parse(Node node)
    {
        import dyaml : NodeType;

        auto resolver = Resolver(schema);

        if (node.type == NodeType.string)
        {
            import std.algorithm : filter, map;
            import std.array : array, empty;
            import std.range : front;

            schemaEnforce(!docEnumRoots.empty, "No candidates for SaladEnumSchema", node);
            auto ret = docEnumRoots.map!(doc => doc.parse(node, resolver).speculate)
                                   .array;
            auto types = ret.map!"a.ast".filter!"a".array;
            auto exceptions = ret.map!"a.exception".filter!"a";
            if (types.empty)
            {
                throw new SchemaException("No matched types", node, exceptions.front);
            }
            else if (types.length == 1)
            {
                return types.front;
            }
            else
            {
                // warning?
                throw new SchemaException("Ambiguous type", node);
            }
        }
        else if (node.type == NodeType.mapping)
        {
            import std.algorithm : filter, map;
            import std.array : array, empty;
            import std.range : front;

            schemaEnforce(!docRecordRoots.empty, "No candidates for SaladRecordSchema", node);
            auto ret = docRecordRoots.map!(doc => doc.parse(node, resolver).speculate)
                                     .array;
            auto types = ret.map!"a.ast".filter!"a".array;
            auto exceptions = ret.map!"a.exception".filter!"a";
            if (types.empty)
            {
                assert(!exceptions.empty);
                throw new SchemaException("No matched types", node, exceptions.front);
            }
            else if (types.length == 1)
            {
                return types.front;
            }
            else
            {
                // warning
                throw new SchemaException("Ambiguous type", node);
            }
        }
        throw new SchemaException("Root document should be enum or record object", node);
    }

    AST parseAs(Node node, string vocabulary)
    {
        auto resolver = Resolver(schema);
        auto schema = resolver.lookup(vocabulary);
        return schema.parse(node, resolver);
    }

    SaladSchema schema;
    SaladRecordSchema[] docRecordRoots;
    SaladEnumSchema[] docEnumRoots;
}

unittest
{
    import dyaml;

    enum schemaStr = q"EOS
{
    "$namespaces": {
        "acid": "http://example.com/acid#"
    },
    "$graph": [{
        "name": "ExampleType",
        "type": "record",
        "documentRoot": true,
        "fields": [{
            "name": "base",
            "type": "string",
            "jsonldPredicate": "http://example.com/base"
        }]
    }]
}
EOS";
    enum docStr = q"EOS
{
    "base": "one",
    "acid:form": {
        "http://example.com/base": "two",
        "http://example.com/three": "three",
    },
    "acid:four": "four"
}
EOS";

    import salad.util : nedig = edig;

    auto schema = Loader.fromString(schemaStr).load.as!SaladSchema;
    auto parser = Parser(schema);
    auto doc = Loader.fromString(docStr).load;

    auto ast = parser.parse(doc);
    ast.edig("base").value.tryMatch!((string s) => assert(s == "one"));

    // Child fields in extension fields are provided as Node objects.
    // No resolution rules are applied to them.
    ast.edig("http://example.com/acid#four").value.tryMatch!((Node n) => assert(n == "four"));

    auto formNode = ast.edig(["http://example.com/acid#form"]).value.tryMatch!((Node n) => n);
    assert(formNode.nedig("http://example.com/base") == "two");
    auto etAst = parser.parseAs(formNode, "ExampleType");
    etAst.edig("base").value.tryMatch!((string s) => assert(s == "two"));
}
