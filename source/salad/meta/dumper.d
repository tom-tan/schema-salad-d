/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.meta.dumper;

import dyaml : Node;
import salad.type : isSumType;
import std.traits : isArray, isScalarType, isSomeString;

///
mixin template genDumper()
{
    ///
    Node opCast(T: Node)() const
    {
        static if (isSaladRecord!(typeof(this)))
        {
            import dyaml : CollectionStyle, NodeType;
            import std.algorithm : endsWith;
            import std.traits : FieldNameTuple;
            import salad.meta.dumper : toNode;

            alias This = typeof(this);

            Node ret;
            static foreach (field; __traits(allMembers, This))
            {
                static if (field.endsWith("_"))
                {
                    {
                        auto valNode = __traits(getMember, this, field).toNode;
                        if (valNode.type != NodeType.null_)
                        {
                            ret.add(field[0..$-1].toNode, valNode);
                        }
                    }
                }
            }
            // TODO: extension_fields
            return ret;
        }
        else static if (isSaladEnum!(typeof(this)))
        {
            return Node(cast(string)value_);
        }
    }
}

Node toNode(T)(T t)
    if (is(T == class) || isScalarType!T || isSomeString!T)
{
    return Node(t);
}

Node toNode(T)(T t)
    if (!isSomeString!T && isArray!T)
{
    import std.algorithm : map;
    import std.array : array;

    return Node(t.map!toNode.array);
}

Node toNode(T)(T t)
    if (isSumType!T)
{
    import dyaml : YAMLNull;
    import salad.type : isOptional, match, None;

    static if (isOptional!T)
    {
        return t.match!(
            (None _) => Node(YAMLNull()),
            other => other.toNode,
        );
    }
    else
    {
        return t.match!(e => e.toNode);
    }
}
