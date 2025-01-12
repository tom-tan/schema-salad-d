/**
 * This module declares primitive types that need special handling.
 *
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.primitives;

import dyaml : Mark, Node;
import salad.context : LoadingContext;

/// A way to handle fields with null value (null fields) when converting them into a YAML node
enum OmitStrategy
{
    default_, /// use default strategy for each schema object
    none,     /// leave them as is
    shallow,  /// omit them in the root level but leave them as is in other levels
    deep,     /// omit them in all the levels
}

/// Base class for schema objects
abstract class SchemaBase
{
    ///
    this() @nogc nothrow pure @safe {}

    ///
    this(Mark mark, in LoadingContext context = LoadingContext.init) nothrow pure @safe
    {
        this.mark = mark;
        this.context = context;
    }

    ///
    Node toNode(OmitStrategy os = OmitStrategy.default_) const @safe;
    ///
    Node opCast(T: Node)() const @safe => toNode(OmitStrategy.default_);

    LoadingContext context;
    Any[string] extension_fields;
    Mark mark;
}

/// Base class for record schema objects
abstract class RecordSchemaBase : SchemaBase
{
    this() @nogc nothrow pure @safe {
        super();
    }

    this(Mark mark, in LoadingContext context = LoadingContext.init) nothrow pure @safe
    {
        super(mark, context);
    }
}

/// Base class for enum schema objects
abstract class EnumSchemaBase : SchemaBase
{
    this() @nogc nothrow pure @safe {
        super();
    }

    this(Mark mark, in LoadingContext context = LoadingContext.init) nothrow pure @safe
    {
        super(mark, context);
    }
}

/// Base class for union schema objects
abstract class UnionSchemaBase : SchemaBase
{
    this() @nogc nothrow pure @safe {
        super();
    }

    this(Mark mark, in LoadingContext context = LoadingContext.init) nothrow pure @safe
    {
        super(mark, context);
    }
}

/// Base class for map schema objects
abstract class MapSchemaBase : SchemaBase
{
    this() @nogc nothrow pure @safe {
        super();
    }

    this(Mark mark, in LoadingContext context = LoadingContext.init) nothrow pure @safe
    {
        super(mark, context);
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Any
class Any : SchemaBase
{
    private import dyaml : Node;

    Node value;

    ///
    this(Node node, in LoadingContext context = LoadingContext.init) @safe
    {
        import dyaml : NodeType;
        import salad.exception : docEnforce;
        docEnforce(node.type != NodeType.null_,
                   "Any should be non-null", node.startMark);
        value = node;
        super(node.startMark, context);
    }

    ///
    T as(T)() @safe
    {
        import salad.meta.impl : as_;
        return value.as_!T(context);
    }

    ///
    override Node toNode(OmitStrategy os = OmitStrategy.default_) const @nogc nothrow @safe
    {
        return value;
    }
}

/// See_Also: https://www.commonwl.org/v1.2/CommandLineTool.html#Expression
alias Expression = string;
