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
        import salad.context : LoadingContext;
        import salad.resolver : splitContext;
        auto r = splitContext(node, uri);

        alias setID = (t) {
            import salad.meta.impl : hasIdentifier;
            static if (hasIdentifier!(typeof(t)))
            {
                import salad.meta.uda : id;
                import std.traits : getSymbolsByUDA;
                import std.range : empty;

                enum idField = getSymbolsByUDA!(typeof(t), id)[0].stringof;

                auto i = __traits(getMember, t, idField);
                static if (is(typeof(i) == string))
                {
                    auto istr = i;
                }
                else
                {
                    import salad.type : match;

                    auto istr = i.match!((string s) => s, _ => "");
                }

                if (istr.empty)
                {
                    t.identifier = t.context.baseURI;
                }
            }
            return t;
        };

        if (r.node.type == NodeType.mapping)
        {
            import salad.type : match;

            return ReturnType(r
                .node
                .as_!T(r.context)
                .match!(t => T(setID(t)))
            );
        }
        else
        {
            import salad.type : match;
            import std.algorithm : map;
            import std.array : array;

            return ReturnType(
                (() @trusted {
                    return r
                        .node
                        .as_!(T[])(r.context)
                        .map!(t => t.match!(t => T(setID(t))))
                        .array;
                }())
            );
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
    import salad.resolver : fragment, withoutFragment;
    import salad.type : match, tryMatch;
    import std.range : empty;

    auto frag = uri.fragment;
    auto baseuri = uri.withoutFragment;
    auto node = fetchNode(baseuri);
    auto objs = parse!module_(node, baseuri);
    if (frag.empty)
    {
        import std.algorithm : startsWith;
        frag = defaultFragment.startsWith("#") ? defaultFragment[1..$] : defaultFragment;
    }
    auto targetURI = baseuri~"#"~frag;

    alias RetType = typeof(objs);
    alias DocType = DocumentRootType!module_;
    return objs.match!(
        (DocType doc) {
            docEnforce(uri.fragment.empty || doc.match!(d => d.identifier) == targetURI,
                       "Mismatched fragment", node.startMark);
            return objs;
        },
        (DocType[] docs) {
            if (frag.empty)
            {
                return objs;
            }
            else
            {
                import std.format : format;

                auto elems = () @trusted {
                    import std.algorithm : filter;
                    import std.array : array;
                    // SumType.opAssign used in `array` is unsafe
                    // we can mark it as trusted because it does not leak any pointers outside an array
                    return docs.filter!(e => e.tryMatch!(d => d.identifier) == targetURI)
                               .array;
                }();
                docEnforce(!elems.empty, format!"No objects for ID `%s`"(targetURI), node.startMark);
                docEnforce(elems.length == 1, format!"Duplicated objects for ID `%s`"(targetURI), node.startMark);
                return RetType(elems[0]);
            }
        }
    );
}
