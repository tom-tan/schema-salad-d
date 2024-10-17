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
        import salad.meta.impl : as_;
        super(node.startMark, context);
        payload = node.as_!(typeof(payload))(context);
    }
}

mixin template genDumper()
{
    private import dyaml : Node;
    private import salad.primitives : OmitStrategy;

    ///
    override Node toNode(OmitStrategy os = OmitStrategy.none) const @safe
    {
        import salad.meta.dumper : toNode;
        return payload.toNode(os);
    }
}

@safe unittest
{
    import dyaml : Node;
    import salad.primitives : UnionSchemaBase;
    import salad.type : Union;
    import salad.meta.impl : genBody_;

    static class Foo : UnionSchemaBase
    {
        Union!(bool, Foo[string]) payload;
        mixin genBody_!"v1.3";
    }

    auto foo = new Foo;
    auto n = Node(foo);
}
