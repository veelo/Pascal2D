import std.stdio;
import epparser;
import p2d;

void test(const string pascal)
{
    auto parseTree = EP(pascal);
    writeln("PASCAL:");
    writeln(pascal);
    writeln("\nD:");
    writeln(toD(parseTree));
    import pegged.tohtml;
    toHTML(parseTree, "test");
}

void main()
{
    version (tracer)
    {
        traceNothing;
    }
    /*test(
`program MyTest(output);

(* Say
   hello. }
begin
    writeln( {Inline comment.} 'Hello D''s \"World\"!' {Inline comment.} {One more {thing.});
    writeln;      {Empty}
    writeln('');  {Empty string}
    writeln('a'); {String}
end.
`);*/

    assert(EP.TypeDefinitionPart(
`TYPE  abbrevs = ARRAY [days] OF
        PACKED ARRAY [1..5] OF char;`
    ).successful);
    assert(EP.ConstantDefinitionPart(
`CONST DayNames = abbrevs
        [ sun: 'Sun'; mon: 'Mon'; tues: 'Tues';
          weds: 'Weds'; thurs: 'Thurs'; fri: 'Fri';
          sat: 'Satur' ];
`).successful);
    assert(EP.ProcedureAndFunctionDeclarationPart(
`FUNCTION DayName (fd: days): dname;
    { Elements of the array constant DayNames can be
      selected with a variable index }
  TYPE  abbrevs = ARRAY [days] OF
          PACKED ARRAY [1..5] OF char;
  CONST DayNames = abbrevs
    [ sun: 'Sun'; mon: 'Mon'; tues: 'Tues';
      weds: 'Weds'; thurs: 'Thurs'; fri: 'Fri';
      sat: 'Satur' ];
  BEGIN
    DayName := trim(DayNames[fd]) + 'day';
  END {DayName};
`).successful);

    version (tracer)
    {
        import std.experimental.logger;
        sharedLog = new TraceLogger("TraceLog.txt");
        bool cond (string ruleName)
        {
            static startTrace = false;
            if (ruleName.startsWith("EP.FunctionDeclaration"))
                startTrace = true;
            return startTrace && ruleName.startsWith("EP");
        }
        /*setTraceConditionFunction(&cond);*/
        setTraceConditionFunction(ruleName => ruleName.startsWith("EP"));
        /*traceAll;*/
    }

    test("PROGRAM arrayc (output);

  { Extended Pascal examples http://ideone.com/YXpi4n }
  { Array constant & constant access }

TYPE  days = (sun,mon {First work day},tues,weds,thurs,fri, {Party!} sat);
      dname = string(8);

VAR   d: days;

FUNCTION DayName (fd: days): dname;
    { Elements of the array constant DayNames can be
      selected with a variable index }
  TYPE  abbrevs = ARRAY [days] OF
          PACKED ARRAY [1..5] OF char;
  CONST DayNames = abbrevs
    [ sun: 'Sun'; mon: 'Mon'; tues: 'Tues';
      weds: 'Weds'; thurs: 'Thurs'; fri: 'Fri';
      sat: 'Satur' ];
  BEGIN
    DayName := trim(DayNames[fd]) + 'day';
  END {DayName};

BEGIN {program}
  FOR d := fri DOWNTO mon DO writeln(DayName(d));
END.

  { Generated output is:
    Friday
    Thursday
    Wedsday
    Tuesday
    Monday
  }
    ");

/*
    enum code = "
PROGRAM arrayc (output);

  { Extended Pascal examples http://ideone.com/YXpi4n }
  { Array constant & constant access }

TYPE  days = (sun,mon {First work day},tues,weds,thurs,fri,sat);
      dname = string(8);

VAR   d: days;

FUNCTION DayName (fd: days): dname;

    { Elements of the array constant DayNames can be
      selected with a variable index }
  TYPE  abbrevs = ARRAY [days] OF
          PACKED ARRAY [1..5] OF char;
  CONST DayNames = abbrevs
    [ sun: 'Sun'; mon: 'Mon'; tues: 'Tues';
      weds: 'Weds'; thurs: 'Thurs'; fri: 'Fri';
      sat: 'Satur' ];
  BEGIN
    DayName := trim(DayNames[fd]) + 'day';
  END {DayName};

BEGIN {program}
  FOR d := fri DOWNTO mon DO writeln(DayName(d));
END.

  { Generated output is:
    Friday
    Thursday
    Wedsday
    Tuesday
    Monday
  }
    ";

    void bench()
    {
        EP(code);
    }

    import std.datetime;
    import std.conv : to;
    auto r = benchmark!(bench)(1);
    writeln("Duration ", to!Duration(r[0]));
    */
}


unittest {
    string input =
`program MyTest(output);

begin
    writeln('Hello D''s "World"!');
end.
`;
    /+
    import std.experimental.logger;
    sharedLog = new FileLogger("TraceLog.txt", LogLevel.all);
    bool cond (string ruleName)
    {
        return (ruleName.startsWith("EP") && !ruleName.startsWith("EP.Literal"));
    }
    setTraceConditionFunction(&cond);
    /*setTraceConditionFunction(ruleName => ruleName.startsWith("EP"));*/
    /*traceAll;*/
    +/
    auto parsed = EP(input);
    assert(equal(toD(parsed),
`import std.stdio;

int main(string[] args)
{
    writeln("Hello D's \"World\"!");
}
`));
}
