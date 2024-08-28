/**
 * Hand-written definition of CWL v1.0
 * It is used only for testing.
 *
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.tests.cwl.v1_0;

version(unittest):

import salad.meta.impl : genBody_;
import salad.meta.parser : import_ = importFromURI;
import salad.meta.uda : defaultValue, documentRoot, id, idMap, link, LinkResolver, typeDSL;
import salad.primitives : EnumSchemaBase, RecordSchemaBase;
import salad.type : None, Union;

enum saladVersion = "v1.1";

mixin template genBody()
{
    mixin genBody_!saladVersion;
}

// workaround for https://issues.dlang.org/show_bug.cgi?id=20443
// it is needed for self-recursive definitions
static if (__traits(compiles, { hashOf(File.init); })) {}
static if (__traits(compiles, { hashOf(Directory.init); })) {}
static if (__traits(compiles, { hashOf(CommandInputArraySchema.init); })) {}
static if (__traits(compiles, { hashOf(CommandOutputArraySchema.init); })) {}
static if (__traits(compiles, { hashOf(InputArraySchema.init); })) {}
static if (__traits(compiles, { hashOf(OutputArraySchema.init); })) {}

@documentRoot class CommandLineTool : RecordSchemaBase
{
    @idMap("id", "type")
    CommandInputParameter[] inputs_;
    @idMap("id", "type")
    CommandOutputParameter[] outputs_;
    static immutable class_ = "CommandLineTool";
    @id Union!(None, string) id_;
    @idMap("class")
    Union!(
        None,
        Union!(
            InlineJavascriptRequirement,
            SchemaDefRequirement,
            DockerRequirement,
            SoftwareRequirement,
            InitialWorkDirRequirement,
            EnvVarRequirement,
            ShellCommandRequirement,
            ResourceRequirement,
            Any,
        )[]
    ) requirements_;
    @idMap("class") Union!(None, Any[]) hints_;
    Union!(None, string) label_;
    Union!(None, string) doc_;
    Union!(None, CWLVersion) cwlVersion_;
    Union!(None, string, string[]) baseCommand_;
    Union!(None, Union!(string, CommandLineBinding)[]) arguments_;
    Union!(None, string) stdin_;
    Union!(None, string) stderr_;
    Union!(None, string) stdout_;
    Union!(None, int[]) successCodes_;
    Union!(None, int[]) temporaryFailCodes_;
    Union!(None, int[]) permanentFailCodes_;

    mixin genBody;
}

class CommandInputParameter : RecordSchemaBase
{
    @id string id_;
    Union!(None, string) label_;
    Union!(None, string, string[]) secondaryFiles_;
    Union!(None, bool) streamable_;
    Union!(None, string, string[]) doc_;
    @link(LinkResolver.id) Union!(None, string, string[]) format_;
    Union!(None, CommandLineBinding) inputBinding_;
    Union!(None, Any) default_;
    @typeDSL
    Union!(
        None,
        CWLType,
        CommandInputRecordSchema,
        CommandInputEnumSchema,
        CommandInputArraySchema,
        string,
        Union!(
            CWLType,
            CommandInputRecordSchema,
            CommandInputEnumSchema,
            CommandInputArraySchema,
            string
        )[]
    ) type_;

    mixin genBody;
}

class CommandLineBinding : RecordSchemaBase
{
    Union!(None, bool) loadContents_;
    Union!(None, int) position_;
    Union!(None, string) prefix_;
    @defaultValue("true") bool separate_;
    Union!(None, string) itemSeparator_;
    Union!(None, string) valueFrom_;
    Union!(None, bool) shellQuote_;

    mixin genBody;
}

/// See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Any
public import salad.primitives : Any;

class CWLType : EnumSchemaBase
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

    mixin genBody;
}

class File : RecordSchemaBase
{
    static immutable class_ = "File";
    @link() Union!(None, string) location_;
    @link() Union!(None, string) path_;
    Union!(None, string) basename_;
    Union!(None, string) dirname_;
    Union!(None, string) nameroot_;
    Union!(None, string) nameext_;
    Union!(None, string) checksum_;
    Union!(None, long) size_;
    Union!(None, Union!(File, Directory)[]) secondaryFiles_;
    @link(LinkResolver.id) Union!(None, string) format_;
    Union!(None, string) contents_;

    mixin genBody;
}

class Directory : RecordSchemaBase
{
    static immutable class_ = "Directory";
    @link() Union!(None, string) location_;
    @link() Union!(None, string) path_;
    Union!(None, string) basename_;
    Union!(
        None,
        Union!(File, Directory)[],
    ) listing_;

    mixin genBody;
}

class CommandInputRecordSchema : RecordSchemaBase
{
    static immutable type_ = "record";
    @idMap("name", "type")
    Union!(None, CommandInputRecordField[]) fields_;
    Union!(None, string) label_;
    @id Union!(None, string) name_;

    mixin genBody;
}

class CommandInputRecordField : RecordSchemaBase
{
    string name_;
    @typeDSL
    Union!(
        CWLType,
        CommandInputRecordSchema,
        CommandInputEnumSchema,
        CommandInputArraySchema,
        string,
        Union!(
            CWLType,
            CommandInputRecordSchema,
            CommandInputEnumSchema,
            CommandInputArraySchema,
            string,
        )[]
    ) type_;
    Union!(None, string) doc_;
    Union!(None, CommandLineBinding) inputBinding_;
    Union!(None, string) label_;

    mixin genBody;
}

class CommandInputEnumSchema : RecordSchemaBase
{
    string[] symbols_;
    static immutable type_ = "enum";
    Union!(None, string) label_;
    @id Union!(None, string) name_;
    Union!(None, CommandLineBinding) inputBinding_;

    mixin genBody;
}

class CommandInputArraySchema : RecordSchemaBase
{
    @typeDSL
    Union!(
        CWLType,
        CommandInputRecordSchema,
        CommandInputEnumSchema,
        CommandInputArraySchema,
        string,
        Union!(
            CWLType,
            CommandInputRecordSchema,
            CommandInputEnumSchema,
            CommandInputArraySchema,
            string,
        )[],
    ) items_;
    static immutable type_ = "array";
    Union!(None, string) label_;
    Union!(None, CommandLineBinding) inputBinding_;

    mixin genBody;
}

class CommandOutputParameter : RecordSchemaBase
{
    @id string id_;
    Union!(None, string) label_;
    Union!(None, string, string[]) secondaryFiles_;
    Union!(None, bool) streamable_;
    Union!(None, string, string[]) doc_;
    Union!(None, CommandOutputBinding) outputBinding_;
    @link(LinkResolver.id) Union!(None, string) format_;
    @typeDSL
    Union!(
        None,
        CWLType,
        stdout,
        stderr,
        CommandOutputRecordSchema,
        CommandOutputEnumSchema,
        CommandOutputArraySchema,
        string,
        Union!(
            CWLType,
            CommandOutputRecordSchema,
            CommandOutputEnumSchema,
            CommandOutputArraySchema,
            string
        )[],
    ) type_;

    mixin genBody;
}

class stdout : EnumSchemaBase // @suppress(dscanner.style.phobos_naming_convention)
{
    enum Symbol
    {
        s1 = "stdout",
    }

    Symbol value;

    mixin genBody;
}

class stderr : EnumSchemaBase // @suppress(dscanner.style.phobos_naming_convention)
{
    enum Symbol
    {
        s2 = "stderr",
    }

    Symbol value;

    mixin genBody;
}

class CommandOutputBinding : RecordSchemaBase
{
    Union!(None, string, string[]) glob_;
    Union!(None, bool) loadContents_;
    Union!(None, string) outputEval_;

    mixin genBody;
}

class CommandOutputRecordSchema : RecordSchemaBase
{
    static immutable type_ = "record";
    @idMap("name", "type")
    Union!(None, CommandOutputRecordField[]) fields_;
    Union!(None, string) label_;
    @id Union!(None, string) name_;

    mixin genBody;
}

class CommandOutputRecordField : RecordSchemaBase
{
    string name_;
    @typeDSL
    Union!(
        CWLType,
        CommandOutputRecordSchema,
        CommandOutputEnumSchema,
        CommandOutputArraySchema,
        string,
        Union!(
            CWLType,
            CommandOutputRecordSchema,
            CommandOutputEnumSchema,
            CommandOutputArraySchema,
            string,
        )[],
    ) type_;
    Union!(None, string) doc_;
    Union!(None, CommandOutputBinding) outputBinding_;

    mixin genBody;
}

class CommandOutputEnumSchema : RecordSchemaBase
{
    string[] symbols_;
    static immutable type_ = "enum";
    Union!(None, string) label_;
    Union!(None, CommandOutputBinding) outputBinding_;

    mixin genBody;
}

class CommandOutputArraySchema : RecordSchemaBase
{
    @typeDSL
    Union!(
        CWLType,
        CommandOutputRecordSchema,
        CommandOutputEnumSchema,
        CommandOutputArraySchema,
        string,
        Union!(
            CWLType,
            CommandOutputRecordSchema,
            CommandOutputEnumSchema,
            CommandOutputArraySchema,
            string,
        )[],
    ) items_;
    static immutable type_ = "array";
    Union!(None, string) label_;
    Union!(None, CommandOutputBinding) outputBinding_;

    mixin genBody;
}

class InlineJavascriptRequirement : RecordSchemaBase
{
    static immutable class_ = "InlineJavascriptRequirement";
    Union!(None, string[]) expressionLib_;

    mixin genBody;
}

class SchemaDefRequirement : RecordSchemaBase
{
    static immutable class_ = "SchemaDefRequirement";
    Union!(
        InputRecordSchema,
        InputEnumSchema,
        InputArraySchema,
    )[] types_;

    mixin genBody;
}

class InputRecordSchema : RecordSchemaBase
{
    static immutable type_ = "record";
    @idMap("name", "type")
    Union!(
        None,
        InputRecordField[]
    ) fields_;
    Union!(None, string) label_;
    @id Union!(None, string) name_;

    mixin genBody;
}

class InputRecordField : RecordSchemaBase
{
    string name_;
    @typeDSL
    Union!(
        CWLType,
        InputRecordSchema,
        InputEnumSchema,
        InputArraySchema,
        string,
        Union!(
            CWLType,
            InputRecordSchema,
            InputEnumSchema,
            InputArraySchema,
            string,
        )[],
    ) type_;
    Union!(None, string) doc_;
    Union!(None, CommandLineBinding) inputBinding_;
    Union!(None, string) label_;

    mixin genBody;
}

class InputEnumSchema : RecordSchemaBase
{
    string[] symbols_;
    static immutable type_ = "enum";
    Union!(None, string) label_;
    @id Union!(None, string) name_;
    Union!(None, CommandLineBinding) inputBinding_;

    mixin genBody;
}

class InputArraySchema : RecordSchemaBase
{
    @typeDSL
    Union!(
        CWLType,
        InputRecordSchema,
        InputEnumSchema,
        InputArraySchema,
        string,
        Union!(
            CWLType,
            InputRecordSchema,
            InputEnumSchema,
            InputArraySchema,
            string,
        )[],
    ) items_;
    static immutable type_ = "array";
    Union!(None, string) label_;
    Union!(None, CommandLineBinding) inputBinding_;

    mixin genBody;
}

class DockerRequirement : RecordSchemaBase
{
    static immutable class_ = "DockerRequirement";
    Union!(None, string) dockerPull_;
    Union!(None, string) dockerLoad_;
    Union!(None, string) dockerFile_;
    Union!(None, string) dockerImport_;
    Union!(None, string) dockerImageId_;
    Union!(None, string) dockerOutputDirectory_;

    mixin genBody;
}

class SoftwareRequirement : RecordSchemaBase
{
    static immutable class_ = "SoftwareRequirement";
    @idMap("package", "specs")
    SoftwarePackage[] packages_;

    mixin genBody;
}

class SoftwarePackage : RecordSchemaBase
{
    string package_;
    Union!(None, string[]) version_;
    Union!(None, string[]) specs_;

    mixin genBody;
}

class InitialWorkDirRequirement : RecordSchemaBase
{
    static immutable class_ = "InitialWorkDirRequirement";
    Union!(
        Union!(
            File,
            Directory,
            Dirent,
            string,
        )[],
        string,
    ) listing_;

    mixin genBody;
}

class Dirent : RecordSchemaBase
{
    string entry_;
    Union!(None, string) entryname_;
    Union!(None, bool) writable_;

    mixin genBody;
}

class EnvVarRequirement : RecordSchemaBase
{
    static immutable class_ = "EnvVarRequirement";
    @idMap("envName", "envValue")
    EnvironmentDef[] envDef_;

    mixin genBody;
}

class EnvironmentDef : RecordSchemaBase
{
    string envName_;
    string envValue_;

    mixin genBody;
}

class ShellCommandRequirement : RecordSchemaBase
{
    static immutable class_ = "ShellCommandRequirement";

    mixin genBody;
}

class ResourceRequirement : RecordSchemaBase
{
    static immutable class_ = "ResourceRequirement";
    Union!(None, long, string) coresMin_;
    Union!(None, int, string) coresMax_;
    Union!(None, long, string) ramMin_;
    Union!(None, long, string) ramMax_;
    Union!(None, long, string) tmpdirMin_;
    Union!(None, long, string) tmpdirMax_;
    Union!(None, long, string) outdirMin_;
    Union!(None, long, string) outdirMax_;

    mixin genBody;
}

class CWLVersion : EnumSchemaBase
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

    mixin genBody;
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

@documentRoot class Workflow : RecordSchemaBase
{
    @idMap("id", "type")
    InputParameter[] inputs_;
    @idMap("id", "type")
    WorkflowOutputParameter[] outputs_;
    static immutable class_ = "Workflow";
    @idMap("id") WorkflowStep[] steps_;
    @id Union!(None, string) id_;
    @idMap("class")
    Union!(
        None, 
        Union!(
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
            Any,
        )[]
    ) requirements_;
    @idMap("class") Union!(None, Any[]) hints_;
    Union!(None, string) label_;
    Union!(None, string) doc_;
    Union!(None, CWLVersion) cwlVersion_;

    mixin genBody;
}

class WorkflowOutputParameter : RecordSchemaBase
{
    @id string id_;
    Union!(None, string) label_;
    Union!(None, string, string[]) secondaryFiles_;
    Union!(None, bool) streamable_;
    Union!(None, string, string[]) doc_;
    Union!(None, CommandOutputBinding) outputBinding_;
    @link(LinkResolver.id) Union!(None, string) format_;
    Union!(None, string, string[]) outputSource_;
    Union!(None, LinkMergeMethod) linkMerge_;
    @typeDSL
    Union!(
        None,
        CWLType,
        OutputRecordSchema,
        OutputEnumSchema,
        OutputArraySchema,
        string,
        Union!(
            CWLType,
            OutputRecordSchema,
            OutputEnumSchema,
            OutputArraySchema,
            string,
        )[],
    ) type_;

    mixin genBody;
}

class LinkMergeMethod : EnumSchemaBase
{
    enum Symbol
    {
        s1 = "merge_nested",
        s2 = "merge_flattened",
    }

    Symbol value;

    mixin genBody;
}

class OutputRecordSchema : RecordSchemaBase
{
    static immutable type_ = "record";
    @idMap("name", "type")
    Union!(None, OutputRecordField[]) fields_;
    Union!(None, string) label_;

    mixin genBody;
}

class OutputRecordField : RecordSchemaBase
{
    string name_;
    @typeDSL
    Union!(
        CWLType,
        OutputRecordSchema,
        OutputEnumSchema,
        OutputArraySchema,
        string,
        Union!(
            CWLType,
            OutputRecordSchema,
            OutputEnumSchema,
            OutputArraySchema,
            string,
        )[],
    ) type_;
    Union!(None, string) doc_;
    Union!(None, CommandOutputBinding) outputBinding_;

    mixin genBody;
}

class OutputEnumSchema : RecordSchemaBase
{
    string[] symbols_;
    static immutable type_ = "enum";
    Union!(None, string) label_;
    Union!(None, CommandOutputBinding) outputBinding_;

    mixin genBody;
}

class OutputArraySchema : RecordSchemaBase
{
    @typeDSL
    Union!(
        CWLType,
        OutputRecordSchema,
        OutputEnumSchema,
        OutputArraySchema,
        string,
        Union!(
            CWLType,
            OutputRecordSchema,
            OutputEnumSchema,
            OutputArraySchema,
            string,
        )[],
    ) items_;
    static immutable type_ = "array";
    Union!(None, string) label_;
    Union!(None, CommandOutputBinding) outputBinding_;

    mixin genBody;
}

class WorkflowStep : RecordSchemaBase
{
    @id string id_;
    @idMap("id", "source")
    WorkflowStepInput[] in_;
    Union!(string, WorkflowStepOutput)[] out_;
    Union!(string, CommandLineTool, ExpressionTool, Workflow) run_;
    @idMap("class")
    Union!(
        None,
        Union!(
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
            Any,
        )[]
    ) requirements_;
    @idMap("class") Union!(None, Any[]) hints_;
    Union!(None, string) label_;
    Union!(None, string) doc_;
    Union!(None, string, string[]) scatter_;
    Union!(None, ScatterMethod) scatterMethod_;

    mixin genBody;
}

class WorkflowStepInput : RecordSchemaBase
{
    @id string id_;
    Union!(None, string, string[]) source_;
    Union!(None, LinkMergeMethod) linkMerge_;
    Union!(None, Any) default_;
    Union!(None, string) valueFrom_;

    mixin genBody;
}

class WorkflowStepOutput : RecordSchemaBase
{
    @id string id_;

    mixin genBody;
}

class ScatterMethod : EnumSchemaBase
{
    enum Symbol
    {
        s1 = "dotproduct",
        s2 = "nested_crossproduct",
        s3 = "flat_crossproduct",
    }

    Symbol value;

    mixin genBody;
}

class SubworkflowFeatureRequirement : RecordSchemaBase
{
    static immutable class_ = "SubworkflowFeatureRequirement";

    mixin genBody;
}

class ScatterFeatureRequirement : RecordSchemaBase
{
    static immutable class_ = "ScatterFeatureRequirement";

    mixin genBody;
}

class MultipleInputFeatureRequirement : RecordSchemaBase
{
    static immutable class_ = "MultipleInputFeatureRequirement";

    mixin genBody;
}

class StepInputExpressionRequirement : RecordSchemaBase
{
    static immutable class_ = "StepInputExpressionRequirement";

    mixin genBody;
}

@documentRoot class ExpressionTool : RecordSchemaBase
{
    @idMap("id", "type")
    InputParameter[] inputs_;
    @idMap("id", "type")
    ExpressionToolOutputParameter[] outputs_;
    static immutable class_ = "ExpressionTool";
    string expression_;
    @id Union!(None, string) id_;
    @idMap("class")
    Union!(
        None,
        Union!(
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
            Any,
        )[]
    ) requirements_;
    @idMap("class") Union!(None, Any[]) hints_;
    Union!(None, string) label_;
    Union!(None, string) doc_;
    Union!(None, CWLVersion) cwlVersion_;

    mixin genBody;
}

class InputParameter : RecordSchemaBase
{
    @id string id_;
    Union!(None, string) label_;
    Union!(None, string, string[]) secondaryFiles_;
    Union!(None, bool) streamable_;
    Union!(None, string, string[]) doc_;
    @link(LinkResolver.id) Union!(None, string, string[]) format_;
    Union!(None, CommandLineBinding) inputBinding_;
    Union!(None, Any) default_;
    @typeDSL
    Union!(
        None,
        CWLType,
        InputRecordSchema,
        InputEnumSchema,
        InputArraySchema,
        string,
        Union!(
            CWLType,
            InputRecordSchema,
            InputEnumSchema,
            InputArraySchema,
            string,
        )[],
    ) type_;

    mixin genBody;
}

class ExpressionToolOutputParameter : RecordSchemaBase
{
    @id string id_;
    Union!(None, string) label_;
    Union!(None, string, string[]) secondaryFiles_;
    Union!(None, bool) streamable_;
    Union!(None, string, string[]) doc_;
    Union!(None, CommandOutputBinding) outputBinding_;
    @link(LinkResolver.id) Union!(None, string) format_;
    @typeDSL
    Union!(
        None,
        CWLType,
        OutputRecordSchema,
        OutputEnumSchema,
        OutputArraySchema,
        string,
        Union!(
            CWLType,
            OutputRecordSchema,
            OutputEnumSchema,
            OutputArraySchema,
            string,
        )[],
    ) type_;

    mixin genBody;
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

///
alias DocumentRootType = Union!(CommandLineTool, ExpressionTool, Workflow);

///
alias importFromURI = import_!DocumentRootType;

///
@safe unittest
{
    import core.exception : AssertError;
    import dyaml : Node;
    import salad.resolver : absoluteURI;
    import salad.type : tryMatch;
    import salad.util : dig, edig;
    import std.exception : assertNotThrown, enforce;

    auto uri = "examples/cwl-v1.0/bwa-mem-tool.cwl".absoluteURI;

    auto cwl = importFromURI(uri).tryMatch!((DocumentRootType r) => r)
                                 .assertNotThrown;
    assert(cwl.edig!("class", string) == "CommandLineTool");

    auto cmd = cwl.tryMatch!((CommandLineTool c) => c)
                  .assertNotThrown;
    assert(cmd.dig!"cwlVersion"(new CWLVersion("draft-2")) == "v1.0");
    assert(cmd.dig!(["inputs", "reference", "type"], CWLType) == "File");
    assert(cmd.dig!(["hints", "ResourceRequirement"], ResourceRequirement)
              .enforce!AssertError
              .dig!("coresMin", long) == 2);
    assert(cmd.edig!(["hints", "ResourceRequirement"], ResourceRequirement)
              .assertNotThrown
              .dig!("coresMin", long) == 2);
    // Test for @defaultValue
    assert(cmd.edig!(["inputs", "reference", "inputBinding", "separate"], bool) == true);

    auto node = Node(cmd);
}

///
@safe unittest
{
    import salad.resolver : absoluteURI;
    import salad.type : tryMatch;
    import salad.util : dig, edig;
    import std.exception : assertNotThrown;

    auto uri = "examples/cwl-v1.0/count-lines1-wf.cwl".absoluteURI;
    auto cwl = importFromURI(uri).tryMatch!((DocumentRootType r) => r)
                                 .assertNotThrown;
    assert(cwl.edig!("class", string) == "Workflow");

    auto wf = cwl.tryMatch!((Workflow w) => w)
                 .assertNotThrown;
    assert(wf.edig!("class", string) == "Workflow");
    assert(wf.dig!"cwlVersion"(new CWLVersion("draft-3")) == "v1.0");
    assert(wf.dig!(["inputs", "file1", "type"], CWLType) == "File");
    assert(wf.dig!(["outputs", "count_output", "outputSource"], string) == "step2/output");
}

@safe unittest
{
    import salad.resolver : absoluteURI;
    import salad.type : tryMatch;
    import salad.util : edig;
    import std.exception : assertNotThrown;

    auto uri = "examples/cwl-v1.0/revsort-packed.cwl".absoluteURI;
    auto cwls = importFromURI(uri).tryMatch!((DocumentRootType[] rs) => rs)
                                  .assertNotThrown;
    assert(cwls.length == 3);

    {
        auto cwl = importFromURI(uri, "#main").tryMatch!((DocumentRootType r) => r)
                                              .assertNotThrown;
        assert(cwl.edig!("class", string) == "Workflow");
    }

    {
        auto cwl = importFromURI(uri, "main").tryMatch!((DocumentRootType r) => r)
                                             .assertNotThrown;
        assert(cwl.edig!("class", string) == "Workflow");

        auto wf = cwl.tryMatch!((Workflow w) => w)
                     .assertNotThrown;
        assert(wf.edig!("doc", string) == "Reverse the lines in a document, then sort those lines.");
    }
}

@safe unittest
{
    import dyaml : Loader;
    import salad.util : edig;

    enum cwl = "examples/cwl-v1.0/glob-expr-list.cwl";
    auto clt = Loader.fromFile(cwl)
                     .load
                     .as!CommandLineTool;
    assert(clt.edig!(["inputs", "ids", "type", "type"], string) == "array");
}

@safe unittest
{
    import salad.resolver : absoluteURI;
    import salad.type : tryMatch;
    import salad.util : edig;
    import std.exception : assertNotThrown;

    auto uri = "examples/cwl-v1.0/params.cwl".absoluteURI;

    auto cwl = importFromURI(uri).tryMatch!((DocumentRootType r) => r)
                                 .assertNotThrown;
    assert(cwl.edig!("class", string) == "CommandLineTool");

    auto cmd = cwl.tryMatch!((CommandLineTool c) => c)
                  .assertNotThrown;
    assert(cmd.edig!(["outputs", "t1", "type"], string) == "Any");
}

@safe unittest
{
    import salad.resolver : absoluteURI;
    import salad.type : tryMatch;
    import salad.util : edig;
    import std.exception : assertNotThrown;

    auto uri = "examples/cwl-v1.0/formattest.cwl".absoluteURI;

    auto cmd = importFromURI(uri).tryMatch!((DocumentRootType r) => r)
                                 .tryMatch!((CommandLineTool c) => c)
                                 .assertNotThrown;
    assert(cmd.edig!(["inputs", "input", "format"], string) == "http://edamontology.org/format_2330");
}

@safe unittest
{
    import salad.resolver : absoluteURI;
    import salad.type : tryMatch;
    import salad.util : edig;
    import std.exception : assertNotThrown;

    auto uri = "examples/cwl-v1.0/formattest2.cwl".absoluteURI;

    auto cmd = importFromURI(uri).tryMatch!((DocumentRootType r) => r)
                                 .tryMatch!((CommandLineTool c) => c)
                                 .assertNotThrown;
    assert(cmd.edig!(["outputs", "output", "format"], string) == "$(inputs.input.format)");
    assert(cmd.identifier == uri);
}

@safe unittest
{
    import salad.resolver : absoluteURI;
    import salad.type : tryMatch;
    import salad.util : edig;
    import std.exception : assertNotThrown;

    auto uri = "examples/cwl-v1.0/search.cwl".absoluteURI;

    auto wf = importFromURI(uri~"#main").tryMatch!((DocumentRootType r) => r)
                                 .tryMatch!((Workflow wf) => wf)
                                 .assertNotThrown;
    assert(wf.identifier == uri~"#main");
}

/// Supporting extension fields in objects
@safe unittest
{
    import salad.resolver : absoluteURI;
    import salad.type : tryMatch;
    import std.exception : assertNotThrown;
    import dyaml : Node;

    auto uri = "examples/cwl-v1.0/metadata.cwl".absoluteURI;

    auto c = importFromURI(uri).tryMatch!((DocumentRootType r) => r)
                               .tryMatch!((CommandLineTool c) => c)
                               .assertNotThrown;
    // Extension field names are resolved
    auto creator = "http://purl.org/dc/terms/creator" in c.extension_fields;
    assert(creator);
    // Each field name and its value are not resolved
    assert(creator.value["class"] == "foaf:Person");
    assert(creator.value["foaf:name"] == "Peter Amstutz");

    // full qualified identifier is shortened when converting to Node
    auto n = Node(c);
    assert("dct:creator" in n);
}

/// Supporting extension objects in array
@safe unittest
{
    import salad.resolver : absoluteURI;
    import salad.type : match, tryMatch;
    import std.exception : assertNotThrown;

    auto uri = "examples/cwltool/mpi_simple.cwl".absoluteURI;

    auto c = importFromURI(uri).tryMatch!((DocumentRootType r) => r)
                               .tryMatch!((CommandLineTool c) => c)
                               .assertNotThrown;

    c.requirements_.match!(
        (None _) {},
        (reqs) {
            assert(reqs.length == 1);
            auto n = reqs[0].tryMatch!((Any a) => a).assertNotThrown.value;
            assert(n["class"] == "cwltool:MPIRequirement");
            assert(n["processes"] == 2);
        }
    );
}

/// Test for defalut constructor with default values
unittest
{
    auto clb = new CommandLineBinding;
    assert(clb.separate_);
}
