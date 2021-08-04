module salad.ast;

import dyaml : Mark, Node;

import salad.type;

import std.typecons : Tuple;

alias ASTNodeType = Optional!(bool,
                              long,
                              real,
                              string,
                              AST[string],
                              AST[],
                              AST, 
                              Node);

///
class AST
{
    Mark mark;
    string vocabulary;
    ASTNodeType value;

    ///
    this(T)(Node node, string vocab, T val) // validate T type
    {
        mark = node.startMark;
        vocabulary = vocab;
        value = ASTNodeType(val);
    }

    override string toString() @trusted
    {
        import std.conv : to;
        import std.format : format;
        return format!"AST(%s, %s)"(vocabulary, value.match!(v => v.to!string));
    }
}

/// dig
auto dig(T)(AST ast, string key, T default_)
{
    return dig(ast, [key], default_);
}

/// ditto
AST dig(T)(AST ast, string[] keys, T default_)
{
    import std.algorithm : canFind;
    import std.range : empty;

    if (auto a = ast.value.match!((AST a) => a, others => null))
    {
        return a.dig(keys, default_);
    }
    else if (auto n = ast.value.match!((Node n) => &n, others => null))
    {
        import salad.util : dig;
        auto digged = n.dig(keys, default_);
        return new AST(digged, "Any", digged);
    }
    else if (keys.empty)
    {
        return ast;
    }

    auto k = keys[0];

    auto rec = ast.value.tryMatch!((AST[string] rec) => rec);
    if (auto a = k in rec)
    {
        return (*a).dig(keys[1..$], default_);
    }
    else
    {
        if (k.canFind("://"))
        {
            static if (is(T: void[]))
            {
                auto n = Node((Node[]).init);
            }
            else
            {
                auto n = Node(default_);
            }
            return new AST(Node.init, "Any", n);
        }
        else
        {
            static if (is(T : void[]))
            {
                auto def = (AST[]).init;
            }
            else
            {
                auto def = default_;
            }
            return new AST(Node.init, "Any", def);
        }
    }
}

/// edig
auto edig(Ex = Exception)(AST ast, string key)
{
    return edig!Ex(ast, [key]);
}

/// ditto
AST edig(Ex = Exception)(AST ast, string[] keys)
{
    import std.algorithm : canFind;
    import std.range : empty;

    if (auto a = ast.value.match!((AST a) => a, others => null))
    {
        return a.edig!Ex(keys);
    }
    else if (auto n = ast.value.match!((return ref Node n) => &n, others => null))
    {
        import salad.util : edig;
        auto digged = (*n).edig!Ex(keys);
        return new AST(digged, "Any", digged);
    }
    else if (keys.empty)
    {
        return ast;
    }

    auto k = keys[0];

    auto rec = ast.value.tryMatch!((AST[string] rec) => rec);
    if (auto a = k in rec)
    {
        return (*a).edig!Ex(keys[1..$]);
    }
    else
    {
        import std.format : format;
        throw new Ex(format!"No such field: %s"(k));
    }
}
