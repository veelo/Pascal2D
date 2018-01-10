import std.stdio;
import std.file;
import epparser;
import p2d;

version(unittest) {
    // Unit tests are run without arguments, don't error.
    void main(){}; 
} else

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
