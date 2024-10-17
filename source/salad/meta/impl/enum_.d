/**
 * This module provides mixins and functions to implement parsers for enum schemas.
 * Authors: Tomoya Tanjo
 * Copyright: © 2024 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.meta.impl.enum_;

mixin template genCtor()
{
    private import dyaml : Node;
    private import salad.context : LoadingContext;

    this() @nogc nothrow pure @safe
    {
        super();
    }

    this(Node node, in LoadingContext context = LoadingContext.init) @safe
    {
        import dyaml : Mark, NodeType;
        import salad.exception : docEnforce;
        import std : canFind, format, EnumMembers;

        docEnforce(node.type == NodeType.string,
            format!"Invalid type for %s: string is expected"(This.stringof),
            node.startMark);
        auto val = node.as!string;
        docEnforce([EnumMembers!Symbol].canFind(val),
            format!"Invalid value for %s: `%s`"(This.stringof, val),
            node.startMark);
        super(node.startMark, context);
        value = cast(Symbol)val;
    }

    this(string value) @safe
    {
        this(Node(value));
    }
}

///
mixin template genOpEq()
{
    bool opEquals(string s) const @nogc nothrow pure @safe
    {
        return value == s;
    }
}

///
mixin template genDumper()
{
    private import dyaml : Node;
    private import salad.primitives : OmitStrategy;

    override Node toNode(OmitStrategy os = OmitStrategy.none) const @safe
    {
        return Node(cast(string)value);
    }
}
