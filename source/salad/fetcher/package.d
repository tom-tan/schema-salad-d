module salad.fetcher;

///
auto fetchText(string uri)
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
auto fetchNode(string uri)
{
    import dyaml : Loader;
    return Loader.fromString(fetchText(uri)).load;
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

unittest
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
    static typeof(this) instance()
    {
        static Fetcher instance_;

        if (instance_ is null)
        {
            instance_ = new Fetcher();
        }
        return instance_;
    }

    ///
    auto addSchemeFetcher(string scheme, TextFetcher fetcher)
    {
        schemeFetchers[scheme] = fetcher;
    }

    ///
    auto fetchText(string uri)
    {
        import std.exception : enforce;
        import std.format : format;

        auto scheme = uri.scheme;
        auto fetcher = *enforce(scheme in schemeFetchers,
                                format!"Scheme `%s` is not supported."(scheme));
        return fetcher(uri);
    }
private:
    this()
    {
        import std.exception : enforce;
        import std.file : exists, readText;

        schemeFetchers["file"] = (uri) {
            import std.format : format;
            auto path = uri.pathWithAuthority;
            enforce(path.exists, format!"File not found: `%s`"(path));
            return path.readText;
        };
        // schemeFetchers["http"] = schemeFetchers["https"] = (uri) {
        //     return "";
        // };
    }
    TextFetcher[string] schemeFetchers;
}
