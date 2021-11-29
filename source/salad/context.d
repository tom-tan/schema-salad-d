/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.context;

struct LoadingContext
{
    string baseURI;
    string[string] namespaces;
    // TODO: validation with RDF schema
}
