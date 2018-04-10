module epcompat.initial;

// Test with rdmd -m64 -main -unittest -debug -g source\epcompat\initial.d

/**
Creates a type that is mostly $(PARAM T), only with a different initial value of $(PARAM val).

It differs from https://dlang.org/library/std/typecons/typedef.html in that `typedef` takes care to
create a new type that does not implicitly convert to the base type, whereas we try to stay
compatible with the base type.
*/
struct Initial(T, T val)
{
    T _payload = val;
    alias _payload this;

    this(T v)
    {
        _payload = v;
    }

    // https://dlang.org/blog/2017/02/13/a-new-import-idiom/
    private template from(string moduleName)
    {
      mixin("import from = " ~ moduleName ~ ";");
    }

    void toString(scope void delegate(const(char)[]) sink, from!"std.format".FormatSpec!char fmt)
    {
        import std.array : appender;
        import std.format : formatValue;
        auto w = appender!string();
        formatValue(w, _payload, fmt);
        sink(w.data);
    }
}

///
unittest
{
    alias int1 = Initial!(int, 1);
    static assert(int1.init == 1); // typeof(int1.init) == int1
    static assert(int1.sizeof == int.sizeof);

    int1 i;
    assert(i == 1);
    int1 ii = 2;
    assert(ii == 2);
    assert(ii.init == 1);
    assert(int1.init == 1);

    void f(int val)
    {
        assert(val == 1);
    }
    f(i);

    int i0;
    assert(i0 == 0);
    i = i0;
    assert(i == 0);
    assert(i.init == 1);
    i0 = ii;
    assert(i0 == 2);
    assert(i0.init == 0);

    import std.string;
    assert(format("%6d", ii) == "     2");
}
