/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.context;

struct LoadingContext
{
    string baseURI;
    /**
     * URI for `include` and `import` directives
     * It is a workaround for common-workflow-language/schema_salad#495
     */
    string fileURI;
    string[string] namespaces;
    string subscope;
    // TODO: validation with RDF schema
}
