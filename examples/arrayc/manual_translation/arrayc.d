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
    /* Idiomatic D, using associate array.
    alias abbrevs = string[days];
    immutable abbrevs DayNames = [sun: "Sun", mon: "Mon", tues: "Tues",
                                  weds: "Weds", thurs: "Thurs", fri: "Fri",
                                  sat: "Satur"];
    */
    alias abbrevs = StaticArray!(StaticArray!(char, 1, 5), days);
    // http://forum.dlang.org/post/wbxaefufzeytvjkjfpyv@forum.dlang.org
    // https://dlang.org/phobos/std_exception.html#assumeUnique
    immutable abbrevs DayNames = {
      abbrevs ret;
      foreach(i, ref e; ret)
        final switch (i) {
          case sun:
            e = "Sun";
            break;
          case mon:
            e = "Mon";
            break;
          case tues:
            e = "Tues";
            break;
          case weds:
            e = "Weds";
            break;
          case thurs:
            e = "Thurs";
            break;
          case fri:
            e = "Fri";
            break;
          case sat:
            e = "Satur";
            break;
        }
      return cast(immutable(abbrevs)) ret;
    }();
    return trim(DayNames[fd]) ~ "day";
}

void main()
{
    //foreach_reverse (d; mon..sat)
    //    writeln(DayName(d));
    for (d = fri; d >= mon; d--)
        writeln(DayName(d));
}
