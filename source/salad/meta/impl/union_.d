/**
 * This module provides mixins and functions to implement parsers for union schemas.
 * Authors: Tomoya Tanjo
 * Copyright: © 2024 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.meta.impl.union_;

///
mixin template genCtor()
{
    private import dyaml : Node;
    private import salad.context : LoadingContext;

    this() @safe { super(); }
    this(Node node, in LoadingContext context = LoadingContext.init) @trusted
    {
        super(node.startMark, context);
        payload = node.as_!(typeof(payload))(context);
    }
}

mixin template genDumper()
{
    private import dyaml : Node;

    ///
    Node opCast(T: Node)() const
    {
        import salad.meta.dumper : toNode;
        return payload.toNode;
    }
}
