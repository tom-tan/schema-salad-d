/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.type;

public import sumtype;
import std.meta : allSatisfy, anySatisfy, templateNot;

struct None{}

private enum isNone(T) = is(T == None);

template Optional(TS...)
if (allSatisfy!(templateNot!isNone, TS))
{
    alias Optional = SumType!(None, TS);
}

enum isOptional(T) = isSumType!T && is(T.Types[0] == None) && allSatisfy!(templateNot!isNone, T.Types[1..$]);

// test for Optional!T
@safe unittest
{
    import std.exception : assertNotThrown;
    auto op = Optional!int.init;
    op.tryMatch!((None _) {})
      .assertNotThrown;
}

// TODO: more appropriate name
template Either(TS...)
if (allSatisfy!(templateNot!isNone, TS))
{
    alias Either = SumType!TS;
}

enum isEither(T) = isSumType!T && allSatisfy!(templateNot!isNone, T.Types);

@safe unittest
{
    static assert(isEither!(SumType!(int, string, double)));
    static assert(!isEither!(Optional!int));
    static assert(isEither!(SumType!(int, string)));
    static assert(!isEither!(SumType!(None, int, string)));
    static assert(!isEither!string);
}
