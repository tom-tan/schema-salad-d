/**
 * Hand-written definition of CWL v1.0
 *
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module cwl.v1_0.schema;

import salad.meta.dumper : genDumper;
import salad.meta.impl : genCtor, genIdentifier, genOpEq;
import salad.meta.uda : documentRoot, id, idMap, link, typeDSL;
import salad.primitives : SchemaBase;
import salad.type : Either, Optional;

@documentRoot class CommandLineTool : SchemaBase
{
    @idMap("id", "type")
    CommandInputParameter[] inputs_;
    @idMap("id", "type")
    CommandOutputParameter[] outputs_;
    static immutable class_ = "CommandLineTool";
    @id Optional!string id_;
    @idMap("class")
    Optional!(
        Either!(
            InlineJavascriptRequirement,
            SchemaDefRequirement,
            DockerRequirement,
            SoftwareRequirement,
            InitialWorkDirRequirement,
            EnvVarRequirement,
            ShellCommandRequirement,
            ResourceRequirement,
        )[]
    ) requirements_;
    @idMap("class") Optional!(Any[]) hints_;
    Optional!string label_;
    Optional!string doc_;
    Optional!CWLVersion cwlVersion_;
    Optional!(string, string[]) baseCommand_;
    Optional!(Either!(string, CommandLineBinding)[]) arguments_;
    Optional!string stdin_;
    Optional!string stderr_;
    Optional!string stdout_;
    Optional!(int[]) successCodes_;
    Optional!(int[]) temporaryFailCodes_;
    Optional!(int[]) permanentFailCodes_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class CommandInputParameter : SchemaBase
{
    @id string id_;
    Optional!string label_;
    Optional!(string, string[]) secondaryFiles_;
    Optional!bool streamable_;
    Optional!(string, string[]) doc_;
    @link Optional!(string, string[]) format_;
    Optional!CommandLineBinding inputBinding_;
    Optional!Any default_;
    @typeDSL
    Optional!(
        CWLType,
        CommandInputRecordSchema,
        CommandInputEnumSchema,
        CommandInputArraySchema,
        string,
        Either!(
            CWLType,
            CommandInputRecordSchema,
            CommandInputEnumSchema,
            CommandInputArraySchema,
            string
        )[]
    ) type_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class CommandLineBinding : SchemaBase
{
    Optional!bool loadContents_;
    Optional!int position_;
    Optional!string prefix_;
    Optional!bool separate_;
    Optional!string itemSeparator_;
    Optional!string valueFrom_;
    Optional!bool shellQuote_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Any
public import salad.primitives : Any;

class CWLType : SchemaBase
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
        s8 = "File",
        s9 = "Directory",
    }

    Symbol value;

    mixin genCtor;
    mixin genOpEq;
    mixin genDumper;
}

class File : SchemaBase
{
    static immutable class_ = "File";
    @link Optional!string location_;
    @link Optional!string path_;
    Optional!string basename_;
    Optional!string dirname_;
    Optional!string nameroot_;
    Optional!string nameext_;
    Optional!string checksum_;
    Optional!long size_;
    Optional!(Either!(File, Directory)[]) secondaryFiles_;
    @link Optional!string format_;
    Optional!string contents_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class Directory : SchemaBase
{
    static immutable class_ = "Directory";
    @link Optional!string location_;
    @link Optional!string path_;
    Optional!string basename_;
    Optional!(
        Either!(File, Directory)[]
    ) listing_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class CommandInputRecordSchema : SchemaBase
{
    static immutable type_ = "record";
    @idMap("name", "type")
    Optional!(CommandInputRecordField[]) fields_;
    Optional!string label_;
    @id Optional!string name_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class CommandInputRecordField : SchemaBase
{
    string name_;
    @typeDSL
    Either!(
        CWLType,
        CommandInputRecordSchema,
        CommandInputEnumSchema,
        CommandInputArraySchema,
        string,
        Either!(
            CWLType,
            CommandInputRecordSchema,
            CommandInputEnumSchema,
            CommandInputArraySchema,
            string,
        )[]
    ) type_;
    Optional!string doc_;
    Optional!CommandLineBinding inputBinding_;
    Optional!string label_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class CommandInputEnumSchema : SchemaBase
{
    string[] symbols_;
    static immutable type_ = "enum";
    Optional!string label_;
    @id Optional!string name_;
    Optional!CommandLineBinding inputBinding_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class CommandInputArraySchema : SchemaBase
{
    @typeDSL
    Either!(
        CWLType,
        CommandInputRecordSchema,
        CommandInputEnumSchema,
        CommandInputArraySchema,
        string,
        Either!(
            CWLType,
            CommandInputRecordSchema,
            CommandInputEnumSchema,
            CommandInputArraySchema,
            string,
        )[],
    ) items_;
    static immutable type_ = "array";
    Optional!string label_;
    Optional!CommandLineBinding inputBinding_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class CommandOutputParameter : SchemaBase
{
    @id string id_;
    Optional!string label_;
    Optional!(string, string[]) secondaryFiles_;
    Optional!bool streamable_;
    Optional!(string, string[]) doc_;
    Optional!CommandOutputBinding outputBinding_;
    @link Optional!string format_;
    @typeDSL
    Optional!(
        CWLType,
        stdout,
        stderr,
        CommandOutputRecordSchema,
        CommandOutputEnumSchema,
        CommandOutputArraySchema,
        string,
        Either!(
            CWLType,
            CommandOutputRecordSchema,
            CommandOutputEnumSchema,
            CommandOutputArraySchema,
            string
        )[],
    ) type_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class stdout : SchemaBase // @suppress(dscanner.style.phobos_naming_convention)
{
    enum Symbol
    {
        s1 = "stdout",
    }

    Symbol value;

    mixin genCtor;
    mixin genOpEq;
    mixin genDumper;
}

class stderr : SchemaBase // @suppress(dscanner.style.phobos_naming_convention)
{
    enum Symbol
    {
        s2 = "stderr",
    }

    Symbol value;

    mixin genCtor;
    mixin genOpEq;
    mixin genDumper;
}

class CommandOutputBinding : SchemaBase
{
    Optional!(string, string[]) glob_;
    Optional!bool loadContents_;
    Optional!string outputEval_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class CommandOutputRecordSchema : SchemaBase
{
    static immutable type_ = "record";
    @idMap("name", "type")
    Optional!(CommandOutputRecordField[]) fields_;
    Optional!string label_;
    @id Optional!string name_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class CommandOutputRecordField : SchemaBase
{
    string name_;
    @typeDSL
    Either!(
        CWLType,
        CommandOutputRecordSchema,
        CommandOutputEnumSchema,
        CommandOutputArraySchema,
        string,
        Either!(
            CWLType,
            CommandOutputRecordSchema,
            CommandOutputEnumSchema,
            CommandOutputArraySchema,
            string,
        )[],
    ) type_;
    Optional!string doc_;
    Optional!CommandOutputBinding outputBinding_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class CommandOutputEnumSchema : SchemaBase
{
    string[] symbols_;
    static immutable type_ = "enum";
    Optional!string label_;
    Optional!CommandOutputBinding outputBinding_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class CommandOutputArraySchema : SchemaBase
{
    @typeDSL
    Either!(
        CWLType,
        CommandOutputRecordSchema,
        CommandOutputEnumSchema,
        CommandOutputArraySchema,
        string,
        Either!(
            CWLType,
            CommandOutputRecordSchema,
            CommandOutputEnumSchema,
            CommandOutputArraySchema,
            string,
        )[],
    ) items_;
    static immutable type_ = "array";
    Optional!string label_;
    Optional!CommandOutputBinding outputBinding_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class InlineJavascriptRequirement : SchemaBase
{
    static immutable class_ = "InlineJavascriptRequirement";
    Optional!(string[]) expressionLib_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class SchemaDefRequirement : SchemaBase
{
    static immutable class_ = "SchemaDefRequirement";
    Either!(
        InputRecordSchema,
        InputEnumSchema,
        InputArraySchema,
    )[] types_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class InputRecordSchema : SchemaBase
{
    static immutable type_ = "record";
    @idMap("name", "type")
    Optional!(
        InputRecordField[]
    ) fields_;
    Optional!string label_;
    @id Optional!string name_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class InputRecordField : SchemaBase
{
    string name_;
    @typeDSL
    Either!(
        CWLType,
        InputRecordSchema,
        InputEnumSchema,
        InputArraySchema,
        string,
        Either!(
            CWLType,
            InputRecordSchema,
            InputEnumSchema,
            InputArraySchema,
            string,
        )[],
    ) type_;
    Optional!string doc_;
    Optional!CommandLineBinding inputBinding_;
    Optional!string label_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class InputEnumSchema : SchemaBase
{
    string[] symbols_;
    static immutable type_ = "enum";
    Optional!string label_;
    @id Optional!string name_;
    Optional!CommandLineBinding inputBinding_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class InputArraySchema : SchemaBase
{
    @typeDSL
    Either!(
        CWLType,
        InputRecordSchema,
        InputEnumSchema,
        InputArraySchema,
        string,
        Either!(
            CWLType,
            InputRecordSchema,
            InputEnumSchema,
            InputArraySchema,
            string,
        )[],
    ) items_;
    static immutable type_ = "array";
    Optional!string label_;
    Optional!CommandLineBinding inputBinding_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class DockerRequirement : SchemaBase
{
    static immutable class_ = "DockerRequirement";
    Optional!string dockerPull_;
    Optional!string dockerLoad_;
    Optional!string dockerFile_;
    Optional!string dockerImport_;
    Optional!string dockerImageId_;
    Optional!string dockerOutputDirectory_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class SoftwareRequirement : SchemaBase
{
    static immutable class_ = "SoftwareRequirement";
    @idMap("package", "specs")
    SoftwarePackage[] packages_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class SoftwarePackage : SchemaBase
{
    string package_;
    Optional!(string[]) version_;
    Optional!(string[]) specs_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class InitialWorkDirRequirement : SchemaBase
{
    static immutable class_ = "InitialWorkDirRequirement";
    Either!(
        Either!(
            File,
            Directory,
            Dirent,
            string,
        )[],
        string,
    ) listing_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class Dirent : SchemaBase
{
    string entry_;
    Optional!string entryname_;
    Optional!bool writable_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class EnvVarRequirement : SchemaBase
{
    static immutable class_ = "EnvVarRequirement";
    @idMap("envName", "envValue")
    EnvironmentDef[] envDef_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class EnvironmentDef : SchemaBase
{
    string envName_;
    string envValue_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class ShellCommandRequirement : SchemaBase
{
    static immutable class_ = "ShellCommandRequirement";

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class ResourceRequirement : SchemaBase
{
    static immutable class_ = "ResourceRequirement";
    Optional!(long, string) coresMin_;
    Optional!(int, string) coresMax_;
    Optional!(long, string) ramMin_;
    Optional!(long, string) ramMax_;
    Optional!(long, string) tmpdirMin_;
    Optional!(long, string) tmpdirMax_;
    Optional!(long, string) outdirMin_;
    Optional!(long, string) outdirMax_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class CWLVersion : SchemaBase
{
    enum Symbol
    {
        s1 = "draft-2",
        s2 = "draft-3.dev1",
        s3 = "draft-3.dev2",
        s4 = "draft-3.dev3",
        s5 = "draft-3.dev4",
        s6 = "draft-3.dev5",
        s7 = "draft-3",
        s8 = "draft-4.dev1",
        s9 = "draft-4.dev2",
        s10 = "draft-4.dev3",
        s11 = "v1.0.dev4",
        s12 = "v1.0",
    }

    Symbol value;

    mixin genCtor;
    mixin genOpEq;
    mixin genDumper;
}

@safe unittest
{
    import core.exception : AssertError;
    import dyaml;
    import salad.util : dig;
    import std.exception : enforce;

    enum cwl = "examples/cwl-v1.0/bwa-mem-tool.cwl";
    auto cmd = Loader.fromFile(cwl)
                     .load
                     .as!CommandLineTool;
    assert(cmd.dig!"cwlVersion"(new CWLVersion("draft-3")) == "v1.0");
    assert(cmd.dig!(["inputs", "reference", "type"], CWLType) == "File");
    assert(cmd.dig!(["hints", "ResourceRequirement"], ResourceRequirement)
              .enforce!AssertError
              .dig!("coresMin", long) == 2);
}

@documentRoot class Workflow : SchemaBase
{
    @idMap("id", "type")
    InputParameter[] inputs_;
    @idMap("id", "type")
    WorkflowOutputParameter[] outputs_;
    static immutable class_ = "Workflow";
    @idMap("id") WorkflowStep[] steps_;
    @id Optional!string id_;
    @idMap("class")
    Optional!(
        Either!(
            InlineJavascriptRequirement,
            SchemaDefRequirement,
            DockerRequirement,
            SoftwareRequirement,
            InitialWorkDirRequirement,
            EnvVarRequirement,
            ShellCommandRequirement,
            ResourceRequirement,
            SubworkflowFeatureRequirement,
            ScatterFeatureRequirement,
            MultipleInputFeatureRequirement,
            StepInputExpressionRequirement,
        )[]
    ) requirements_;
    @idMap("class") Optional!(Any[]) hints_;
    Optional!string label_;
    Optional!string doc_;
    Optional!CWLVersion cwlVersion_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class WorkflowOutputParameter : SchemaBase
{
    @id string id_;
    Optional!string label_;
    Optional!(string, string[]) secondaryFiles_;
    Optional!bool streamable_;
    Optional!(string, string[]) doc_;
    Optional!CommandOutputBinding outputBinding_;
    Optional!string format_;
    Optional!(string, string[]) outputSource_;
    Optional!LinkMergeMethod linkMerge_;
    @typeDSL
    Optional!(
        CWLType,
        OutputRecordSchema,
        OutputEnumSchema,
        OutputArraySchema,
        string,
        Either!(
            CWLType,
            OutputRecordSchema,
            OutputEnumSchema,
            OutputArraySchema,
            string,
        )[],
    ) type_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class LinkMergeMethod : SchemaBase
{
    enum Symbol
    {
        s1 = "merge_nested",
        s2 = "merge_flattened",
    }

    Symbol value;

    mixin genCtor;
    mixin genOpEq;
    mixin genDumper;
}

class OutputRecordSchema : SchemaBase
{
    static immutable type_ = "record";
    @idMap("name", "type")
    Optional!(OutputRecordField[]) fields_;
    Optional!string label_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class OutputRecordField : SchemaBase
{
    string name_;
    @typeDSL
    Either!(
        CWLType,
        OutputRecordSchema,
        OutputEnumSchema,
        OutputArraySchema,
        string,
        Either!(
            CWLType,
            OutputRecordSchema,
            OutputEnumSchema,
            OutputArraySchema,
            string,
        )[],
    ) type_;
    Optional!string doc_;
    Optional!CommandOutputBinding outputBinding_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class OutputEnumSchema : SchemaBase
{
    string[] symbols_;
    static immutable type_ = "enum";
    Optional!string label_;
    Optional!CommandOutputBinding outputBinding_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class OutputArraySchema : SchemaBase
{
    @typeDSL
    Either!(
        CWLType,
        OutputRecordSchema,
        OutputEnumSchema,
        OutputArraySchema,
        string,
        Either!(
            CWLType,
            OutputRecordSchema,
            OutputEnumSchema,
            OutputArraySchema,
            string,
        )[],
    ) items_;
    static immutable type_ = "array";
    Optional!string label_;
    Optional!CommandOutputBinding outputBinding_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class WorkflowStep : SchemaBase
{
    @id string id_;
    @idMap("id", "source")
    WorkflowStepInput[] in_;
    Either!(string, WorkflowStepOutput)[] out_;
    Either!(string, CommandLineTool, ExpressionTool, Workflow) run_;
    @idMap("class")
    Optional!(
        Either!(
            InlineJavascriptRequirement,
            SchemaDefRequirement,
            DockerRequirement,
            SoftwareRequirement,
            InitialWorkDirRequirement,
            EnvVarRequirement,
            ShellCommandRequirement,
            ResourceRequirement,
            SubworkflowFeatureRequirement,
            ScatterFeatureRequirement,
            MultipleInputFeatureRequirement,
            StepInputExpressionRequirement,
        )[]
    ) requirements_;
    @idMap("class") Optional!(Any[]) hints_;
    Optional!string label_;
    Optional!string doc_;
    Optional!(string, string[]) scatter_;
    Optional!ScatterMethod scatterMethod_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class WorkflowStepInput : SchemaBase
{
    @id string id_;
    Optional!(string, string[]) source_;
    Optional!LinkMergeMethod linkMerge_;
    Optional!Any default_;
    Optional!string valueFrom_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class WorkflowStepOutput : SchemaBase
{
    @id string id_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class ScatterMethod : SchemaBase
{
    enum Symbol
    {
        s1 = "dotproduct",
        s2 = "nested_crossproduct",
        s3 = "flat_crossproduct_",
    }

    Symbol value;

    mixin genCtor;
    mixin genOpEq;
    mixin genDumper;
}

class SubworkflowFeatureRequirement : SchemaBase
{
    static immutable class_ = "SubworkflowFeatureRequirement";

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class ScatterFeatureRequirement : SchemaBase
{
    static immutable class_ = "ScatterFeatureRequirement";

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class MultipleInputFeatureRequirement : SchemaBase
{
    static immutable class_ = "MultipleInputFeatureRequirement";

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class StepInputExpressionRequirement : SchemaBase
{
    static immutable class_ = "StepInputExpressionRequirement";

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

@documentRoot class ExpressionTool : SchemaBase
{
    @idMap("id", "type")
    InputParameter[] inputs_;
    @idMap("id", "type")
    ExpressionToolOutputParameter[] outputs_;
    static immutable class_ = "ExpressionTool";
    string expression_;
    @id Optional!string id_;
    @idMap("class")
    Optional!(
        Either!(
            InlineJavascriptRequirement,
            SchemaDefRequirement,
            DockerRequirement,
            SoftwareRequirement,
            InitialWorkDirRequirement,
            EnvVarRequirement,
            ShellCommandRequirement,
            ResourceRequirement,
            SubworkflowFeatureRequirement,
            ScatterFeatureRequirement,
            MultipleInputFeatureRequirement,
            StepInputExpressionRequirement,
        )[]
    ) requirements_;
    @idMap("class") Optional!(Any[]) hints_;
    Optional!string label_;
    Optional!string doc_;
    Optional!CWLVersion cwlVersion_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class InputParameter : SchemaBase
{
    @id string id_;
    Optional!string label_;
    Optional!(string, string[]) secondaryFiles_;
    Optional!bool streamable_;
    Optional!(string, string[]) doc_;
    @link Optional!(string, string[]) format_;
    Optional!CommandLineBinding inputBinding_;
    Optional!Any default_;
    @typeDSL
    Optional!(
        CWLType,
        InputRecordSchema,
        InputEnumSchema,
        InputArraySchema,
        string,
        Either!(
            CWLType,
            InputRecordSchema,
            InputEnumSchema,
            InputArraySchema,
            string,
        )[],
    ) type_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

class ExpressionToolOutputParameter : SchemaBase
{
    @id string id_;
    Optional!string label_;
    Optional!(string, string[]) secondaryFiles_;
    Optional!bool streamable_;
    Optional!(string, string[]) doc_;
    Optional!CommandOutputBinding outputBinding_;
    @link Optional!string format_;
    @typeDSL
    Optional!(
        CWLType,
        OutputRecordSchema,
        OutputEnumSchema,
        OutputArraySchema,
        string,
        Either!(
            CWLType,
            OutputRecordSchema,
            OutputEnumSchema,
            OutputArraySchema,
            string,
        )[],
    ) type_;

    mixin genCtor;
    mixin genIdentifier;
    mixin genDumper;
}

unittest
{
    import dyaml;
    import salad.util : dig;

    enum cwl = "examples/cwl-v1.0/count-lines1-wf.cwl";
    auto wf = Loader.fromFile(cwl)
                    .load
                    .as!Workflow;
    assert(wf.dig!"class"("Invalid") == "Workflow");
    assert(wf.dig!"cwlVersion"(new CWLVersion("draft-3")) == "v1.0");
    assert(wf.dig!(["inputs", "file1", "type"], CWLType) == "File");
    assert(wf.dig!(["outputs", "count_output", "outputSource"], string) == "step2/output");
}
