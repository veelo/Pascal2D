program arraybase(input,output);

type t = array[2..20] of integer;
var a : t;
    n : integer;
    {f : bindable file of t;}

begin
  for n := 2 to 20 do
    a[n] := n;
  writeln('Size of t in bytes is ',sizeof(a):1);
  {if openwrite(f,'array.dat') then
    begin
      write(f,a);
      close(f);
    end;}
end.

