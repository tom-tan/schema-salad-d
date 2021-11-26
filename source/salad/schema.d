/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.schema;

import dyaml : Node, NodeType;

import salad.exception;
import salad.meta;
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

class SaladRecordSchema
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
}

class SaladRecordField
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
}

class PrimitiveType
{
    mixin Canonicalize!(so.PrimitiveType);

    mixin genToString;
}

class Any
{
    mixin Canonicalize!(so.Any);
}

class RecordSchema
{
    mixin Canonicalize!(
        so.RecordSchema,
        "fields", (Optional!(so.RecordField[]) fields) =>
                    fields.match!((so.RecordField[] rf) => rf.map!(r => new RecordField(r)).array,
                                  none => (RecordField[]).init),
    );

    mixin genToString;
}

class RecordField
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
}

class EnumSchema
{
    mixin Canonicalize!(so.EnumSchema);

    mixin genToString;
}

class ArraySchema
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
}

class JsonldPredicate
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

class SpecializeDef
{
    mixin Canonicalize!(so.SpecializeDef);
}

class SaladEnumSchema
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
}

class Documentation
{
    mixin Canonicalize!(
        so.Documentation,
        "inVocab", (Optional!bool inVocab) => inVocab.orDefault(true),
        "doc", (Optional!(string, string[]) doc) => doc.concat,
        "docChild", (Optional!(string, string[]) docChild) => docChild.concat,
    );
}
