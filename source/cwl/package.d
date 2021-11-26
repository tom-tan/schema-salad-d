module cwl;

import cwl.schema;

import salad.parser : import_ = importFromURI;
import salad.meta : DocRootType = DocumentRootType;
import salad.type : match, tryMatch;
import salad.util : dig;

alias importFromURI = import_!(cwl.schema);
alias DocumentRootType = DocRootType!(cwl.schema);

unittest
{
    import std.exception : assertNotThrown;
    import std.path : absolutePath;

    auto uri = "file://"~"examples/bwa-mem-tool.cwl".absolutePath;

    auto cwl = importFromURI(uri).tryMatch!((DocumentRootType r) => r)
                                 .assertNotThrown;
    assert(cwl.tryMatch!(p => p.dig!("class", string))
              .assertNotThrown == "CommandLineTool");

    auto cmd = cwl.tryMatch!((CommandLineTool c) => c)
                  .assertNotThrown;
    assert(cmd.dig!"cwlVersion"("v1.2") == "v1.0");
    assert(cmd.dig!(["inputs", "reference", "type"], CWLType) == "File");
    assert(cmd.dig!("hints", Any[])[0]
              .as!ResourceRequirement
              .dig!("coresMin", long) == 2);
}

unittest
{
    import std.exception : assertNotThrown;
    import std.path : absolutePath;

    auto uri = "file://"~"examples/count-lines1-wf.cwl".absolutePath;
    auto cwl = importFromURI(uri).tryMatch!((DocumentRootType r) => r)
                                 .assertNotThrown;
    assert(cwl.tryMatch!(p => p.dig!("class", string))
              .assertNotThrown == "Workflow");

    auto wf = cwl.tryMatch!((Workflow w) => w)
                 .assertNotThrown;
    assert(wf.dig!"class"("Invalid") == "Workflow");
    assert(wf.dig!"cwlVersion"("v1.2") == "v1.0");
    assert(wf.dig!(["inputs", "file1", "type"], CWLType) == "File");
    assert(wf.dig!(["outputs", "count_output", "outputSource"], string) == "step2/output");
}

unittest
{
    import std.exception : assertNotThrown;
    import std.path : absolutePath;

    auto uri = "file://"~"examples/revsort-packed.cwl".absolutePath;
    auto cwls = importFromURI(uri).tryMatch!((DocumentRootType[] rs) => rs)
                                  .assertNotThrown;
    assert(cwls.length == 3);

    auto cwl = importFromURI(uri, "#main").tryMatch!((DocumentRootType r) => r)
                                          .assertNotThrown;
    assert(cwl.tryMatch!(p => p.dig!("class", string)) == "Workflow");

    auto wf = cwl.tryMatch!((Workflow w) => w)
                 .assertNotThrown;
    assert(wf.dig!("doc", string) == "Reverse the lines in a document, then sort those lines.");
}
