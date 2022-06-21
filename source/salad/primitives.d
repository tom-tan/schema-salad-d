/**
 * This module declares primitive types that need special handling.
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.primitives;

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Any
class Any
{
    private import dyaml : Mark, Node, NodeType;
    private import salad.context : LoadingContext;

    enum Symbols
    {
        Any = "Any",
    }

    Node value;
    LoadingContext context;
    Mark mark;

    ///
    this(Node node, in LoadingContext context = LoadingContext.init) @safe
    {
        import salad.exception : docEnforce;
        docEnforce(node.type != NodeType.null_,
                   "Any should be non-null", node.startMark);
        value = node;
        this.context = context;
        mark = node.startMark;
    }

    ///
    T as(T)() @safe
    {
        import salad.meta.impl : as_;
        return value.as_!T(context);
    }

    ///
    Node opCast(T: Node)() const @nogc nothrow @safe
    {
        return value;
    }
}
