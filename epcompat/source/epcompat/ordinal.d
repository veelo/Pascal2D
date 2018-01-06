module epcompat.ordinal;

import std.traits;

/**
    An integral type with specified inclusive bounds.

    No bounds checking is implemented.

    See also bound.d in https://code.dlang.org/packages/phobos-next
*/
// TODO Normaal gesproken zijn EP ranges altijd integers, maar wanneer deel van een packed record wordt
// het kleinst mogelijke base type gezocht. Dat wordt hier geimplementeerd. Maar voor 1-1 compatibiliteit
// is het nodig dat configureerbaar te maken. Helaas heb ik geen trait gevonden voor het opvragen van align().
struct Ordinal(alias lower, alias upper) if (isIntegral!(typeof(lower)) &&
                                             isIntegral!(typeof(upper)))
{
    static assert(lower < upper);
    enum imp = r" _payload;
        alias _payload this;
        static auto min()
        {
            return lower;
        }
        static auto max()
        {
            return upper;
        }
        ";
    
    static if (lower < 0)
    {
        static if (lower >= byte.min && upper <= byte.max)
        {
            mixin("byte" ~ imp);
        }
        else static if (lower >= short.min && upper <= short.max)
        {
            mixin("short" ~ imp);
        }
        else static if (lower >= int.min && upper <= int.max)
        {
            mixin("int" ~ imp);
        }
        else
        {
            static assert(lower >= long.min && upper <= long.max);
            mixin("long" ~ imp);
        }
    }
    else
    {
        static if (upper <= ubyte.max)
        {
            mixin("ubyte" ~ imp);
        }
        else static if (upper <= ushort.max)
        {
            mixin("ushort" ~ imp);
        }
        else static if (upper <= uint.max)
        {
            mixin("uint" ~ imp);
        }
        else
        {
            static assert(upper <= ulong.max);
            mixin("ulong" ~ imp);
        }
    }
}

unittest
{
    Ordinal!(-3, 6) o1;
    assert(o1.min == -3);
    assert(o1.max == 6);
    assert(o1.sizeof == 1);
    static assert(!__traits(compiles, Ordinal!(33, 6)));    // 33 > 6
    Ordinal!(10, 300) o2;
    assert(o2.min == 10);
    assert(o2.max == 300);
    assert(o2.sizeof == 2);
    static assert(Ordinal!(0, 255).sizeof == 1);
    static assert(Ordinal!(-1, 255).sizeof == 2);
    static assert(Ordinal!(-1, 127).sizeof == 1);
    static assert(Ordinal!(-1, 70000).sizeof == 4);
}
