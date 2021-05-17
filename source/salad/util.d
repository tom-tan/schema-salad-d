module salad.util;

import dyaml : Node;

/// dig
auto dig(T)(in Node node, string key, T default_)
{
    return dig(node, [key], default_);
}

/// ditto
auto dig(T)(in Node node, string[] keys, T default_)
{
    Node ret = node;
    foreach(k; keys)
    {
        if (auto n = k in ret)
        {
            ret = *n;
        }
        else
        {
            static if (is(T : void[]))
            {
                return Node((Node[]).init);
            }
            else
            {
                return Node(default_);
            }
        }
    }
    return ret;
}

/// enforceDig
auto edig(Ex = Exception)(in Node node, string key, string msg = "")
{
    return edig!Ex(node, [key], msg);
}

/// ditto
auto edig(Ex = Exception)(in Node node, string[] keys, string msg = "")
{
    Node ret = node;
    foreach(k; keys)
    {
        if (auto n = k in ret)
        {
            ret = *n;
        }
        else
        {
            import std.format : format;
            import std.range : empty;
            msg = msg.empty ? format!"No such field: %s"(k) : msg;
            throw new Ex(msg);
        }
    }
    return ret;
}
