/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.meta.dumper;

import dyaml : Node;
import salad.context : LoadingContext;
import salad.primitives : SchemaBase;
import salad.type : isSumType;
import std : isArray, isScalarType, isSomeString, Unqual;

Node toNode(T)(T t)
    if (is(Unqual!T : SchemaBase) || isScalarType!T || isSomeString!T)
{
    return Node(t);
}

Node toNode(T)(T t)
    if (!isSomeString!T && isArray!T)
{
    import std : array, map;

    return Node(t.map!toNode.array);
}

Node toNode(T)(T t)
    if (isSumType!T)
{
    import dyaml : YAMLNull;
    import salad.type : isOptional, match, None;

    static if (isOptional!T)
    {
        return t.match!(
            (None _) => Node(YAMLNull()),
            other => other.toNode,
        );
    }
    else
    {
        return t.match!(e => e.toNode);
    }
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
auto normalizeContexts(LoadingContext parent, ref Node child)
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

        newParentContext.schemas = multiwayUnion([parent.schemas, schs.sequence.map!"a.as!string".array]).array;
        child.removeAt("$schemas");
    }

    return newParentContext;
}
