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

/// A fetcher type that returns a string from absolute URI.
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
    bool canSupport(string scheme) const @nogc nothrow pure @safe
    {
        return scheme in schemeFetchers;
    }

    ///
    auto fetchText(string uri) const @safe
    {
        import salad.fetcher.exception : fetcherEnforce;
        import salad.resolver : scheme_ = scheme;
        import std.format : format;

        auto scheme = uri.scheme_;
        auto fetcher = *fetcherEnforce(scheme in schemeFetchers,
                                       format!"Scheme `%s` is not supported (uri: `%s`)."(scheme, uri));
        return fetcher(uri);
    }
private:
    this() nothrow pure @safe
    {
        schemeFetchers["file"] = (uri) {
            import salad.fetcher.exception : fetcherEnforce;
            import salad.resolver : path_ = path;
            import std.file : exists, readText;
            import std.format : format;

            auto path = uri.path_;
            fetcherEnforce(path.exists, format!"File not found: `%s`"(path));
            return path.readText;
        };
        schemeFetchers["http"] = schemeFetchers["https"] = (uri) {
            import requests : getContent;
            import salad.resolver : withoutFragment;

            auto path = uri.withoutFragment;
            return () @trusted { return cast(string)(path.getContent); } ();
        };
    }
    TextFetcher[string] schemeFetchers;
}
