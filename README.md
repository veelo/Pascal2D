[![Build Status](https://travis-ci.org/veelo/Pascal2D.svg?branch=master)](https://travis-ci.org/veelo/Pascal2D)

# Pascal2D

**Pascal2D** is a transcompiler that translates [ISO 10206 Extended Pascal](http://pascal-central.com/docs/iso10206.pdf) (EP) to D,
with support for some non-standard [Prospero](https://web.archive.org/web/20131023234615/http://www.prosperosoftware.com:80/)
extensions.

The goal is to translate around 500 kloc of proprietary source code, see the
[DConf 2017 talk](https://www.youtube.com/watch?v=t5y9dVMdI7I&list=PL3jwVPmk_PRxo23yyoc0Ip_cP3-rCm7eB&index=21) (with
[continuation](https://www.youtube.com/watch?v=3ugQ1FFGkLY)) for some background information. You can also read
[how an engineering company chose tomigrate to D](https://dlang.org/blog/2018/06/20/how-an-engineering-company-chose-to-migrate-to-d/).

## Current status

What you see here is the initial development of *Pascal2D*, developed in open source prior to the decision of
[SARC](https://www.sarc.nl) to go ahead with translation of all its EP code. _For the time being, SARC management has decided to fund
further development off-line. If you have any interest in this project, for any reason, please
[do get in contact](https://www.sarc.nl/contact/), we'd love to hear from you_. We are very reasonable people and I'm sure we can work
something out.

## Getting started
Given you have installed a [D compiler](https://dlang.org/download.html) and a [git client](https://git-scm.com/downloads/),
clone the Pascal2D repository and do
```shell
cd Pascal2D
dub build
```
This will produce the `pascal2d` executable that can then be used to translate a Pascal source file, say `example.pas`, like
so:
```
pascal2d example.pas > example.d
```
Optionally, the syntax tree of the Pascal file can be produced in HTML format by passing the `--syntax_tree` or `-s` argument.


## Minimal example
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

## Compatibility library *epcompat*
Translated sources depend on the [epcompat sub package](https://github.com/veelo/Pascal2D/tree/master/epcompat), which is a library that provides type compatibility with and implements features of Extended Pascal. Some of its modules can be of value in hand written D code as wel, the [*epcompat* API](https://veelo.github.io/Pascal2D/) is available online.

## Array example
In Extended Pascal, arrays can start at any index value. The example [examples/arraybase](examples/arraybase) shows how this is translated, including writing such array's to binary file. This is the Extended Pascal source:
```Pascal
program arraybase(input,output);

type t = array[2..20] of integer;
var a : t;
    n : integer;
    f : bindable file of t;

begin
  for n := 2 to 20 do
    a[n] := n;
  writeln('Size of t in bytes is ',sizeof(a):1);
  if openwrite(f,'array.dat') then
    begin
      write(f,a);
      close(f);
    end;
end.
```
Calling `dub` in that directory translates this into the following working D code, using [dfmt](https://code.dlang.org/packages/dfmt) to fixup formatting:
```D
import epcompat;
import std.stdio;

// Program name: arraybase
alias t = StaticArray!(int, 2, 20);

t a;
int n;
Bindable!t f;

void main(string[] args)
{
    for (n = 2; n <= 20; n++)
        a[n] = n;
    writeln("Size of t in bytes is ", a.sizeof);
    if (openwrite(f, "array.dat"))
    {
        epcompat.write(f, a);
        close(f);
    }
}
```

## Running tests
The following script will run unit tests, transcompile examples, run them and check their output to make sure they work as expected:
```shell
rdmd runtests.d
```
