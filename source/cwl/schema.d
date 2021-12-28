/**
 * Hand-written definition of CWL v1.0 CommandLineTool
 *
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module cwl.schema;

import salad.context : LoadingContext;
import salad.exception;
import salad.meta;
import salad.type;
import salad.util;

@documentRoot class CommandLineTool
{
    @idMap("id", "type")
    CommandInputParameter[] inputs_;
    @idMap("id", "type")
    CommandOutputParameter[] outputs_;
    immutable class_ = "CommandLineTool";
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
}

class CommandInputParameter
{
    @id string id_;
    Optional!string label_;
    Optional!(string, string[]) secondaryFiles_;
    Optional!bool streamable_;
    Optional!(string, string[]) doc_;
    Optional!(string, string[]) format_;
    Optional!CommandLineBinding inputBinding_;
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
}

class CommandLineBinding
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
}

class Any
{
    import dyaml : Node, NodeType;

    Node value_;

    alias value_ this;

    this(Node node, in LoadingContext context = LoadingContext.init)
    {
        docEnforce(node.type != NodeType.null_,
                   "Any should be non-null", node);
        value_ = node;
    }
}

class CWLType
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
        File_ = "File",
        Directory_ = "Directory",
    }

    alias type_ this;

    string type_;

    this(in Node node, in LoadingContext context = LoadingContext.init) @safe
    {
        type_ = node.as!string;
        // enforce
    }

    bool opEquals(string s) const @nogc nothrow pure
    {
        return type_ == s;
    }
}

class File
{
    immutable class_ = "File";
    Optional!string location_;
    Optional!string path_;
    Optional!string basename_;
    Optional!string dirname_;
    Optional!string nameroot_;
    Optional!string nameext_;
    Optional!string checksum_;
    Optional!int size_;
    Optional!(Either!(File, Directory)[]) secondaryFiles_;
    Optional!string format_;
    Optional!string contents_;

    mixin genCtor;
    mixin genIdentifier;
}

class Directory
{
    immutable class_ = "Directory";
    Optional!string location_;
    Optional!string path_;
    Optional!string basename_;
    Optional!(
        Either!(File, Directory)[]
    ) listing_;

    mixin genCtor;
    mixin genIdentifier;
}

class CommandInputRecordSchema
{
    immutable type_ = "record";
    @idMap("name", "type")
    Optional!(CommandInputRecordField[]) fields_;
    Optional!string label_;
    Optional!string name_;

    mixin genCtor;
    mixin genIdentifier;
}

class CommandInputRecordField
{
    string name_;
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
}

class CommandInputEnumSchema
{
    string[] symbols_;
    immutable type_ = "enum";
    Optional!string label_;
    Optional!string name_;
    Optional!CommandLineBinding inputBinding_;

    mixin genCtor;
    mixin genIdentifier;
}

class CommandInputArraySchema
{
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
    immutable type_ = "array";
    Optional!string label_;
    Optional!CommandLineBinding inputBinding_;

    mixin genCtor;
    mixin genIdentifier;
}

class CommandOutputParameter
{
    @id string id_;
    Optional!string label_;
    Optional!(string, string[]) secondaryFiles_;
    Optional!bool streamable_;
    Optional!(string, string[]) doc_;
    Optional!CommandOutputBinding outputBinding_;
    Optional!string format_;
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
}

class stdout
{
    import dyaml : Node;

    enum Symbols
    {
        stdout_ = "stdout",
    }

    alias type_ this;

    string type_;

    this(in Node node, in LoadingContext context = LoadingContext.init) @safe
    {
        type_ = node.as!string;
        // enforce
    }
}

class stderr
{
    import dyaml : Node;

    enum Symbols
    {
        stderr_ = "stderr",
    }

    alias type_ this;

    string type_;

    this(in Node node, in LoadingContext context = LoadingContext.init) @safe
    {
        type_ = node.as!string;
        // enforce
    }
}

class CommandOutputBinding
{
    Optional!(string, string[]) glob_;
    Optional!bool loadContents_;
    Optional!string outputEval_;

    mixin genCtor;
    mixin genIdentifier;
}

class CommandOutputRecordSchema
{
    immutable type_ = "record";
    @idMap("name", "type")
    Optional!(CommandOutputRecordField[]) fields_;
    Optional!string label_;
    @id Optional!string name_;

    mixin genCtor;
    mixin genIdentifier;
}

class CommandOutputRecordField
{
    string name_;
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
}

class CommandOutputEnumSchema
{
    string[] symbols_;
    immutable type_ = "enum";
    Optional!string label_;
    Optional!CommandOutputBinding outputBinding_;

    mixin genCtor;
    mixin genIdentifier;
}

class CommandOutputArraySchema
{
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
    immutable type_ = "array";
    Optional!string label_;
    Optional!CommandOutputBinding outputBinding_;

    mixin genCtor;
    mixin genIdentifier;
}

class InlineJavascriptRequirement
{
    immutable class_ = "InlineJavascriptRequirement";
    Optional!(string[]) expressionLib_;

    mixin genCtor;
    mixin genIdentifier;
}

class SchemaDefRequirement
{
    immutable class_ = "SchemaDefRequirement";
    Either!(
        InputRecordSchema,
        InputEnumSchema,
        InputArraySchema,
    )[] types_;

    mixin genCtor;
    mixin genIdentifier;
}

class InputRecordSchema
{
    immutable type_ = "record";
    @idMap("name", "type")
    Optional!(
        InputRecordField[]
    ) fields_;
    Optional!string label_;
    @id Optional!string name_;

    mixin genCtor;
    mixin genIdentifier;
}

class InputRecordField
{
    string name_;
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
}

class InputEnumSchema
{
    string[] symbols_;
    immutable type_ = "enum";
    Optional!string label_;
    @id Optional!string name_;
    Optional!CommandLineBinding inpuBinding_;

    mixin genCtor;
    mixin genIdentifier;
}

class InputArraySchema
{
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
    immutable type_ = "array";
    Optional!string label_;
    Optional!CommandLineBinding inputBinding_;

    mixin genCtor;
    mixin genIdentifier;
}

class DockerRequirement
{
    immutable class_ = "DockerRequirement";
    Optional!string dockerPull_;
    Optional!string dockerLoad_;
    Optional!string dockerFile_;
    Optional!string dockerImport_;
    Optional!string dockerImageId_;
    Optional!string dockerOutputDirectory_;

    mixin genCtor;
    mixin genIdentifier;
}

class SoftwareRequirement
{
    immutable class_ = "SoftwareRequirement";
    @idMap("package", "specs")
    SoftwarePackage[] packages_;

    mixin genCtor;
    mixin genIdentifier;
}

class SoftwarePackage
{
    string package_;
    Optional!(string[]) version_;
    Optional!(string[]) specs_;

    mixin genCtor;
    mixin genIdentifier;
}

class InitialWorkDirRequirement
{
    immutable class_ = "InitialWorkDirRequirement";
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
}

class Dirent
{
    string entry_;
    Optional!string entryname_;
    Optional!bool writable_;

    mixin genCtor;
    mixin genIdentifier;
}

class EnvVarRequirement
{
    immutable class_ = "EnvVarRequirement";
    @idMap("envName", "envValue")
    EnvironmentDef[] envDef_;

    mixin genCtor;
    mixin genIdentifier;
}

class EnvironmentDef
{
    string envName_;
    string envValue_;

    mixin genCtor;
    mixin genIdentifier;
}

class ShellCommandRequirement
{
    immutable class_ = "ShellCommandRequirement";

    mixin genCtor;
    mixin genIdentifier;
}

class ResourceRequirement
{
    immutable class_ = "ResourceRequirement";
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
}

class CWLVersion
{
    import dyaml : Node;

    enum Symbols
    {
        draft_2	= "draft-2",
        draft_3_dev1 = "draft-3.dev1",
        draft_3_dev2 = "draft-3.dev2",
        draft_3_dev3 = "draft-3.dev3",
        draft_3_dev4 = "draft-3.dev4",
        draft_3_dev5 = "draft-3.dev5",
        draft_3 = "draft-3",
        draft_4_dev1 = "draft-4.dev1",
        draft_4_dev2 = "draft-4.dev2",
        draft_4_dev3 = "draft-4.dev3",
        v1_0_dev4 = "v1.0.dev4",
        v1_0 = "v1.0",
    }

    alias type_ this;

    string type_;

    this(in Node node, in LoadingContext context = LoadingContext.init) @safe
    {
        type_ = node.as!string;
        // enforce
    }

    bool opEquals(string s) const @nogc nothrow pure
    {
        return type_ == s;
    }
}

unittest
{
    import dyaml;

    enum cwl = "examples/bwa-mem-tool.cwl";
    auto cmd = Loader.fromFile(cwl)
                     .load
                     .as!CommandLineTool;
    assert(cmd.dig!"cwlVersion"("v1.2") == "v1.0");
    assert(cmd.dig!(["inputs", "reference", "type"], CWLType) == "File");
    assert(cmd.dig!("hints", Any[])[0]
              .as!ResourceRequirement
              .dig!("coresMin", long) == 2);
}

@documentRoot class Workflow
{
    @idMap("id", "type")
    InputParameter[] inputs_;
    @idMap("id", "type")
    WorkflowOutputParameter[] outputs_;
    immutable class_ = "Workflow";
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
}

class WorkflowOutputParameter
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
}

class LinkMergeMethod
{
    import dyaml : Node;

    enum Symbols
    {
        merge_nested_ = "merge_nested",
        merge_flattened_ = "merge_flattened",
    }

    alias type_ this;

    string type_;

    this(in Node node, in LoadingContext context = LoadingContext.init) @safe
    {
        type_ = node.as!string;
    }
}

class OutputRecordSchema
{
    immutable type_ = "record";
    @idMap("name", "type")
    Optional!(OutputRecordField[]) fields_;
    Optional!string label_;

    mixin genCtor;
    mixin genIdentifier;
}

class OutputRecordField
{
    string name_;
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
}

class OutputEnumSchema
{
    string[] symbols_;
    immutable type_ = "enum";
    Optional!string label_;
    Optional!CommandOutputBinding outputBinding_;

    mixin genCtor;
    mixin genIdentifier;
}

class OutputArraySchema
{
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
    immutable type_ = "array";
    Optional!string label_;
    Optional!CommandOutputBinding outputBinding_;

    mixin genCtor;
    mixin genIdentifier;
}

class WorkflowStep
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
}

class WorkflowStepInput
{
    @id string id_;
    Optional!(string, string[]) source_;
    Optional!LinkMergeMethod linkMerge_;
    Optional!Any default_;
    Optional!string valueFrom_;

    mixin genCtor;
    mixin genIdentifier;
}

class WorkflowStepOutput
{
    @id string id_;

    mixin genCtor;
    mixin genIdentifier;
}

class ScatterMethod
{
    import dyaml : Node;

    enum Symbols
    {
        dotproduct_ = "dotproduct",
        nested_crossproduct_ = "nested_crossproduct",
        flat_crossproduct_ = "flat_crossproduct_",
    }

    alias type_ this;

    string type_;

    this(in Node node, in LoadingContext context = LoadingContext.init) @safe
    {
        type_ = node.as!string;
        // enforce
    }
}

class SubworkflowFeatureRequirement
{
    immutable class_ = "SubworkflowFeatureRequirement";

    mixin genCtor;
    mixin genIdentifier;
}

class ScatterFeatureRequirement
{
    immutable class_ = "ScatterFeatureRequirement";

    mixin genCtor;
    mixin genIdentifier;
}

class MultipleInputFeatureRequirement
{
    immutable class_ = "MultipleInputFeatureRequirement";

    mixin genCtor;
    mixin genIdentifier;
}

class StepInputExpressionRequirement
{
    immutable class_ = "StepInputExpressionRequirement";

    mixin genCtor;
    mixin genIdentifier;
}

@documentRoot class ExpressionTool
{
    @idMap("id", "type")
    InputParameter[] inputs_;
    @idMap("id", "type")
    ExpressionToolOutputParameter[] outputs_;
    immutable class_ = "Expression";
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
}

class InputParameter
{
    @id string id_;
    Optional!string label_;
    Optional!(string, string[]) secondaryFiles_;
    Optional!bool streamable_;
    Optional!(string, string[]) doc_;
    Optional!(string, string[]) format_;
    Optional!CommandLineBinding inputBinding_;
    Optional!Any default_;
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
}

class ExpressionToolOutputParameter
{
    @id string id_;
    Optional!string label_;
    Optional!(string, string[]) secondaryFiles_;
    Optional!bool streamable_;
    Optional!(string, string[]) doc_;
    Optional!CommandOutputBinding outputBinding_;
    Optional!string format_;
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
}

unittest
{
    import dyaml;

    enum cwl = "examples/count-lines1-wf.cwl";
    auto wf = Loader.fromFile(cwl)
                    .load
                    .as!Workflow;
    assert(wf.dig!"class"("Invalid") == "Workflow");
    assert(wf.dig!"cwlVersion"("v1.2") == "v1.0");
    assert(wf.dig!(["inputs", "file1", "type"], CWLType) == "File");
    assert(wf.dig!(["outputs", "count_output", "outputSource"], string) == "step2/output");
}
