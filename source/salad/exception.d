/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.exception;

import dyaml : Mark, Node;

///
abstract class SaladException : Exception
{
    ///
    this(string msg, Mark mark, Throwable nextInChain = null) nothrow pure @safe
    {
        super(msg, mark.name, mark.line+1, nextInChain);
        this.mark = mark;
    }

    Mark mark;
}

///
class SchemaException : SaladException
{
    ///
    this(string msg, Mark mark, Throwable nextInChain = null) nothrow pure @safe
    {
        super(msg, mark, nextInChain);
    }
}

///
E schemaEnforce(E)(lazy E exp, string msg, Mark mark)
{
    import std.exception : enforce;
    return enforce(exp, new SchemaException(msg, mark));
}

///
class DocumentException : SaladException
{
    ///
    this(string msg, Mark mark, Throwable nextInChain = null) nothrow pure @safe
    {
        super(msg, mark, nextInChain);
    }
}

///
E docEnforce(E)(lazy E exp, string msg, Mark mark)
{
    import std.exception : enforce;
    return enforce(exp, new DocumentException(msg, mark));
}
