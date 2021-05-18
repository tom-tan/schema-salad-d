module salad.resolution;

version(none):


// field name resolution
// identifier resolution
// link resolution
// vocabulary resolution
// $import
// $include
// $mixin
// identifier map
// DSL
auto preprocess(Node node, Context context, string[string] vocabulary, string baseURI)
{
    ///
    if (node.type == NodeType.mapping)
    {
        foreach(string f, Node v; node)
        {
            // 3.1. Field name resolution
            // See_Also: https://www.commonwl.org/v1.0/SchemaSalad.html#Field_name_resolution
            if (auto split = f.findSplit(":"))
            {
                if (split[2].startsWith("//"))
                {
                    // 3.1. (2) If a field name URI is an absolute URI consisting of a scheme and path and is not part of the vocabulary, no processing occurs.
                    auto newF = f;
                }
                else
                {
                    // 3.1. (1) If an field name URI begins with a namespace prefix declared in the document context (@context) followed by a colon :, the prefix and colon must be replaced by the namespace declared in @context.
                    auto pre = *enforce(split[0] in context);
                    auto newF = pre ~ split[2];
                }
            }
            else if (auto voc = f in vocabulary)
            {
                // 3.1. (3) If there is a vocabulary term which maps to the URI of a resolved field, the field name must be replace with the vocabulary term.
                auto newF = *voc;
            }

            // 3.2. identifier resolution
            if (v.type != NodeType.string)
            {
                auto newV = v; // TODO: preprocess
            }
            auto id = v.get!string;
            if (id.startsWith("#"))
            {
                // 3.2. (1) If an identifier URI is prefixed with # it is a URI relative fragment identifier. It is resolved relative to the base URI by setting or replacing the fragment portion of the base URI.
                // TODO: can we assume `baseURI` does not end with "/"?
                auto newV = baseURI~id;
            }
            else if (id.canFind("://"))
            {
                // 3.2. (4) If an identifier URI is an absolute URI consisting of a scheme and path, no processing occurs.
                auto newV = id;
            }
            else
            {
                // 3.2. (2) If an identifier URI does not contain a scheme and is not prefixed # it is a parent relative fragment identifier. It is resolved relative to the base URI by the following rule:

                if (!baseURI.canFind("#"))
                {
                    // if the base URI does not contain a document fragment, set the fragment portion of the base URI.
                    auto newV = baseURI ~ "#" ~ id;
                }
                else
                {
                    // If the base URI does contain a document fragment, append a slash / followed by the identifier field to the fragment portion of the base URI.
                    auto newV = baseURI ~ '/' ~ id;
                }
            }
        }
    }

}

unittest
{
    enum schemaStr = q"EOS
    {
      "$namespaces": {
        "acid": "http://example.com/acid#"
      },
      "$graph": [{
        "name": "ExampleType",
        "type": "record",
        "fields": [{
          "name": "base",
          "type": "string",
          "jsonldPredicate": "http://example.com/base"
        }]
      }]
    }
EOS";

    auto schema = Loader.fromString(schemaStr)
                        .load
                        .as!Schema;

    enum example = q"EOS
    {
      "base": "one",
      "form": {
        "http://example.com/base": "two",
        "http://example.com/three": "three",
      },
      "acid:four": "four"
    }
EOS";

    enum expected = q"EOS
    {
      "base": "one",
      "form": {
        "base": "two",
        "http://example.com/three": "three",
      },
      "http://example.com/acid#four": "four"
    }
EOS";
}
