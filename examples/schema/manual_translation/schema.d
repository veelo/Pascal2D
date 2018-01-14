// rdmd -I"..\..\..\epcompat\source" schema.d

/*

// http://www.gnu-pascal.de/gpc/Schema-Types.html
program Schema1Demo;
type
  PositiveInteger = 1 .. MaxInt;
  RealArray (n: Integer) = array [1 .. n] of Real;
  Matrix (n, m: PositiveInteger) = array [1 .. n, 1 .. m] of Integer;

var
  Foo: RealArray (42);
  Bar: Matrix(10, 20);

begin
  WriteLn (Foo.n)  { yields 42 }
end.

*/

import std.stdio;
import epcompat;

alias PositiveInteger = Ordinal!(1, int.max);

struct RealArray
{
    Array!double _payload;
    alias _payload this;
    immutable int n;
    @disable this();
    this(int n)
    {
        this.n = n;
        _payload = Array!double(1, n);
    }
}

//struct Matrix
//{
//    Array!(Array!PositiveInteger) _payload;
//    alias _payload this;
//    immutable PositiveInteger n, m;
//    @disable this();
//    this(PositiveInteger n, PositiveInteger m)
//    {
//        this.n = n;
//        this.m = m;
//        _payload = Array!(Array!PositiveInteger(1, n), 1, m); // TODO Can't do multi-dimansional arrays yet.
//    }
//}

auto foo = RealArray(42);

void main()
{
    writeln(foo.n);
    foo[1] = 10;
    writeln(foo[1]);
}
