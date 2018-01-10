// rdmd -I"..\..\..\epcompat\source" arrayc.d

/*
PROGRAM arrayc (output);

TYPE  days = (sun,mon,tues,weds,thurs,fri,sat);
      dname = string(8);

VAR   d: days;

FUNCTION DayName (fd: days): dname;
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
*/

import std.stdio;
import epcompat;

enum days {sun, mon, tues, weds, thurs, fri, sat};
mixin withEnum!days;

@EPString(8) alias dname = string; // Variable length instead of fixed.

days d;

dname DayName(days fd)
{
    /*alias abbrevs = char[days][5 - 1];*/
    /*alias abbrevs = string[];*/
    /*alias abbrevs = char
    [5 - 1][days];*/
    alias abbrevs = string[days];
    immutable abbrevs DayNames = [sun: "Sun", mon: "Mon", tues: "Tues",
                                  weds: "Weds", thurs: "Thurs", fri: "Fri",
                                  sat: "Satur"];
    return DayNames[fd] ~ "day";
}

void main()
{
    //foreach_reverse (d; mon..sat)
    //    writeln(DayName(d));
    for (d = fri; d >= mon; d--)
        writeln(DayName(d));
}
