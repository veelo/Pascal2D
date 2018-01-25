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

    private mixin template implementation(T)
    {
        private T _payload = init;
        static T init()
        {
            return lower;
        }
        static T min()
        {
            return lower;
        }
        static T max()
        {
            return upper;
        }
        this(long from)
        {
            opAssign(from);
        }
        T opAssign(long from)
        {
            import std.conv;
            return _payload = to!T(from);
        }
        import std.typecons;
        mixin Proxy!_payload;
        alias _payload this;
    }
 
    static if (lower < 0)
    {
        static if (lower >= byte.min && upper <= byte.max)
        {
            mixin implementation!byte;
        }
        else static if (lower >= short.min && upper <= short.max)
        {
            mixin implementation!short;
        }
        else static if (lower >= int.min && upper <= int.max)
        {
            mixin implementation!int;
        }
        else
        {
            static assert(lower >= long.min && upper <= long.max);
            mixin implementation!long;
        }
    }
    else
    {
        static if (upper <= ubyte.max)
        {
            mixin implementation!ubyte;
        }
        else static if (upper <= ushort.max)
        {
            mixin implementation!ushort;
        }
        else static if (upper <= uint.max)
        {
            mixin implementation!uint;
        }
        else
        {
            static assert(upper <= ulong.max);
            mixin implementation!ulong;
        }
    }
}

unittest
{
    Ordinal!(-3, 10) o1;
    assert(o1.min == -3);
    assert(o1.max == 10);
    assert(o1.sizeof == 1);

    static assert(!__traits(compiles, Ordinal!(33, 6)));    // 33 > 6
    static assert(Ordinal!(0, 255).sizeof == 1);
    static assert(Ordinal!(-1, 255).sizeof == 2);
    static assert(Ordinal!(-1, 127).sizeof == 1);
    static assert(Ordinal!(-1, 70000).sizeof == 4);

    alias O2 = Ordinal!(10, 300);
    static assert(O2.min == 10);
    static assert(O2.max == 300);
    static assert(O2.init == 10);
    O2 o2;
    assert(o2 == 10);
    assert(o2.min == 10);
    assert(o2.max == 300);
    assert(o2.sizeof == 2);

    o2 = 20;
    o2 = 300;

    import std.conv;
    ushort us = to!ushort(o2 + 10);
    assert(us == 310);
    o2 = us - 10;
    assert(o2 == 300);

    int i = o2;
    assert(i == 300);
    o2 = i - 10;

    o1 = 10;
    o2 = o1;
    assert(o2 == 10);
    o2++;
    assert(o2 == 11);

    void intfun(int) {}
    void o2fun(O2 arg) {}
    intfun(o2);
    o2fun(o2);
    o2fun(O2(o1));
    o2fun(O2(10L));
    // http://forum.dlang.org/post/mailman.1513.1310326809.14074.digitalmars-d-learn@puremagic.com
    //o2fun(o1);  // No implicit argument conversion, sadly.
    //o2fun(10);  // No implicit argument conversion, sadly.

    // TODO bounds check:
    //us = 9;
    //o2fun(O2(us));   // FIXME Should be illegal.
    //o2fun(O2(9));    // FIXME Should be illegal.
    //import std.exception;
    //assertThrown(o2 = 9);
    //assertThrown(o2 = 301);
    //o1 = 10;
    //assertThrown(o1++);
}
