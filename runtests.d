#! /usr/bin/env rdmd

import std.process;
import std.stdio;
import std.file : remove, exists, read;
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
        string actual = cast(string)read(outlog);
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
    pid = spawnProcess(["dub", "run"],
                        std.stdio.stdin,
                        std.stdio.stdout,
                        std.stdio.stderr,
                        null, Config.none, "examples\\arraybase");
    if (wait(pid) != 0) {
        return 0;
    }
    pid = spawnProcess(["examples\\arraybase\\arraybase.exe"],
                        std.stdio.stdin,
                        outfile,
                        std.stdio.stderr,
                        null, Config.none, "examples\\arraybase");
    if (wait(pid) != 0) {
        return 0;
    } else {
        //string actual = cast(string)read(outlog);
        //auto expected = "" ~ newline;
        //if (cmp(actual, expected) != 0) {
        //    writeln("Unexpected output. See " ~ outlog ~ ".");
        //    writeln("EXPECTED OUTPUT:");
        //    writeln(expected);
        //    writeln("ACTUAL OUTPUT:");
        //    writeln(actual);
        //    return 0;
        //} else {
        //    remove(outlog);
        //}
    }
    writeln("=== runtests: completed example \"arraybase\"");


    return 1;
}