import std.stdio;

import epparser;

unittest // Extended Pascal comments
{
    assert(EP.Comment("(* Mixed. }\n").successful, "Mixed opening and closing comment notations.");
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
        return s.replace("\"", "\\\"");
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
                case "EP._":
                    return parseChildren(p, &parseDefaults);
                case "EP.Comment", "EP.InlineComment":
                    assert(p.children.length == 3);
                    assert(equal(p.children[1].name, "EP.CommentContent"));
                    auto contentString = contents(p.children[1]);
                    if(equal(p.name, "EP.Comment") && !canFind(contentString, "\n"))
                        return "//" ~ contentString;    // End-of-line comment.
                    return "/*" ~ contentString ~ "*/"; // Ordinary comment.
                    // These translate verbally
                case "EP.WhiteSpace":
                    return contents(p);
                default:
                    if(startsWith(p.name, "Literal") || startsWith(p.name, "CILiteral"))   // Disregard keywords etc.
                        writeln("LOG: Found literal ", contents(p));
                        return "";
                    assert(false, p.name ~ " is unhandled.");
            }
        }

        string parseTypeDef(const ref ParseTree p)
        {
            string typeDefName;

            bool firstIdentifier = true;

            string parseEnumDef(const ref ParseTree p)
            {
                switch(p.name)
                {
                    case "EP.IdentifierList":
                        return parseChildren(p, &parseEnumDef);
                    case "EP.Identifier":
                        string result = firstIdentifier ? "" : ", ";
                        firstIdentifier = false;
                        return result ~ contents(p);
                    default:
                        return parseDefaults(p);
                }
            }

            string parseTypeDefChild(const ref ParseTree p)
            {
                switch(p.name)
                {
                    case "EP.TypeDenoter", "EP.NewType", "EP.NewOrdinalType":
                        return parseChildren(p, &parseTypeDefChild);
                    case "EP.BNVTypeDefName":
                        typeDefName = contents(p);
                        return "";
                    case "EP.EnumeratedType":
                        return "enum " ~ typeDefName ~ " {" ~ parseChildren(p, &parseEnumDef) ~ "};";
                    default:
                        return parseDefaults(p);
                }
            }

            return parseChildren(p, &parseTypeDefChild);
        }

        import std.range.primitives;
        switch(p.name)
        {
            case "EP":
                return parseToCode(p.children[0]);	// The grammar result has only one child: the start rule's parse tree.
            // These just recurse into their children.
            case "EP.CompileUnit",
                 "EP.Program", "EP.ProgramBlock", "EP.MainProgramBlock", "EP.Block", "EP.ProgramComponent",
                 "EP.MainProgramDeclaration", "EP.ProgramHeading",
                 "EP.StatementSequence", "EP.Statement", "EP.ProcedureStatement",
                 "EP.WriteParameter",
                 "EP.Expression", "EP.SimpleExpression", "EP.Term", "EP.Factor",
                 "EP.Primary", "EP.UnsignedConstant", "EP.StringElement",
                 "EP.TypeDefinitionPart":
                return parseChildren(p);

            case "EP.BNVProgramName":
                programName = contents(p);
                writeln("LOG: detected program name: ", programName);
                return "";
            case "EP.ProgramParameterList":
                imports.insert("std.stdio");
                return "";

            case "EP.TypeDefinition":
                return parseTypeDef(p);

            case "EP.StatementPart":
                return "void main(string[] args)\n" ~ parseChildren(p);

            case "EP.CompoundStatement":
                return "{" ~ parseChildren(p) ~ "}";
            case "EP.SimpleStatement":
                return parseChildren(p) ~ ";";
            case "EP.CharacterString":
                return "\"" ~ escapeString(parseChildren(p).dup) ~ "\"";
            case "EP.ApostropheImage":
                return "'";
            case "EP.WritelnParameterList":
                return "(" ~ parseChildren(p) ~ ")";

            // These translate verbally
            case "EP.ProcedureName", "EP.StringCharacter", "EP.Identifier":
                return contents(p);

            // These are ignored
            case "EP.PROGRAM", "EP.BEGIN", "EP.END":
                return "";

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
    //writeln("test0");
    auto test = EP(`bug`);
    //writeln("test1");
    auto parseTree = EP(pascal);
    writeln("___________________________");
    //writeln(parseTree);
    writeln("PASCAL:");
    writeln(pascal);
    writeln("\nD:");
    writeln(toD(parseTree));
}

void main()
{
    test("
program MyTest(output);

(* Say
   hello. }
begin
    writeln( {Inline comment.} 'Hello D''s \"World\"!' {Inline comment.} {One more {thing.});
    writeln;      {Empty}
    writeln('');  {Empty string}
    writeln('a'); {String}
end.
    ");


    test("
PROGRAM arrayc (output);

  { Extended Pascal examples }
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
}


unittest {
    string input = `
program MyTest(output);

begin
    writeln('Hello D''s "World"!');
end.
`;
    auto parsed = EP(input);
    assert(equal(toD(parsed),
`import std.stdio;


 

void main(string[] args)
{
    writeln("Hello D's \"World\"!");
}
`));
}
