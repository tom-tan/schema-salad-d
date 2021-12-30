/**
 * Hand-written definition of Schema Salad v1.2
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.schema_original;

import salad.context : LoadingContext;
import salad.exception;
import salad.meta;
import salad.type;
import salad.util;

import std.typecons : Tuple;

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SaladRecordSchema
@documentRoot class SaladRecordSchema
{
    @id string name_;
    static immutable type_ = "record";
    Optional!bool inVocab_;
    @idMap("name", "type") Optional!(SaladRecordField[]) fields_;
    Optional!(string, string[]) doc_;
    Optional!string docParent_;
    Optional!(string, string[]) docChild_;
    Optional!string docAfter_;
    Optional!(string, JsonldPredicate) jsonldPredicate_;
    Optional!bool documentRoot_;
    Optional!bool abstract_;
    Optional!(string, string[]) extends_;
    @idMap("specializeFrom", "specializeTo") Optional!(SpecializeDef[]) specialize_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genToString;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SaladRecordField
class SaladRecordField
{
    @id string name_;
    @typeDSL
    Either!(
        PrimitiveType,
        RecordSchema,
        EnumSchema,
        ArraySchema,
        string,
        Either!(
            PrimitiveType,
            RecordSchema,
            EnumSchema,
            ArraySchema,
            string)[]
    ) type_;
    Optional!(string, string[]) doc_;
    Optional!(string, JsonldPredicate) jsonldPredicate_;
    Optional!Any default_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genToString;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#PrimitiveType
class PrimitiveType
{
    import dyaml : Node;

    enum Symbols
    {
        null_ = "null",
        boolean_ = "boolean",
        int_ = "int",
        long_ = "long",
        float_ = "float",
        double_ = "double",
        string_ = "string",
    }

    string type_;

    this(in Node node, in LoadingContext context = LoadingContext.init) @safe
    {
        type_ = node.as!string;
        // enforce
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Any
class Any
{
    import dyaml : Node;

    enum Symbols
    {
        Any = "Any",
    }

    string type_;

    this(in Node node, in LoadingContext context = LoadingContext.init) @safe
    {
        type_ = node.as!string;
        // enforce
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#RecordSchema
class RecordSchema
{
    static immutable type_ = "record";
    @idMap("name", "type") Optional!(RecordField[]) fields_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genToString;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#RecordField
class RecordField
{
    @id string name_;
    @typeDSL 
    Either!(
        PrimitiveType,
        RecordSchema,
        EnumSchema,
        ArraySchema,
        string,
        Either!(
            PrimitiveType,
            RecordSchema,
            EnumSchema,
            ArraySchema,
            string)[]
    ) type_;
    Optional!(string, string[]) doc_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genToString;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#EnumSchema
class EnumSchema
{
    string[] symbols_;
    static immutable type_ = "enum";

    mixin genCtor;
    mixin genIdentifier;
    mixin genToString;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#ArraySchema
class ArraySchema
{
    Either!(
        PrimitiveType,
        RecordSchema,
        EnumSchema,
        ArraySchema,
        string,
        Either!(
            PrimitiveType,
            RecordSchema,
            EnumSchema,
            ArraySchema,
            string)[]
    ) items_;
    static immutable type_ = "array";

    mixin genCtor;
    mixin genIdentifier;
    mixin genToString;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#JsonldPredicate
class JsonldPredicate
{
    Optional!string _id_;
    Optional!string _type_;
    Optional!string _container_;
    Optional!bool identity_;
    Optional!bool noLinkCheck_;
    Optional!string mapSubject_;
    Optional!string mapPredicate_;
    Optional!int refScope_;
    Optional!bool typeDSL_;
    Optional!bool secondaryFilesDSL_;
    Optional!string subscope_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genToString;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SpecializeDef
class SpecializeDef
{
    string specializeFrom_;
    string specializeTo_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genToString;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SaladEnumSchema
@documentRoot class SaladEnumSchema
{
    @id string name_;
    string[] symbols_;
    static immutable type_ = "enum";
    Optional!bool inVocab_;
    Optional!(string, string[]) doc_;
    Optional!string docParent_;
    Optional!(string, string[]) docChild_;
    Optional!string docAfter_;
    Optional!(string, JsonldPredicate) jsonldPredicate_;
    Optional!bool documentRoot_;
    Optional!(string, string[]) extends_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genToString;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Documentation
@documentRoot class Documentation
{
    @id string name_;
    static immutable type_ = "documentation";
    Optional!bool inVocab_;
    Optional!(string, string[]) doc_;
    Optional!string docParent_;
    Optional!(string, string[]) docChild_;
    Optional!string docAfter_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genToString;
}
