module salad.schema_original;

import salad.exception;
import salad.meta;
import salad.type;
import salad.util;

import std.typecons : Tuple;

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SaladRecordSchema
class SaladRecordSchema
{
    string name_;
    enum type_ = "record";
    Optional!bool inVocab_;
    Optional!(SaladRecordField[]) fields_; // TODO: map<name, type>
    Optional!(string, string[]) doc_;
    Optional!string docParent_;
    Optional!(string, string[]) docChild_;
    Optional!string docAfter_;
    Optional!(string, JsonldPredicate) jsonldPredicate_;
    Optional!bool documentRoot_;
    @("abstract") Optional!bool abstract_;
    Optional!(string, string[]) extends_;
    Optional!(SpecializeDef[]) specialize_; // TODO: map<specializeFrom, specializeTo>

    mixin genCtor;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SaladRecordField
class SaladRecordField
{
    string name_;
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
    @("default") Optional!Any default_;


    mixin genCtor;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#PrimitiveType
class PrimitiveType
{
    import dyaml : Node;

    enum Types{
        null_ = "null",
        boolean_ = "boolean",
        int_ = "int",
        long_ = "long",
        float_ = "float",
        double_ = "double",
        string_ = "string",
    }

    string type_;

    this(in Node node) @safe
    {
        type_ = node.as!string;
        // enforce
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Any
class Any
{
    import dyaml : Node;

    enum Types{
        Any = "Any",
    }

    string type_;

    this(in Node node) @safe
    {
        type_ = node.as!string;
        // enforce
    }
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#RecordSchema
class RecordSchema
{
    enum type_ = "record";
    Optional!(RecordField[]) fields_; // TODO: map<name, type>

    mixin genCtor;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#RecordField
class RecordField
{
    string name_;
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
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#EnumSchema
class EnumSchema
{
    string[] symbols_;
    enum type_ = "enum";

    mixin genCtor;
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
    enum type_ = "array";

    mixin genCtor;
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
    mixin genToString;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SpecializeDef
class SpecializeDef
{
    string specializeFrom_;
    string specializeTo_;

    mixin genCtor;
    mixin genToString;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SaladEnumSchema
class SaladEnumSchema
{
    string name_;
    string[] symbols_;
    enum type_ = "enum";
    Optional!bool inVocab_;
    Optional!(string, string[]) doc_;
    Optional!string docParent_;
    Optional!(string, string[]) docChild_;
    Optional!string docAfter_;
    Optional!(string, JsonldPredicate) jsonldPredicate_;
    Optional!bool documentRoot_;
    Optional!(string, string[]) extends_;

    mixin genCtor;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Documentation
class Documentation
{
    string name_;
    enum type_ = "documentation";
    Optional!bool inVocab_;
    Optional!(string, string[]) doc_;
    Optional!string docParent_;
    Optional!(string, string[]) docChild_;
    Optional!string docAfter_;

    mixin genCtor;
    mixin genToString;
}
