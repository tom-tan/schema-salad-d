/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.fetcher;

///
auto fetchText(string uri) @safe
{
    if (__ctfe)
    {
        import std.format : format;
        assert(false, format!"%s is not supported at compile time."(__FUNCTION__));
        //return import(uri);
    }
    else
    {
        return Fetcher.instance.fetchText(uri);
    }
}

///
auto fetchNode(string uri) @safe
{
    import dyaml : Loader;
    auto loader = Loader.fromString(fetchText(uri));
    loader.name = uri;
    return loader.load;
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
auto pathWithAuthority(string uri) pure @safe
{
    import std.algorithm : findSplit;
    if (auto sp1 = uri.findSplit("://"))
    {
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
    else
    {
        throw new Exception("Not valid URI");
    }
}

pure @safe unittest
{
    assert("file:///foo/bar#buzz".pathWithAuthority == "/foo/bar");
    assert("file:///foo/bar/buzz".pathWithAuthority == "/foo/bar/buzz");
    assert("ssh://user@hostname:/fuga/hoge/piyo".pathWithAuthority == "user@hostname:/fuga/hoge/piyo");
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

/++
A fetcher type that returns a string from absolute URI.
+/
alias TextFetcher = string delegate(string) @safe;

///
class Fetcher
{
    ///
    static typeof(this) instance() nothrow @safe
    {
        static Fetcher instance_;

        if (instance_ is null)
        {
            instance_ = new Fetcher();
        }
        return instance_;
    }

    ///
    void addSchemeFetcher(string scheme, TextFetcher fetcher) nothrow pure @safe
    {
        schemeFetchers[scheme] = fetcher;
    }

    ///
    void removeSchemeFetcher(string scheme) @nogc nothrow pure @safe
    {
        schemeFetchers.remove(scheme);
    }

    ///
    auto fetchText(string uri) const @safe
    {
        import salad.fetcher.exception : fetcherEnforce;
        import std.format : format;

        auto scheme = uri.scheme;
        auto fetcher = *fetcherEnforce(scheme in schemeFetchers,
                                       format!"Scheme `%s` is not supported (uri: `%s`)."(scheme, uri));
        return fetcher(uri);
    }
private:
    this() nothrow pure @safe
    {
        schemeFetchers["file"] = (uri) {
            import salad.fetcher.exception : fetcherEnforce;
            import std.file : exists, readText;
            import std.format : format;

            auto path = uri.pathWithAuthority;
            fetcherEnforce(path.exists, format!"File not found: `%s`"(path));
            return path.readText;
        };
        schemeFetchers["http"] = schemeFetchers["https"] = (uri) @trusted {
            import requests : getContent;
            import std.algorithm : findSplit;

            string path;
            if (auto split = uri.findSplit("#"))
            {
                path = split[0];
            }
            else
            {
                path = uri;
            }
            return cast(string)(path.getContent);
        };
    }
    TextFetcher[string] schemeFetchers;
}
