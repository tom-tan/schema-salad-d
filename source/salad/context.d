/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.context;

struct LoadingContext
{
    ///
    this(ref return scope inout LoadingContext rhs) nothrow pure @safe
    {
        import std.conv : to;
        import std.exception : assertNotThrown;

        baseURI = rhs.baseURI;
        fileURI = rhs.fileURI;
        namespaces = rhs
            .namespaces
            .to!(string[string])
            .assertNotThrown; // https://issues.dlang.org/show_bug.cgi?id=21236
        subscope = rhs.subscope;
        schemas = rhs.schemas.dup;
    }

    string baseURI;
    /**
     * URI for `include` and `import` directives
     * It is a workaround for common-workflow-language/schema_salad#495
     */
    string fileURI;
    string[string] namespaces;
    string subscope;
    // TODO (optional feature): validate extension fields with RDF schema
    // https://www.commonwl.org/v1.0/SchemaSalad.html#Explicit_context
    string[] schemas;
}
