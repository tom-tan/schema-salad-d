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
    private import dyaml : Node, NodeType;
    private import salad.context : LoadingContext;

    enum Symbols
    {
        Any = "Any",
    }

    Node value_;
    const LoadingContext context_;

    this(Node node, in LoadingContext context = LoadingContext.init)
    {
        import salad.exception : docEnforce;
        docEnforce(node.type != NodeType.null_,
                   "Any should be non-null", node);
        value_ = node;
        context_ = context;
    }

    T as(T)()
    {
        import salad.meta.impl : as_;
        return value_.as_!T(context_);
    }
}
