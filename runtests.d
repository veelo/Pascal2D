#! /usr/bin/env rdmd

import std.process;
import std.stdio;
import std.file : remove, exists, readText;
import std.algorithm;
import std.ascii;

enum outlog = "output.log";

int main()
{
    if (exists(outlog)) {
        writeln("\"" ~ outlog ~ "\" still exists. Aborting.");
        return 0;
    }


    writeln("=== runtests: starting \"dub test\"");
    auto pid = spawnProcess(["dub", "test"],
                            std.stdio.stdin,
                            std.stdio.stdout,
                            std.stdio.stderr);
    if (wait(pid) != 0) {
        return 0;
    }
    writeln("=== runtests: completed \"dub test\"");


    writeln("=== runtests: starting \"dub test pascal2d:epcompat\"");
    pid = spawnProcess(["dub", "test", "pascal2d:epcompat"],
                            std.stdio.stdin,
                            std.stdio.stdout,
                            std.stdio.stderr);
    if (wait(pid) != 0) {
        return 0;
    }
    writeln("=== runtests: completed \"dub test pascal2d:epcompat\"");


    writeln("=== runtests: testing example \"hello\"");
    pid = spawnProcess(["dub", "build"],
                        std.stdio.stdin,
                        std.stdio.stdout,
                        std.stdio.stderr,
                        null, Config.none, "examples\\hello");
    if (wait(pid) != 0) {
        return 0;
    }
    auto outfile = File(outlog, "w");
    pid = spawnProcess(["examples\\hello\\hello.exe"],
                        std.stdio.stdin,
                        outfile,
                        std.stdio.stderr,
                        null, Config.none, "examples\\hello");
    if (wait(pid) != 0) {
        return 0;
    } else {
        string actual = readText(outlog);
        auto expected = "Hello D's \"World\"!" ~ newline;
        if (cmp(actual, expected) != 0) {
            writeln("Unexpected output. See " ~ outlog ~ ".");
            writeln("EXPECTED OUTPUT:");
            writeln(expected);
            writeln("ACTUAL OUTPUT:");
            writeln(actual);
            return 0;
        } else {
            remove(outlog);
        }
    }
    writeln("=== runtests: completed example \"hello\"");


    writeln("=== runtests: testing example \"arraybase\"");
    pid = spawnProcess(["dub", "build"],
                        std.stdio.stdin,
                        std.stdio.stdout,
                        std.stdio.stderr,
                        null, Config.none, "examples\\arraybase");
    if (wait(pid) != 0) {
        return 0;
    }
    outfile = File(outlog, "w");
    pid = spawnProcess(["examples\\arraybase\\arraybase.exe"],
                        std.stdio.stdin,
                        outfile,
                        std.stdio.stderr,
                        null, Config.none, "examples\\arraybase");
    if (wait(pid) != 0) {
        return 0;
    } else {
        string actual = readText(outlog);
        auto expected = "Size of t in bytes is 76" ~ newline;
        if (cmp(actual, expected) != 0) {
            writeln("Unexpected output. See " ~ outlog ~ ".");
            writeln("EXPECTED OUTPUT:");
            writeln(expected);
            writeln("ACTUAL OUTPUT:");
            writeln(actual);
            return 0;
        } else {
            remove(outlog);
        }
        enum arraydat = "examples\\arraybase\\array.dat";
        import std.file;
        assert(getSize(arraydat) == 76);
        assert(cmp(cast(int[])read(arraydat),
                   [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]) == 0);
    }
    writeln("=== runtests: completed example \"arraybase\"");


    return 1;
}