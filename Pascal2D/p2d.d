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
    _           <- ( WhiteSpace / Comment / InlineComment ) _*
    WhiteSpace  <- ( " " / "\t" / endOfLine )+

# Comments:
    CommentOpen     <-  "{" / "(*"
    CommentClose    <-  "}" / "*)"
    CommentContent  <- ( !CommentClose . )*
    InlineComment   <- CommentOpen CommentContent CommentClose !endOfLine
    Comment         <- CommentOpen CommentContent CommentClose &endOfLine

# 6.1.1
    Digit           <- [0-9]
    Letter          <- [a-zA-Z]

# 6.1.3
    Identifier      <~ Letter ( "_"? ( Letter / Digit ) )*

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
#TODO   Block           <- ImportPart (LabelDeclarationPart / ConstantDefinitionPart / TypeDefinitionPart / VariableDeclarationPart / ProcedureAndFunctionDeclarationPart)* StatementPart
    Block               <- ImportPart TypeDefinitionPart* StatementPart
    ImportPart          <- ("import" (ImportSpecification ";")+ )?
    StatementPart       <- _? CompoundStatement _?
    TypeDefinitionPart  <- :TYPE _ ( ( TypeDefinition / SchemaDefinition ) _? :";" _? )+

# 6.4.1 (complete)
    TypeDefinition      <- BNVTypeDefName _? "=" _? TypeDenoter _?
    TypeDenoter         <- (BINDABLE _ )? ( TypeName / NewType / TypeInquiry / DiscriminatedSchema ) _? InitialStateSpecifier?
    NewType             <- NewOrdinalType / NewStructuredType / NewPointerType / RestrictedType
    SimpleTypeName      <- TypeName
    StructuredTypeName  <- ArrayTypeName / RecordTypeName / SetTypeName / FileTypeName
    ArrayTypeName       <- TypeName
    RecordTypeName      <- TypeName
    SetTypeName         <- TypeName
    FileTypeName        <- TypeName
    PointerTypeName     <- TypeName
    TypeIdentifier      <- Identifier
    TypeName            <- ( ImportedInterfaceIdentifier "." )? TypeIdentifier
#BNV extensions
    BNVTypeDefName      <- Identifier

# 6.4.2.1 (complete)
    SimpleType          <- OrdinalType / RealTypeName / ComplexTypeName
    OrdinalType         <- NewOrdinalType / OrdinalTypeName / TypeInquiry / DiscriminatedSchema
    NewOrdinalType      <- EnumeratedType / SubrangeType
    OrdinalTypeName     <- TypeName
    RealTypeName        <- TypeName
    ComplexTypeName     <- TypeName

# 6.4.2.3 (complete)
    EnumeratedType      <- "(" _? IdentifierList _? ")"
    IdentifierList      <- Identifier ( _? "," _? Identifier )*

# 6.4.2.4 (complete)
    SubrangeType        <- SubrangeBound _? ".." _? SubrangeBound
    SubrangeBound       <- Expression

# 6.4.2.5 (complete)
    RestrictedType      <- RESTRICTED _ TypeName

# 6.4.3.1 (complete)
    StructuredType          <- NewStructuredType / StructuredTypeName
    NewStructuredType       <- PACKED? _? UnpackedStructuredType
    UnpackedStructuredType  <- ArrayType / RecordType / SetType / FileType

# 6.4.3.2 (complete)
    ArrayType           <- ARRAY _ "[" _? IndexType ( _? "," _? IndexType )* _? "]" _ OF _ ComponentType
    IndexType           <- OrdinalType
    ComponentType       <- TypeDenoter

# 6.4.3.4 (complete)
    RecordType          <- RECORD _ FieldList _ END
    FieldList           <- ( ( FixedPart ( _? ";" _? VariantPart )? / VariantPart ) _? ";"? )?
    FixedPart           <- RecordSection ( _? ";" _? RecordSection )*
    RecordSection       <- IdentifierList _? ":" _? TypeDenoter
    FieldIdentifier     <- Identifier
    VariantPart         <- CASE _ VariantSelector _ OF _ ( VariantListElement ( _? ";" _? VariantListElement )* _? ( ":"? _? VariantPartCompleter )? / VariantPartCompleter )
    VariantListElement  <- CaseConstantList _? ":" _? VariantDenoter
    VariantPartCompleter    <- OTHERWISE _ VariantDenoter
    VariantDenoter      <- "(" _? FieldList _? ")"
    VariantSelector     <- ( TagField _? ":" _? )? TagType / DiscriminantIdentifier
    TagField            <- Identifier
    TagType             <- OrdinalTypeName
    CaseConstantList    <- CaseRange ( _? "," _? CaseRange )*
    CaseRange           <- CaseConstant ( _? ".." _? CaseConstant )?
    CaseConstant        <- ConstantExpression

# 6.4.3.5 (complete)
    SetType             <- SET _ OF _ BaseType
    BaseType            <- OrdinalType

# 6.4.3.6 (complete)
    FileType            <- FILE _ ( "[" _? IndexType _? "]" _? )? OF _ ComponentType

# 6.4.4 (complete)
    PointerType         <- NewPointerType / PointerTypeName
    NewPointerType      <- "^" _? DomainType
    DomainType          <- TypeName / SchemaName

# 6.4.7 (complete)
    SchemaDefinition            <- ( Identifier _? "=" _? SchemaName ) / ( Identifier _? FormalDiscriminantPart _? "=" _? TypeDenoter )
    FormalDiscriminantPart      <- "(" _? DiscriminantSpecification ( _? ";" _? DiscriminantSpecification )* _? ")"
    DiscriminantSpecification   <- IdentifierList _? ":" _? OrdinalTypeName
    DiscriminantIdentifier      <- Identifier
    SchemaIdentifier            <- Identifier
    SchemaName                  <- ( ImportedInterfaceIdentifier _? "." _? )? SchemaIdentifier

# 6.4.8
    DiscriminatedSchema     <- SchemaName ActualDiscriminantPart
    ActualDiscriminantPart  <- "(" _? DiscriminantValue _? ( "," _? DiscriminantValue _? )* ")"
    DiscriminantValue       <- Expression

# 6.4.9 (complete)
    TypeInquiry         <- TYPE _ OF _ TypeInquiryObject
    TypeInquiryObject   <- VariableName / ParameterIdentifier

# 6.5.1
#TODO    VariableDeclaration <- IdentifierList ":" TypeDenoter
    VariableIdentifier  <- Identifier
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
#TODO    ProcedureHeading        <- "procedure" Identifier FormalParameterList?
    ProcedureIdentification <- "procedure" ProcedureIdentifier
    ProcedureIdentifier     <- Identifier
    ProcedureBlock          <- Block
    ProcedureName           <- ( ImportedInterfaceIdentifier "." )? ProcedureIdentifier

# 6.7.3.1
    ParameterIdentifier <- Identifier

# 6.8.1
    Expression          <- SimpleExpression (RelationalOperator SimpleExpression)?
    SimpleExpression    <- Sign? Term ( AddingOperator Term )*
    Term                <- Factor ( MultiplyingOperator Factor )*
    Factor              <- Primary ( ExponentiatingOperator Primary )?
#TODO    Primary             <- VariableAccess / UnsignedConstant / SetConstructor / FunctionAccess / "(" Expression ")" / NOT Primary / ConstantAccess / SchemaDiscriminant / StructuredValueConstructor / DiscriminantIdentifier
    Primary             <- UnsignedConstant
#TOCO    UnsignedConstant    <- UnsignedNumber / CharacterString / NIL / ExtendedNumber
    UnsignedConstant    <- CharacterString

# 6.8.2
    ConstantExpression  <- Expression

# 6.8.3.1 (complete)
    ExponentiatingOperator  <- "**" / POW
    MultiplyingOperator     <- "*" / "/" / DIV / MOD / AND / AND_THEN
    AddingOperator          <- "+" / "-" / "><" / OR / OR_ELSE
    RelationalOperator      <- "=" / "<>" / "<=" / "<" / ">=" / ">" / IN

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
#TODO    ProcedureStatement  <- ProcedureName _? ( _? ActualParameterList? / ReadParameterList / ReadlnParameterList / ReadstrParameterList / WriteParameterList / WritelnParameterList / WritestrParameterList _? )
    ProcedureStatement  <- ProcedureName _? WritelnParameterList _?

# 6.9.3.1
    StatementSequence   <- _? Statement _? ( :";" _? Statement _? )*

# 6.9.3.2   (NOTE: modified to allow ";" before "end".)
    CompoundStatement   <- BEGIN StatementSequence :";"? _? END

# 6.9.3.10
    FieldDesignatorIdentifier   <- Identifier

# 6.10.3
    WriteParameter  <- Expression ( ":" Expression ( ":" Expression )? )?

# 6.10.4
#TODO    WritelnParameterList    <- ( "(" _? ( FileVariable / WriteParameter ) _? ( "," _? WriteParameter _? )* ")" )?
    WritelnParameterList    <- ( "(" _? WriteParameter _? ( "," _? WriteParameter _? )* ")" )?

# 6.11.2
    ConstituentIdentifier   <- Identifier
    InterfaceIdentifier     <- Identifier

# 6.11.3 (complete)
    ImportSpecification         <- InterfaceIdentifier AccessQualifier? ImportQualifier?
    AccessQualifier             <- QUALIFIED
    ImportQualifier             <- SelectiveImportOption? "(" ImportList ")"
    SelectiveImportOption       <- ONLY
    ImportList                  <- ImportClause ("," ImportClause)*
    ImportClause                <- ConstituentIdentifier / ImportRenamingClause
    ImportRenamingClause        <- ConstituentIdentifier "=>" Identifier
    ImportedInterfaceIdentifier <- Identifier

# 6.12
    MainProgramDeclaration  <- ProgramHeading ";" _ MainProgramBlock
    MainProgramBlock        <- Block
    ProgramHeading          <- PROGRAM _ BNVProgramName ( _? "(" ProgramParameterList ")" )?
    ProgramParameterList    <- IdentifierList
# BNV extensions
    BNVProgramName          <- Identifier

# 6.13
    Program             <- _? ProgramBlock _?
    ProgramBlock        <- ProgramComponent+
    ProgramComponent    <- ( MainProgramDeclaration "." ) #TODO/ ( ModuleDeclaration "." )

# Keywords
    PROGRAM     <~ [Pp] [Rr] [Oo] [Gg] [Rr] [Aa] [Mm]
    ONLY        <~ [Oo][Nn][Ll][Yy]
    QUALIFIED   <~ [Qq][Uu][Aa][Ll][Ii][Ff][Ii][Ee][Dd]
    BEGIN       <~ [Bb][Ee][Gg][Ii][Nn]
    END         <~ [Ee][Nn][Dd]
    POW         <~ [Pp][Oo][Ww]
    DIV         <~ [Dd][Ii][Vv]
    MOD         <~ [Mm][Oo][Dd]
    AND         <~ [Aa][Nn][Dd]
    AND_THEN    <~ [Aa][Nn][Dd][_][Tt][Hh][Ee][Nn]
    OR          <~ [Oo][Rr]
    OR_ELSE     <~ [Oo][Rr][_][Ee][Ll][Ss][Ee]
    IN          <~ [Ii][Nn]
    NIL         <~ [Nn][il][IL]
    NOT         <~ [Nn][Oo][Tt]
    TYPE        <~ [Tt][Yy][Pp][Ee]
    BINDABLE    <~ [Bb][Ii][Nn][Dd][Aa][Bb][Ll][Ee]
    RESTRICTED  <~ [Rr][Ee][Ss][Tt][Rr][Ii][Cc][Tt][Ee][Dd]
    PACKED      <~ [Pp][Aa][Cc][Kk][Ee][Dd]
    ARRAY       <~ [Aa][Rr][Rr][Aa][Yy]
    OF          <~ [Oo][Ff]
    RECORD      <~ [Rr][Ee][Cc][Oo][Rr][Dd]
    CASE        <~ [Cc][Aa][Ss][Ee]
    OTHERWISE   <~ [Oo][Tt][Hh][Ee][Rr][Ww][Ii][Ss][Ee]
    SET         <~ [Ss][Ee][Tt]
    FILE        <~ [Ff][Ii][Ll][Ee]
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
                    if(startsWith(p.name, "literal"))   // Disregard keywords etc.
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
    test("
program MyTest(output);

(* Say
   hello. }
begin
    writeln( {Inline comment.} 'Hello D''s \"World\"!' {Inline comment.} {One more {thing.});
    writeln;     {Empty}
    writeln('');
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