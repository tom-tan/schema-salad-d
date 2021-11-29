/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad;

import salad.schema;

import salad.parser : import_ = importFromURI;
import salad.meta : DocRootType = DocumentRootType;

alias importFromURI = import_!(salad.schema);
alias DocumentRootType = DocRootType!(salad.schema);
