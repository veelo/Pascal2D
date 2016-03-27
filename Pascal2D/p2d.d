import std.stdio;

import epparser;

unittest // Extended Pascal comments
{
    assert(EP.TrailingComment("(* Mixed. }\n").successful, "Mixed opening and closing comment notations.");
    assert(EP.InlineComment("(* Mixed. }").successful, "Mixed opening and closing comment notations, inline.");
    assert(EP.InlineComment("{Multi word comment.}").successful, "Multi-word comment.");
    assert(EP.InlineComment("{Multi line
	                   comment. With \n
                       \"escapes\"}").successful, "Multi-line comment.");

    // The EP standard does not allow nested comments.
    assert(!EP("(* Here comes a {nested} comment.}").successful, "Comments cannot nest.");
}


string toD(const ref ParseTree p)
{
    import std.container;
    auto imports = new RedBlackTree!string;

    string programName;

    string escapeString(const string s)
    {
        import std.array;
        return s.replace("\"", "\\\""); // TODO consider translate()
    }

    string contents(const ref ParseTree p)
    {
        return p.input[p.begin .. p.end];
    }

    bool childExists(const ref ParseTree p, const string name)
    {
        foreach(child; p.children) {
            if(equal(child.name, name) || childExists(child, name))
                return true;
        }
        return false;
    }

	string parseToCode(const ref ParseTree p)
	{
        string parseChildren(const ref ParseTree p, string delegate(const ref ParseTree) parser = &parseToCode)
        {
            string result;
            foreach(child; p.children)  // child is a ParseTree.
                result ~= parser(child);
            return result;
        }

        string parseDefaults(const ref ParseTree p)
        {
            import std.algorithm.searching;
            switch(p.name)
            {
                case "EP._", "EP.Comment":
                    return parseChildren(p, &parseDefaults);
                case "EP.TrailingComment", "EP.InlineComment":
                    assert(p.children.length == 3);
                    assert(equal(p.children[1].name, "EP.CommentContent"));
                    auto contentString = contents(p.children[1]);
                    if(equal(p.name, "EP.TrailingComment") && !canFind(contentString, "\n"))
                        return "//" ~ contentString;    // End-of-line comment.
                    return "/*" ~ contentString ~ "*/"; // Ordinary comment.
                    // These translate verbally
                case "EP.Spacing":
                    return contents(p);
                case "fail":
                    writeln("PARSE ERROR: " ~ p.toString);
                    assert(0, "Parse unsuccessful");
                default:
                    if(startsWith(p.name, "Literal") || startsWith(p.name, "CILiteral"))   // Disregard keywords etc.
                    {
                        writeln("LOG: Found literal ", contents(p));
                        return "";
                    }
                    //assert(0, p.name ~ " is unhandled:\n" ~ p.toString());
                    writeln(p.name ~ " is unhandled.");
                    return "";
            }
        }

        string parseTypeDefinition(const ref ParseTree p /* EP.TypeDefinition */)
        {
            string typeDefName;

            bool firstIdentifier = true;
            string aliases;

            string parseEnumDef(const ref ParseTree p)
            {
                switch(p.name)
                {
                    case "EP.IdentifierList":
                        return parseChildren(p, &parseEnumDef);
                    case "EP.Identifier":
                        string result = firstIdentifier ? "" : ", ";
                        firstIdentifier = false;
                        assert(typeDefName.length > 0);
                        aliases ~= "\nalias " ~ contents(p) ~ " = " ~ typeDefName ~ "." ~ contents(p) ~ ";\t// EPcompat: In D, enum values are prepended with their enum type.";
                        return result ~ contents(p);
                    default:
                        return parseDefaults(p);
                }
            }

            string parseTypeDefChild(const ref ParseTree p)
            {
                import std.algorithm.searching;
                switch(p.name)
                {
                    case "EP.TypeDenoter":
                        assert(typeDefName.length > 0);
                        if (p.children.canFind!("a.name == b")("EP.NewType"))
                            return parseChildren(p, &parseTypeDefChild) ~ ";";
                        return "alias " ~ typeDefName ~ " = " ~ parseChildren(p, &parseTypeDefChild) ~ ";";
                    case "EP.NewType", "EP.NewOrdinalType":
                        return parseChildren(p, &parseTypeDefChild);
                    case "EP.BNVTypeDefName":
                        typeDefName = contents(p);
                        return "";
                    case "EP.EnumeratedType":
                        assert(typeDefName.length > 0);
                        return "enum " ~ typeDefName ~ " {" ~ parseChildren(p, &parseEnumDef) ~ "}";
                    case "EP.DiscriminatedSchema":
                        if (contents(p).startsWith("string"))
                            return "string";
                        goto default;
                    default:
                        // writeln("parseTypeDefChild does parseDefaults on ", p);
                        return parseDefaults(p);
                }
            }

            string result = parseChildren(p, &parseTypeDefChild);
            return result ~ aliases;
        }

        string parseVariableDeclaration(const ref ParseTree p /* EP.VariableDeclaration */)
        {
            // TODO We could keep a list of declared variables and correct any deviations of case in
            // subsequent uses.

            import std.range.primitives;
            string initialValue, type;
            string[] variables;

            foreach (child; p.children)
            {
                switch (child.name)
                {
                case "EP.TypeDenoter":
                    foreach (grandchild; child.children)
                    {
                        if (grandchild.name == "EP.InitialStateSpecifier")
                            initialValue ~= parseToCode(grandchild);
                        else
                            type ~= parseToCode(grandchild);
                    }
                    break;
                case "EP.IdentifierList":
                    foreach (grandchild; child.children)
                        variables ~= parseToCode(grandchild);
                    break;
                default:
                    // Nothing
                }
            }

            if (!initialValue.empty)
                foreach (i, var; variables)
                    variables[i] = var ~ "(" ~ initialValue ~ ")";

            string result = type ~ " " ~ variables[0];
            foreach (var; variables[1..$])
                result ~= ", " ~ var;
            return result ~ ";";
        }

        import std.range.primitives;
        import std.string : translate;
        switch(p.name)
        {
            case "EP":
                return parseToCode(p.children[0]);	// The grammar result has only one child: the start rule's parse tree.
            // These just recurse into their children.
            case "EP.BNVCompileUnit",
                 "EP.Program", "EP.ProgramBlock", "EP.MainProgramBlock", "EP.Block", "EP.ProgramComponent",
                 "EP.MainProgramDeclaration", "EP.ProgramHeading",
                 "EP.StatementSequence", "EP.Statement", "EP.ProcedureStatement",
                 "EP.WriteParameter",
                 "EP.Expression", "EP.SimpleExpression", "EP.Term", "EP.Factor",
                 "EP.Primary", "EP.UnsignedConstant", "EP.StringElement",
                 "EP.TypeDefinitionPart", "EP.VariableDeclarationPart",
                 "EP.ProcedureAndFunctionDeclarationPart":
                return parseChildren(p);

            case "EP.BNVProgramName":
                programName = contents(p);
                writeln("LOG: detected program name: ", programName);
                return "";
            case "EP.ProgramParameterList":
                imports.insert("std.stdio");
                return "";

            case "EP.TypeDefinition":
                return parseTypeDefinition(p);

            case "EP.StatementPart":
                return "void main(string[] args)\n" ~ parseChildren(p);

            case "EP.CompoundStatement":
                return "{" ~ parseChildren(p) ~ "}";
            case "EP.SimpleStatement":
                if (p.children[0].name == "EP.EmptyStatement")
                    return "";
                return parseChildren(p) ~ ";";
            case "EP.CharacterString":
                string result;
                foreach(child; p.children)
                    result ~= parseToCode(child);
                return "\"" ~ escapeString(result) ~ "\"";
            case "EP.ApostropheImage":
                return "'";
            case "EP.WritelnParameterList":
                return "(" ~ parseChildren(p) ~ ")";
            case "EP.DiscriminatedSchema":
                {
                    if (contents(p.children[0]) == "string")
                        // Built in schema.
                        return "immutable(char)[" ~ contents(p.children[1]) ~ "] /* Fixed-length, consider using \"string\" instead. */";
                    else
                    {
                        assert(0, "generic " ~ p.name ~ " is unhandled.");
                        return "";
                    }
                }
            case "EP.VariableDeclaration":
                return parseVariableDeclaration(p);
            case "EP.TypeName":
                return contents(p);

            // These translate verbally
            case "EP.ProcedureName", "EP.StringCharacter", "EP.Identifier":
                return contents(p);

            // These are ignored
            case "EP.PROGRAM", "EP.BEGIN", "EP.END", "EP.EmptyStatement":
                return "";

            // Required procedures
            case "EP.WRITELN":
                return "writeln";

            default:
                return parseDefaults(p);
        }
    }

    auto code = parseToCode(p);

    string importDeclaration;
    foreach(imp; imports[]) {
        importDeclaration ~= "import " ~ imp ~ ";\n";
    }

	return importDeclaration ~ "\n" ~ code;
}

void test(const string pascal)
{
    auto parseTree = EP(pascal);
    writeln("___________________________");
    writeln(parseTree);
    writeln("PASCAL:");
    writeln(pascal);
    writeln("\nD:");
    writeln(toD(parseTree));
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

    test("
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

void main(string[] args)
{
    writeln("Hello D's \"World\"!");
}
`));
}
