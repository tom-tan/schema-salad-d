/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.parser;

import dyaml : Node;

import salad.context : LoadingContext;
import salad.exception;
import salad.meta;
import salad.schema;
import salad.type;

///
auto parse(alias module_)(Node node, string uri)
{
    import std.traits : moduleName;
    mixin("import "~moduleName!module_~";");
    import dyaml : NodeType;

    alias T = DocumentRootType!module_;
    alias ReturnType = SumType!(T, T[]);

    if (node.type == NodeType.mapping)
    {
        import std.algorithm : map;
        import std.array : array;

        string baseuri;
        if (auto base = "$base" in node)
        {
            baseuri = base.as!string;
        }
        else
        {
            baseuri = uri;
        }
        string[string] namespaces;
        if (auto ns = "$namespaces" in node)
        {
            import std.array : assocArray;
            import std.typecons : tuple;
            namespaces = ns.mapping
                           .map!(a => tuple(a.key.as!string, a.value.as!string))
                           .assocArray;
        }
        string[] schemas;
        if (auto s = "$schemas" in node)
        {
            schemas = s.sequence.map!(a => a.as!string).array;
        }

        auto context = LoadingContext(baseuri, namespaces);

        if (auto g = "$graph" in node)
        {
            return ReturnType(g.sequence.map!((a) {
                import salad.util : edig;
                T ret;
                mixin(Assign_!("a", "ret", T));
                return ret;
            }).array);
        }
        else
        {
            import salad.util : edig;
            T ret;
            mixin(Assign_!("node", "ret", T));
            return ReturnType(ret);
        }
    }
    else
    {
        assert(false, "Not yet supported");
    }
}

///
auto importFromURI(alias module_)(string uri, string fragment = "")
{
    import salad.fetcher : fetchNode, fragment_ = fragment;
    import std.format : format;
    import std.range : empty;

    auto frag = uri.fragment_;
    auto baseuri = uri[0..$-frag.length];
    auto node = fetchNode(baseuri);
    auto objs = parse!module_(node, baseuri);
    if (frag.empty)
    {
        frag = fragment;
    }

    alias RetType = typeof(objs);
    alias DocType = DocumentRootType!module_;
    return objs.match!(
        (DocType doc) {
            docEnforce(frag.empty || doc.match!(d => d.identifier) == frag,
                       "Mismatched fragment", node);
            return objs;
        },
        (DocType[] docs) {
            if (frag.empty)
            {
                return objs;
            }
            else
            {
                import std.algorithm : filter;
                import std.array : array;
                auto elems = docs.filter!(e => e.tryMatch!(d => d.identifier) == frag)
                                 .array;
                docEnforce(!elems.empty, format!"No objects for fragment `%s`"(frag), node);
                docEnforce(elems.length == 1, format!"Duplicated objects for fragment `%s`"(frag), node);
                return RetType(elems[0]);
            }
        }
    );
}
