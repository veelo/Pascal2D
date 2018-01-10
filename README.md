# Pascal2D
_This is very much work in progress._

**Pascal2D** is a transcompiler that translates [ISO 10206 Extended Pascal](http://pascal-central.com/docs/iso10206.pdf) to D,
with support for some non-standard [Prospero](https://web.archive.org/web/20131023234615/http://www.prosperosoftware.com:80/)
extensions.

## Current status
The [parser](source/epgrammar.d) in *Pascal2D* is almost comlete and should be able to parse most Extended Pascal programs. The
[translator](source/p2d.d) is very incomplete and can only translate a small set of simple programs, see below. The goal is to
translate around 500 kloc of proprietary source code, see the
[DConf 2017 talk](https://www.youtube.com/watch?v=t5y9dVMdI7I&list=PL3jwVPmk_PRxo23yyoc0Ip_cP3-rCm7eB&index=21) (with
[continuation](https://www.youtube.com/watch?v=3ugQ1FFGkLY)) for some background information.

As soon as I reach that goal, my interest in Pascal2D is likely to drop dramatically, and that might happen before it covers
100% of the language perfectly. We may consider rewriting some of the Pascal code if that removes difficulties in
translation to speed up the process. Nevertheless, I am likely to accept contributions by others and I wouldn't rule out
complete coverage eventually or even support for other Pascal dialects.

## Getting started
Given you have installed a [D compiler](https://dlang.org/download.html) and a [git client](https://git-scm.com/downloads/),
clone the Pascal2D repository and do
```
cd Pascal2D
dub build
```
This will produce the `pascal2d` executable that can then be used to translate a Pascal source file, say `example.pas`, like
so:
```
pascal2d example.pas > example.d
```

## Example
In [examples/hello/source/hello.pas](examples/hello/source/hello.pas) you will find this Pascal source:
```Pascal
program hello(output);

begin
    writeln('Hello D''s "World"!');
end.
```
Calling dub in that directory
```
cd examples\hello
dub
```
will translate, compile and run that file. The translated file ends up in `examples\hello\source\hello.d` and looks like this:
```D
import std.stdio;

// Program name: hello
void main(string[] args)
{
    writeln("Hello D's \"World\"!");
}

```
