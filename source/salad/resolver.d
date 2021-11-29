/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.resolver;

import dyaml : Node, NodeType;

import salad.context : LoadingContext;

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
    auto context = LoadingContext(
        "http://example.com/base",
        [
            "acid": "http://example.com/acid#",
        ]
    );
    
    enum zero = "http://example.com/base/zero";
    assert(zero.resolveLink(context) == zero);

    assert("one".resolveLink(context) == "http://example.com/one");
    assert("two".resolveLink(context) == "http://example.com/two");
    assert("#three".resolveLink(context) == "http://example.com/base#three");
    assert("four#five".resolveLink(context) == "http://example.com/four#five");
    assert("acid:six".resolveLink(context) == "http://example.com/acid#six");
}

/**
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Import
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Include
 */
auto preprocess(in Node node, in LoadingContext context)
{
    import salad.fetcher : fetchNode, fetchText;

    if (node.type != NodeType.mapping)
    {
        return node;
    }
    else if (auto link = "$import" in node)
    {
        auto resolved = resolveLink(link.as!string, context);
        return resolved.fetchNode;
    }
    else if (auto link = "$include" in node)
    {
        auto resolved = resolveLink(link.as!string, context);
        return Node(resolved.fetchText);
    }
    else
    {
        return node;
    }
}

/**
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Import_example
 */
unittest
{
    import dyaml : Loader;
    import std.path : absolutePath;

    auto context = LoadingContext(
        "file://"~"examples/import/parent.json".absolutePath,
    );

    enum str = q"EOS
        "bar": {
            "$import": "import.json"
        }
EOS";

    auto node = Loader.fromString(str).load;
    auto processed = node["bar"].preprocess(context);
    assert("hello" in processed);
    assert(processed["hello"] == "world");
}

/**
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Include_example
 */
unittest
{
    import dyaml : Loader;
    import std.path : absolutePath;

    auto context = LoadingContext(
        "file://"~"examples/include/parent.json".absolutePath,
    );

    enum str = q"EOS
        "bar": {
            "$include": "include.txt"
        }
EOS";

    auto node = Loader.fromString(str).load;
    auto processed = node["bar"].preprocess(context);
    assert(processed == "hello world");
}
