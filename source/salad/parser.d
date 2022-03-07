/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.parser;

import dyaml : Node;

///
auto parse(alias module_)(Node node, string uri) @safe
if (__traits(isModule, module_))
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
auto importFromURI(alias module_)(string uri, string defaultFragment = "") @safe
if (__traits(isModule, module_))
{
    import salad.exception : docEnforce;
    import salad.fetcher : fetchNode;
    import salad.meta : DocumentRootType;
    import salad.resolver : fragment;
    import salad.type : match, tryMatch;
    import std.range : empty;

    auto frag = uri.fragment;
    auto baseuri = uri[0..$-frag.length];
    auto node = fetchNode(baseuri);
    auto objs = parse!module_(node, baseuri);
    if (frag.empty)
    {
        import std.algorithm : startsWith;
        frag = defaultFragment.startsWith("#") ? defaultFragment[1..$] : defaultFragment;
    }

    alias RetType = typeof(objs);
    alias DocType = DocumentRootType!module_;
    return objs.match!(
        (DocType doc) {
            import salad.context : LoadingContext;
            import salad.resolver : resolveIdentifier;

            auto context = LoadingContext(uri);
            docEnforce(frag.empty || doc.match!(d => d.identifier.resolveIdentifier(context).fragment) == frag,
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
                import salad.context : LoadingContext;
                import salad.resolver : resolveIdentifier;
                import std.algorithm : filter;
                import std.array : array;
                import std.format : format;
    
                auto context = LoadingContext(uri);
                auto elems = () @trusted {
                    // SumType.opAssign used in array is unsafe
                    // we can mark it trusted because there are no pointers outside an array
                    return docs.filter!(e => e.tryMatch!(d => d.identifier
                                                               .resolveIdentifier(context)
                                                               .fragment) == frag)
                               .array;
                }();
                docEnforce(!elems.empty, format!"No objects for fragment `%s`"(frag), node);
                docEnforce(elems.length == 1, format!"Duplicated objects for fragment `%s`"(frag), node);
                return RetType(elems[0]);
            }
        }
    );
}
