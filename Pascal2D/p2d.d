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

    static string escapeString(const string s)
    {
        import std.array;
        return s.replace("\"", "\\\""); // TODO consider translate()
    }

    static string contents(const ref ParseTree p)
    {
        return p.input[p.begin .. p.end];
    }

    static bool childExists(const ref ParseTree p, const string name)
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

        import std.typecons: Tuple, tuple;
        Tuple!(string, "name", string, "matches")[] readIdentifierList(const ref ParseTree p /* EP.IdentifierList */)
        {
            assert(p.name == "EP.IdentifierList");
            Tuple!(string, "name", string, "matches") identifiers[];
            string name, matches;
            foreach (child; p.children)
            {
                switch (child.name)
                {
                    case "EP.Identifier":
                        name = contents(child);
                        matches ~= name;
                        break;
                    case "EP.COMMA":
                        identifiers ~= tuple!("name", "matches")(name, matches);
                        matches = "";
                        break;
                    default:
                        matches ~= parseDefaults(child);
                }
            }
            identifiers ~= tuple!("name", "matches")(name, matches);
            return identifiers;
        }

        string parseTypeDefinition(const ref ParseTree p /* EP.TypeDefinition */)
        {
            string typeDefName;
            string aliases;

            string parseEnumDef(const ref ParseTree p)
            {
                switch(p.name)
                {
                    case "EP.IdentifierList":
                        string result;
                        foreach(i, ident; readIdentifierList(p))
                        {
                            if (i > 0)
                                result ~= ",";
                            result ~= ident.matches;
                            assert(typeDefName.length > 0);
                            aliases ~= "\nalias " ~ ident.name ~ " = " ~ typeDefName ~ "." ~ ident.name ~ ";\t// EPcompat: In D, enum values are prepended with their enum type.";
                        }
                        return result;
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
            // subsequent uses, to convert from the case-insensitive Pascal to case-sensitive D.

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

        string parseFormalParameterList(const ref ParseTree p /* EP.FormalParameterList */)
        {
            bool first = true;
            string parseFormalParameterSection(const ref ParseTree p /* EP.FormalParameterSection */)
            {
                string parseValueParameterSpecification(const ref ParseTree p /* EP.ValueParameterSpecification */)
                {
                    bool isConst = false;
                    Tuple!(string, "name", string, "matches") identifiers[];
                    string result, theType, comments;
                    foreach (child; p.children)
                    {
                        switch (child.name)
                        {
                            case "EP.PROTECTED":
                                isConst = true;
                                break;
                            case "EP.IdentifierList":
                                identifiers = readIdentifierList(child);
                                break;
                            case "EP.ParameterForm":
                                theType = contents(child);
                                break;
                            default:
                                comments ~= parseDefaults(child);
                        }
                    }
                    foreach(i, ident; identifiers)
                    {
                        if (i > 0)
                            result ~= ", ";
                        if (isConst)
                            result ~= "const ";
                        result ~= theType ~ " " ~ ident.matches;
                    }
                    result ~= comments;
                    return result;
                }

                string result;
                if (!first)
                    result ~= ", ";
                first = false;
                switch (p.children[0].name) // FormalParameterSection has 1 child.
                {
                    case "EP.ValueParameterSpecification":
                        result ~= parseValueParameterSpecification(p.children[0]);
                        break;
                    default:
                        writeln("TODO: " ~ p.children[0].name);
                }
                return result;
            }

            string result;
            foreach (child; p.children)
                if (child.name == "EP.FormalParameterSection")
                    result ~= parseFormalParameterSection(child);
                else
                    result ~= parseDefaults(child);
            return "(" ~ result ~ ")";
        }

        string parseFunctionDeclaration(const ref ParseTree p /* EP.FunctionDeclaration */)
        in
        {
            assert(p.name == "EP.FunctionDeclaration");
        }
        body
        {
            string result, name, resultVariable, resultType, block;

            string parseHeading(const ref ParseTree p /* EP.FunctionHeading */)
            {
                string comments, heading;
                foreach(child; p.children[1..$])
                {
                    switch (child.name)
                    {
                        case "EP.Identifier":
                            name = contents(child);
                            heading = name;
                            break;
                        case "EP.FormalParameterList":
                            heading ~= parseFormalParameterList(child);
                            break;
                        case "EP.ResultVariableSpecification":
                            resultVariable = contents(child);
                            break;
                        case "EP.ResultType":
                            resultType = contents(child);
                            heading = resultType ~ " " ~ heading;
                            break;
                        default:
                            comments ~= parseDefaults(child);
                    }
                }
                heading ~= comments;
                return heading;
            }

            foreach (child; p.children)
            {
                switch (child.name)
                {
                    case "EP.FunctionHeading":
                        result ~= parseHeading(child);
                        break;
                    case "EP.FunctionBlock":
                        result ~= parseChildren(child);
                        break;
                    case "EP._":
                        result ~= parseDefaults(child);
                        break;
                    default:
                        writeln(child.name ~ " is unhandled in parseFunctionDeclaration.");
                }
            }

            return result;
        }

        string parseMainProgramBlock(const ref ParseTree p /* EP.MainProgramBlock || EP.Block */)
        {
            string result;
            foreach (child; p.children)
                switch (child.name)
                {
                    case "EP.Block":
                        result ~= parseMainProgramBlock(child);
                        break;
                    case "EP.StatementPart":
                        result ~= "int main(string[] args)\n" ~ parseChildren(child);
                        break;
                    default:
                        result ~= parseToCode(child);
                }
            return result;
        }

        import std.range.primitives;
        import std.string : translate;
        switch(p.name)
        {
            case "EP":
                return parseToCode(p.children[0]);	// The grammar result has only one child: the start rule's parse tree.
            // These just recurse into their children.
            case "EP.BNVCompileUnit",
                 "EP.Program", "EP.ProgramBlock", "EP.Block", "EP.ProgramComponent",
                 "EP.MainProgramDeclaration", "EP.ProgramHeading",
                 "EP.StatementSequence", "EP.Statement", "EP.ProcedureStatement",
                 "EP.WriteParameter",
                 "EP.Expression", "EP.SimpleExpression", "EP.Term", "EP.Factor",
                 "EP.Primary", "EP.UnsignedConstant", "EP.StringElement",
                 "EP.TypeDefinitionPart", "EP.VariableDeclarationPart",
                 "EP.ProcedureAndFunctionDeclarationPart",
                 "EP.StatementPart":
                return parseChildren(p);
            case "EP.MainProgramBlock":
                return parseMainProgramBlock(p);
            case "EP.BNVProgramName":
                programName = contents(p);
                writeln("LOG: detected program name: ", programName);
                return "";
            case "EP.ProgramParameterList":
                imports.insert("std.stdio");
                return "";
            case "EP.TypeDefinition":
                return parseTypeDefinition(p);
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
            case "EP.FunctionDeclaration":
                return parseFunctionDeclaration(p);

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

void main(string[] args)
{
    writeln("Hello D's \"World\"!");
}
`));
}
