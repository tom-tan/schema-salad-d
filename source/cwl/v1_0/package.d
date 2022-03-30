/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module cwl.v1_0;

public import cwl.v1_0.schema;

import salad.meta.parser : DocRootType = DocumentRootType, import_ = importFromURI;

///
alias importFromURI = import_!(cwl.v1_0.schema);
///
alias DocumentRootType = DocRootType!(cwl.v1_0.schema);

///
@safe unittest
{
    import core.exception : AssertError;
    import salad.type : tryMatch;
    import salad.util : dig, edig;
    import std.exception : assertNotThrown, enforce;
    import std.path : absolutePath;

    auto uri = "file://"~"examples/bwa-mem-tool.cwl".absolutePath;

    auto cwl = importFromURI(uri).tryMatch!((DocumentRootType r) => r)
                                 .assertNotThrown;
    assert(cwl.edig!("class", string) == "CommandLineTool");

    auto cmd = cwl.tryMatch!((CommandLineTool c) => c)
                  .assertNotThrown;
    assert(cmd.dig!"cwlVersion"("v1.2") == "v1.0");
    assert(cmd.dig!(["inputs", "reference", "type"], CWLType) == "File");
    assert(cmd.dig!(["hints", "ResourceRequirement"], ResourceRequirement)
              .enforce!AssertError
              .dig!("coresMin", long) == 2);
    assert(cmd.edig!(["hints", "ResourceRequirement"], ResourceRequirement)
              .assertNotThrown
              .dig!("coresMin", long) == 2);
}

///
@safe unittest
{
    import salad.type : tryMatch;
    import salad.util : dig, edig;
    import std.exception : assertNotThrown;
    import std.path : absolutePath;

    auto uri = "file://"~"examples/count-lines1-wf.cwl".absolutePath;
    auto cwl = importFromURI(uri).tryMatch!((DocumentRootType r) => r)
                                 .assertNotThrown;
    assert(cwl.edig!("class", string) == "Workflow");

    auto wf = cwl.tryMatch!((Workflow w) => w)
                 .assertNotThrown;
    assert(wf.edig!("class", string) == "Workflow");
    assert(wf.dig!"cwlVersion"("v1.2") == "v1.0");
    assert(wf.dig!(["inputs", "file1", "type"], CWLType) == "File");
    assert(wf.dig!(["outputs", "count_output", "outputSource"], string) == "step2/output");
}

@safe unittest
{
    import salad.type : tryMatch;
    import salad.util : dig, edig;
    import std.exception : assertNotThrown;
    import std.path : absolutePath;

    auto uri = "file://"~"examples/revsort-packed.cwl".absolutePath;
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

/// Dump a CWL document as a JSON string
unittest
{
    import std.array : appender;
    import std.regex : ctRegex, replaceAll;
    import dyaml : dumper, Loader, Node;

    enum cwl = "examples/count-lines1-wf.cwl";
    auto wf = Loader.fromFile(cwl)
                    .load
                    .as!Workflow;

    auto app = appender!string;

    // Convert CWL document to Node
    auto n = Node(wf);

    // Dump Node to JSON string
    auto d = dumper();
    d.YAMLVersion = null;
    d.dump(app, n);
    // Note: dumper.dump outputs multi-line (but not pretty-printed) JSON string
    auto str = app[].replaceAll(ctRegex!`\n\s+`, " ");

    import std.exception : assertNotThrown;
    import std.json : JSONException, parseJSON;
    parseJSON(str).assertNotThrown!JSONException;
}
