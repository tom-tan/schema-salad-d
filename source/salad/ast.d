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
                              AST);

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

version(none):

/** candidate 1
 get a field via a property, record is a struct with provided names
 Pros:
 - easy access
 - static type check and no type conversion
 Cons:
 - may conflict property names or struct names with reserved words
*/
unittest
{
    alias parser = Parser!schema;
    auto cwl = parser.parse(node);
    static assert(is(cwl == CommandLineTool));
    assert(cwl.cwlVersion == "v1.2");
}

/** candidate 2
 get a field via `dig` that accesses an internal assoc array
 Pros:
 - no conflicts property names or struct names with reserved words
 Cons:
 - less user-friendly syntax
 - no-static type checking and need type conversion
*/
unittest
{
    auto parser = Parser(schema);
    auto ast = parser.parse(node);
    static assert(is(ast == AST));
    assert(ast.dig("cwlVersion").as!string == "v1.2");
}

/** candidate 3
 get a field via a preudo property internally uses opDispatch
 Pros:
 - easy access
 - less conflicts property names or struct with reserved words
 Cons:
 - no-static type checking and need type conversion
*/
unittest
{
    auto parser = Parser(schema);
    auto ast = parser.parse(node);
    static assert(is(ast == AST));
    assert(ast.cwlVersion_.as!string == "v1.2");
    assert(ast.opDispatch!"cwlVersion".as!string = "v1.2");
}

/** candidate 4
 get a field via a property, record is a struct with modified names
 Pros:
 - easy access
 - static type check and no type conversion
 - less conflict property names or struct with reserved words
 Cons:
 - cannot generate parsers at compile tiem (std.reegx.match is not CTFEable)
 - how to deal with extension fields?
*/
unittest
{
    alias parser = Parser!schema;
    auto cwl = parser.parse(node);
    static assert(is(cwl == CommandLineTool_));
    assert(cwl.cwlVersion_ == "v1.2");
    // dig is necessary in any cases
    // requirements may be null
    // how to dispatch the types for SumType?
    if (auto img = cwl.dig!("requirements", "DockerRequirement", "dockerPull"))
    {
    }
    if (auto img = cwl.dig!("requirements", 0, "dockerPull"))
    {
    }

    // providing default value
    auto llisting = cwl.dig!("requirements", "LoadListingRequirement", "loadListing")(LoadListingEnum_.no_listing_);

    // throw exception if no such field
    // no need to configure the type of exception or exception message
    auto cls = cwl.edig!"class";

    // extension field is accesible via dig/edig
    // only absolute URI is allowed
    auto authors = cwl.dig!("https://schema.org/author");
    static assert(is(authors == AST));
}
