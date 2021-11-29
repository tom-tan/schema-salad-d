/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.fetcher.exception;

import std.exception : enforce;

///
class FetcherException : Exception
{
    import std.exception : basicExceptionCtors;
    ///
    mixin basicExceptionCtors;
}

///
alias fetcherEnforce = enforce!FetcherException;
