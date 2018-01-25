// rdmd -I"..\..\..\epcompat\source" schema.d

/*

// http://www.gnu-pascal.de/gpc/Schema-Types.html
program Schema1Demo;
type
  PositiveInteger = 1 .. MaxInt;
  RealArray (n: Integer) = array [1 .. n] of Real;
  Matrix (n, m: PositiveInteger) = array [1 .. n, 1 .. m] of Integer;

var
  foo: RealArray (42);
  mat: Matrix(4, 7);
  i: PositiveInteger;
  n, m : integer;

begin
  WriteLn (foo.n)  { yields 42 }
  foo[1] := 10;
  writeln(foo[1]);

  i := 0;
  for n := 1 to mat.n do
    for m := 1 to mat.m do
      begin
        mat[n][m] := i;
        i := i + 1;
      end;

  for n := 1 to mat.n do
    begin
      for m := 1 to mat.m do
        write(mat[n][m]);
      writeln;
    end;
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

struct Matrix
{
    Array!(Array!int) _payload;
    alias _payload this;
    immutable PositiveInteger n, m;
    @disable this();
    this(PositiveInteger n, PositiveInteger m)
    {
        this.n = n;
        this.m = m;
        _payload.resize(1, n);
        foreach(ref row; _payload)
            row.resize(1, m);
    }
}

auto foo = RealArray(42);
auto mat = Matrix(PositiveInteger(4), PositiveInteger(7));

void main()
{
    import std.format;

    writeln(foo.n);
    foo[1] = 10;
    writeln(foo[1]);

    PositiveInteger i = 0;
    for (int n = 1; n <= mat.n; n++)
      for (int m = 1; m <= mat.m; m++)
        mat[n][m] = i++;
    for (int n = 1; n <= mat.n; n++) {
      for (int m = 1; m <= mat.m; m++)
        write(format!"%6d"(mat[n][m]));
      writeln;
    }
}
