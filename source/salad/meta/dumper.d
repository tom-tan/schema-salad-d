/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.meta.dumper;

import dyaml : Node;
import salad.context : LoadingContext;
import salad.primitives : OmitStrategy, SchemaBase;
import salad.type : isSumType;
import std : isArray, isAssociativeArray, isScalarType, isSomeString, Unqual;

Node toNode(T)(T t, OmitStrategy os = OmitStrategy.none) @safe
    if (isScalarType!T || isSomeString!T)
{
    return Node(t);
}

Node toNode(T)(T t, OmitStrategy os = OmitStrategy.none) @safe
    if (!isSomeString!T && isArray!T)
{
    import std : array, map;

    return Node(t.map!(e => e.toNode(os)).array);
}

Node toNode(T)(T t, OmitStrategy os = OmitStrategy.none) @safe
    if (isSumType!T)
{
    import dyaml : YAMLNull;
    import salad.type : isOptional, match, None;

    static if (isOptional!T)
    {
        return t.match!(
            (None _) => Node(YAMLNull()),
            other => other.toNode(os),
        );
    }
    else
    {
        return t.match!(e => e.toNode(os));
    }
}

Node toNode(T)(T t, OmitStrategy os = OmitStrategy.none) @safe
    if (isAssociativeArray!T)
{
    import std : array, each, empty, filter, format, KeyType;
    import salad.primitives : OmitStrategy;
    import salad.resolver : scheme;

    static assert(is(KeyType!T : string),
        format!"Key type is %s but string is needed"((KeyType!T).stringof)
    );

    Node ret = (Node[string]).init;
    auto childOs = os == OmitStrategy.shallow ? OmitStrategy.none : os;
    LoadingContext normalized;
    foreach(k, v; t)
    {
        import dyaml : NodeType;

        auto valNode = v.toNode(childOs);
        switch(valNode.type)
        {
        case NodeType.null_:
            if (os == OmitStrategy.shallow || os == OmitStrategy.deep)
            {
                break;
            }
            goto default;
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

/**
 * Translate two given parent and child contexts into the normalized contexts.
 *
 * Returns: The normalized contexts of the parent and child. 
 *          That is:
 *            - Each namespace in the child is merged into the parent one unless its key is not duplicated
 *            - Each namespace in the child, that has duplicated key in the parent one, is left in the child namespace
 *            - Each RDF schema in the child is merged into the parent one
 *
 * Note: A term `normalized contexts` is schema-salad-d specific.
 */
auto normalizeContexts(LoadingContext parent, ref Node child) @safe
{
    import std : multiwayUnion;

    auto newParentContext = parent;
    if (auto localNS = "$namespaces" in child)
    {
        string[string] newLocalNS;
        foreach (pair; localNS.mapping)
        {
            newParentContext.namespaces.update(pair.key.as!string,
                () => pair.value.as!string,
                (string resolved) {
                    if (pair.value != resolved)
                    {
                        newLocalNS[pair.key.as!string] = pair.value.as!string;
                    }
                }
            );
        }
        if (newLocalNS.length == 0)
        {
            child.removeAt("$namespaces");
        }
        else
        {
            child["$namespaces"] = newLocalNS;
        }
    }

    if (auto schs = "$schemas" in child)
    {
        import std : array, map;

        newParentContext.schemas = () @trusted {
            return multiwayUnion([parent.schemas, schs.sequence.map!"a.as!string".array]).array;
        } ();
        child.removeAt("$schemas");
    }

    return newParentContext;
}
