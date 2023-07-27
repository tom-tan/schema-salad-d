/**
 * Authors: Tomoya Tanjo
 * Copyright: © 2021 Tomoya Tanjo
 * License: Apache-2.0
 */
module salad.type;

public import std.sumtype;
import std.meta : allSatisfy, anySatisfy, NoDuplicates, templateNot;
import std.traits : isArray;

struct None{}

enum isNone(T) = is(T == None);

template Optional(TS...)
if (allSatisfy!(templateNot!isNone, TS))
{
    alias Optional = Union!(None, TS);
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

/**
 * It corresponds to the union type in SALAD
 */
template Union(TS...)
if (NoDuplicates!TS.length > 1)
{
    import std.meta : NoDuplicates;

    alias Union = SumType!(NoDuplicates!TS);
}

/// ditto
template Union(TS...)
if (NoDuplicates!TS.length == 1)
{
    alias Union = NoDuplicates!TS[0];
}

///
unittest
{
    import salad.primitives : Expression;

    static assert(is(Union!(None, string, Expression) == SumType!(None, string)));
    static assert(is(Union!(int, Expression) == SumType!(int, string)));
    static assert(is(Union!(string, Expression) == string));
}
