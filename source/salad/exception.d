/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.exception;

import dyaml : Node;

///
class SchemaException : Exception
{
    ///
    this(string msg, Node node, Throwable nextInChain = null) nothrow pure
    {
        auto mark = node.startMark;
        super(msg, mark.name, mark.line+1, nextInChain);
        column = mark.column+1;
    }

    ///
    ulong column;
}

///
E schemaEnforce(E)(lazy E exp, string msg, Node node)
{
    if (auto e = exp())
    {
        return e;
    }
    throw new SchemaException(msg, node);
}

///
class DocumentException : Exception
{
    ///
    this(string msg, Node node, Throwable nextInChain = null) nothrow pure
    {
        auto mark = node.startMark;
        super(msg, mark.name, mark.line+1, nextInChain);
        column = mark.column+1;
    }

    ///
    ulong column;
}

///
E docEnforce(E)(lazy E exp, string msg, Node node)
{
    if (auto e = exp())
    {
        return e;
    }
    throw new DocumentException(msg, node);
}
