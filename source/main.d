import std.stdio;
import std.file;
import epparser;
import p2d;

int main(string[] args)
{
    if (args.length != 2)
    {
        writeln("Usage: ", args[0], " <source.pas>");
        return 1;
    }

    auto parsed = EP(readText(args[1]));
    writeln(toD(parsed));

    return 0;
}
