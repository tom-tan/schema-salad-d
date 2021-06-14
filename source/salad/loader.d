module salad.loader;

import dyaml;

import salad.schema;
import salad.type;

struct Loader
{
    ///
    this(SaladSchema s)
    {
        import std.algorithm : filter, map;
        import std.array : array, assocArray;
        import std.range : empty;
        import std.typecons : tuple;

        schema = s;
        auto defs = s.graph
                     .filter!(ds => ds.match!(
                        (SaladRecordSchema _) => true,
                        (SaladEnumSchema _) => true,
                        _ => false,
                     ))
                     .array; 
        docRoots = defs.filter!(ds => ds.match!(
                            (SaladRecordSchema srs) => srs.documentRoot.match!(
                                (bool b) => b,
                                _ => false,
                            ),
                            (SaladEnumSchema ses) => ses.documentRoot.match!(
                                (bool b) => b,
                                _ => false,
                            ),
                            _ => false, // assert(false)
                       ))
                       .map!(ds => ds.match!(
                            (SaladRecordSchema srs) => cast(DocumentSchema)srs,
                            (SaladEnumSchema ses) => cast(DocumentSchema)ses,
                            _ => null, // assert(false)
                       ))
                       .filter!"a"
                       .array;
        docSchema = defs.map!(ds => ds.match!(
                            (SaladRecordSchema srs) => tuple(srs.name, cast(DocumentSchema)srs),
                            (SaladEnumSchema ses) => tuple(ses.name, cast(DocumentSchema)ses),
                            _ => tuple("", DocumentSchema.init), // assert(false)
                        ))
                        .filter!(a => !a[0].empty)
                        .assocArray;
    }

    ///
    auto load(Node node, LoadOption lo = LoadOption.init)
    {
        if (node.type == NodeType.string)
        {
            import std.algorithm : canFind, find, filter, map;
            import std.array : array;

            auto sym = node.as!string;
            auto types = docRoots.map!(doc => cast(SaladEnumSchema)doc)
                                 .filter!"a"
                                 .find!(doc => doc.symbols.canFind(sym))
                                 .array;
            if (types.length == 1)
            {
                return new EnumObject(types[0], sym);
            }
            else
            {
                // TODO: error? ambiguous object
                return null;
            }
        }
        else if (node.type == NodeType.mapping)
        {
            //
        }
        // TODO: error! invalid object
        return null;
    }

    SaladSchema schema;
    DocumentSchema[] docRoots;
    DocumentSchema[string] docSchema;
}

unittest
{
    static import dyaml;
    enum schema_str = q"EOS
{
    "$namespaces": {
        "acid": "http://example.com/acid#"
    },
    "$graph": [{
        "name": "ExampleType",
        "type": "record",
        "documnentRoot": true,
        "fields": [{
            "name": "base",
            "type": "string",
            "jsonldPredicate": "http://example.com/base"
        }]
    }]
}
EOS";
    enum doc_str = q"EOS
{
    "base": "one",
    "form": {
        "http://example.com/base": "two",
        "http://example.com/three": "three",
    },
    "acid:four": "four"
}
EOS";

    auto schema = dyaml.Loader.fromString(schema_str).load.as!SaladSchema;
    auto loader = Loader(schema);
    auto doc = dyaml.Loader.fromString(doc_str).load;

    //auto loadedObject = loader.load(doc).assertNotThrown;

}

abstract class LoadedObject
{
    this(DocumentSchema schema)
    {
        this.schema = schema;
    }
    DocumentSchema schema;
}

class RecordObject : LoadedObject
{
    this(DocumentSchema schema, LoadedObject[string] fields)
    {
        super(schema);
        this.fields = fields;
    }
    LoadedObject[string] fields;
}

class EnumObject : LoadedObject
{
    this(DocumentSchema schema, string value)
    {
        super(schema);
        this.value = value;
    }
    string value;
}

class PrimitiveObject : LoadedObject
{
    this(DocumentSchema schema)
    {
        super(schema);
    }
    // XXX
}

struct LoadOption
{
    /// control whether external URI (e.g., `Workflow.steps.*.run`) should be loaded
    bool loadExternalURI;

    /**
    true: throws an exception when an error occurs
    false: collect exceptions
    */
    bool strictValidation;
}
