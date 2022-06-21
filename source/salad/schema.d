/**
 * Hand-written definition of Schema Salad v1.2
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.schema;

import salad.meta.dumper : genDumper;
import salad.meta.impl : genCtor, genIdentifier, genOpEq;
import salad.meta.uda : documentRoot, id, idMap, typeDSL;
import salad.primitives : SchemaBase;
import salad.type : Either, Optional;

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SaladRecordSchema
@documentRoot class SaladRecordSchema : SchemaBase
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
    mixin genDumper;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SaladRecordField
class SaladRecordField : SchemaBase
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
    mixin genDumper;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#PrimitiveType
class PrimitiveType : SchemaBase
{
    enum Symbol
    {
        s1 = "null",
        s2 = "boolean",
        s3 = "int",
        s4 = "long",
        s5 = "float",
        s6 = "double",
        s7 = "string",
    }

    Symbol value;

    mixin genCtor;
    mixin genOpEq;
    mixin genDumper;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Any
public import salad.primitives : Any;

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#RecordSchema
class RecordSchema : SchemaBase
{
    static immutable type_ = "record";
    @idMap("name", "type") Optional!(RecordField[]) fields_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#RecordField
class RecordField : SchemaBase
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
    mixin genDumper;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#EnumSchema
class EnumSchema : SchemaBase
{
    string[] symbols_;
    static immutable type_ = "enum";

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#ArraySchema
class ArraySchema : SchemaBase
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
    mixin genDumper;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#JsonldPredicate
class JsonldPredicate : SchemaBase
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
    mixin genDumper;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SpecializeDef
class SpecializeDef : SchemaBase
{
    string specializeFrom_;
    string specializeTo_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SaladEnumSchema
@documentRoot class SaladEnumSchema : SchemaBase
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
    mixin genDumper;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Documentation
@documentRoot class Documentation : SchemaBase
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
    mixin genDumper;
}
