module salad.ast;

import dyaml : Mark, Node;

import salad.type;

import std.typecons : Tuple;

///
struct RecordType
{
    AST[string] fields;
    AST[string] extensionFields;

    string toString() @trusted
    {
        import std.format : format;
        return format!"RecordType(fields: %s, exts: %s)"(fields, extensionFields);
    }
}

alias ASTNodeType = Optional!(bool,
                              long,
                              real,
                              string,
                              RecordType,
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
    else if (keys.empty)
    {
        return ast;
    }

    auto k = keys[0];

    auto rec = ast.value.tryMatch!((RecordType rt) => rt);
    if (k.canFind("://"))
    {
        if (auto a = k in rec.extensionFields)
        {
            import salad.util : dig;
            auto n = a.value.tryMatch!((Node n) => n.dig(keys[1..$], default_));
            return new AST(n, "Any", n);
        }
        else
        {
            static if (is(T: void[]))
            {
                auto n = Node((Node[]).init);
            }
            else
            {
                auto n = Node(default_);
            }
            return new AST(n, "Any", n);
        }
    }
    else if (auto a = k in rec.fields)
    {
        return (*a).dig(keys[1..$], default_);
    }
    else
    {
        static if (is(T : void[]))
        {
            return new AST(Node.init, "Any", (AST[]).init);
        }
        else
        {
            return new AST(Node.init, "Any", default_);
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
    else if (keys.empty)
    {
        return ast;
    }

    auto k = keys[0];

    auto rec = ast.value.tryMatch!((RecordType rt) => rt);
    if (k.canFind("://"))
    {
        if (auto a = k in rec.extensionFields)
        {
            import salad.util : edig;
            auto n = a.value.tryMatch!((Node n) => n.edig!Ex(keys[1..$]));
            return new AST(n, "Any", n);
        }
        else
        {
            import std.format : format;
            throw new Ex(format!"No such field: %s"(k));
        }
    }
    else if (auto a = k in rec.fields)
    {
        return (*a).edig!Ex(keys[1..$]);
    }
    else
    {
        import std.format : format;
        throw new Ex(format!"No such field: %s"(k));
    }
}
