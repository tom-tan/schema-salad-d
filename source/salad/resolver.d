/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.resolver;

import dyaml : Node, NodeType;

import salad.context : LoadingContext;

import std.file : getcwd;
import std.typecons : Tuple;

/** 
 * Returns: an absolute URI
 *
 * Note: It assumes that a string with "://" is an absolute URI
 */
auto isAbsoluteURI(string uriOrPath) @nogc nothrow pure @safe
{
    import std.algorithm : canFind;
    return uriOrPath.canFind("://");
}

/**
 * Returns: an absolute URI with scheme
 * Params: 
 *   pathOrURI = a string that is an absolute or relative local path, or a URI
 */
auto absoluteURI(string pathOrURI, string base = getcwd()) nothrow pure @safe
{
    import salad.resolver : isAbsoluteURI;
    import std.path : isAbsolute;

    if (pathOrURI.isAbsoluteURI)
    {
        return pathOrURI;
    }
    else if (pathOrURI.isAbsolute)
    {
        return "file://"~pathOrURI;
    }
    else if (base.isAbsolute)
    {
        import std.exception : assumeUnique, assumeWontThrow;
        import std.path : absolutePath, asNormalizedPath;
        import std.array : array;
        auto absPath = pathOrURI.absolutePath(base)
                                .assumeWontThrow
                                .asNormalizedPath
                                .array;
        return "file://"~(() @trusted => absPath.assumeUnique)();
    }
    else
    {
        assert(base.isAbsoluteURI);
        auto sc = base.scheme; // assumes `base` starts with `$sc://`
        auto abs = pathOrURI.absoluteURI(base[sc.length+2..$]);
        return sc~"://"~abs[(sc == "file" ? 7 : 8)..$];
    }
}

pure @safe unittest
{
    assert("http://example.com/foo/bar".absoluteURI == "http://example.com/foo/bar");
    assert("/foo/bar/buzz".absoluteURI == "file:///foo/bar/buzz");
    assert("../fuga/piyo".absoluteURI("http://example.com/foo/bar")
        == "http://example.com/foo/fuga/piyo");
    assert("../fuga/piyo".absoluteURI("/foo/bar")
        == "file:///foo/fuga/piyo");
}

///
auto scheme(string uri) @nogc nothrow pure @safe
{
    import std.algorithm : findSplit;
    if (auto split = uri.findSplit("://"))
    {
        return split[0];
    }
    else
    {
        return "";
    }
}

///
auto path(string uri) pure @safe
{
    import std.algorithm : findSplit;
    import std.exception : enforce;

    auto sp1 = enforce(uri.findSplit("://"), "Not valid URI");
    auto rest = sp1[2];
    if (auto sp2 = rest.findSplit("#"))
    {
        return sp2[0];
    }
    else
    {
        return rest;
    }
}

///
pure @safe unittest
{
    assert("file:///foo/bar#buzz".path == "/foo/bar");
    assert("file:///foo/bar/buzz".path == "/foo/bar/buzz");
    assert("ssh://user@hostname:/fuga/hoge/piyo".path == "user@hostname:/fuga/hoge/piyo");
}

///
auto fragment(string uri) @nogc nothrow pure @safe
{
    import std.algorithm : findSplit;
    if (auto split = uri.findSplit("#"))
    {
        return split[2];
    }
    else
    {
        return "";
    }
}

///
@nogc nothrow pure @safe unittest
{
    assert("file:///foo/bar#buzz".fragment == "buzz");
    assert("#foo".fragment == "foo");
}

/**
 * Returns: URI without fragment
 */
auto withoutFragment(string uri) @nogc nothrow pure @safe
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

/**
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Identifier_resolution
 */
auto resolveIdentifier(string id, in LoadingContext context) nothrow pure @safe
{
    import std.algorithm : canFind, findSplitBefore, startsWith;
    import std.range : empty;

    if (id.empty)
    {
        return id;
    }
    else if (id.isAbsoluteURI || id.isExpression)
    {
        return id;
    }
    else if (id.startsWith("#"))
    {
        // current document fragment identifier
        return context.baseURI.withoutFragment~id;
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

    if (link.isAbsoluteURI || link.isExpression)
    {
        return link;
    }
    else if (link.startsWith("#"))
    {
        // rerlative fragment identifier
        return context.baseURI.withoutFragment~link;
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
        string pathPortionOfRefURI = link.withoutFragment;
        string pathPortionOfBaseURI = context.baseURI.withoutFragment;
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

nothrow pure @safe unittest
{
    LoadingContext context = {
        baseURI: "http://example.com/base",
        namespaces: [
            "edam": "http://edamontology.org/",
        ]
    };

    assert("edam:format_2330".resolveLink(context) == "http://edamontology.org/format_2330");
}

// Returns: true if `exp` is an expression, which starts with `"$("` or `"${"`
// Note: It is CWL-specific but needed as a workaround for schema_salad#39.
// See_Also: https://github.com/common-workflow-language/schema_salad/issues/39
auto isExpression(string exp) @nogc nothrow pure @safe
{
    import std.algorithm : startsWith;
    return exp.startsWith("$(") || exp.startsWith("${");
}

///
alias ExplicitContext = Tuple!(Node, "node", LoadingContext, "context");

/**
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Document_context
 */
ExplicitContext splitContext(Node node, string uri) @safe
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

        if (auto ns = "$namespaces" in node)
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
ExplicitContext resolveDirectives(Node node, in LoadingContext context) @trusted
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
            return typeof(return)(n, context);
        }
    }
    return typeof(return)(node, context);
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
