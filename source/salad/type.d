module salad.type;

import sumtype;

struct None{}

alias Optional(T) = SumType!(None, T);

enum isOptional(T) = isSumType!T &&
    T.Types.length == 2 &&
    is(T.Types[0] == None);

// test for Optional!T
@safe unittest
{
    import std.exception : assertNotThrown;
    auto op = Optional!int.init;
    assertNotThrown(op.tryMatch!((None _) {}));
}

alias Either(TS...) = SumType!TS;

enum isEither(T) = isSumType!T &&
    (T.Types.length > 2 || !is(T.Types[0] == None));

@safe unittest
{
    static assert(isEither!(SumType!(int, string, double)));
    static assert(!isEither!(Optional!int));
    static assert(isEither!(SumType!(int, string)));
    static assert(isEither!(SumType!(None, int, string)));
    static assert(!isEither!string);
}
