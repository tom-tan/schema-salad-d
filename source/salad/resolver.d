/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.resolver;

import dyaml : Node, NodeType;

import salad.context : LoadingContext;

import std.typecons : Tuple;

/**
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Link_resolution
 */
auto resolveLink(string link, in LoadingContext context) nothrow pure @safe
{
    import std.algorithm : canFind, endsWith, findSplitAfter, findSplitBefore, startsWith;

    auto pathPortionOf(string uri)
    {
        if (auto split = uri.findSplitBefore("#"))
        {
            return split[0];
        }
        else
        {
            return uri;
        }
    }

    if (link.startsWith("#"))
    {
        // rerlative fragment identifier
        return pathPortionOf(context.baseURI)~link;
    }
    else if (auto split = link.findSplitBefore(":"))
    {
        import std.algorithm : canFind;

        if (auto ns = split[0] in context.namespaces)
        {
            // resolved with namespaces
            return *ns ~ split[1][1..$];
        }
        else if (link.canFind("://"))
        {
            // assumption: an absolute URI contains "://"
            return link;
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
unittest
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
ExplicitContext splitContext(in Node node, string uri)
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
ExplicitContext resolveDirectives(in Node node, in LoadingContext context)
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
