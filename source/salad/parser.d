/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.parser;

import dyaml : Node;

import std.traits : moduleName;

enum isModule(alias module_) = __traits(compiles, { mixin("import "~moduleName!module_~";"); });

///
auto parse(alias module_)(Node node, string uri)
if (isModule!module_)
{
    import dyaml : NodeType;
    import salad.meta : as_, DocumentRootType;
    import salad.type : SumType;

    alias T = DocumentRootType!module_;
    alias ReturnType = SumType!(T, T[]);

    if (node.type == NodeType.mapping)
    {
        import salad.resolver : splitContext;
        auto r = splitContext(node, uri);

        if (r.node.type == NodeType.mapping)
        {
            return ReturnType(r.node.as_!T(r.context));
        }
        else
        {
            return ReturnType(r.node.as_!(T[])(r.context));
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
    import salad.exception : docEnforce;
    import salad.fetcher : fetchNode, fragment_ = fragment;
    import salad.meta : DocumentRootType;
    import salad.type : match, tryMatch;
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
                import std.format : format;
                auto elems = docs.filter!(e => e.tryMatch!(d => d.identifier) == frag)
                                 .array;
                docEnforce(!elems.empty, format!"No objects for fragment `%s`"(frag), node);
                docEnforce(elems.length == 1, format!"Duplicated objects for fragment `%s`"(frag), node);
                return RetType(elems[0]);
            }
        }
    );
}
