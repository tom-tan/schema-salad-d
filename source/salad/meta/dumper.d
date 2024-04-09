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
import std.traits : isArray, isScalarType, isSomeString, Unqual;

///
mixin template genDumper()
{
    private import dyaml : Node;

    ///
    Node opCast(T: Node)() const
    {
        static if (isSaladRecord!(typeof(this)))
        {
            import dyaml : NodeType;
            import std.algorithm : each, filter, endsWith;
            import std.array : array, byPair;
            import std.range : empty;
            import salad.meta.dumper : normalizeContexts, toNode;
            import salad.resolver : scheme, shortname;

            alias This = typeof(this);

            LoadingContext normalized = context;

            auto ret = Node((Node[string]).init);
            static foreach (field; __traits(allMembers, This))
            {
                static if (field.endsWith("_"))
                {
                    {
                        auto valNode = __traits(getMember, this, field).toNode;
                        switch(valNode.type)
                        {
                        case NodeType.null_: break;
                        case NodeType.mapping:
                            normalized = normalizeContexts(normalized, valNode);
                            goto default;
                        case NodeType.sequence:
                            // TODO: supporting nested sequence
                            auto elems = valNode.sequence.array;
                            elems.filter!(e => e.type == NodeType.mapping).each!((ref e) =>
                                normalized = normalizeContexts(normalized, e)
                            );
                            valNode = Node(elems);
                            goto default;
                        default:
                            ret.add(field[0..$-1].toNode, valNode);
                        }
                    }
                }
            }

            foreach(k, v; extension_fields.byPair)
            {
                ret.add(k.shortname(normalized), v.toNode);
            }

            if (normalized.namespaces.length > 0)
            {
                ret.add("$namespaces", normalized.namespaces);
            }

            if (!normalized.schemas.empty)
            {
                import std.algorithm : map;
                import std.array : array;
                import std.path : relativePath;

                import salad.resolver : isAbsoluteURI, path;

                ret.add(
                    "$schemas",
                    normalized.schemas.map!(s =>
                        s.isAbsoluteURI ? s.path.relativePath(normalized.fileURI.path) : s
                    ).array,
                );
            }
            if (normalized.baseURI.scheme != "file")
            {
                ret.add("$base", normalized.baseURI);
            }
            return ret;
        }
        else static if (isSaladEnum!(typeof(this)))
        {
            return Node(cast(string)value);
        }
        else
        {
            static assert(false, "It must be a SchemaRecord type or SchemaEnum type");
        }
    }
}

Node toNode(T)(T t)
    if (is(Unqual!T : SchemaBase) || isScalarType!T || isSomeString!T)
{
    return Node(t);
}

Node toNode(T)(T t)
    if (!isSomeString!T && isArray!T)
{
    import std.algorithm : map;
    import std.array : array;

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
