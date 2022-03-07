/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad;

public import salad.schema_original;

import salad.parser : import_ = importFromURI;
import salad.meta : DocRootType = DocumentRootType;

///
alias importFromURI = import_!(salad.schema_original);
///
alias DocumentRootType = DocRootType!(salad.schema_original);

/// Loading SALAD metaschema
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
/// Does not work due to `:` in a string
/// See_Also: https://dlang-community.github.io/D-YAML/articles/spec_differences.html
version(none)
@safe unittest
{
    import salad.type : tryMatch;
    import std.exception : assertNotThrown;

    auto uri = "https://raw.githubusercontent.com/common-workflow-language/cwl-v1.1/main/CommonWorkflowLanguage.yml";
    auto schemas = importFromURI(uri).tryMatch!((DocumentRootType[] drts) => drts)
                                     .assertNotThrown;
}

/// Loading CWL v1.2 schema
/// Does not work due to `:` in a string
/// See_Also: https://dlang-community.github.io/D-YAML/articles/spec_differences.html
version(none)
@safe unittest
{
    import salad.type : tryMatch;
    import std.exception : assertNotThrown;

    auto uri = "https://raw.githubusercontent.com/common-workflow-language/cwl-v1.2/main/CommonWorkflowLanguage.yml";
    auto schemas = importFromURI(uri).tryMatch!((DocumentRootType[] drts) => drts)
                                     .assertNotThrown;
}
