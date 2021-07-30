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
