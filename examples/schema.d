/*

// http://www.gnu-pascal.de/gpc/Schema-Types.html
program Schema1Demo;
type
  PositiveInteger = 1 .. MaxInt;
  RealArray (n: Integer) = array [1 .. n] of Real;
  Matrix (n, m: PositiveInteger) = array [1 .. n, 1 .. m] of Integer;

var
  Foo: RealArray (42);

begin
  WriteLn (Foo.n)  { yields 42 }
end.

*/

import std.stdio;

alias double Real;

/+
template RealArray(int discVal)
{
    immutable int n = discVal;
    //Real[n + 1];
}

RealArray!(42) foo; // foo is an array of 42 Reals. // Error: RealArray!42 is used as a type

void main()
{
    writeln(foo.n);
}
+/

struct RealArray
{
private:
    Real payload[];
public:
    int n;
    this(int discriminant)
    {
        n = discriminant;
        payload.length = n;
    }
}

auto foo = RealArray(42);

void main()
{
    writeln(foo.n);
}

/*
template schema(SchemaName, alias DiscriminantValue)
{

}
*/
