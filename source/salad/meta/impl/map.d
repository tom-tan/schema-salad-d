/**
 * This module provides mixins and functions to implement parsers for map schemas.
 * Authors: Tomoya Tanjo
 * Copyright: © 2024 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.meta.impl.map;

///
mixin template genCtor()
{
    private import dyaml : Node;
    private import salad.context : LoadingContext;

    this() @safe { super(); }
    this(Node node, in LoadingContext context = LoadingContext.init) @trusted
    {
        import dyaml : NodeType;
        import salad.exception : docEnforce;
        import std : format, ValueType;
        docEnforce(
            node.type == NodeType.mapping,
            format!"%s requires a mapping node but a given node type is %s"(typeof(this).stringof, node.type),
            node.startMark,
        );
        foreach(pair; node.mapping)
        {
            import salad.meta.impl : as_;

            auto k = pair.key.as!string;
            auto v = pair.value;

            if (v.type == NodeType.null_)
            {
                continue;
            }

            import salad.resolver : isAbsoluteURI, resolveIdentifier;
            auto resolved = k.resolveIdentifier(context);
            if (resolved.isAbsoluteURI)
            {
                import salad.primitives : Any;
                extension_fields[resolved] = v.as_!Any(context);
                continue;
            }

            payload[k] = v.as_!(ValueType!(typeof(payload)))(context);
        }
    }
}

mixin template genDumper()
{
    private import dyaml : Node;

    ///
    Node opCast(T: Node)() const
    {
        import salad.resolver : scheme;
        import std : array, each, empty, filter;

        // TODO: remove duplication with salad.meta.dumper.toNode
        LoadingContext normalized = context;

        Node ret = (Node[string]).init;
        foreach(k, v; payload)
        {
            import dyaml : NodeType;
            import salad.meta.dumper : normalizeContexts, toNode;

            auto valNode = v.toNode;
            switch(valNode.type)
            {
            case NodeType.null_: break;
            case NodeType.mapping:
                normalized = normalizeContexts(normalized, valNode);
                goto default;
            case NodeType.sequence:
                auto elems = valNode.sequence.array;
                elems.filter!(e => e.type == NodeType.mapping).each!((ref e) =>
                    normalized = normalizeContexts(normalized, e)
                );
                valNode = Node(elems);
                goto default;
            default:
                ret.add(k.toNode, valNode);
            }
        }

        foreach(k, v; extension_fields)
        {
            import salad.meta.dumper : toNode;
            import salad.resolver : shortname;
            ret.add(k.shortname(normalized), v.toNode);
        }

        if (normalized.namespaces.length > 0)
        {
            ret.add("$namespaces", normalized.namespaces);
        }

        if (!normalized.schemas.empty)
        {
            import std : array, map, relativePath;
            import salad.resolver : isAbsoluteURI, path;

            ret.add(
                "$schemas",
                normalized.schemas.map!(s =>
                    s.isAbsoluteURI ? s.path.relativePath(normalized.fileURI.path) : s
                ).array,
            );
        }
        if (!normalized.baseURI.empty && normalized.baseURI.scheme != "file")
        {
            ret.add("$base", normalized.baseURI);
        }
        return ret;
    }
}

unittest
{
    import dyaml : Node;
    import salad.primitives : MapSchemaBase;
    import salad.meta.impl : genBody_;

    static class Foo : MapSchemaBase
    {
        Foo[string] payload;
        mixin genBody_!"v1.3";
    }

    auto foo = new Foo;
    auto n = Node(foo);
}
