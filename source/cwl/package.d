/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module cwl;

public import cwl.schema;

import salad.parser : import_ = importFromURI;
import salad.meta : DocRootType = DocumentRootType;

///
alias importFromURI = import_!(cwl.schema);
///
alias DocumentRootType = DocRootType!(cwl.schema);

///
unittest
{
    import salad.type : tryMatch;
    import salad.util : dig, edig;
    import std.exception : assertNotThrown;
    import std.path : absolutePath;

    auto uri = "file://"~"examples/bwa-mem-tool.cwl".absolutePath;

    auto cwl = importFromURI(uri).tryMatch!((DocumentRootType r) => r)
                                 .assertNotThrown;
    assert(cwl.edig!("class", string) == "CommandLineTool");

    auto cmd = cwl.tryMatch!((CommandLineTool c) => c)
                  .assertNotThrown;
    assert(cmd.dig!"cwlVersion"("v1.2") == "v1.0");
    assert(cmd.dig!(["inputs", "reference", "type"], CWLType) == "File");
    assert(cmd.dig!("hints", Any[])[0]
              .as!ResourceRequirement
              .dig!("coresMin", long) == 2);
}

///
unittest
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

unittest
{
    import salad.type : tryMatch;
    import salad.util : dig, edig;
    import std.exception : assertNotThrown;
    import std.path : absolutePath;

    auto uri = "file://"~"examples/revsort-packed.cwl".absolutePath;
    auto cwls = importFromURI(uri).tryMatch!((DocumentRootType[] rs) => rs)
                                  .assertNotThrown;
    assert(cwls.length == 3);

    auto cwl = importFromURI(uri, "#main").tryMatch!((DocumentRootType r) => r)
                                          .assertNotThrown;
    assert(cwl.edig!("class", string) == "Workflow");

    auto wf = cwl.tryMatch!((Workflow w) => w)
                 .assertNotThrown;
    assert(wf.edig!("doc", string) == "Reverse the lines in a document, then sort those lines.");
}
