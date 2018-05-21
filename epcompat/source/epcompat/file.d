/// Implements Prospero file i/o.
module epcompat.file;
private import std.stdio;

struct Bindable(T)
{
    alias ComponentType = T;
    string filename;
    File f;
}

// Local Prospero extension
bool openwrite(T)(ref Bindable!T f, string filename)
{
    import std.exception;
    try {
        f.filename = filename;
        // TODO if T is text, use "w+"
        f.f = File(filename, "wb+");
    }
    catch (ErrnoException e) {
        return false;
    }
    assert(f.f.isOpen);
    return true;
}

// Local Prospero extension
void close(T)(ref Bindable!T f)
{
    f.f.close;
}

//Built-in procedure
void write(T, S...)(Bindable!T f, S args)
{
    static foreach(arg; args)
        arg.toFile!T(f);
}
