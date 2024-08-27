/**
 * This module provides mixins and functions to implement parsers for record schemas.
 * Authors: Tomoya Tanjo
 * Copyright: © 2024 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.meta.impl.record;

///
mixin template genCtor()
{
    this() @safe
    {
        import salad.meta.impl : hasIdentifier;
        import std : FieldNameTuple, getSymbolsByUDA, hasUDA;

        super();
        static if (hasIdentifier!This)
        {
            identifier = "";
        }

        Node unused = (Node[string]).init;
        static foreach (field; FieldNameTuple!This)
        {
            import salad.meta.uda : defaultValue;
            static if (hasUDA!(__traits(getMember, this, field), defaultValue))
            {
                import dyaml : NodeType, YAMLNull;
                import salad.meta.impl : Assign, as_;
                import std : endsWith, format;
                static assert(
                    field.endsWith("_"),
                    format!"Bug in the generated parser: Invalid field name with @defaultValue: %s.%s"(
                        This.stringof, field,
                    )
                );
                mixin(Assign!(unused, __traits(getMember, this, field), LoadingContext.init));
            }
        }
    }

    private import dyaml : Node;
    private import salad.context : LoadingContext;

    this(Node node, in LoadingContext context = LoadingContext.init) @trusted
    {
        import dyaml : Mark, NodeType;
        import salad.exception : docEnforce;
        import salad.meta.impl : Assign, as_, hasIdentifier, StaticMembersOf;
        import salad.meta.uda : LinkResolver;
        import salad.util : edig;
        import salad.type : None, Optional, SumType;
        import std : empty, endsWith, FieldNameTuple, format, getSymbolsByUDA, hasUDA, make, RedBlackTree, to;

        auto rest = make!(RedBlackTree!string)(node.mappingKeys!string);

        static foreach(m; StaticMembersOf!This)
        {
            static if (m.endsWith("_"))
            {
                auto val = docEnforce(
                    m[0..$-1] in node,
                    format!"Missing field `%s` in %s"(m[0..$-1], This.stringof),
                    node.startMark,
                );
                docEnforce(
                    __traits(getMember, this, m) == val.as!string,
                    format!"Conflict the value of %s.%s (Expected: %s, Actual: %s)"(
                        This.stringof, m[0..$-1], __traits(getMember, this, m), val.as!string
                    ),
                    node.startMark,
                );
                rest.removeKey(m[0..$-1]);
            }
        }

        static if (hasIdentifier!This)
        {
            mixin(Assign!(node, getSymbolsByUDA!(This, id)[0], context));
            rest.removeKey(getSymbolsByUDA!(This, id)[0].stringof[5..$-1]);

            identifier = (() {
                import salad.resolver : resolveIdentifier;
                import std : Unqual;
                auto i = getSymbolsByUDA!(This, id)[0];
                alias idType = Unqual!(typeof(i));
                static assert(is(idType == string) || is(idType == Union!(None, string)));
                static if (is(idType == string))
                {
                    return i.resolveIdentifier(context);
                }
                else
                {
                    import salad.type : match;

                    return i.match!(
                        (string s) => s.resolveIdentifier(context),
                        none => "",
                    );
                }
            })();

            static immutable idFieldName = getSymbolsByUDA!(This, id)[0].stringof;

            auto con = LoadingContext(
                identifier.empty ? context.baseURI : identifier,
                context.fileURI,
                context.namespaces.to!(string[string]),
                context.subscope,
                context.schemas.dup,
            );
        }
        else
        {
            static immutable idFieldName = "";
            auto con = context;
        }

        super(node.startMark, con);

        static foreach (field; FieldNameTuple!This)
        {
            static if (field.endsWith("_") && field != idFieldName~"_")
            {
                mixin(Assign!(node, __traits(getMember, this, field), con));
                rest.removeKey(field[0..$-1]);
            }
        }

        foreach(f; rest[])
        {
            import salad.primitives : Any;
            import salad.resolver : resolveLink;
            import std : canFind, format;

            if (["$base", "$namespaces", "$schemas", "$graph"].canFind(f))
            {
                continue;
            }

            docEnforce(
                f.canFind(":"),
                format!"Invalid field found: `%s` in %s"(f, This.stringof),
                node.startMark,
            );
            auto resolved = f.resolveLink(con);
            extension_fields[resolved] = node[f].as_!Any(con);
        }
    }
}

///
mixin template genIdentifier()
{
    private import std : getSymbolsByUDA;

    static if (getSymbolsByUDA!(This, id).length == 1)
    {
        string identifier;
    }
}

///
mixin template genDumper()
{
    private import dyaml : Node;

    ///
    Node opCast(T: Node)() const
    {
        import dyaml : NodeType;
        import salad.meta.dumper : normalizeContexts, toNode;
        import salad.resolver : scheme, shortname;
        import std : array, byPair, each, empty, endsWith, filter;

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
