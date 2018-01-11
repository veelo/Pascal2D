/**
Implements intervals between two inclusive values of ordinal type, or `char` or
enum.
*/
module epcompat.interval;

/**
Defines an interval between two inclusive extremes on an explicitly supplied
base type.
*/
struct Interval(T)
{
    immutable T low, high;
    this (T low, T high)
    in {
        assert(low <= high);
    } do {
        this.low = low;
        this.high = high;
    }
    this (T single) {
        low = single;
        high = single;
    }
}

///
unittest
{
    auto i1 = Interval!byte(10, 20);
    auto i2 = Interval!byte(15);
    assert(i1.low == 10);
    assert(i1.high == 20);
    assert(i2.low == 15);
    assert(i2.high == 15);
}

///
unittest
{
    import epcompat.enumeration;
    enum Count {One, Two, Three, Four, Five, Six, Seven, Eight, Nine, Ten}
    mixin withEnum!Count;
    auto i1 = Interval!Count(Three, Six);
    auto i2 = Interval!Count(Eight, Ten);
    assert(i1.low == Three);
    assert(i1.high == Six);
    assert(i2.low == Eight);
    assert(i2.high == Ten);
}


/**
Constructor of an $(D Interval) on an implicitly derived base type.
*/
template interval(T)
{
    Interval!T interval(T a)
    {
        return Interval!T(a);
    }
    Interval!T interval(T a, T b)
    {
        return Interval!T(a, b);
    }
}

import std.traits;
enum isOrdinalType(T) = isIntegral!T || isSomeChar!T || isBoolean!T;

unittest
{
    static assert(isOrdinalType!int);
    static assert(isOrdinalType!uint);
    enum E {One, Two, Three, Four}
    static assert(isOrdinalType!E);
    static assert(isOrdinalType!bool);
    static assert(isOrdinalType!char);
    static assert(isOrdinalType!wchar);
    static assert(isOrdinalType!byte);
    static assert(isOrdinalType!ubyte);
    static assert(isOrdinalType!short);
    static assert(isOrdinalType!ushort);
    static assert(isOrdinalType!long);
    static assert(isOrdinalType!ulong);
    static assert(!isOrdinalType!(int[]));
    static assert(!isOrdinalType!float);
}

template isOrdinalInterval(T)
{
    static if (isArray!T)
    {
        //static if (T.length == 2)
        //{
            template tt(U : U[])
            {
                static if (isOrdinalType!U)
                    enum tt = true;
                else
                    enum tt = false;
            }

            enum isOrdinalInterval = tt!T;
        //}
        //    else enum isOrdinalInterval = false;
    }
    else enum isOrdinalInterval = false;
}

unittest
{
    int[2] a;
    static assert(isOrdinalInterval!(typeof(a)));
    static assert(isOrdinalInterval!(int[2]));
    //static assert(!isOrdinalInterval!(int[3]));
    static assert(!isOrdinalInterval!(int));
    enum E {One, Two, Three}
    E[2] aa = [E.One, E.Three];
    static assert(isOrdinalInterval!(typeof(aa)));
}

template areIntervalsCompatibleTo(U, V...)
{
    import std.range.primitives: ElementEncodingType;
    static if (V.length == 0)
    {
        enum areIntervalsCompatibleTo = true;
    }
    else static if (isOrdinalInterval!U)
    {
        static if (areIntervalsCompatibleTo!(ElementEncodingType!U, V))
        {
            enum areIntervalsCompatibleTo = true;
        }
        else
        {
            enum areIntervalsCompatibleTo = false;
        }
    }
    else
    {
        static if (isOrdinalInterval!(V[0]))
        {
            static if (is(ElementEncodingType!(V[0]) == U) && areIntervalsCompatibleTo!(U, V[1..$]))
            {
                enum areIntervalsCompatibleTo = true;
            }
            else
            {
                enum areIntervalsCompatibleTo = false;
            }
        }
        else
        {
            static if (is(V[0] == U) && areIntervalsCompatibleTo!(U, V[1..$]))
            {
                enum areIntervalsCompatibleTo = true;
            }
            else
            {
                enum areIntervalsCompatibleTo = false;
            }
        }
    }
}

unittest
{
    static assert(areIntervalsCompatibleTo!(int, int));
    static assert(areIntervalsCompatibleTo!(int, int[2]));
    static assert(areIntervalsCompatibleTo!(int[2], int));
    static assert(areIntervalsCompatibleTo!(int, int[2], int, int, int[2], int[2]));
    static assert(!areIntervalsCompatibleTo!(int, uint));
}

template compatibleIntervals(T...)
{
    static if (T.length == 0 || T.length == 1)
    {
        enum compatibleIntervals = true;
    }
    else static if (areIntervalsCompatibleTo!(T[0], T[1..$]))
    {
        enum compatibleIntervals = true;
    }
    else
    {
        enum compatibleIntervals = false;
    }
}

unittest
{
    static assert(compatibleIntervals!(int, int[2], int, int, int[2], int[2]));
    static assert(compatibleIntervals!(int, int, int[2], int, int, int[2], int[2]));
    static assert(compatibleIntervals!(int[2], int, int, int[2], int[2]));
    static assert(compatibleIntervals!(int[2], int[2], int, int, int[2], int[2]));
    bool f(Args...)(Args args)
    {
        static if (compatibleIntervals!Args)
            return true;
        else
            return false;
    }
    static assert(f(2, [3, 4], 5, 6, [7, 9]));
}
