import std.stdio;
import std.file;
import std.getopt;
import std.string: chomp;
import pegged.tohtml;
import epparser;
import p2d;

version(unittest) {
    // Unit tests are run without arguments, don't error.
    void main(){}; 
} else

int main(string[] args)
{
    bool syntax_tree = false;
    GetoptResult helpInforation;
    try {
        helpInforation = getopt(
            args,
            "syntax_tree|s", "Generate an HTML file with the syntax tree in <source.html>.", &syntax_tree
            );
    }
    catch (std.getopt.GetOptException e) {
        writeln(args[0] ~ ": " ~ e.msg ~ ". See " ~ args[0] ~ " --help");
        return 1;
    }

    if (helpInforation.helpWanted ||
        args.length != 2)
    {
        defaultGetoptPrinter("Transcompile Extended Pascal into D.\n" ~
            "Usage: " ~ args[0] ~ " [-s][-h] <source.pas> > <source.d>",
            helpInforation.options);
        return 1;
    }

    auto parsed = EP(readText(args[1]));
    if (syntax_tree)
        toHTML(parsed, args[1].chomp(".pas")~".html");
    writeln(toD(parsed));

    return 0;
}
