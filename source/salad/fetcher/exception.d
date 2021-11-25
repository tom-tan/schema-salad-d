module salad.fetcher.exception;

///
class FetcherException : Exception
{
    import std.exception : basicExceptionCtors;
    ///
    mixin basicExceptionCtors;
}
