/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.meta.parser;

import dyaml : Node;

///
template DocumentRootType(alias module_)
{
    import salad.meta.uda : documentRoot;
    import std.meta : allSatisfy, ApplyRight, Filter, staticMap;
    import std.traits : fullyQualifiedName, hasUDA;

    alias StrToType(string T) = __traits(getMember, module_, T);
    alias syms = staticMap!(StrToType, __traits(allMembers, module_));
    alias RootTypes = Filter!(ApplyRight!(hasUDA, documentRoot), syms);
    static if (RootTypes.length > 0)
    {
        import salad.meta.impl : hasIdentifier;
        import salad.type : SumType;
        static assert(allSatisfy!(hasIdentifier, RootTypes));
        alias DocumentRootType = SumType!RootTypes;
    }
    else
    {
        import std.format : format;
        import std.traits : moduleName;
        static assert(false, format!"No schemas with `documentRoot: true` in module `%s`"(moduleName!module_));
    }
}

///
template IdentifierType(alias module_)
{
    import std.meta : allSatisfy, Filter, staticMap;
    import std.traits : fullyQualifiedName;

    alias StrToType(string T) = __traits(getMember, module_, T);
    alias syms = staticMap!(StrToType, __traits(allMembers, module_));
    alias IDTypes = Filter!(hasIdentifier, syms);

    static if (IDTypes.length > 0)
    {
        alias IdentifierType = SumType!IDTypes;
    }
    else
    {
        static assert(false, "No schemas with identifier field");
    }
}

///
auto parse(alias module_)(Node node, string uri) @safe
if (__traits(isModule, module_))
{
    import dyaml : NodeType;
    import salad.meta.impl : as_;
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
            import salad.resolver : resolveIdentifier, withoutFragment;

            auto context = LoadingContext(uri.withoutFragment);
            docEnforce(uri.fragment || doc.match!(d => d.identifier.resolveIdentifier(context).fragment) == frag,
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
                import salad.resolver : resolveIdentifier, withoutFragment;
                import std.algorithm : filter;
                import std.array : array;
                import std.format : format;
    
                auto context = LoadingContext(uri.withoutFragment);
                auto elems = () @trusted {
                    // SumType.opAssign used in `array` is unsafe
                    // we can mark it as trusted because it does not leak any pointers outside an array
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
