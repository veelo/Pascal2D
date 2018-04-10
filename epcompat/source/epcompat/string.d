/** 
Provides compatibility between D strings and the binary Extended Pascal formats 
of ShortString and String, for file i/o using the fromFile and toFile methods.

Special care is given to strings embedded in aggregate types such as structs and unions.

Authors: Bastiaan Veelo
Copyright: SARC B.V.
License: Boost.
*/

module epcompat.string;
import std.stdio : File;

//version = VerboseStdOut;
version (VerboseStdOut)
{
    import std.stdio;
}


/**
To be used as an attribute to string members of structs for specifying the file format.

Examples:
--------------------
Struct S
{
    @EPString(80) string str = "Hello";
}
--------------------
*/
struct EPString
{
    ushort capacity;
}


/**
To be used as an attribute to string members of structs for specifying the file format.

Examples:
--------------------
Struct S
{
    @EPShortString(80) string str = "Hello";
}
--------------------
*/
struct EPShortString
{
    ubyte capacity;
}


unittest // UDA
{
    @EPString(80) string str = "Hello";
    import std.traits;
    assert(hasUDA!(str, EPString));
}


/**
Writes a string to file in standard Extended Pascal string format.

This format consists of the string contents, truncated or padded with `'\0'` upto `capacity`, followed by
two bytes (`ushort`) stating the length of the padding.

Params:
    str         = The string to write.
    capacity    = The length of the written data section. If the length of `str` exceeds `capacity` then trunctation
                  will happen. The written string is padded with `'\0'` upto `capacity`.
    file        = The file to write to.

Throws: Exception (only in debug mode) if `str.length > capacity`.

See_Also: readEPString, writeAsEPShortString.
*/
void writeAsEPString(string str, ushort capacity, File file)
in {
    assert(capacity > 0);
}
body {
    import std.algorithm.mutation : copy;
    import std.range : repeat;
    import std.algorithm.comparison : min;
    import std.conv : to;
    immutable ushort pad = (str.length > capacity) ? 0 : to!ushort(capacity - str.length);
    str[0..min($, capacity)].copy(file.lockingBinaryWriter);
    '\0'.repeat(pad).copy(file.lockingBinaryWriter);
    (&pad)[0 .. 1].copy(file.lockingBinaryWriter);
    // I am not sure we want to throw here, because if it isn't catched somewhere then the program terminates.
    // We can also choose to truncate silently (I think Prospero does the same, if not compiled with range checking, which we don't).
    // Version debug for now.
    debug {
        import std.exception : enforce;
        enforce(str.length <= capacity, "String will be written to file truncated, discarding " ~ to!string(str.length - capacity) ~ " characters.");
    }
}


unittest    // writeAsEPString
{
    import std.stdio;
    File tmp = File.tmpfile();
    writeAsEPString("Jan Karel is een proleet", 80, tmp);
    tmp.flush;

    assert(tmp.size == 82);

    tmp.rewind;
    auto buf = tmp.rawRead(new char[cast(uint)(tmp.size)]);
    foreach (i, b; buf)
    {
        switch (i) {
            case 0:
                assert(b == 'J');
                break;
            case 1, 5:
                assert(b == 'a');
                break;
            case 2, 15:
                assert(b == 'n');
                break;
            case 3, 9, 12, 16:
                assert(b == ' ');
                break;
            case 4:
                assert(b == 'K');
                break;
            case 6:
                assert(b == 'r');
                break;
            case 7, 21, 22:
                assert(b == 'e');
                break;
            case 8, 20:
                assert(b == 'l');
                break;
            case 10:
                assert(b == 'i');
                break;
            case 11:
                assert(b == 's');
                break;
            case 13, 14:
                assert(b == 'e');
                break;
            case 17:
                assert(b == 'p');
                break;
            case 18:
                assert(b == 'r');
                break;
            case 19:
                assert(b == 'o');
                break;
            case 23:
                assert(b == 't');
                break;
            case 24: .. case 79:
                assert(b == '\0');
                break;
            case 80:
                assert(b == 56);    // 80 - 24
                break;
            case 81:
                assert(b == '\0');
                break;
            default:
                assert(false);
        }
    }
}

unittest    // truncation
{
    import std.stdio;
    import std.exception;
    File tmp = File.tmpfile();
    enum str = "Jan Karel is een proleet";
    debug
    {
        assertThrown(writeAsEPString(str, 10, tmp));  // <===
    } else {
        writeAsEPString(str, 10, tmp);
    }
    tmp.flush;

    assert(tmp.size == 12);

    tmp.rewind;
    auto buf = tmp.rawRead(new char[cast(uint)(tmp.size)]);
    foreach (i, b; buf)
    {
        switch (i) {
            case 0:
                assert(b == 'J');
                break;
            case 1, 5:
                assert(b == 'a');
                break;
            case 2:
                assert(b == 'n');
                break;
            case 3, 9:
                assert(b == ' ');
                break;
            case 4:
                assert(b == 'K');
                break;
            case 6:
                assert(b == 'r');
                break;
            case 7:
                assert(b == 'e');
                break;
            case 8:
                assert(b == 'l');
                break;
            case 10, 11:
                assert(b == '\0');
                break;
            default:
                assert(false);
        }
    }
}


/**
Reads a string in standard Extended Pascal string format.

This format consists of the string contents, truncated or padded with `'\0'` upto `capacity`, followed by
two bytes (`ushort`) stating the length of the padding.

Params:
    capacity    = The length of the data section to be read, excluding the two byte suffix.
    file        = The file to read from.

Returns: the string as read from file.

See_Also: writeAsEPString, readEPShortString.
*/
string readEPString(ushort capacity, File file)
{
    string str = file.rawRead(new char[capacity]).idup;
    auto l = file.rawRead(new ushort[1]);
    return str[0 .. capacity - l[0]];
}


///
unittest    // readEPString
{
    enum str = "Jan Karel is een proleet";
    import std.stdio;
    File tmp = File.tmpfile();
    writeAsEPString(str, 80, tmp);
    tmp.flush;

    assert(tmp.size == 82);

    tmp.rewind;
    assert(readEPString(80, tmp) == str);
}


/**
Writes a string to file in standard Pascal shortstring format.

In this format, the first written byte represents the length of the string. The string itself follows, truncated or
padded with `'\0'` upto `capacity`.

Params:
    str         = The string to write.
    capacity    = The length of the written data section. If the length of `str` exceeds `capacity` then trunctation
                  will happen. The written string is padded with `'\0'` upto `capacity`.
    file        = The file to write to.

Throws: Exception (only in debug mode) if `str.length > capacity`.

See_Also: readEPShortString, writeAsEPString.
*/
void writeAsEPShortString(string str, ubyte capacity, File file)
in {
    assert(capacity > 0);
}
body {
    import std.algorithm.mutation : copy;
    import std.range : repeat;
    import std.algorithm.comparison : min;
    import std.conv : to;
    immutable ubyte pad = (str.length > capacity) ? 0 : to!ubyte(capacity - str.length);
    immutable ubyte l = to!ubyte(capacity - pad);
    (&l)[0 .. 1].copy(file.lockingBinaryWriter);
    str[0..min($, capacity)].copy(file.lockingBinaryWriter);
    '\0'.repeat(pad).copy(file.lockingBinaryWriter);
    // I am not sure we want to throw here, because if it isn't catched somewhere then the program terminates.
    // We can also choose to truncate silently (I think Prospero does the same, if not compiled with range checking, which we don't).
    // Version debug for now.
    debug {
        import std.exception : enforce;
        enforce(str.length <= capacity, "String will be written to file truncated, discarding " ~ to!string(str.length - capacity) ~ " characters.");
    }
}


unittest  // writeAsEPShortString
{
    import std.stdio;
    File tmp = File.tmpfile();
    writeAsEPShortString("Jan Karel is een proleet", 80, tmp);
    tmp.flush;

    assert(tmp.size == 81);

    tmp.rewind;
    auto buf = tmp.rawRead(new char[cast(uint)(tmp.size)]);
    foreach (i, b; buf)
    {
        switch (i - 1) {
            case -1:
                assert(b == 24);    // length
                break;
            case 0:
                assert(b == 'J');
                break;
            case 1, 5:
                assert(b == 'a');
                break;
            case 2, 15:
                assert(b == 'n');
                break;
            case 3, 9, 12, 16:
                assert(b == ' ');
                break;
            case 4:
                assert(b == 'K');
                break;
            case 6:
                assert(b == 'r');
                break;
            case 7, 21, 22:
                assert(b == 'e');
                break;
            case 8, 20:
                assert(b == 'l');
                break;
            case 10:
                assert(b == 'i');
                break;
            case 11:
                assert(b == 's');
                break;
            case 13, 14:
                assert(b == 'e');
                break;
            case 17:
                assert(b == 'p');
                break;
            case 18:
                assert(b == 'r');
                break;
            case 19:
                assert(b == 'o');
                break;
            case 23:
                assert(b == 't');
                break;
            case 24: .. case 79:
                assert(b == '\0');
                break;
            default:
                assert(false);
        }
    }
}


/**
Reads a string in standard Pascal shortstring format.

In this format, the first written byte represents the length of the string. The string itself follows, truncated or
padded with `'\0'` upto `capacity`.

Params:
    capacity    = The length of the data section to be read, excluding the one byte prefix.
    file        = The file to read from.

Returns: the string as read from file.

See_Also: writeAsEPShortString, readEPString.
*/
string readEPShortString(ushort capacity, File file)
{
    auto l = file.rawRead(new ubyte[1]);
    return file.rawRead(new char[capacity])[0 .. l[0]].idup;
}


///
unittest    // readEPShortString
{
    enum str = "Jan Karel is een proleet";
    import std.stdio;
    File tmp = File.tmpfile();
    writeAsEPShortString(str, 80, tmp);
    tmp.flush;

    assert(tmp.size == 81);

    tmp.rewind;
    assert(readEPShortString(80, tmp) == str);
}


/**
Writes structs to file.

It looks at the members of the struct and selects the appropriate method:
$(UL
$(LI If the type of the member has a `toFile` member, it calls `toFile(f)` on it.)
$(LI If the member is itself a struct, it recurses by calling `toFile(f)` on it.)
$(LI If the member is a string, it checks that its format and capacity are defined
     with either an `@EPString(n)` UDA or `@EPShortString(n)` UDA, and then calls
     `writeAsEPString` or `writeAsEPShortString` respectively. A missing UDA is an error
     and reported at compile time.)
$(LI In all other cases the member is written using `std.stdio.File.rawWrite`.)
)

Params:
    s = The struct variable to write.
    f = The File to write to.

See_Also: fromFile.
*/
void toFile(S)(S s, File f) if (is(S == struct))
{
    import std.traits;
    import std.stdio;
    version (VerboseStdOut) { writeln("===== toFile ", __traits(identifier, S), " has fields ", [FieldNameTuple!S]); }
    static if (!hasIndirections!S)
    {
        version (VerboseStdOut) { write("toFile: ", __traits(identifier, S), " [No indirections: rawWrite] "); }
        f.rawWrite((&s)[0 .. 1]);
        version (VerboseStdOut) { writeln(s); }
    }
    else
        // FIXME handle anonimous unions https://forum.dlang.org/post/zwpctoccawmkwfoqkoyf@forum.dlang.org
        // Currently, all overlapping members are written to file.
        // http://192.168.36.202/SARCwiki/index.php/Fileformaat
        // Best is to not support unions, detect them at compile time.
        foreach(field; FieldNameTuple!S)
        {
            version (VerboseStdOut) { write("toFile: ", __traits(identifier, S), ".", field, " "); }
            static if (hasMember!(typeof(__traits(getMember, s, field)), "toFile"))  // TODO use isSomeFunction or isCallable
            {
                version (VerboseStdOut) { writeln("[calling function]"); pragma(msg, field); }
                __traits(getMember, s, field).toFile(f);
            }
            else static if (is(typeof(__traits(getMember, s, field)) == struct))
            {
                version (VerboseStdOut) { writeln("[recursing]"); }
                toFile!(typeof(__traits(getMember, s, field)))(__traits(getMember, s, field), f);    // Recursion.
            }
            else static if (is(typeof(__traits(getMember, s, field)) == string))
            {
                //toFile!(__traits(getMember, s, field))(f); // TODO. Difficult?
                static if (hasUDA!(__traits(getMember, s, field), EPString))
                {
                    version (VerboseStdOut) { writeln("[EPString]"); }
                    enum capacity  = getUDAs!(__traits(getMember, s, field), EPString)[0].capacity;
                    static assert(capacity > 0);
                    writeAsEPString(__traits(getMember, s, field), capacity, f);
                }
                else static if (hasUDA!(__traits(getMember, s, field), EPShortString))
                {
                    version (VerboseStdOut) { writeln("[EPShortString]"); }
                    enum capacity  = getUDAs!(__traits(getMember, s, field), EPShortString)[0].capacity;
                    static assert(capacity > 0);
                    writeAsEPShortString(__traits(getMember, s, field), capacity, f);
                }
                else static assert(false, `Need an @EPString(n) or @EPShortString(n) in front of ` ~ fullyQualifiedName!S ~ `.` ~ field );
            }
            else static if(!isFunction!(__traits(getMember, s, field))) {
                version (VerboseStdOut) { writeln("[rawWrite]"); }
                f.rawWrite((&__traits(getMember, s, field))[0 .. 1]);
            }
        }
}
/**
Where s is an alias to a string annotated with either an `@EPString(n)` UDA or `@EPShortString(n)` UDA,
writes s to file f in the appropriate Prospero formats.
*/
/* Seems we need an alias to get the UDA over. But how to constrain this to strings? */
void toFile(alias s)(File f) //if (/*isSomeString!(typeOf!(s))*/ isType!s)
{
    import std.traits;
    static if (hasUDA!(s, EPString))
    {
        version (VerboseStdOut) { writeln("[EPString]"); }
        enum capacity  = getUDAs!(s, EPString)[0].capacity;
        static assert(capacity > 0);
        writeAsEPString(s, capacity, f);
    }
    else static if (hasUDA!(s, EPShortString))
    {
        version (VerboseStdOut) { writeln("[EPShortString]"); }
        enum capacity  = getUDAs!(s, EPShortString)[0].capacity;
        static assert(capacity > 0);
        writeAsEPShortString(s, capacity, f);
    }
    else static assert(false, `Need an @EPString(n) or @EPShortString(n) in front of ` + s.stringof);
}


///
unittest    // Writing structs with strings.
{
    import std.stdio;

    struct MyType
    {
        ubyte b = 0xF;
        @EPShortString(5) string str = "Hello";
        // string error; // Must produce a compile time error. OK.
    }
    struct Record
    {
        int i;
        @EPString(10) string str = "World!";
        MyType n;
    }

    Record r;
    r.str = "Mars!";
    r.n.str = "Bye";

    File tmp = File.tmpfile();
    r.toFile(tmp);  // <===
    tmp.flush;

    assert(tmp.size == 4   // int i
                     + 10  // String
                     + 2   // String unused length
                     + 1   // ubyte
                     + 1   // ShortString length
                     + 5   // ShortString
                     );

    tmp.rewind;
    auto buf = tmp.rawRead(new ubyte[cast(uint)(tmp.size)]);

    foreach (i, b; buf)
    {
        final switch (i)
        {
            case 0, 1, 2, 3, 9, 10, 11, 12, 13, 15, 21, 22:
                assert(b == 0x0);
                break;
            case 4:
                assert(b == 'M');
                break;
            case 5:
                assert(b == 'a');
                break;
            case 6:
                assert(b == 'r');
                break;
            case 7:
                assert(b == 's');
                break;
            case 8:
                assert(b == '!');
                break;
            case 14:
                assert(b == 5); // unused length EP string
                break;
            case 16:
                assert(b == 0xF);
                break;
            case 17:
                assert(b == 3); // length of EP short string
                break;
            case 18:
                assert(b == 'B');
                break;
            case 19:
                assert(b == 'y');
                break;
            case 20:
                assert(b == 'e');
                break;
        }
    }
}
///
unittest //     Writing string variables to file.
{
    @EPShortString(5) string str1 = "Hello";
    @EPString(10) string str2 = "World!";

    File tmp = File.tmpfile();
    toFile!str1(tmp);
    toFile!str2(tmp);
    tmp.flush;

    assert(tmp.size == 1   // ShortString length
                     + 5   // ShortString
                     + 10  // String
                     + 2   // String unused length
                     );

    tmp.rewind;
    auto buf = tmp.rawRead(new ubyte[cast(uint)(tmp.size)]);

    foreach (i, b; buf)
    {
        final switch (i)
        {
            case 12, 13, 14, 15, 17:
                assert(b == 0x0);
                break;
            case 0:
                assert(b == 5); // length of EP short string
                break;
            case 1:
                assert(b == 'H');
                break;
            case 2:
                assert(b == 'e');
                break;
            case 3, 4, 9:
                assert(b == 'l');
                break;
            case 5:
                assert(b == 'o');
                break;
            case 6:
                assert(b == 'W');
                break;
            case 7:
                assert(b == 'o');
                break;
            case 8:
                assert(b == 'r');
                break;
            case 10:
                assert(b == 'd');
                break;
            case 11:
                assert(b == '!');
                break;
            case 16:
                assert(b == 4); // unused length EP string
                break;
        }
    }

}


/**
Reads structs from file.

It looks at the members of the struct and selects the appropriate method:
$(UL
$(LI If the type of the member has a `fromFile` member, it calls `fromFile(f)` on it.)
$(LI If the member is itself a struct, it recurses by calling `fromFile(f)` on it.)
$(LI If the member is a string, it checks that its format and capacity are defined
     with either an `@EPString(n)` UDA or `@EPShortString(n)` UDA, and then calls
     `readEPString` or `readEPShortString` respectively. A missing UDA is an error
     and reported at compile time.)
$(LI In all other cases the member is read using `std.stdio.File.rawRead`.)
)

Params:
    s = The struct variable to read.
    f = The File to read from.

See_Also: toFile.
*/
void fromFile(S)(ref S s, File f) if (is(S == struct))
{
    import std.traits;
    import std.range;
    version (VerboseStdOut) { writeln("===== fromFile ", __traits(identifier, S), " has fields ", [FieldNameTuple!S]); }
    static if (!hasIndirections!S)
    {
        version (VerboseStdOut) { write("fromFile: ", __traits(identifier, S), " [No indirections: rawRead] "); }
        f.rawRead((&s)[0 .. 1]);
        version (VerboseStdOut) { writeln(s); }
    }
    else
        foreach(field; FieldNameTuple!S)
        {
            version (VerboseStdOut) { write("fromFile: ", __traits(identifier, S), ".", field, " "); }
            static if (hasMember!(typeof(__traits(getMember, s, field)), "fromFile"))   // TODO use isSomeFunction or isCallable
            {
                version (VerboseStdOut) { writeln("[calling function]"); pragma(msg, field); }
                //version (VerboseStdOut) { writeln(__traits(identifier, __traits(getMember, s, field).fromFile(f))); }
                __traits(getMember, s, field).fromFile(f);
            }
            // FIXME https://forum.dlang.org/post/zwpctoccawmkwfoqkoyf@forum.dlang.org
            // http://192.168.36.202/SARCwiki/index.php/Fileformaat
            // Best is to not support unions, detect them at compile time.
/*            else static if (is(typeof(__traits(getMember, s, field)) == union))
            {
                static if (!hasIndirections!(typeof(field)))
                {
                    version (VerboseStdOut) { write("[Union without indirections: rawRead] "); }
                    f.rawRead((&__traits(getMember, s, field))[0 .. 1]);
                }
                else static assert(false, "Union " ~ __traits(identifier, S) ~ "." ~ field ~ " has indirections, it needs a fromFile member function.");
            }*/
            else static if (is(typeof(__traits(getMember, s, field)) == struct))
            {
                version (VerboseStdOut) { writeln("[recursing]"); }
                fromFile!(typeof(__traits(getMember, s, field)))(__traits(getMember, s, field), f);    // Recursion.
            }
            else static if (is(typeof(__traits(getMember, s, field)) == string))
            {
                // TODO use function.
                static if (hasUDA!(__traits(getMember, s, field), EPString))
                {
                    version (VerboseStdOut) { writeln("[EPString]"); }
                    enum capacity  = getUDAs!(__traits(getMember, s, field), EPString)[0].capacity;
                    static assert(capacity > 0);
                    __traits(getMember, s, field) = readEPString(capacity, f);
                }
                else static if (hasUDA!(__traits(getMember, s, field), EPShortString))
                {
                    version (VerboseStdOut) { writeln("[EPShortString]"); }
                    enum capacity  = getUDAs!(__traits(getMember, s, field), EPShortString)[0].capacity;
                    static assert(capacity > 0);
                    __traits(getMember, s, field) = readEPShortString(capacity, f);
                }
                else static assert(false, `Need an @EPString(n) or @EPShortString(n) in front of ` ~ fullyQualifiedName!S ~ `.` ~ field );
            }
            else static if(!isFunction!(__traits(getMember, s, field)))
            {
                version (VerboseStdOut) { writeln("[rawRead]"); }
                f.rawRead((&__traits(getMember, s, field))[0 .. 1]);
            }
            //version (VerboseStdOut) { writeln(" (", __traits(getMember, s, field), ")"); } // String80._payload is not visible from std.format
        }
}
/**
Where s is an alias to a string annotated with either an `@EPString(n)` UDA or `@EPShortString(n)` UDA,
reads s from file f in the appropriate Prospero formats.
*/
void fromFile(alias s)(File f) //if (/*isSomeString!(typeOf!(s))*/ isType!s)
{
    import std.stdio;
    import std.traits;
    static if (hasUDA!(s, EPString))
    {
        version (VerboseStdOut) { writeln("[EPString]"); }
        enum capacity  = getUDAs!(s, EPString)[0].capacity;
        static assert(capacity > 0);
        s = readEPString(capacity, f);
    }
    else static if (hasUDA!(s, EPShortString))
    {
        version (VerboseStdOut) { writeln("[EPShortString]");}
        enum capacity  = getUDAs!(s, EPShortString)[0].capacity;
        static assert(capacity > 0);
        s = readEPShortString(capacity, f);
    }
    else static assert(false, `Need an @EPString(n) or @EPShortString(n) in front of ` + s.stringof);
}


///
unittest    // Reading structs with strings.
{
    import std.stdio;

    struct MyType
    {
        ubyte b = 0xF;
        @EPShortString(5) string str = "Hello";
    }
    struct Record
    {
        int i;
        @EPString(10) string str = "World!";
        MyType n;
    }

    Record r;
    r.str = "Mars!";
    r.n.str = "Bye";

    File tmp = File.tmpfile();
    r.toFile(tmp);  // <===
    tmp.flush;
    tmp.rewind;

    Record rec;
    rec.fromFile(tmp);
    assert(rec == r);
}


///
unittest    // Reading unions without indirections.
{
    import std.stdio;

    enum soort_subcompartiment_type {rechthoek, extern_subcompartiment}

    struct subcompartiment_type
    {
        int start_opgebouwde_tank;
        struct {
            soort_subcompartiment_type soort_subcompartiment;
            union {
                struct {int one, two, three, four;};
                struct {double d_one, d_two;}
            }
        }
    }

    subcompartiment_type sc;
    sc.soort_subcompartiment = soort_subcompartiment_type.rechthoek;
    sc.one = 1;
    sc.three = 3;

    File tmp = File.tmpfile();
    sc.toFile(tmp);  // <===
    tmp.flush;
    tmp.rewind;

    subcompartiment_type sc2;
    sc2.fromFile(tmp);
    assert(sc2 == sc);
}


///
unittest    // Reading unions with indirections.
{
    import std.stdio;

    enum soort_subcompartiment_type {rechthoek, extern_subcompartiment}

    struct subcompartiment_type
    {
        int start_opgebouwde_tank;
        struct {
            soort_subcompartiment_type soort_subcompartiment;
            union {
                struct {int one, two, three, four;};
                struct {double d_one, d_two;
                        @EPString(80) string name;
                       }
            }
        }
    }

    subcompartiment_type sc;
    sc.soort_subcompartiment = soort_subcompartiment_type.rechthoek;
    sc.one = 1;
    sc.three = 3;
    sc.name = "John Doe";

    File tmp = File.tmpfile();
    sc.toFile(tmp);  // <===
    tmp.flush;
    tmp.rewind;

    subcompartiment_type sc2;
    sc2.fromFile(tmp);
    assert(sc2 == sc);
}


unittest    // Defining EP string types with given capacity.
{
    struct String80
    {
        @EPString(80) private string _payload;  // FIXME private means public whithin the same file.
        alias _payload this;
    }

    String80 str;
    str = "Jan Karel is een proleet";

    void testValueString(string s)
    {
        assert(s == "Jan Karel is een proleet");
        s = "CHANGED";  // No effect? Good.
    }

    void testReferenceString(ref string s)
    {
        assert(s == "Jan Karel is een proleet");
        s = "CHANGED";  // With effect! Good.
    }

    testValueString(str);
    assert(str == "Jan Karel is een proleet");

    testReferenceString(str);
    assert(str == "CHANGED");

    struct Record
    {
        String80 str;
    }

    Record rec;
    rec.str = "Jan, kerel!";

    File tmp = File.tmpfile();
    rec.toFile(tmp);  // <===
    tmp.flush;
    assert(tmp.size == 82);
    tmp.rewind;

    Record rec2;
    rec2.fromFile(tmp);
    assert(rec2 == rec);
    assert(rec2.str == "Jan, kerel!");
}


unittest    // Run-time capacity
{
    // Strings are always "dynamic".
    string sptr;
    // sptr = new string; // There is no equivalent to sptr = new String(200);
    sptr = "dynamische toekomst";
    assert(sptr == "dynamische toekomst");
    sptr.destroy;
    assert(sptr == "");
    sptr = null;
    assert(sptr == "");

    // Newing a string (slice of immutable char) makes no sense.
    // But it is possible to new an array of mutable char, although the above is preferred:
    char[] ptr = new char[200];
    ptr[0 .. 5] = 'a';
    assert(ptr.length == 200);
    assert(ptr[0 .. 5] == "aaaaa");
    assert(ptr[6] == char.init);
    ptr.destroy;
    assert(ptr.length == 0);
    assert(sptr == "");
    ptr = null;
    assert(ptr.length == 0);
    assert(sptr == "");
}

/**
Returns a string with any whitespace trimmed from str.
*/
string trim(string str)
{
    import std.string;
    return strip(fromStringz(str.ptr));
}
