/**
Provides type compatibility with, and comparable features to Extended Pascal.

This is the library that translated Pascal sources rely on. It also provides
features that can be of value in hand-written D code. The epcompat library is
supplied as a dub sub package so it supports that use case.

$(TABLE
    $(TR $(TH Module) $(TH Purpose))

    $(TR $(TD $(LINK2 epcompat/array, array)) $(TD
        Fixed length array types that can start at any index.
    ))
    $(TR $(TD $(LINK2 epcompat/enumeration, enumeration)) $(TD
        Brings the members of an enumeration into scope, as if the following
        code would be in a `with` block.
    ))
    $(TR $(TD $(LINK2 epcompat/file, file)) $(TD
        Implementation of EP file i/o and local Prospero extensions.
    ))
    $(TR $(TD $(LINK2 epcompat/initial, initial)) $(TD
        Changes `.init` to a custom default value.
    ))
    $(TR $(TD $(LINK2 epcompat/ordinal, ordinal)) $(TD
        An integral type with specific inclusive bounds.
    ))
    $(TR $(TD $(LINK2 epcompat/set, set)) $(TD
        Sets of integral values, ordinal values or members of enumerations.
    ))
    $(TR $(TD $(LINK2 epcompat/string, string)) $(TD
        String types that are compatible with native D `string`, and binary
        compatible with Prospero Extended Pascal strings in file i/o. 
    ))
)
*/

module epcompat;

public import epcompat.array;
public import epcompat.string;
public import epcompat.file;
public import epcompat.initial;
public import epcompat.interval;
public import epcompat.set;
public import epcompat.ordinal;
version(ddox) {} else // https://issues.dlang.org/show_bug.cgi?id=18211
public import epcompat.enumeration;
