/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.type;

public import std.sumtype;
import std.meta : allSatisfy, anySatisfy, templateNot;
import std.traits : isArray;

struct None{}

enum isNone(T) = is(T == None);

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

///
auto orElse(T, U)(T val, lazy U default_) @safe
if (isOptional!T && T.Types.length == 2)
{
    alias V = T.Types[1];

    static if ((isArray!V && is(U == void[])) ||
               (is(V == class) && is(U == typeof(null))))
    {
        return val.match!((V v) => v, none => V.init);
    }
    else
    {
        return val.match!((U u) => u, none => default_);
    }
}

///
@safe unittest
{
    Optional!int num;
    assert(num.orElse(5) == 5);

    num = 1;
    assert(num.orElse(5) == 1);
}

@safe unittest
{
    Optional!(string[]) arr;
    assert(arr.orElse(["a", "b", "c"]) == ["a", "b", "c"]);
    assert(arr.orElse([]) == (string[]).init);
    
    arr = ["foo"];
    assert(arr.orElse([]) == ["foo"]);
}

@safe unittest
{
    static class C {}

    Optional!C c;
    assert(c.orElse(null) is null);

    c = new C;
    assert(c.orElse(null) !is null);
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
