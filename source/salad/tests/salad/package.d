/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.tests.salad;

version(unittest):

public import salad.tests.salad.schema;

import salad.meta.parser : DocRootType = DocumentRootType, import_ = importFromURI;

///
alias importFromURI = import_!(salad.tests.salad.schema);
///
alias DocumentRootType = DocRootType!(salad.tests.salad.schema);

/// Loading SALAD metaschema
// disabled due to https://github.com/common-workflow-language/schema_salad/issues/626
version(none):
@safe unittest
{
    import salad.type : tryMatch;
    import salad.util : edig;
    import std.exception : assertNotThrown;

    auto uri = "https://raw.githubusercontent.com/common-workflow-language/schema_salad/main/schema_salad/metaschema/metaschema.yml"; // @suppress(dscanner.style.long_line)
    auto schemas = importFromURI(uri).tryMatch!((DocumentRootType[] drts) => drts)
                                     .assertNotThrown;
    assert(schemas[0].edig!("name", string) == "Semantic_Annotations_for_Linked_Avro_Data");
    assert(schemas[3].edig!("name", string) == "Schema");
}

/// Loading CWL v1.0 schema
@safe unittest
{
    import salad.type : tryMatch;
    import std.exception : assertNotThrown;

    auto uri = "https://raw.githubusercontent.com/common-workflow-language/common-workflow-language/main/v1.0/CommonWorkflowLanguage.yml"; // @suppress(dscanner.style.long_line)
    auto schemas = importFromURI(uri).tryMatch!((DocumentRootType[] drts) => drts)
                                     .assertNotThrown;
}

/// Loading CWL v1.1 schema
@safe unittest
{
    import salad.type : tryMatch;
    import std.exception : assertNotThrown;

    auto uri = "https://raw.githubusercontent.com/common-workflow-language/cwl-v1.1/main/CommonWorkflowLanguage.yml";
    auto schemas = importFromURI(uri).tryMatch!((DocumentRootType[] drts) => drts)
                                     .assertNotThrown;
}

/// Loading CWL v1.2 schema
@safe unittest
{
    import salad.type : tryMatch;
    import std.exception : assertNotThrown;

    auto uri = "https://raw.githubusercontent.com/common-workflow-language/cwl-v1.2/main/CommonWorkflowLanguage.yml";
    auto schemas = importFromURI(uri).tryMatch!((DocumentRootType[] drts) => drts)
                                     .assertNotThrown;
}

/// Loading CWL v1.3 schema
@safe unittest
{
    import salad.type : tryMatch;
    import std.exception : assertNotThrown;

    auto uri = "https://raw.githubusercontent.com/common-workflow-language/cwl-v1.3/main/CommonWorkflowLanguage.yml";
    auto schemas = importFromURI(uri).tryMatch!((DocumentRootType[] drts) => drts)
                                     .assertNotThrown;
}
