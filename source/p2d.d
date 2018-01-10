module p2d;

import std.stdio;

import epparser;
import pegged.peg : equal, strip;

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
        } // parseChildren

        // In parseToCode.
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
        } // parseDefaults

        // In parseToCode.
        import std.typecons: Tuple, tuple;
        Tuple!(string, "name", string, "matches")[] readIdentifierList(const ref ParseTree p)
        in {
            assert(p.name == "EP.IdentifierList");
        }
        body {
            Tuple!(string, "name", string, "matches")[] identifiers;
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
        } // readIdentifierList

        // In parseToCode.
        string parseArrayType(const ref ParseTree p)
        in {
            assert(p.name == "EP.ArrayType");
        }
        body {
            string lastIndex, result, comments;
            string[] indices;

            foreach(child; p.children)
            {
                switch (child.name)
                {
                    case "EP.IndexType":
                        lastIndex = contents(child);
                        break;
                    case "EP.COMMA":
                        if (comments.length > 0) {
                            lastIndex ~= " " ~ comments;
                            comments = "";
                        }
                        indices ~= indices;
                        lastIndex = "";
                        break;
                    case "EP.ComponentType":
                        result ~= parseToCode(child);
                        indices ~= lastIndex;
                        foreach (index; indices)
                            result ~= "[" ~ index ~ "]";
                        result ~= comments;
                        break;
                    default:
                        comments ~= strip(parseDefaults(child));
                }
            }
            return result;
        } // parseArrayType

        // In parseToCode.
        // TypeDenoter is used in TypeDefinition, (array) ComponentType, RecordSection, SchemaDefinition, VariableDeclaration
        // The problem is that D does not have the simple type denoter from Pascal where everything is to the right of ':' or '='.
        // In D the /kind/ of type (enum, class, struct) comes first, then the identifier (unless anonymous), then the definition.
        void readTypeDenoter(const ref ParseTree p, ref string type, ref string initialValue, ref string aliases, string typeDefName = "")
        in {
            assert(p.name == "EP.TypeDenoter");
        }
        body {
            foreach (child; p.children)
            {
                if (child.name == "EP.InitialStateSpecifier")
                    initialValue ~= parseToCode(child);
                else
                    type ~= parseToCode(child);
            }
        } // readTypeDenoter

        // In parseToCode.
        string parseTypeDefinition(const ref ParseTree p)
        in {
            assert(p.name == "EP.TypeDefinition");
        }
        body {
            string typeDefName;
            string aliases;

            // In parseTypeDefinition
            string parseEnumTypeChild(const ref ParseTree p)
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
            } // parseEnumTypeChild

            /* TODO ongebruikt! */
            // In parseTypeDefinition
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
                    case "EP.NewType", "EP.NewOrdinalType", "EP.NewStructuredType",
                         "EP.UnpackedStructuredType":
                        return parseChildren(p, &parseTypeDefChild);
                    case "EP.BNVTypeDefName":
                        typeDefName = contents(p);
                        return "";
                    case "EP.EnumeratedType":
                        assert(typeDefName.length > 0);
                        return "enum " ~ typeDefName ~ " {" ~ parseChildren(p, &parseEnumTypeChild) ~ "}";
                    case "EP.ArrayType":
                        return parseArrayType(p);
                    case "EP.DiscriminatedSchema":
                        if (contents(p).startsWith("string"))
                            return "string";
                        goto default;
                    default:
                        return parseToCode(p);
                }
            } // parseTypeDefChild

            // Body parseTypeDefinition
            string comments, type, initialValue, additional_statements;
            foreach (child; p.children)
            {
                switch (child.name)
                {
                    case "EP.BNVTypeDefName":
                        typeDefName = contents(child);
                        break;
                    case "EP._":
                        comments ~= strip(parseDefaults(child)); // TODO
                        break;
                    case "EP.TypeDenoter":
                        readTypeDenoter(child, type, initialValue, additional_statements);
                        break;
                    default:
                        assert(0);
                }
            }

            string result = type;
            return result ~ additional_statements;
        } // parseTypeDefinition

        // In parseToCode.
        string parseTypeInquiry(const ref ParseTree p)
        in {
            assert(p.name == "EP.TypeInquiry");
        }
        body {
            string result;
            foreach(child; p.children)
            {
                switch (child.name)
                {
                    case "EP._":
                        result ~= strip(parseToCode(child));
                        break;
                    default:
                        result ~= parseToCode(child);
                        break;
                }
            }
            return "typeof(" ~ result ~ ")";
        }   // parseTypeInquiry

        // In parseToCode.
        string parseVariableDeclaration(const ref ParseTree p)
        in {
            assert(p.name == "EP.VariableDeclaration");
        }
        body {
            // TODO We could keep a list of declared variables and correct any deviations of case in
            // subsequent uses, to convert from the case-insensitive Pascal to case-sensitive D.

            import std.range.primitives;
            string comments, type, initialValue, additional_statements;
            string[] variables;

            foreach (child; p.children)
            {
                switch (child.name)
                {
                case "EP.IdentifierList":
                    foreach (grandchild; child.children)
                        variables ~= parseToCode(grandchild);
                    break;
                case "EP._":
                    comments ~= strip(parseDefaults(child)); /* TODO */
                    break;
                case "EP.TypeDenoter":
                    readTypeDenoter(child, type, initialValue, additional_statements /*TODO*/);
                    break;
                default:
                    assert(0);
                }
            }

            if (!initialValue.empty)
                foreach (i, var; variables)
                    variables[i] = var ~ "(" ~ initialValue ~ ")";

            string result = type ~ " " ~ variables[0];
            foreach (var; variables[1..$])
                result ~= ", " ~ var;
            return result ~ ";";
        } // parseVariableDeclaration

        // In parseToCode.
        string parseFormalParameterList(const ref ParseTree p)
        in {
            assert(p.name == "EP.FormalParameterList");
        }
        body {
            bool first = true;
            string parseFormalParameterSection(const ref ParseTree p)
            in {
                assert(p.name == "EP.FormalParameterSection");
            }
            body {
                string parseValueParameterSpecification(const ref ParseTree p)
                in {
                    assert(p.name == "EP.ValueParameterSpecification");
                }
                body {
                    bool isConst = false;
                    Tuple!(string, "name", string, "matches")[] identifiers;
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
                } // parseValueParameterSpecification

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
            } // parseFormalParameterSection

            string result;
            foreach (child; p.children)
                if (child.name == "EP.FormalParameterSection")
                    result ~= parseFormalParameterSection(child);
                else
                    result ~= parseDefaults(child);
            return "(" ~ result ~ ")";
        } // parseFormalParameterList

        // In parseToCode.
        string parseFunctionDeclaration(const ref ParseTree p)
        in {
            assert(p.name == "EP.FunctionDeclaration");
        }
        body {
            string result, name, resultVariable, resultType, block;

            string parseHeading(const ref ParseTree p)
            in {
                assert(p.name == "EP.FunctionHeading");
            }
            body {
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
            } // parseHeading

            string parseFunctionBlockChildren(const ref ParseTree p)
            {
                if (p.name == "EP.StatementPart") {
                    assert(p.children.length == 1 && p.children[0].name == "EP.CompoundStatement");
                    return parseChildren(p.children[0]);    // Omits curly braces of ordinary CompoundStatement.
                }
                return parseToCode(p);
            }

            foreach (child; p.children)
            {
                switch (child.name)
                {
                    case "EP.FunctionHeading":
                        result ~= parseHeading(child);
                        break;
                    case "EP.FunctionBlock":
                        assert(child.children.length == 1 && child.children[0].name == "EP.Block");
                        result ~= "{" ~ parseChildren(child.children[0], &parseFunctionBlockChildren) ~ "}";
                        break;
                    case "EP._":
                        result ~= parseDefaults(child);
                        break;
                    default:
                        writeln(child.name ~ " is unhandled in parseFunctionDeclaration.");
                }
            }

            return result;
        }   // parseFunctionDeclaration

        // In parseToCode.
        string parseMainProgramBlock(const ref ParseTree p)
        in {
            assert(p.name == "EP.MainProgramBlock" || p.name == "EP.Block");
        }
        body {
            string result;
            foreach (child; p.children)
                switch (child.name)
                {
                    case "EP.Block":
                        result ~= parseMainProgramBlock(child);
                        break;
                    case "EP.StatementPart":
                        // TODO check whether the return type should be void or int, depending on invocations of "return".
                        result ~= "void main(string[] args)\n" ~ parseChildren(child);
                        break;
                    default:
                        result ~= parseToCode(child);
                }
            return result;
        } // parseMainProgramBlock

        // Body parseToCode
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
                 "EP.StatementPart",
                 "EP.TypeInquiryObject",
                 "EP.VariableName":
                return parseChildren(p);
            case "EP.MainProgramBlock":
                return parseMainProgramBlock(p);
            case "EP.BNVProgramName":
                programName = contents(p);
                return "// Program name: " ~ programName ~ "\n";
            case "EP.ProgramParameterList":
                imports.insert("std.stdio");
                return "";
            case "EP.TypeDefinition":
                return parseTypeDefinition(p);
            case "EP.TypeInquiry":
                return parseTypeInquiry(p);
            case "EP.ComponentType":
                assert(p.children.length == 1 && p.children[0].name == "EP.TypeDenoter");
                return parseToCode(p.children[0]); /* TODO */
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
                    }
                }
            case "EP.VariableDeclaration":
                return parseVariableDeclaration(p);
            case "EP.FunctionDeclaration":
                return parseFunctionDeclaration(p);

            // These translate verbally
            case "EP.ProcedureName",
                 "EP.StringCharacter",
                 "EP.TypeName",
                 "EP.Identifier",
                 "EP.ParameterIdentifier",
                 "EP.ImportedInterfaceIdentifier",
                 "EP.DOT":
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
    } // parseToCode

    // body toD

    auto code = parseToCode(p);

    string importDeclaration;
    foreach(imp; imports[]) {
        importDeclaration ~= "import " ~ imp ~ ";\n";
    }

	return importDeclaration ~ "\n" ~ code;
} // toD


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
    assert(__traits(compiles, toD(parsed)));
}
