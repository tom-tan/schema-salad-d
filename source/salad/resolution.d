module salad.resolution;

import dyaml;

import salad.schema;
import salad.type;

import std.meta : staticMap;
import std.traits : isArray, isSomeString;
import std.typecons : Tuple;

import sumtype;

struct Resolver
{
    this(Schema s)
    {
        schema = s;
        termMapping = setupTermMapping(schema);
    }

    auto setupTermMapping(Schema s)
    {
        import std.algorithm : filter, joiner, map;
        import std.array : assocArray;
        import std.range : empty;
        import std.typecons : tuple;

        return s.graph
                .map!(g => g.visit!(string, "jsonldPredicate"))
                .joiner
                .filter!(tpl => !tpl[1].empty)
                .map!(tpl => tuple(tpl[1], tpl[0]))
                .assocArray;
    }

    Schema schema;

    string[string] termMapping;
}

unittest
{
    import std.file : remove;
    import std.stdio : File;

    enum base = "examples/field-name-resolution";
    auto s = Loader.fromFile(base~"/schema.json")
                   .load
                   .as!Schema;
    auto r = Resolver(s);

    auto example = Loader.fromFile(base~"/example.json")
                         .load;
    auto processed = r.preprocess(example);

    auto expected = Loader.fromFile(base~"/expected.json")
                          .load;
    
    enum pr_yml = "processed.yml";
    auto f = File(pr_yml, "w");
    dumper.dump(f.lockingTextWriter, processed);
    f.close;
    scope(exit) pr_yml.remove;

    auto pr = Loader.fromFile(pr_yml)
                    .load;
    assert(pr == expected);
}

Tuple!(string, PropType)[] visit(PropType, string prop, T)(T t)
if (is(T == class))
{
    import std.algorithm : canFind, filter;
    import std.meta : anySatisfy;
    import std.range : only;
    import std.traits : FieldNameTuple, hasMember;
    import std.typecons : tuple;

    typeof(return) ret;

    enum FieldNames = FieldNameTuple!T.only;
    static if (hasMember!(T, prop))
    {
        alias PT = typeof(mixin("t."~prop));
        enum isPropType(P) = is(P: PropType);

        static if (isPropType!PT)
        {
            ret ~= tuple(t.name, mixin("t."~prop));
        }
        else static if (isSumType!PT && anySatisfy!(isPropType, PT.Types))
        {
            mixin("t."~prop).match!(
                (PropType pt) { ret ~= tuple(t.name, pt); },
                (_) {},
            );
        }
    }
    static foreach(f; FieldNames.filter!(a => a != prop))
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
        enum visitFun(F) = (F f) => f.visit!(PropType, prop);
        return t.match!(staticMap!(visitFun, T.Types));
    }
    else
    {
        return typeof(return).init;
    }
}

Node preprocess(Resolver resolver, Node node)
{
    switch(node.type)
    {
    case NodeType.mapping: {
        Node processed;
        foreach(string f, Node v; node)
        {
            string resolved = resolver.resolveFieldName(f);
            processed.add(resolved, resolver.preprocess(v));
        }
        return processed;
    }
    case NodeType.sequence:
        import std.algorithm : map;
        import std.array : array;
        return Node(node.sequence.map!(n => resolver.preprocess(n)).array);
    case NodeType.string:
        return node; // TODO
    default:
        return node;
    }
}

auto resolveFieldName(Resolver resolver, string field)
{
    import std.algorithm : canFind, findSplit;

    string resolvedField = field;
    // See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Field_name_resolution
    if (auto split = field.findSplit(":"))
    {
        if (auto ns = split[0] in resolver.schema.namespaces)
        {
            // 3.1. (1) If an field name URI begins with a namespace prefix declared in the document context (@context) followed by a colon :, the prefix and colon must be replaced by the namespace declared in @context.
            resolvedField = *ns ~ split[2];
        }
    }
            
    if (auto voc = field in resolver.termMapping)
    {
        // 3.1. (3) If there is a vocabulary term which maps to the URI of a resolved field, the field name must be replace with the vocabulary term.
        resolvedField = *voc;
    }

    if (field.canFind("://"))
    {
        // 3.1. (2) If a field name URI is an absolute URI consisting of a scheme and path and is not part of the vocabulary, no processing occurs.
        // nop
    }
    else
    {
        // TODO: Under "strict" validation, it is an error for a document to include fields which are not part of the vocabulary and not resolvable to absolute URIs.
        // nop
    }
    return resolvedField;
}
