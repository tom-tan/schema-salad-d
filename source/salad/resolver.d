/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.resolver;

import dyaml : Node, NodeType;

import salad.context : LoadingContext;

import std.typecons : Tuple;

//
auto pathPortionOf(string uri) nothrow pure @safe
{
    import std.algorithm : findSplitBefore;

    if (auto split = uri.findSplitBefore("#"))
    {
        return split[0];
    }
    else
    {
        return uri;
    }
}

/// assumption: an absolute URI contains "://"
auto isAbsoluteURI(string uriOrPath) nothrow pure @safe
{
    import std.algorithm : canFind;
    return uriOrPath.canFind("://");
}

/**
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Identifier_resolution
 */
auto resolveIdentifier(string id, in LoadingContext context) nothrow pure @safe
{
    import salad.fetcher : fragment, scheme;
    import std.algorithm : canFind, findSplitBefore, startsWith;
    import std.range : empty;

    if (id.isAbsoluteURI)
    {
        return id;
    }
    else if (id.startsWith("#"))
    {
        // current document fragment identifier
        return pathPortionOf(context.baseURI)~id;
    }
    else if (auto split = id.findSplitBefore(":"))
    {
        if (auto ns = split[0] in context.namespaces)
        {
            // resolved with namespaces
            return *ns ~ split[1][1..$];
        }
        else
        {
            // unresolved identifier
            return id;
        }
    }
    else if (id.canFind("#"))
    {
        // relative URI with fragment identifier
        import std.path : buildPath, dirName;
        return context.baseURI.dirName.buildPath(id);
    }
    else
    {
        // parent relative fragment identifier
        if (context.baseURI.fragment.empty)
        {
            return context.baseURI~"#"~id;
        }

        string baseURI = context.baseURI;
        if (!context.subscope.empty)
        {
            baseURI = context.baseURI~"/"~context.subscope;
        }

        if (!baseURI.fragment.empty)
        {
            return baseURI~"/"~id;
        }
        // unresolved identifier
        return id;
    }
}

/**
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Identifier_resolution_example
 */
nothrow pure @safe unittest
{
    LoadingContext context0 = {
        baseURI: "",
        namespaces: [
            "acid": "http://example.com/acid#",
        ]
    };
    enum base = "http://example.com/base";
    assert(base.resolveIdentifier(context0) == base);

    LoadingContext context1 = {
        baseURI: base,
        namespaces: [
            "acid": "http://example.com/acid#",
        ]
    };
    assert("one".resolveIdentifier(context1) == "http://example.com/base#one");

    LoadingContext context2 = {
        baseURI: "http://example.com/base#one",
        namespaces: [
            "acid": "http://example.com/acid#",
        ]
    };
    assert("two".resolveIdentifier(context2) == "http://example.com/base#one/two");
    assert("#three".resolveIdentifier(context2) == "http://example.com/base#three");
    assert("four#five".resolveIdentifier(context2) == "http://example.com/four#five");
    assert("acid:six".resolveIdentifier(context2) == "http://example.com/acid#six");

    LoadingContext context3 = {
        baseURI: "http://example.com/base#one",
        namespaces: [
            "acid": "http://example.com/acid#",
        ],
        subscope: "thisIsASubscope"
    };
    assert("seven".resolveIdentifier(context3) == "http://example.com/base#one/thisIsASubscope/seven");
}

/**
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Link_resolution
 */
auto resolveLink(string link, in LoadingContext context) nothrow pure @safe
{
    import std.algorithm : canFind, endsWith, findSplitAfter, findSplitBefore, startsWith;

    if (link.isAbsoluteURI)
    {
        return link;
    }
    else if (link.startsWith("#"))
    {
        // rerlative fragment identifier
        return pathPortionOf(context.baseURI)~link;
    }
    else if (auto split = link.findSplitBefore(":"))
    {
        if (auto ns = split[0] in context.namespaces)
        {
            // resolved with namespaces
            return *ns ~ split[1][1..$];
        }
        else
        {
            // unresolved link
            return link;
        }
    }
    else
    {
        // path relative reference
        string pathPortionOfRefURI = pathPortionOf(link);
        string pathPortionOfBaseURI = pathPortionOf(context.baseURI);
        if (pathPortionOfBaseURI.endsWith("/"))
        {
            return context.baseURI ~ pathPortionOfRefURI;
        }
        else
        {
            import std.path : buildPath, dirName;
            return context.baseURI.dirName.buildPath(link);
        }
    }
}

/**
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Link_resolution_example
 */
nothrow pure @safe unittest
{
    LoadingContext context = {
        baseURI: "http://example.com/base",
        namespaces: [
            "acid": "http://example.com/acid#",
        ]
    };
    
    enum zero = "http://example.com/base/zero";
    assert(zero.resolveLink(context) == zero);

    assert("one".resolveLink(context) == "http://example.com/one");
    assert("two".resolveLink(context) == "http://example.com/two");
    assert("#three".resolveLink(context) == "http://example.com/base#three");
    assert("four#five".resolveLink(context) == "http://example.com/four#five");
    assert("acid:six".resolveLink(context) == "http://example.com/acid#six");
}

///
alias ExplicitContext = Tuple!(Node, "node", LoadingContext, "context");

/**
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Document_context
 */
ExplicitContext splitContext(in Node node, string uri) @safe
{
    if (node.type == NodeType.mapping)
    {
        LoadingContext con;
        if (auto base = "$base" in node)
        {
            con.baseURI = base.as!string;
        }
        else
        {
            con.baseURI = uri;
        }
        con.fileURI = uri;

        if (auto ns = "$namespaaces" in node)
        {
            import std.algorithm : map;
            import std.array : assocArray;
            import std.typecons : tuple;

            con.namespaces = ns.mapping
                .map!(a => tuple(a.key.as!string, a.value.as!string))
                .assocArray;
        }

        if (auto s = "$schemas" in node)
        {
            // TODO
            import std.algorithm : map;
            import std.array : array;
            auto schemas = s.sequence.map!(a => a.as!string).array;
        }

        if (auto g = "$graph" in node)
        {
            return typeof(return)(*g, con);
        }
        else
        {
            return typeof(return)(node, con);
        }
    }
    else
    {
        return typeof(return)(node, LoadingContext(uri, uri));
    }
}

/**
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Import
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Include
 */
ExplicitContext resolveDirectives(in Node node, in LoadingContext context) @trusted
{
    if (node.type == NodeType.mapping)
    {
        import salad.resolver : resolveLink;

        if (auto link = "$import" in node)
        {
            import salad.fetcher : fetchNode;

            // workaround for common-workflow-language/schema_salad#495
            const LoadingContext con = {
                baseURI: context.fileURI,
                fileURI: context.fileURI,
                namespaces: context.namespaces
            };
            auto uri = resolveLink(link.as!string, con);
            return splitContext(uri.fetchNode, uri);
        }
        else if (auto link = "$include" in node)
        {
            import salad.fetcher : fetchText;

            // workaround for common-workflow-language/schema_salad#495
            const LoadingContext con = {
                baseURI: context.fileURI,
                fileURI: context.fileURI,
                namespaces: context.namespaces
            };
            auto uri = resolveLink(link.as!string, con);
            auto n = Node(uri.fetchText);
            return typeof(return)(n, cast()context);
        }
    }
    return typeof(return)(cast()node, cast()context);
}

/**
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Import_example
 */
unittest
{
    import dyaml : Loader;
    import std.path : absolutePath;

    LoadingContext context = {
        baseURI: "file://"~"examples/import/parent.json".absolutePath,
        fileURI: "file://"~"examples/import/parent.json".absolutePath,
    };

    enum str = q"EOS
        "bar": {
            "$import": "import.json"
        }
EOS";

    auto node = Loader.fromString(str).load;
    auto resolved = resolveDirectives(node["bar"], context);
    assert("hello" in resolved.node);
    assert(resolved.node["hello"] == "world");
}

/**
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Include_example
 */
unittest
{
    import dyaml : Loader;
    import std.path : absolutePath;

    LoadingContext context = {
        fileURI: "file://"~"examples/include/parent.json".absolutePath,
    };

    enum str = q"EOS
        "bar": {
            "$include": "include.txt"
        }
EOS";

    auto node = Loader.fromString(str).load;
    auto resolved = resolveDirectives(node["bar"], context);
    assert(resolved.node == "hello world");
}
