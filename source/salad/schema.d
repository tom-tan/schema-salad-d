/**
 * Hand-written definition of Schema Salad v1.2
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.schema;

import salad.meta.impl : genBody_;
import salad.meta.uda : documentRoot, id, idMap, typeDSL;
import salad.primitives : EnumSchemaBase, RecordSchemaBase, SchemaBase;
import salad.type : Union, Optional;

enum saladVersion = "v1.1";

mixin template genBody()
{
    mixin genBody_!saladVersion;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SaladRecordSchema
@documentRoot class SaladRecordSchema : RecordSchemaBase
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

    mixin genBody;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SaladRecordField
class SaladRecordField : RecordSchemaBase
{
    @id string name_;
    @typeDSL
    Union!(
        PrimitiveType,
        RecordSchema,
        EnumSchema,
        ArraySchema,
        string,
        Union!(
            PrimitiveType,
            RecordSchema,
            EnumSchema,
            ArraySchema,
            string)[]
    ) type_;
    Optional!(string, string[]) doc_;
    Optional!(string, JsonldPredicate) jsonldPredicate_;
    Optional!Any default_;

    mixin genBody;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#PrimitiveType
class PrimitiveType : EnumSchemaBase
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

    mixin genBody;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Any
public import salad.primitives : Any;

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#RecordSchema
class RecordSchema : RecordSchemaBase
{
    static immutable type_ = "record";
    @idMap("name", "type") Optional!(RecordField[]) fields_;

    mixin genBody;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#RecordField
class RecordField : RecordSchemaBase
{
    @id string name_;
    @typeDSL 
    Union!(
        PrimitiveType,
        RecordSchema,
        EnumSchema,
        ArraySchema,
        string,
        Union!(
            PrimitiveType,
            RecordSchema,
            EnumSchema,
            ArraySchema,
            string)[]
    ) type_;
    Optional!(string, string[]) doc_;

    mixin genBody;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#EnumSchema
class EnumSchema : RecordSchemaBase
{
    string[] symbols_;
    static immutable type_ = "enum";

    mixin genBody;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#ArraySchema
class ArraySchema : RecordSchemaBase
{
    Union!(
        PrimitiveType,
        RecordSchema,
        EnumSchema,
        ArraySchema,
        string,
        Union!(
            PrimitiveType,
            RecordSchema,
            EnumSchema,
            ArraySchema,
            string)[]
    ) items_;
    static immutable type_ = "array";

    mixin genBody;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#JsonldPredicate
class JsonldPredicate : RecordSchemaBase
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

    mixin genBody;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SpecializeDef
class SpecializeDef : RecordSchemaBase
{
    string specializeFrom_;
    string specializeTo_;

    mixin genBody;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SaladEnumSchema
@documentRoot class SaladEnumSchema : RecordSchemaBase
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

    mixin genBody;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Documentation
@documentRoot class Documentation : RecordSchemaBase
{
    @id string name_;
    static immutable type_ = "documentation";
    Optional!bool inVocab_;
    Optional!(string, string[]) doc_;
    Optional!string docParent_;
    Optional!(string, string[]) docChild_;
    Optional!string docAfter_;

    mixin genBody;
}
