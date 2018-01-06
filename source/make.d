int main(string[] opts)
in {assert(opts.length == 2);} do
{
    enum source1 = "epgrammar.d";
    enum source2 = "generate.d";
    enum target  = "epparser.d";

    import std.file;
    import std.datetime.systime;
    if (timeLastModified(source1) >= timeLastModified(target, SysTime.min) ||
        timeLastModified(source2) >= timeLastModified(target, SysTime.min) ||
        timeLastModified(__FILE__) >= timeLastModified(target, SysTime.min))
    {
        import std.process;
        import std.stdio;
        auto args = ["rdmd", "-I" ~ opts[1], "generate.d"];
        foreach (arg; args)
            write(arg, " ");
        writeln;
        auto dmd = execute(args);
        if (dmd.status != 0)
        {
            writeln("Compilation failed:\n", dmd.output);
            return 1;
        }
    }
    return 0;
}