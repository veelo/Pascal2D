/// Implements sets of ordinal values and ranges.
module epcompat.set;

/**
The Set type supports set operations. Sets can be instantiated with an explicitly
specified base type, in which case the range of values that the Set can contain
is limited by the base type. Sets can also be constructed with an implicitly
derived base type using the set() functions, where the underlying data is managed
dynamically and the range of values that the et can contain is only limited by
the available memory. Base types are ordinal types like the standard signed and
unsigned integer types of various sizes, but also char types, booleans and custom
enumerations.
*/
struct Set(T)
{
    import std.bitmanip;
    import std.traits;
    import std.conv;
    static bool staticArray()
    {
        return ((isUnsigned!T && T.max <= ushort.max) ||
               (T.min >= short.min && T.max <= short.max));
    }
    static if (staticArray)
    { // Cover the complete range of possible values in T.
        this (Interval!T[] ar...) { // Allows construction from any number of Intervals.
            init();
            foreach(i; ar) {
                foreach(b; i.low .. i.high+1)
                    bits[b - minval] = true;
            }
        }
    }
    else
    { // The range of possible values of T is too large to fit in the bitarray completely.
      // Manage bitarray dynamically.
        this (Interval!T[] ar...) { // Allows construction from any number of Intervals.
            import std.algorithm.comparison;
            int low = int.max;
            int high = int.min;
            foreach(i; ar) {
                low = min(low, i.low);
                high = max(high, i.high);
            }
            minval = to!T(low);
            bits.length = (high >= low) ? high + 1 - low : 0;
            foreach(i; ar) {
                foreach(b; i.low .. i.high+1)
                    bits[b - minval] = true;
            }
        }
    }
    /**
     Support for set operations.
     "+": set union
     "-": set difference
     "*": set intersection
     "%": set symmetric difference (A + B - A * B)
     
     See also https://dlang.org/phobos/std_algorithm_setops.html
              https://github.com/BBasile/iz/blob/master/import/iz/enumset.d
              https://dlang.org/library/std/typecons/flag.html
     */
    Set!T opBinary(string op)(Set!T rhs)
        if (op == "+" || op == "-" /*|| op == "&" || op == "^"*/)
    {
        Set!T compatibleOpBinary(const ref Set!T comp_l, const ref Set!T comp_r)
        in {
            assert(comp_l.bits.length == comp_r.bits.length);
            assert(comp_l.minval == comp_r.minval);
        } do {
            Set!T ret;
            ret.minval = comp_l.minval;
            ret.bits.length = comp_l.bits.length;
            static if (op == "+")
                ret.bits = comp_l.bits | comp_r.bits;
            else
                mixin("ret.bits = comp_l.bits " ~ op ~ " comp_r.bits;");
            return ret;
        }

        static if (staticArray)
        {
            return compatibleOpBinary(this, rhs);
        }
        else
        {
            if (minval == rhs.minval && bits.length == rhs.bits.length)
            {
                return compatibleOpBinary(this, rhs);
            }
            else
            {
                import std.algorithm.comparison;
                auto minminval = min(minval, rhs.minval);
                auto maxlength = max((bits.length + minval), (rhs.bits.length + rhs.minval)) - minminval;
                Set!T thisset, rhsset;
                thisset.bits = this.bits.dup;
                thisset.bits.length = maxlength;
                if (minminval < minval)
                    thisset.bits <<= (minval - minminval);
                thisset.minval = minminval;
                rhsset.bits = rhs.bits.dup;
                rhsset.bits.length = maxlength;
                if (minminval < rhs.minval)
                    rhsset.bits <<= (rhs.minval - minminval);
                rhsset.minval = minminval;
                return compatibleOpBinary(thisset, rhsset);
            }
        }
    }
    /// ditto (+= etc)
    Set!T opOpAssign(string op)(const Set!T rhs)
        if (op == "+" || op == "-" /*|| op == "&" || op == "^"*/)
    {
        Set!T compatibleOpOpAssign(const Set!T comp_r)
        in {
            assert(this.bits.length = comp_r.bits.length);
            assert(this.minval == comp_r.minval);
        } do {
            static if (op == "+")
                this.bits |= comp_r.bits;
            else
                mixin("this.bits " ~ op ~ "= comp_r.bits;");
            return this;
        }

        static if (staticArray)
        {
            return compatibleOpOpAssign(rhs);
        }
        else
        {
            if (minval == rhs.minval && bits.length == rhs.bits.length)
            {
                return compatibleOpOpAssign(rhs);
            }
            else
            {
                import std.algorithm.comparison;
                auto minminval = min(minval, rhs.minval);
                auto maxlength = max((bits.length + minval), (rhs.bits.length + rhs.minval)) - minminval;
                Set!T rhsset;
                this.bits.length = maxlength;
                if (minminval < minval)
                    this.bits <<= (minval - minminval);
                this.minval = minminval;
                rhsset.bits = rhs.bits.dup;
                rhsset.bits.length = maxlength;
                if (minminval < rhs.minval)
                    rhsset.bits <<= (rhs.minval - minminval);
                rhsset.minval = minminval;
                return compatibleOpOpAssign(rhsset);
            }
        }
    }

    /**
    Returns the cardinality of the set (the number of members). O(n).
    */
    size_t card()
    {
        size_t c = 0;
        foreach (b; bits)
            if (b)
                c++;
        return c;
    }
    /**
     Support for $(D foreach) loops over members of the $(D Set).
     */
    int opApply(scope int delegate(T) dg) const
    {
        int result;

        foreach (immutable i; bits.bitsSet)
        {
            result = dg(to!T(to!int(i) + minval));
            if (result)
                break;
        }
        return result;
    }
    /**
    Support for set membership testing using $(D in).
    */
    bool opBinaryRight(string op)(T t) if (op == "in")
    {
        if (t - minval < 0)
            return false;
        if (t - minval >= bits.length)
            return false;
        return bits[t - minval];
    }
private:
    BitArray bits;
    T minval = T.min;
    static if (staticArray)
    {
        void init()
        in {
            assert(bits.length == 0);
        } do {
            bits.length = to!int(T.max) + 1 - to!int(minval);
        }        
    }
}

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
    auto s1 = Set!byte(Interval!byte(10, 20));
    assert(5 !in s1);
    assert(20 in s1);
    byte a = 7;
    auto s2 = Set!byte(i1, i2, Interval!byte(a));
    assert(7 in s2);
}

///
unittest
{
    enum Count {One, Two, Three, Four, Five, Six, Seven, Eight, Nine, Ten}
    auto i1 = Interval!Count(Count.Three, Count.Six);
    auto i2 = Interval!Count(Count.Eight, Count.Ten);
    auto s1 = Set!Count(i1, i2);
    assert(s1.card == 7);
    assert(Count.Nine in s1);
    s1 -= Set!Count(i2);
    assert(s1.card == 4);
    assert(Count.Four in s1);
    assert(Count.Nine !in s1);
}


/**
This struct serves only a range-based interface for convenient construction
of Sets implemented on an explicitly supplied base type.
*/
struct SetFactory(T)
{
    @disable this();
    static Transfer opSlice(size_t pos)(T start, T end)
    {
        return Transfer(start, end);
    }
    static Set!T opIndex(...)
    {
        import core.vararg;
        Set!T s;
        s.init;
        for (int i = 0; i < _arguments.length; i++)
        {
            if (_arguments[i] == typeid(int))
            {
                s = s + Set!T(Interval!T(cast(T)va_arg!(int)(_argptr)));
            }
            else if (_arguments[i] == typeid(T))
            {
                s = s + Set!T(Interval!T(va_arg!(T)(_argptr)));
            }
            else if (_arguments[i] == typeid(Transfer))
            {
                Transfer t = va_arg!(Transfer)(_argptr);
                s = s + Set!T(Interval!T(t.start, t.end));
            }
            else {
                import std.stdio;
                writeln("!!!!!else ", _arguments[i]);
                assert(0);
            }
        }
        return s;
    }
private:
    struct Transfer
    {
        T start, end;
    }
}

///
unittest
{
    auto s0 = SetFactory!byte[1, 4..7, 10];

    enum Count {One, Two, Three, Four, Five, Six, Seven, Eight, Nine, Ten}
    auto s1 = SetFactory!Count[Count.Three, Count.Six .. Count.Nine];

    auto s2 = SetFactory!char['a'..'z'];
    assert('b' in s2);
    assert('A' !in s2);

    with (Count) {
        auto s3 = SetFactory!Count[Six, Two .. Four];
        assert(Two in s3);
        assert(Three in s3);
        assert(Four in s3);
        assert(Six in s3);
    }

    auto s5 = SetFactory!char[];    // Empty set.
    assert(s5.card() == 0);
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

/**
Constructor of a $(D Set) on an implicitly derived base type with a given
sequence of intervals.
*/
auto set(T)(Interval!T[] ar...)
{
    return Set!T(ar);
}
/**
Constructor of the empty set.
*/
Set!int set()   // Empty set.
{
    return Set!int();
}

///
unittest
{
    auto s1 = set(interval('a'), interval('e', 'g'));
    assert('f' in s1);
    auto s2 = set(interval(6), interval(10, 14));
    assert(11 in s2);
    auto s3 = set(interval(8, 12));
    auto s4 = s2 - s3;
    assert(11 !in s4);
    assert(6 in s4);
    assert(13 in s4);
    auto s5 = set();
    assert(s5.card == 0);
}

///
unittest
{
    assert(4 in set(interval(0, 10)));
    assert(4 !in set(interval(-3, 3)));
    assert(-4 !in set(interval(-3, 3)));
    enum Count {One, Two, Three, Four, Five, Six, Seven, Eight, Nine, Ten}
    auto i1 = interval(Count.Three, Count.Six);
    auto i2 = interval(Count.Eight, Count.Ten);
    auto s1 = set(i1, i2);
    assert(s1.card == 7);
    assert(Count.Nine in s1);
    assert(Count.Seven !in s1);
    s1 -= set(i2);
    assert(s1.card == 4);
    assert(Count.Four in s1);
    assert(Count.Nine !in s1);
}

/**
Constructor of $(D Set)s on an implicitly derived base type. It cannot support
the range-like notation for $(D Interval)s like $(D SetFactory) does, but offers
a 2-element array notation for intervals.
*/
auto set(Args...)(Args args) if (compatibleIntervals!Args)
{
    static assert(Args.length > 0); // set() is already implemented.
    static if (isOrdinalInterval!(Args[0]))
        auto s = set(interval(args[0][0], args[0][1]));
    else
        auto s = set(interval(args[0]));
    static foreach (i, a; args[1..$])
    {
        static if (isOrdinalInterval!(Args[i+1]))
            s += set(interval(a[0], a[1]));
        else
            s += set(interval(a));
    }
    return s;
}

///
unittest
{
    int i = 5;
    auto s1 = set(1);
    auto s2 = set(1, [1,2], i);
    assert(2 in s2);
    enum Count {One, Two, Three, Four, Five}
    auto s3 = set([Count.Three, Count.Five]);
    s3 += set(Count.One);
    assert(Count.Four in s3);
    assert(Count.One in s3);
    assert(Count.Two !in s3);
}

private:

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

template arrayElementType(W : W[])
{
    alias arrayElementType = W;
}

unittest
{
    static assert (is(arrayElementType!(int[]) == int));
}

template areIntervalsCompatibleTo(U, V...)
{
    static if (V.length == 0)
    {
        enum areIntervalsCompatibleTo = true;
    }
    else static if (isOrdinalInterval!U)
    {
        static if (areIntervalsCompatibleTo!(arrayElementType!U, V))
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
            static if (is(arrayElementType!(V[0]) == U) && areIntervalsCompatibleTo!(U, V[1..$]))
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
