module epcompat.array;

// Test with rdmd -m64 -main -unittest -debug -g source\epcompat\array.d



/**
A fixed-length array on type $(D_PARAM T) with an index that runs from
$(D_PARAM first) to $(D_PARAM last) inclusive. The bounds are supplied at
compile-time.
 */

align(1):
struct Array(T, ptrdiff_t first, ptrdiff_t last) {
  align(1):
    private T[last - first + 1] _payload;

    alias _payload this;

    /**
        Indexing operators yield or modify the value at a specified $(D_PARAM index).

        Precondition: `first <= index <= last`

        Complexity: $(BIGOH 1)
    */

    // Support e = arr[5];
    ref inout(T) opIndex(ptrdiff_t index) inout {
        assert(index >= first);
        assert(index <= last);
        return _payload[index - first];
    }

    /// ditto
    // Support arr[5] = e;
    void opIndexAssign(U : T)(auto ref U value, ptrdiff_t index) {
        assert(index >= first);
        assert(index <= last);
        _payload[index - first] = value;
    }

    /// ditto
    // Support foreach(e; arr).
    int opApply(scope int delegate(ref T) dg)
    {
        int result = 0;

        for (int i = 0; i < _payload.length; i++)
        {
            result = dg(_payload[i]);
            if (result)
                break;
        }
        return result;
    }

    /// ditto
    // Support foreach(i, e; arr).
    int opApply(scope int delegate(ptrdiff_t index, ref T) dg)
    {
        int result = 0;

        for (size_t i = 0; i < _payload.length; i++)
        {
            result = dg(i + first, _payload[i]);
            if (result)
                break;
        }
        return result;
    }

    import std.stdio;
    /**
    Write to binary file.
    */
    void toFile(File f)
    {
        f.rawWrite(_payload);
    }
    /// ditto
    void toFile(string fileName)
    {
        auto f = File(fileName, "wb");
        f.lock;
        toFile(f);
        f.unlock;
    }
}

///
unittest {
    Array!(int, -10, 10) arr;
    assert(arr.length == 21);
    assert(arr.sizeof == arr.length * int.sizeof);

    foreach (ref e; arr)
        e = 42;
    assert(arr[-10] == 42);
    assert(arr[0]   == 42);
    assert(arr[10]  == 42);

    import std.conv : to;
    foreach (i, ref e; arr)
        e = i.to!int;   // i is of type size_t.
    assert(arr[-10] == -10);
    assert(arr[0]   ==   0);
    assert(arr[5]   ==   5);
    assert(arr[10]  ==  10);

    arr[5] = 15;
    assert(arr[5]   == 15);
}



/**
A fixed-length array on type $(D_PARAM T) with an index that runs from
$(D_PARAM first) to $(D_PARAM last) inclusive. The bounds are supplied at
run-time.
 */
align(1):
struct RTArray(T) {
  align(1):
private:
    immutable ptrdiff_t first;
    immutable ptrdiff_t last;
    T[] _payload;
public:

    alias _payload this;

    @disable this();    // No default constructor;
    /**
    Construct an RTArray from first to last inclusive.
    */
    this(ptrdiff_t first, ptrdiff_t last)
    {
        this.first = first;
        this.last = last;
        _payload = new T[last - first + 1];
    }

    /**
        Indexing operators yield or modify the value at a specified $(D_PARAM index).

        Precondition: $(D first <= index <= last)

        Complexity: $(BIGOH 1)
    */
    // Support e = arr[5];
    ref inout(T) opIndex(ptrdiff_t index) inout {
        assert(index >= first);
        assert(index <= last);
        return _payload[index - first];
    }

    // Support arr[5] = e;
    void opIndexAssign(U : T)(auto ref U value, ptrdiff_t index) {
        assert(index >= first);
        assert(index <= last);
        _payload[index - first] = value;
    }

    // Support foreach(e; arr).
    int opApply(scope int delegate(ref T) dg)
    {
        int result = 0;

        for (int i = 0; i < _payload.length; i++)
        {
            result = dg(_payload[i]);
            if (result)
                break;
        }
        return result;
    }

    // Support foreach(i, e; arr).
    int opApply(scope int delegate(ptrdiff_t index, ref T) dg)
    {
        int result = 0;

        for (size_t i = 0; i < _payload.length; i++)
        {
            result = dg(i + first, _payload[i]);
            if (result)
                break;
        }
        return result;
    }

    // Write to binary file.
    import std.stdio;
    void toFile(File f)
    {
        f.rawWrite(_payload);
    }
    // Write to binary file.
    void toFile(string fileName)
    {
        auto f = File(fileName, "wb");
        f.lock;
        toFile(f);
        f.unlock;
    }
    // Read from binary file.
    void fromFile(File f)
    {
        f.rawRead(_payload);
    }
    // Read from binary file.
    void fromFile(string fileName)
    {
        auto f = File(fileName, "b");
        f.lock;
        fromFile(f);
        f.unlock;
    }
}

///
unittest {
    auto arr = RTArray!int(-10, 10);
    assert(arr.length == 21);
    import std.stdio;
    // writeln("arr.length * int.sizeof = ", arr.length * int.sizeof);
    // assert(arr.sizeof == arr.length * int.sizeof);  // 94 != 32 (in 64 bit) 94 != 16 (in 32 bit). FIXME

    foreach (ref e; arr)
        e = 42;
    assert(arr[-10] == 42);
    assert(arr[0]   == 42);
    assert(arr[10]  == 42);

    import std.conv : to;
    foreach (i, ref e; arr)
        e = i.to!int;   // i is of type size_t.
    assert(arr[-10] == -10);
    assert(arr[0]   ==   0);
    assert(arr[5]   ==   5);
    assert(arr[10]  ==  10);

    arr[5] = 15;
    assert(arr[5]   == 15);
}

///
unittest {  // schema array toFile/fromFile
    // type s(low,high:integer) = array[low..high] of integer;
    struct s
    {
        @disable this();
        this(int low, int high)
        {
            this.low = low;
            this.high = high;
            _payload = RTArray!int(low, high);
        }
        immutable int low, high;
      private:
        RTArray!int _payload;
        alias _payload this;
    }

    s t1 = s(-5, 5);
    for (int n = t1.low; n <= t1.high; n++)
        t1[n] = n * 3;
    import std.stdio;
    File tmp = File.tmpfile();
    t1.toFile(tmp);
    tmp.flush;

    assert(tmp.size == 11 * int.sizeof);

    tmp.rewind;
    auto buf = tmp.rawRead(new int[cast(uint)(tmp.size)]);
    foreach (i, b; buf)
        assert(b == (i - 5) * 3);

    tmp.rewind;
    s t2 = s(-5, 5);
    t2.fromFile(tmp);
    assert(t2 == t1);
}


/* Notitie aangaande alternatieve implementaties.
Een alternatief voor de hier gebruikte aanpak is gebaseerd op een truc uit Press et al
"Numerical Recipes in C":

  float b[4], *bb;
  bb = b - 1;

Door de pointer verschuiving is nu bb[1] tot bb[4] te gebruiken, wat equivalent is aan b[0] tot b[3].
De D-implementatie hiervan is nog terug te vinden op
http://192.168.36.202/trac/browser/zandbak/Pascal2017/D/epcompat/source/epcompat/array.d?rev=15430#L137

Echter, door analyse van de door Prospero gegenereerde assembly is gebleken dat Prospero achter de
schermen met 0-based arrays werkt, en het startpunt van de index aftrekt bij elke indexering, dus ten
koste van een kleine overhead. Hoewel pointer verschuiving die overhead elimineert, zijn er
meerdere nadelen:

    - Door een extra laag van indirectie is het helemaal niet zeker dat het efficienter is, de
      kans op cache-misses is groter.
    - Het is theoretisch mogelijk dat de verschoven pointer niet representeerbaar is omdat
      deze buiten (size_t.min, size_t.max] komt te liggen, wat fataal zou zijn.
    - Door een eigenschap van D wordt de inhoud van de array niet meegerekend in .sizeof().

Nog een ander alternatief is gebruik van D slices:

  float b[5]; // Loopt van 0..4, gebruikt worden 1..4.
  float _b[] = b[1..$]; // Deelt de elementen 1..4 van b, gebruikt voor addrof en opslag.

Hier wordt 1 element te veel gealloceerd, wat zou werken voor kleine positive offsets, maar je moet
oppassen dat je b gebruikt voor indiceren en _b voor opslag. Bij inlezen is ook weer conversie
nodig. Dit werkt niet voor negatieve offsets.

Daarom is gekozen om het zelfde te doen als Prospero: elke index corrigeren, zonder dat dat in de
code zichtbaar is.
*/
