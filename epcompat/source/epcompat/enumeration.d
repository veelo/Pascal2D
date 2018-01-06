module epcompat.enumeration;

/**
Aliases the members of the enum to bring them into scope so that they
can be used without surrounding them with a $(D with) statement or
prepending them with the enum name.
*/
mixin template withEnum(E) if (is(E == enum))
{
    import std.traits;
    import std.format;
    static foreach (i, member; EnumMembers!E)
        mixin(format!"alias %s = %s.%s;\n"(member, __traits(identifier, E), member));
}

///
unittest
{
    enum Enumer {One, Four = 4, Five, Six, Ten = 10}
    mixin withEnum!(Enumer);
    static assert(One == Enumer.One);
    static assert(Four == Enumer.Four);
}