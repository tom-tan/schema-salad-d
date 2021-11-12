/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.schema;

import dyaml : Node, NodeType;

import salad.ast : AST;
import salad.exception;
import salad.meta;
import salad.resolver;
import salad.canonicalizer;
import salad.type;

import so = salad.schema_original;

import std.algorithm : map;
import std.array : array;
import std.typecons : Tuple;

private Optional!string concat(Optional!(string, string[]) ss)
{
    import std.array : join;

    return ss.match!(
        (string s) => Optional!string(s),
        (string[] ss) => Optional!string(ss.join("\n")),
        none => Optional!string.init,
    );
}

private auto canonicalize(Optional!(string, so.JsonldPredicate) jp)
{
    return jp.match!(
        (string id) {
            auto pred = new JsonldPredicate;
            if (id == "@id")
            {
                pred._type_ = "@id";
                pred.identity_ = true;
            }
            else
            {
                pred._id_ = id;
            }
            return pred;
        },
        (so.JsonldPredicate pred) => new JsonldPredicate(pred),
        none => null,
    );
}

private Either!(
            PrimitiveType,
            RecordSchema,
            EnumSchema,
            ArraySchema,
            string)[] canonicalize(Either!(
                                    so.PrimitiveType,
                                    so.RecordSchema,
                                    so.EnumSchema,
                                    so.ArraySchema,
                                    string,
                                    Either!(
                                        so.PrimitiveType,
                                        so.RecordSchema,
                                        so.EnumSchema,
                                        so.ArraySchema,
                                        string)[]
                                    ) type)
{
    import std.range : ElementType;

    alias RetElemType = ElementType!(typeof(return));

    return type.match!(
        (so.PrimitiveType pt) => [RetElemType(new PrimitiveType(pt))],
        (so.RecordSchema rs) => [RetElemType(new RecordSchema(rs))],
        (so.EnumSchema es) => [RetElemType(new EnumSchema(es))],
        (so.ArraySchema as) => [RetElemType(new ArraySchema(as))],
        (string str) => [RetElemType(str)],
        (Either!(
            so.PrimitiveType,
            so.RecordSchema,
            so.EnumSchema,
            so.ArraySchema,
            string)[] types) => types.map!(
                t => t.match!(
                    (so.PrimitiveType pt) => RetElemType(new PrimitiveType(pt)),
                    (so.RecordSchema rs) => RetElemType(new RecordSchema(rs)),
                    (so.EnumSchema es) => RetElemType(new EnumSchema(es)),
                    (so.ArraySchema as) => RetElemType(new ArraySchema(as)),
                    str => RetElemType(str),
                )
            ).array,
    );
}

private auto orDefault(T, U)(T val, U default_)
if (isOptional!T && is(T.Types[1] == U))
{
    return val.match!((U u) => u, none => default_);
}

struct SaladSchema
{
    string base;
    string[string] namespaces;
    string[] schemas;
    Either!(SaladRecordSchema, SaladEnumSchema, Documentation)[] graph;

    this(in Node node) @trusted
    {
        import salad.util : dig, edig;
        import std.algorithm : map;
        import std.array : array, assocArray;
        import std.typecons : tuple;

        // TODO: load implied context
        base = node.dig("$base", "").as!string;
        namespaces = node.dig("$namespaces", (string[string]).init)
                         .mapping
                         .map!(kv => tuple(kv.key.as!string, kv.value.as!string))
                         .assocArray;
        schemas = node.dig("$schemas", [])
                      .sequence
                      .map!"a.as!string"
                      .array;

        graph = node.dig("$graph", [])
                    .sequence
                    .map!((n) {
                        import std.range : ElementType;

                        alias T = ElementType!(typeof(graph));

                        switch(n.edig("type").as!string)
                        {
                        case "record": return T(n.as!SaladRecordSchema);
                        case "enum": return T(n.as!SaladEnumSchema);
                        case "documentation": return T(n.as!Documentation);
                        default: throw new SchemaException("Invalid data type: "~n.edig("type").as!string, n);
                        }
                    })
                    .array;
    }
}

unittest
{
    import dyaml;
    import std.algorithm : filter;
    import std.file : dirEntries, isDir, SpanMode;
    foreach(dir; dirEntries("examples", SpanMode.shallow).filter!(d => d.isDir))
    {
        import std.exception : assertNotThrown;
        Loader.fromFile(dir~"/schema.json")
              .load
              .as!SaladSchema
              .assertNotThrown("Failed to load "~dir);
    }
}

abstract class DocumentSchema
{
    ///
    AST parse(Node node, Resolver resolver, JsonldPredicate jp = null)
    out(result; result)
    {
        assert(false, "It should be overridden by its subclass");
    }
}

class SaladRecordSchema : DocumentSchema
{
    mixin Canonicalize!(
        so.SaladRecordSchema,
        "inVocab", (Optional!bool inVocab) => inVocab.orDefault(true),
        "fields", (Optional!(so.SaladRecordField[]) fields) =>
                        fields.match!((so.SaladRecordField[] fs) => fs.map!(f => new SaladRecordField(f)).array,
                                      none => (SaladRecordField[]).init),
        "doc", (Optional!(string, string[]) doc) => doc.concat,
        "docChild", (Optional!(string, string[]) doc) => doc.concat,
        "jsonldPredicate", (Optional!(string, so.JsonldPredicate) jp) => jp.canonicalize,
        "documentRoot", (Optional!bool documentRoot) => documentRoot.orDefault(false),
        "abstract", (Optional!bool abstract_) => abstract_.orDefault(false),
        "extends", (Optional!(string, string[]) extends) => extends.match!((string s) => [s],
                                                                           (string[] ss) => ss,
                                                                           none => (string[]).init),
        "specialize", (Optional!(so.SpecializeDef[]) specialize) => 
                            specialize.match!((so.SpecializeDef[] sd) => sd.map!(s => new SpecializeDef(s)).array,
                                              none => (SpecializeDef[]).init),
    );

    mixin genToString;

    override AST parse(Node node, Resolver resolver, JsonldPredicate jp = null)
    {
        import std.format : format;
        import std.range : empty;

        schemaEnforce(node.type == NodeType.mapping, format!"mapping is expected but actual: %s"(node.type), node);

        auto rest = fields_.dup;
        AST[string] ret;

        // auto ids = srfs.find!(srf => srf.jsonldPredicate.match!(
        //     (string s) => s == "@id",
        //     (JsonldPredicate jp) => jp._type.match!((string s) => s == "@id", others => false) && 
        //                             jp.identity.match!((bool b) => b, others => false),
        //     others => false,
        // )).array;
        // string id;
        // schemaEnforce(ids.length <= 1, "Only one identifier field is allowed", node);
        // Resolver nextResolver;
        // if (ids.length == 1)
        // {
        //     auto idField = ids.front;
        //     id = idField.name;
        //     rest = rest.remove!(a => a.name == idField.name);
        //     nextResolver = resolver.withNewURI();
        // }
        // else
        // {
        //     nextResolver = resolver;
        // }
        foreach(string field, Node val; node)
        {
            import std.algorithm : canFind;

            auto resolved = resolver.resolveFieldName(field);

            if (resolved.canFind("://"))
            {
                ret[resolved] = new AST(val, "Any", val);
            }
            else
            {
                import std.algorithm : find;

                auto rng = rest.find!(r => r.name_ == resolved).array;
                schemaEnforce(!rng.empty, format!"No corresponding schema for `%s`"(resolved), node);
                    
                if (rng.length == 1)
                {
                    import std.algorithm : remove;
                    import std.range : front;

                    auto r = rng.front;
                    rest = rest.remove!(a => a.name_ == r.name_);
                    auto tpl = r.parse_(resolved, val, resolver);
                    ret[tpl[0]] = tpl[1];
                }
                else
                {
                    // ambiguous schema: there are several candidates
                    throw new SchemaException("ambiguous schema: there are several candidates (not yet implemented)", node);
                }
            }
        }
        // TODO: use `default` fields for non-provided fields
        schemaEnforce(rest.empty, format!"Missing fields: %(%s, %)"(rest.map!"a.name_".array), node);
        return new AST(node, "SaladRecordSchema", ret);
    }
}

class SaladRecordField : DocumentSchema
{
    mixin Canonicalize!(
        so.SaladRecordField,
        "type", (Either!(
                    so.PrimitiveType,
                    so.RecordSchema,
                    so.EnumSchema,
                    so.ArraySchema,
                    string,
                    Either!(
                        so.PrimitiveType,
                        so.RecordSchema,
                        so.EnumSchema,
                        so.ArraySchema,
                        string)[]
                    ) type) => type.canonicalize,
        "doc", (Optional!(string, string[]) doc) => doc.concat,
        "jsonldPredicate", (Optional!(string, so.JsonldPredicate) jp) => jp.canonicalize,
        "default", (Optional!(so.Any) default_) => default_.match!((so.Any any) => new Any(any), none => null),
    );

    mixin genToString;

    Tuple!(string, AST) parse_(string resolved, Node node, Resolver resolver, JsonldPredicate jp = null)
    in(resolved == name_)
    {
        import std.algorithm : filter, map;
        import std.array : array;
        import std.format : format;
        import std.typecons : tuple;

        auto ret = type_.map!(s => s.parse(node, resolver).speculate)
                        .array;
        auto ts = ret.map!"a.ast".filter!"a";
        auto exceptions = ret.map!"a.exception".filter!"a";
        if (ts.empty)
        {
            assert(!exceptions.empty);
            throw new SchemaException(format!"No matching types for `%s`"(name_), node, exceptions.front);
        }
        // TODO: consider the case of finds.length > 1 (ambiguous candidates)
        return tuple(name_, new AST(node, "SaladRecordField", ts.front));
    }
}

class PrimitiveType : DocumentSchema
{
    mixin Canonicalize!(so.PrimitiveType);

    mixin genToString;

    override AST parse(Node node, Resolver resolver, JsonldPredicate jp = null)
    {
        final switch(type_) with(so.PrimitiveType.Types)
        {
        case null_:
            schemaEnforce(node.type == NodeType.null_, "null is expected", node);
            return new AST(node, "null", None());
        case boolean_:
            schemaEnforce(node.type == NodeType.boolean, "boolean is expected", node);
            return new AST(node, "boolean", node.as!bool);
        case int_:
            schemaEnforce(node.type == NodeType.integer, "integer is expected", node);
            return new AST(node, "integer", node.as!long);
        case long_:
            schemaEnforce(node.type == NodeType.integer, "integer is expected", node);
            return new AST(node, "integer", node.as!long);
        case float_:
            schemaEnforce(node.type == NodeType.decimal, "decimal is expected", node);
            return new AST(node, "float", node.as!real);
        case double_:
            schemaEnforce(node.type == NodeType.decimal, "decimal is expected", node);
            return new AST(node, "float", node.as!real);
        case string_:
            schemaEnforce(node.type == NodeType.string, "string is expected", node);
            auto val = node.as!(.string);
            // if (jp &&
            //     jp._type.match!((string s) => s, others => "") == "@id" &&
            //     jp.identity.match!((bool b) => b, others => false) == true)
            // {
            //     auto id = resolver.resolveIdentifier(val, jp);
            //     return new AST(node, "string", id);
            // }
            // else
            // {
                return new AST(node, "string", val);
            // }
        }
    }
}

class Any : DocumentSchema
{
    mixin Canonicalize!(so.Any);

    override AST parse(Node node, Resolver resolver, JsonldPredicate jp = null)
    {
        return new AST(node, "Any", node);
    }
}

class RecordSchema : DocumentSchema
{
    mixin Canonicalize!(
        so.RecordSchema,
        "fields", (Optional!(so.RecordField[]) fields) =>
                    fields.match!((so.RecordField[] rf) => rf.map!(r => new RecordField(r)).array,
                                  none => (RecordField[]).init),
    );

    mixin genToString;

    override AST parse(Node node, Resolver resolver, JsonldPredicate jp = null)
    {
        import std.algorithm : map;
        import std.array : array;
        import std.format : format;
        import std.range : empty;

        schemaEnforce(node.type == NodeType.mapping, "mapping is expected", node);

        auto rest = fields_.dup;
        AST[string] ret;
        foreach(string field, Node val; node)
        {
            import std.algorithm : canFind, find;

            auto resolved = resolver.resolveFieldName(field);
            if (resolved.canFind("://"))
            {
                ret[resolved] = new AST(val, "Any", val);
            }
            else
            {
                import std.algorithm : find;

                auto rng = rest.find!(r => r.name_ == resolved).array;
                schemaEnforce(!rng.empty, format!"No corresponding schema for `%s`"(resolved), node);
                    
                if (rng.length == 1)
                {
                    import std.algorithm : remove;
                    import std.range : front;

                    auto r = rng.front;
                    rest = rest.remove!(a => a.name_ == r.name_);
                    auto tpl = r.parse_(resolved, node, resolver);
                    ret[tpl[0]] = tpl[1];
                }
                else
                {
                    // ambiguous schema: there are several candidates
                    throw new SchemaException("ambiguous schema: there are several candidates (not yet implemented)", node);
                }
            }
        }
        schemaEnforce(rest.empty, format!"Missing fields: %(%s, %)"(rest.map!"a.name_".array), node);
        return new AST(node, "RecordSchema", ret);
    }
}

class RecordField : DocumentSchema
{
    mixin Canonicalize!(
        so.RecordField,
        "type", (Either!(
                    so.PrimitiveType,
                    so.RecordSchema,
                    so.EnumSchema,
                    so.ArraySchema,
                    string,
                    Either!(
                        so.PrimitiveType,
                        so.RecordSchema,
                        so.EnumSchema,
                        so.ArraySchema,
                        string)[]
                    ) type) => type.canonicalize,
        "doc", (Optional!(string, string[]) doc) => doc.concat,
    );

    mixin genToString;

    Tuple!(string, AST) parse_(string resolved, Node node, Resolver resolver, JsonldPredicate jp = null)
    in(resolved == name_)
    {
        import std.algorithm : filter, map;
        import std.array : array;
        import std.format : format;
        import std.typecons : tuple;

        auto ret = type_.map!(s => s.parse(node, resolver).speculate)
                        .array;
        auto ts = ret.map!"a.ast".filter!"a";
        auto exceptions = ret.map!"a.exception".filter!"a";
        if (ts.empty)
        {
            assert(!exceptions.empty);
            throw new SchemaException(format!"No matching types for `%s`"(name_), node, exceptions.front);
        }
        // TODO: consider the case of types.length > 1 (ambiguous candidates)
        return tuple(name_, new AST(node, "RecordField", ts.front)); //tpl(ts.front);
    }
}

class EnumSchema : DocumentSchema
{
    mixin Canonicalize!(so.EnumSchema);

    mixin genToString;

    override AST parse(Node node, Resolver resolver, JsonldPredicate jp = null)
    {
        import std.algorithm : find;
        import std.format : format;
        import std.range : empty, front;

        schemaEnforce(node.type == NodeType.string, "string is expected", node);
        auto s = node.as!string;
        auto syms = symbols_.find(s);
        schemaEnforce(!syms.empty, format!"Unknown symbol `%s`"(s), node);
        return new AST(node, "EnumSchema", syms.front);
    }
}

class ArraySchema : DocumentSchema
{
    mixin Canonicalize!(
        so.ArraySchema,
        "items", (Either!(
                    so.PrimitiveType,
                    so.RecordSchema,
                    so.EnumSchema,
                    so.ArraySchema,
                    string,
                    Either!(
                        so.PrimitiveType,
                        so.RecordSchema,
                        so.EnumSchema,
                        so.ArraySchema,
                        string)[]
                    ) items) => items.canonicalize,
    );

    mixin genToString;

    override AST parse(Node node, Resolver resolver, JsonldPredicate jp = null)
    {
        import std.algorithm : map;
        import std.array : array;

        schemaEnforce(node.type == NodeType.sequence, "sequence is expected", node);
        return new AST(node, "ArraySchema",
                       node.sequence.map!((n) {
            import std.algorithm : filter;
            import std.format : format;
            auto ret = items_.map!(s => s.parse(n, resolver).speculate)
                             .array;
            auto ts = ret.map!"a.ast".filter!"a";
            auto exceptions = ret.map!"a.exception".filter!"a";
            if (ts.empty)
            {
                assert(!exceptions.empty);
                throw new SchemaException("No matching element types for array", node, exceptions.front);
            }
            // TODO: consider the case of types.length > 1 (ambiguous candidates)
            return ts.front;
        }).array);
    }
}

class JsonldPredicate : DocumentSchema
{
    mixin Canonicalize!(
        so.JsonldPredicate,
        "_id", (Optional!string _id) => _id.orDefault(""),
        "_type", (Optional!string _type) => _type.orDefault(""),
        "_container", (Optional!string _container) => _container.orDefault(""),
        "identity", (Optional!bool identity) => identity.orDefault(false),
        "noLinkCheck", (Optional!bool noLinkCheck) => noLinkCheck.orDefault(false),
        "mapSubject", (Optional!string mapSubject) => mapSubject.orDefault(""),
        "mapPreidcate", (Optional!string mapPredicate) => mapPredicate.orDefault(""),
        "refScope", (Optional!int refScope) => refScope.orDefault(0),
        "typeDSL", (Optional!bool typeDSL) => typeDSL.orDefault(false),
        "secondaryFilesDSL", (Optional!bool secondaryFilesDSL) => secondaryFilesDSL.orDefault(false),
        "subscope", (Optional!string subscope) => subscope.orDefault(""),
    );
}

class SpecializeDef : DocumentSchema
{
    mixin Canonicalize!(so.SpecializeDef);
}

class SaladEnumSchema : DocumentSchema
{
    mixin Canonicalize!(
        so.SaladEnumSchema,
        "inVocab", (Optional!bool inVocab) => inVocab.orDefault(true),
        "doc", (Optional!(string, string[]) doc) => doc.concat,
        "docChild", (Optional!(string, string[]) docChild) => docChild.concat,
        "jsonldPredicate", (Optional!(string, so.JsonldPredicate) jp) => jp.canonicalize,
        "documentRoot", (Optional!bool documentRoot) => documentRoot.orDefault(false),
        "extends", (Optional!(string, string[]) extends) => extends.match!((string s) => [s],
                                                                           (string[] ss) => ss,
                                                                           none => (string[]).init),
    );

    mixin genToString;

    override AST parse(Node node, Resolver resolver, JsonldPredicate jp = null)
    {
        import std.algorithm : find;
        import std.format : format;
        import std.range : empty, front;

        schemaEnforce(node.type == NodeType.string,
                      format!"string is expected but %s occurs"(node.type), node);
        auto s = node.as!string;
        auto syms = symbols_.find(s);
        schemaEnforce(!syms.empty, format!"Unknown symbol `%s`"(s), node);
        return new AST(node, "SaladEnumSchema", syms.front);
    }
}

class Documentation : DocumentSchema
{
    mixin Canonicalize!(
        so.Documentation,
        "inVocab", (Optional!bool inVocab) => inVocab.orDefault(true),
        "doc", (Optional!(string, string[]) doc) => doc.concat,
        "docChild", (Optional!(string, string[]) docChild) => docChild.concat,
    );
}


AST parse(string schemaName, Node node, Resolver resolver, JsonldPredicate jp = null)
{
    return resolver.lookup(schemaName).parse(node, resolver);
}

AST parse(T)(T either, Node node, Resolver resolver, JsonldPredicate jp = null)
if (isEither!T)
{
    return either.match!(
        s => s.parse(node, resolver),
    );
}

Tuple!(AST, "ast", Exception, "exception") speculate(lazy AST ast)
{
    try
    {
        return typeof(return)(ast(), null);
    }
    catch(SchemaException e)
    {
        return typeof(return)(null, e);
    }
}
