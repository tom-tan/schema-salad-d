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