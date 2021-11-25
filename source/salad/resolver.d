/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.resolver;

import dyaml;

import salad.schema;
import salad.type;

import std.meta : staticMap;
import std.range : empty;
import std.traits : isArray, isSomeString;
import std.typecons : Tuple;

import sumtype;

version(none):
struct Resolver
{
    this(SaladSchema s)
    {
        schema = s;

        baseURI = schema.base;
        URI2vocab = setupURI2Vocab(schema);
        vocab2URI = setupVocab2URI(URI2vocab);
        assert(URI2vocab.length == vocab2URI.length);

        vocab2Schema = setupVocab2Schema(schema);
    }

    auto lookup(string vocabulary)
    {
        return vocab2Schema[vocabulary];
    }

    SaladSchema schema;

    string baseURI;
    string subscope;
    string[string] vocab2URI;
    string[string] URI2vocab;
    DocumentSchema[string] vocab2Schema;

private:
    auto setupURI2Vocab(SaladSchema s)
    {
        import std.algorithm : filter, joiner, map;
        import std.array : assocArray;
        import std.range : empty;
        import std.typecons : tuple;

        return s.graph
                .map!(g => g.visit!(JsonldPredicate, "jsonldPredicate"))
                .joiner
                .filter!(tpl => tpl[1] && !tpl[1]._id_.empty)
                .map!(tpl => tuple(tpl[1]._id_, tpl[0]))
                .assocArray;
    }

    auto setupVocab2URI(string[string] URI2vocab)
    in(!URI2vocab.empty)
    {
        import std.algorithm : map;
        import std.array : assocArray, byPair;
        import std.typecons : tuple;

        return URI2vocab.byPair
                        .map!(tpl => tuple(tpl[1], tpl[0]))
                        .assocArray;
    }

    auto setupVocab2Schema(SaladSchema schema)
    {
        import std.algorithm : filter, map;
        import std.array : assocArray;
        import std.typecons : tuple;

        return schema.graph
                     .filter!(ds => ds.match!(
                        (SaladRecordSchema _) => true,
                        (SaladEnumSchema _) => true,
                        _ => false,
                     ))
                     .map!(ds => ds.match!(
                            (SaladRecordSchema srs) => tuple(srs.name_, cast(DocumentSchema)srs),
                            (SaladEnumSchema ses) => tuple(ses.name_, cast(DocumentSchema)ses),
                            _ => tuple("", DocumentSchema.init),
                     ))
                     .filter!(a => !a[0].empty)
                     .assocArray;
    }
}

// unittest
// {
//     import std.algorithm : map, joiner;
//     import std.array : array;
//     import std.conv : to;
//     import salad.util : diff;

//     enum base = "examples/field-name-resolution";
//     auto s = Loader.fromFile(base~"/schema.json")
//                    .load
//                    .as!SaladSchema;
//     auto r = Resolver(s);

//     auto example = Loader.fromFile(base~"/example.json")
//                          .load;
//     auto processed = r.preprocess(example);

//     auto expected = Loader.fromFile(base~"/expected.json")
//                           .load;
    
//     assert(processed == expected, diff(processed, expected).to!string);
// }

Tuple!(string, PropType)[] visit(PropType, string prop, T)(T t)
if (is(T == class))
{
    import std.algorithm : canFind, filter;
    import std.meta : anySatisfy;
    import std.range : only;
    import std.traits : FieldNameTuple, hasMember;
    import std.typecons : tuple;

    enum prop_ = prop~"_";
    typeof(return) ret;
    if (t is null)
    {
        return ret;
    }

    enum FieldNames = FieldNameTuple!T.only;
    static if (hasMember!(T, prop_))
    {
        alias PT = typeof(mixin("t."~prop_));
        enum isPropType(P) = is(P: PropType);

        static if (isPropType!PT)
        {
            static assert(hasMember!(T, "name_"));
            ret ~= tuple(t.name_, mixin("t."~prop_));
        }
        else static if (isSumType!PT && anySatisfy!(isPropType, PT.Types))
        {
            mixin("t."~prop_).match!(
                (PropType pt) {
                    static assert(hasMember!(T, "name_"));
                    ret ~= tuple(t.name_, pt);
                },
                (_) {},
            );
        }
    }
    static foreach(f; FieldNames.filter!(a => a != prop_))
    {
        ret ~= visit!(PropType, prop)(mixin("t."~f));
    }
    return ret;
}

Tuple!(string, PropType)[] visit(PropType, string prop, T)(T t)
if (!is(T == class))
{
    static if (isArray!T && !isSomeString!T)
    {
        import std.algorithm : joiner, map;
        import std.array : array;
        return t.map!(a => a.visit!(PropType, prop)).joiner.array;
    }
    else static if (isSumType!T)
    {
        return t.match!(f => f.visit!(PropType, prop));
    }
    else
    {
        return typeof(return).init;
    }
}

/**
Note: This function keeps `tag` field for `Node.opEquals`
*/
Node preprocess(Resolver resolver, Node node)
out(result; result.tag == node.tag)
out(result; result.type == node.type)
{
    switch(node.type)
    {
    case NodeType.mapping: {
        Node processed = Node(Node.init, node.tag);
        foreach(Node f, Node v; node)
        {
            auto resolved = Node(resolver.resolveFieldName(f.as!string), f.tag);
            processed.add(resolved, resolver.preprocess(v));
        }
        return processed;
    }
    case NodeType.sequence:
        import std.algorithm : map;
        import std.array : array;
        return Node(node.sequence.map!(n => resolver.preprocess(n)).array, node.tag);
    case NodeType.string:
        if (false /+ node is identifier+/)
        {
            // return Node(resolver.resolveIdentifier(node.as!string), node.tag);
            return node;
        }
        else
        {
            return node;
        }
    default:
        return node;
    }
}

/**
See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Field_name_resolution
*/
auto resolveFieldName(Resolver resolver, string field)
{
    import std.algorithm : canFind;
    import std.format : format;

    if (!field.canFind("://") && field.canFind(":"))
    {
        import std.algorithm : findSplit;
        import std.exception : enforce;

        auto split = field.findSplit(":");
        auto ns = enforce(split[0] in resolver.schema.namespaces,
                          format!"No such namespaces: `%s`"(split[0]));
        // 3.1. (1) If an field name URI begins with a namespace prefix declared in the document context (@context) followed by a colon :, the prefix and colon must be replaced by the namespace declared in @context.
        return *ns ~ split[2];
    }
    else if (auto voc = field in resolver.URI2vocab)
    {
        // 3.1. (2) If there is a vocabulary term which maps to the URI of a resolved field, the field name must be replace with the vocabulary term.
        return *voc;
    }
    else if (field.canFind("://"))
    {
        // 3.1. (3) If a field name URI is an absolute URI consisting of a scheme and path and is not part of the vocabulary, no processing occurs.
        return field;
    }
    else if (field in resolver.vocab2URI)
    {
        return field;
    }
    else
    {
        throw new Exception(format!"There are no vocabularies for `%s`"(field));
    }
}

/**
See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Identifier_resolution
*/
auto resolveIdentifier(Resolver resolver, string id, JsonldPredicate jp)
{
    import std.algorithm : canFind, startsWith;

    const baseURI = resolver.schema.base;

    //
    if (id.startsWith("#")) // 3.2. (1) If an identifier URI begins with `#` it is a current document fragment identifier.
    {
        import std.algorithm : findSplitBefore;

        if (auto b = baseURI.findSplitBefore("#"))
        {
            // It is resolved relative to the base URI by ... replacing the fragment portion of the base URI.
            return b[0]~id;
        }
        else
        {
            // It is resolved relative to the base URI by setting ... the fragment portion of the base URI.
            return baseURI ~ id;
        }
    }
    else if (id.canFind("#"))
    {
        // 3.2. (2) If an identifier URI contains `#` in some other position it is a relative URI with fragment identifier.
        // It is resolved relative to the base URI by stripping the last path segment from the base URI and adding the identifier followed by the fragment.
        import std.path : dirName;
        return baseURI.dirName~id;
    }
    else if (!id.canFind(":")) // 3.2. (3) If an identifier URI does not contain a scheme and does not contain `#` it is a parent relative fragment identifier.
    {
        if (!baseURI.canFind("#"))
        {
            // 3.2. (4) If an identifier URI is a parent relative fragment identifier and the base URI does not contain a document fragment, set the document fragment on the base URI.
            return baseURI ~ "#" ~ id;
        }
        else if (false /* parent object has `subscope` in `jsonldPredicate` */)
        {
            // 3.2. (5) If an identifier URI is a parent relative fragment identifier and the object containing this identifier is assigned to a parent object field defined with subscope in jsonldPredicate, append a slash / to the base URI fragment followed by the value of the parent field subscope. Then append the identifier as described in the next rule.
            //auto newBase = baseURI ~ "/" ~ parent.subscope;
            if (baseURI.canFind("#"))
            {
                // 3.2. (6) If an identifier URI is a parent relative fragment identifier and the base URI contains a document fragment, append a slash / to the fragment followed by the identifier field to the fragment portion of the base URI.

            }
            return id; // TODO
        }
        else
        {
            // TODO: Under "strict" validation, it is an error for a document to include fields which are not part of the vocabulary and not resolvable to absolute URIs.
            return id;
        }
    }
    else if (!id.canFind("://") && id.canFind(":"))
    {
        import std.algorithm : findSplit;

        auto split = id.findSplit(":");
        if (auto ns = split[0] in resolver.schema.namespaces)
        {
            // 3.2. (7) If an identifier URI begins with a namespace prefix declared in $namespaces followed by a colon :, the prefix and colon must be replaced by the namespace declared in $namespaces.
            return *ns ~ split[2];
        }
        else
        {
            // TODO: Under "strict" validation, it is an error for a document to include fields which are not part of the vocabulary and not resolvable to absolute URIs.
            return id;
        }
    }
    else if (id.canFind("://"))
    {
        // 3.2. (8) If an identifier URI is an absolute URI consisting of a scheme and path, no processing occurs.
        return id;
    }
    else
    {
        // TODO: Under "strict" validation, it is an error for a document to include fields which are not part of the vocabulary and not resolvable to absolute URIs.
        return id;
    }
}
