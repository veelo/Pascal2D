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

enum days {sun, man, tues, weds, thurs, fri, sat};
alias sun = days.sun;
alias dname = string; // Variable length instead of fixed.

days d;

dname DayName(days fd)
{
    /*alias abbrevs = char[days][5 - 1];*/
    /*alias abbrevs = string[];*/
    /*alias abbrevs = char
    [5 - 1][days];*/
    alias abbrevs = string[days];
    immutable abbrevs DayNames = [sun: "Sun", days.man: "Man", days.tues: "Tues",
                                  days.weds: "Weds", days.thurs: "Thurs", days.fri: "Fri",
                                  days.sat: "Satur"];
    /*with (days) {
        immutable abbrevs DayNames = [sun: "Sun", man: "Man", tues: "Tues",
                                      weds: "Weds", thurs: "Thurs", fri: "Fri",
                                      sat: "Satur"];
    }*/
    return DayNames[fd] ~ "day";
}

void main()
{
    /*foreach (d; days.fri..days.man)
        writeln(DayName(d));*/
    for (d = days.fri; d >= days.man; d--)
        writeln(DayName(d));
}
