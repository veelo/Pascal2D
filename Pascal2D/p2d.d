import pegged.grammar;
import std.stdio;

// Extended Pascal grammar.
// Comments refer to the section numbers in IEEE/ANSI 770X3.160-1989
// http://dx.doi.org/10.1109/IEEESTD.1990.101061
mixin(grammar(`
EP:
#    CompileUnit  <- (Program / Comment) eoi
    CompileUnit  <- Program eoi

# Token separators
    _           <- ( WhiteSpace / Comment ) _*
    WhiteSpace  <- ( " " / "\t" / "\r" / "\n" / "\r\n" )+

# Comments:
    CommentOpen     <-  "{" / "(*"
    CommentClose    <-  "}" / "*)"
    CommentContent  <- (!CommentClose .)*
    Comment         <- CommentOpen CommentContent CommentClose

# 6.1.1
    Digit           <- [0-9]

# 6.1.7
    DigitSequence   <~ (Digit+)     # The tilde fuses the Digit nodes (["1", "2", "3"]) into one DigitSequence node (["123"]);
    Sign            <- [-+]

# 6.1.8
    Label   <- DigitSequence

# 6.1.9 (complete)
    CharacterString <- :"'" StringElement* :"'"  # The colon discards the quotes.
    StringElement   <- ApostropheImage / StringCharacter
    ApostropheImage <- "''"
    StringCharacter <- !"'" .

# 6.2.1
#TODO   Block       <- ImportPart (LabelDeclarationPart / ConstantDefinitionPart / TypeDefinitionPart / VariableDeclarationPart / ProcedureAndFunctionDeclarationPart)* StatementPart
    Block           <- ImportPart StatementPart
    ImportPart      <- ("import" (ImportSpecification ";")+ )?
    StatementPart   <- _? CompoundStatement _?

# 6.4.2.3
    IdentifierList      <- identifier ("," identifier)*

# 6.4.3.4
    FieldIdentifier     <- identifier

# 6.5.1
#TODO    VariableDeclaration <- IdentifierList ":" TypeDenoter
    VariableIdentifier  <- identifier
    VariableName        <- ( ImportedInterfaceIdentifier "." )? VariableIdentifier
#TODO    VariableAccess      <- EntireVariable / ComponentVariable / IdentifiedVariable / BufferVariable / SubstringVariable / FunctionIdentifiedVariable
    VariableAccess      <- EntireVariable / ComponentVariable / IdentifiedVariable / BufferVariable / SubstringVariable

# 6.5.2 (complete)
    EntireVariable      <- VariableName

# 6.5.3.1 (complete)
    ComponentVariable   <- IndexedVariable / FieldDesignator

# 6.5.3.2 (complete)
    IndexedVariable     <- (ArrayVariable "[" IndexExpression ( "," IndexExpression )* "]" ) / ( StringVariable "[" IndexExpression "]" )
    ArrayVariable       <- VariableAccess
    StringVariable      <- VariableAccess
    IndexExpression     <- Expression

# 6.5.3.3 (complete)
    FieldDesignator     <- ( RecordVariable "." FieldSpecifier ) / FieldDesignatorIdentifier
    RecordVariable      <- VariableAccess
    FieldSpecifier      <- FieldIdentifier

# 6.5.4 (complete)
    IdentifiedVariable  <- PointerVariable "^"
    PointerVariable     <- VariableAccess

# 6.5.5 (complete)
    BufferVariable      <- FileVariable "^"
    FileVariable        <- VariableAccess

# 6.5.6 (complete)
    SubstringVariable   <- StringVariable "[" IndexExpression ".." IndexExpression "]"

# 6.6 (complete)
    InitialStateSpecifier   <- "value" ComponentValue

# 6.7.1 (complete)
#TODO    ProcedureHeading        <- "procedure" identifier FormalParameterList?
    ProcedureIdentification <- "procedure" ProcedureIdentifier
    ProcedureIdentifier     <- identifier
    ProcedureBlock          <- Block
    ProcedureName           <- ( ImportedInterfaceIdentifier "." )? ProcedureIdentifier

# 6.8.1
    Expression          <- SimpleExpression (RelationalOperator SimpleExpression)?
    SimpleExpression    <- Sign? Term ( AddingOperator Term )*
    Term                <- Factor ( MultiplyingOperator Factor )*
    Factor              <- Primary ( ExponentiatingOperator Primary )?
#TODO    Primary             <- VariableAccess / UnsignedConstant / SetConstructor / FunctionAccess / "(" Expression ")" / "not" Primary / ConstantAccess / SchemaDiscriminant / StructuredValueConstructor / DiscriminantIdentifier
    Primary             <- UnsignedConstant
#TOCO    UnsignedConstant    <- UnsignedNumber / CharacterString / "nil" / ExtendedNumber
    UnsignedConstant    <- CharacterString

# 6.8.3.1 (complete)
    ExponentiatingOperator  <- "**" / "pow"
    MultiplyingOperator <- "*" / "/" / "div" / "mod" / "and" / "and_then"
    AddingOperator          <- "+" / "-" / "><" / "or" / "or_else"
    RelationalOperator  <- "=" / "<>" / "<=" / "<" / ">=" / ">" / "in"

# 6.8.6.4
#TODO    FunctionIdentifiedVariable  <- PointerFunction "^"
#TODO    PointerFunction             <- FunctionAccess

# 6.8.7.1
#TODO    ComponentValue  <- Expression / ArrayValue / RecordValue
    ComponentValue  <- Expression

# 6.9.1
#TODO    Statement   <- ( Label ":" )? ( SimpleStatement / StructuredStatement )
    Statement   <- ( Label ":" )? SimpleStatement

# 6.9.2.1
#TODO    SimpleStatement <- EmptyStatement / AssignmentStatement / ProcedureStatement / GotoStatement
    SimpleStatement <- ProcedureStatement

# 6.9.2.3
#TODO    ProcedureStatement  <- ProcedureName (ActualParameterList? / ReadParameterList / ReadlnParameterList / ReadstrParameterList / WriteParameterList / WritelnParameterList / WritestrParameterList )
    ProcedureStatement  <- ProcedureName WritelnParameterList

# 6.9.3.1
    StatementSequence   <- _? Statement _? ( :";" _? Statement _? )*

# 6.9.3.2   (NOTE: modified to allow ";" before "end".)
    CompoundStatement   <- "begin" StatementSequence :";"? _? "end"

# 6.9.3.10
    FieldDesignatorIdentifier   <- identifier

# 6.10.3
    WriteParameter  <- Expression ( ":" Expression ( ":" Expression )? )?

# 6.10.4
#TODO    WritelnParameterList    <- ( "(" ( FileVariable / WriteParameter ) ( "," WriteParameter )* ")" )?
    WritelnParameterList    <- ( "(" WriteParameter ( "," WriteParameter )* ")" )?

# 6.11.2
    ConstituentIdentifier   <- identifier
    InterfaceIdentifier     <- identifier

# 6.11.3 (complete)
    ImportSpecification         <- InterfaceIdentifier AccessQualifier? ImportQualifier?
    AccessQualifier             <- "qualified"
    ImportQualifier             <- SelectiveImportOption? "(" ImportList ")"
    SelectiveImportOption       <- "only"
    ImportList                  <- ImportClause ("," ImportClause)*
    ImportClause                <- ConstituentIdentifier / ImportRenamingClause
    ImportRenamingClause        <- ConstituentIdentifier "=>" identifier
    ImportedInterfaceIdentifier <- identifier

# 6.12
    MainProgramDeclaration  <- ProgramHeading ";" _ MainProgramBlock
    MainProgramBlock        <- Block
    ProgramHeading          <- "program" _ identifier ( "(" ProgramParameterList ")" )?
    ProgramParameterList    <- IdentifierList

# 6.13
    Program             <- _? ProgramBlock _?
    ProgramBlock        <- ProgramComponent+
    ProgramComponent    <- ( MainProgramDeclaration "." ) #/ ( ModuleDeclaration "." )
    
`));



unittest // Extended Pascal comments
{
	assert(EP.Comment("(* Mixed. }").successful);
    assert(EP.Comment("{Multi word comment.}").successful);
    assert(EP.Comment("{Multi line
	                   comment. With \n
                       \"escapes\"}").successful);

    // The EP standard does not allow nested comments.
    assert(!EP("(* Here comes a {nested} comment.}").successful);
}


string toD(ParseTree p)
{
    import std.container;
    auto imports = new RedBlackTree!string;

    string escapeString(string s)
    {
        import std.array;
        return s.replace("\"", "\\\"");
    }

	string parseToCode(ParseTree p)
	{
        import std.range.primitives;
		switch(p.name)
		{
			case "EP":
				return parseToCode(p.children[0]);	// The grammar result has only one child: the start rule's parse tree.
            // These just recurse into their children.
            case "EP.CompileUnit", "EP._",
                 "EP.Program", "EP.ProgramBlock", "EP.MainProgramBlock", "EP.Block", "EP.ProgramComponent",
                 "EP.MainProgramDeclaration", "EP.ProgramHeading",
                 "EP.StatementSequence", "EP.Statement", "EP.ProcedureStatement",
                 "EP.WriteParameter",
                 "EP.Expression", "EP.SimpleExpression", "EP.Term", "EP.Factor",
                 "EP.Primary", "EP.UnsignedConstant", "EP.StringElement":
				string result;
				foreach(child; p.children)	// child is a ParseTree.
					result ~= parseToCode(child);
				return result;
            case "EP.Comment":
                assert(p.children.length == 3);
                assert(equal(p.children[1].name, "EP.CommentContent"));
                return parseToCode(p.children[1]);
			case "EP.CommentContent":
                assert(p.children.length == 0); // No nested comments.
                return "/*" ~ p.input[p.begin .. p.end] ~ "*/";

            case "EP.WhiteSpace":
                return p.input[p.begin .. p.end];
            case "EP.ProgramParameterList":
                imports.insert("std.stdio");
                return "";

            case "EP.StatementPart":
                string result;
                foreach(child; p.children)  // child is a ParseTree.
                    result ~= parseToCode(child);
                return "void main(string[] args)\n" ~ result;

            case "EP.CompoundStatement":
                string result;
                foreach(child; p.children)  // child is a ParseTree.
                    result ~= parseToCode(child);
                return "{" ~ result ~ "}";
            case "EP.SimpleStatement":
                string result;
                foreach(child; p.children)  // child is a ParseTree.
                    result ~= parseToCode(child);
                return result ~ ";";
            case "EP.CharacterString":
                string result;
                foreach(child; p.children)  // child is a ParseTree.
                    result ~= parseToCode(child);
                return "\"" ~ escapeString(result) ~ "\"";
            case "EP.ApostropheImage":
                return "'";
            case "EP.WritelnParameterList":
                string result;
                foreach(child; p.children)  // child is a ParseTree.
                    result ~= parseToCode(child);
                return "(" ~ result ~ ")";


            // These translate verbally
            case "EP.ProcedureName", "EP.StringCharacter":
                return p.input[p.begin .. p.end];
               

			default:
                if(startsWith(p.name, "literal"))   // Disregard keywords etc.
                    return "";
                writeln(p.name[0..6]);
				assert(false, p.name ~ " is unhandled.");
		}
	}

    auto code = parseToCode(p);

    string importDeclaration;
    foreach(imp; imports[]) {
        importDeclaration ~= "import " ~ imp ~ ";\n";
    }

	return importDeclaration ~ "\n" ~ code;
}

void test(string pascal)
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
    test("(* Here comes a {wannabe nested comment.}");

    test("
program MyTest(output);

begin
    writeln('Hello D''s \"World\"!');
    writeln;
    writeln('');
end.
    ");

}


unittest {
    assert(equal(toD(EP("
program MyTest(output);

begin
    writeln('Hello D''s \"World\"!');
end.
    ")), "import std.stdio;


 

int main(string[] args)
{
    writeln(\"Hello D's \\\"World\\\"!\");
}
    "));
}