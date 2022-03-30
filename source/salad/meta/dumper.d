/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.meta.dumper;

import dyaml : Node;
import salad.type : isOptional, isSumType, None;
import std.traits : hasStaticMember, isArray, isScalarType, isSomeString;

///
mixin template genDumper()
{
    private import salad.meta.dumper : toNode;

    ///
    Node opCast(T: Node)() const
    {
        static if (isSaladRecord!(typeof(this)))
        {
            import dyaml : CollectionStyle, NodeType;
            import std.algorithm : endsWith;
            import std.traits : FieldNameTuple;

            alias This = typeof(this);

            Node ret;
            ret.setStyle(CollectionStyle.flow);

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
            import dyaml : ScalarStyle;
            auto ret = Node(cast(string)value_);
            ret.setStyle(ScalarStyle.doubleQuoted);
            return ret;
        }
    }
}

Node toNode(T)(T t)
    if (is(T == class) || isScalarType!T || isSomeString!T)
{
    auto ret = Node(t);
    static if (isSomeString!T)
    {
        import dyaml : ScalarStyle;
        ret.setStyle(ScalarStyle.doubleQuoted);
    }
    return ret;
}

Node toNode(T)(T t)
    if (!isSomeString!T && isArray!T)
{
    import dyaml : CollectionStyle;
    Node ret;

    ret.setStyle(CollectionStyle.flow);
    foreach(e; t)
    {
        ret.add(e.toNode);
    }
    return ret;
}

Node toNode(T)(T t)
    if (isSumType!T)
{
    import dyaml : YAMLNull;
    import salad.type : match;

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
