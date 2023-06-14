/**
 * It is used only for testing.
 *
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.tests.optional;

version(unittest):

import salad.meta.impl : genCtor;
import salad.meta.uda : documentRoot, id, idMap, link, LinkResolver, typeDSL;
import salad.primitives : SchemaBase;
import salad.type : Optional;

class Root : SchemaBase
{
    string id_;
    Optional!string value_;

    mixin genCtor;
}

/++
 + When a field is not present in the node, the corresponding field must have `None` value.
 + See_Also: https://github.com/common-workflow-language/cwl-v1.2/issues/75#issuecomment-741730322
 +/
@safe unittest
{
    import dyaml : Loader;
    import salad.context : LoadingContext;
    import salad.meta.impl : as_;
    import salad.type : None;
    import salad.util : edig;
    import std : assertNotThrown;

    enum yaml = q"EOS
        id: name
EOS";

    auto node = Loader.fromString(yaml).load;
    auto root = node.as_!Root(LoadingContext.init);
    root.edig!(["value"], None).assertNotThrown;
}

/++
 + A field with null value is treated as the field is not present.
 + See_Also: https://github.com/common-workflow-language/cwl-v1.2/issues/75#issuecomment-741730322
 +/
@safe unittest
{
    import dyaml : Loader;
    import salad.context : LoadingContext;
    import salad.meta.impl : as_;
    import salad.type : None;
    import salad.util : edig;
    import std : assertNotThrown;

    enum yaml = q"EOS
        id: name
        value: null
EOS";

    auto node = Loader.fromString(yaml).load;
    auto root = node.as_!Root(LoadingContext.init);
    root.edig!(["value"], None).assertNotThrown;
}
