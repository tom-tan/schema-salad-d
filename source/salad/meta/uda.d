/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.meta.uda;

/**
 * UDA for identifier maps
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Identifier_maps
*/
struct idMap { string subject; string predicate = ""; } // @suppress(dscanner.style.phobos_naming_convention)

/**
 * UDA for DSL for types
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Domain_Specific_Language_for_types
*/
struct typeDSL {} // @suppress(dscanner.style.phobos_naming_convention)

/**
 * UDA for DSL for secondary files
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Domain_Specific_Language_for_secondary_files
*/
struct secondaryFilesDSL {} // @suppress(dscanner.style.phobos_naming_convention)

/** 
 * UDA for documentRoot
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#SaladRecordSchema
 */
struct documentRoot {} // @suppress(dscanner.style.phobos_naming_convention)

/** 
 * UDA for identifier
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Record_field_annotations
 */
struct id {} // @suppress(dscanner.style.phobos_naming_convention)

/** 
 * UDA for subscope
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Identifier_resolution
 */
struct subscope { string subscope; } // @suppress(dscanner.style.phobos_naming_convention)

/// See_Also: https://github.com/common-workflow-language/schema_salad/pull/631
enum LinkResolver
{
    none,
    link, // use link resolution
    id, // use identifier resolution
}

/**
 * UDA for link fields
 * See_Also: https://www.commonwl.org/v1.2/SchemaSalad.html#Link_validation
 */
struct link // @suppress(dscanner.style.phobos_naming_convention)
{
    LinkResolver resolver = LinkResolver.link;
}
