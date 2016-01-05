module epgrammar;

// Extended Pascal grammar.
// Comments refer to the section numbers in the standard:
// http://dx.doi.org/10.1109/IEEESTD.1990.101061
// http://pascal-central.com/docs/iso10206.pdf
//
// Uses extended PEG syntax:
// https://github.com/PhilippeSigaud/Pegged/wiki/Extended-PEG-Syntax

enum EPgrammar = `
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

# 6.1.7 (complete)
    SignedNumber    <- SignedInteger / SignedReal
    SignedReal      <~ Sign? UnsignedReal
    SignedInteger   <~ Sign? UnsignedInteger
    UnsignedNumber  <- UnsignedInteger / UnsignedReal
    Sign            <- [-+]
    UnsignedReal    <~ DigitSequence "." FractionalPart ( [eE] ScaleFactor )? / DigitSequence [eE] ScaleFactor
    UnsignedInteger <- DigitSequence
    FractionalPart  <- DigitSequence
    ScaleFactor     <~ Sign? DigitSequence
    DigitSequence   <~ Digit+   # The tilde fuses the Digit nodes (["1", "2", "3"]) into one DigitSequence node (["123"]);
    Number          <~ SignedNumber / Sign? ( DigitSequence "." / "." FractionalPart ) ( [eE] ScaleFactor )?
    ExtendedDigit   <- Digit / Letter
    ExtendedNumber  <- UnsignedInteger "#" ExtendedDigit+

# 6.1.8
    Label   <- DigitSequence

# 6.1.9 (complete)
    CharacterString <- :"'" StringElement* :"'"  # The colon discards the quotes.
    StringElement   <- ApostropheImage / StringCharacter
    ApostropheImage <- "''"
    StringCharacter <- !"'" .

# 6.2.1
#TODO   Block           <- ImportPart ( _? LabelDeclarationPart / ConstantDefinitionPart / TypeDefinitionPart / VariableDeclarationPart / ProcedureAndFunctionDeclarationPart )* _? StatementPart
    Block               <- ImportPart ( _? TypeDefinitionPart )* _? StatementPart
    ImportPart          <- ("import" (ImportSpecification ";")+ )?
    StatementPart       <- _? CompoundStatement _?
    TypeDefinitionPart  <- :TYPE _ ( TypeDefinition / SchemaDefinition ) _? ";" _? ( ( TypeDefinition / SchemaDefinition ) _? ";" _? )*

# 6.3.1
    ConstantName        <- ( ImportedInterfaceIdentifier _? "." _? )? ConstantIdentifier
    ConstantIdentifier  <- Identifier

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
    DiscriminatedSchema     <- SchemaName _? ActualDiscriminantPart
    ActualDiscriminantPart  <- "(" _? DiscriminantValue _? ( "," _? DiscriminantValue _? )* ")"
    DiscriminantValue       <- Expression

# 6.4.9 (complete)
    TypeInquiry         <- TYPE _ OF _ TypeInquiryObject
    TypeInquiryObject   <- VariableName / ParameterIdentifier

# 6.5.1
    VariableDeclaration <- IdentifierList ":" TypeDenoter
    VariableIdentifier  <- Identifier
    VariableName        <- ( ImportedInterfaceIdentifier "." )? VariableIdentifier
    VariableAccess      <- EntireVariable / ComponentVariable / IdentifiedVariable / BufferVariable / SubstringVariable #TODO/ FunctionIdentifiedVariable

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

# 6.7.2
    FunctionIdentifier  <- Identifier
    FunctionName        <- ( ImportedInterfaceIdentifier _? "." _? )? FunctionIdentifier

# 6.7.3.1
    ParameterIdentifier <- Identifier

# 6.8.1 (complete)
    Expression          <- SimpleExpression _? (RelationalOperator _? SimpleExpression)?
    SimpleExpression    <- Sign? _? Term ( _? AddingOperator _? Term )*
    Term                <- Factor ( _? MultiplyingOperator _? Factor )*
    Factor              <- Primary ( _? ExponentiatingOperator _? Primary )?
    Primary             <- VariableAccess / UnsignedConstant / SetConstructor / FunctionAccess / "(" _? Expression _? ")" / NOT _? Primary / ConstantAccess / SchemaDiscriminant / StructuredValueConstructor / DiscriminantIdentifier
    UnsignedConstant    <- UnsignedNumber / CharacterString / NIL / ExtendedNumber
    SetConstructor      <- "[" _? ( MemberDesignator ( _? "," _? MemberDesignator )* )? _? "]"
    MemberDesignator    <- Expression ( _? ".." _? Expression )?

# 6.8.2
    ConstantExpression  <- Expression

# 6.8.3.1 (complete)
    ExponentiatingOperator  <- "**" / POW
    MultiplyingOperator     <- "*" / "/" / DIV / MOD / AND / AND_THEN
    AddingOperator          <- "+" / "-" / "><" / OR / OR_ELSE
    RelationalOperator      <- "=" / "<>" / "<=" / "<" / ">=" / ">" / IN

# 6.8.4
    SchemaDiscriminant      <- ( VariableAccess / ConstantAccess ) _? "." _? DiscriminantSpecifier / SchemaDiscriminantIdentifier
    DiscriminantSpecifier   <- DiscriminantIdentifier


# 6.8.5 (complete)
    FunctionDesignator      <- FunctionName _? ActualParameterList?
    ActualParameterList     <- "(" _? ActualParameter ( _? "," _? ActualParameter )* _? ")"
    ActualParameter         <- Expression / VariableAccess / ProcedureName / FunctionName

# 6.8.6.1 (complete)
    FunctionAccess          <- EntireFunctionAccess / ComponentFunctionAccess / SubstringFunctionAccess
    ComponentFunctionAccess <- IndexedFunctionAccess / RecordFunctionAccess
    EntireFunctionAccess    <- FunctionDesignator

# 6.8.6.2 (complete)
    IndexedFunctionAccess   <- ArrayFunction _? "[" _? IndexExpression ( _? "," _? IndexExpression )* _? "]"
    ArrayFunction           <- FunctionAccess
    StringFunction          <- FunctionAccess

# 6.8.6.3 (complete)
    RecordFunctionAccess    <- RecordFunction _? "." _? FieldSpecifier
    RecordFunction          <- FunctionAccess

# 6.8.6.5 (complete)
    SubstringFunctionAccess <- StringFunction _? "[" _? IndexExpression _? ".." _? IndexExpression _? "]"

# 6.8.6.4 (complete)
    FunctionIdentifiedVariable  <- PointerFunction _? "^"
    PointerFunction             <- FunctionAccess

# 6.8.7.1 (complete)
    StructuredValueConstructor  <- ArrayTypeName _? ArrayValue / RecordTypeName _? RecordValue / SetTypeName _? SetValue
    ComponentValue  <- Expression / ArrayValue / RecordValue

# 6.8.7.2 (complete)
    ArrayValue          <- "[" _? ( ArrayValueElement ( _? ";" _? ArrayValueElement )* _? ";"? )? ( _? ArrayValueCompleter _? ";"? )? _? "]"
    ArrayValueElement   <- CaseConstantList _? ":" _? ComponentValue
    ArrayValueCompleter <- OTHERWISE _? ComponentValue

# 6.8.7.3 (complete)
    RecordValue         <- "[" _? FieldListValue _? "]"
    FieldListValue      <- ( ( FixedPartValue ( _? ";" _? VariantPartValue )? / VariantPartValue ) _? ";"? )?
    FixedPartValue      <- FieldValue ( _? ";" _? FieldValue )*
    FieldValue          <- FieldIdentifier ( _? ";" FieldIdentifier )* _? ":" _? ComponentValue
    VariantPartValue    <- CASE _? ( TagFieldIdentifier _? ":" _?)? ConstantTagValue _? OF _? "[" _? FieldListValue _? "]"
    ConstantTagValue    <- ConstantExpression
    TagFieldIdentifier  <- FieldIdentifier

# 6.8.7.4
    SetValue            <- SetConstructor

# 6.8.8.1 (complete)
    ConstantAccess          <- ConstantAccessComponent / ConstantName
    ConstantAccessComponent <- IndexedConstant / FieldDesignatedConstant / SubstringConstant

# 6.8.8.2 (complete)
    IndexedConstant <- ArrayConstant _? "[" _? IndexExpression ( _? "," _? IndexExpression )* _? "]" / StringConstant _? "[" _? IndexExpression _? "]"
    ArrayConstant   <- ConstantAccess
    StringConstant  <- ConstantAccess

# 6.8.8.3 (complete)
    FieldDesignatedConstant <- RecordConstant _? "." _? FieldSpecifier / ConstantFieldIdentifier
    RecordConstant          <- ConstantAccess

# 6.8.8.4 (complete)
    SubstringConstant   <- StringConstant _. "[" _? IndexExpression _? ".." _? IndexExpression _? "]"

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
    CompoundStatement   <- BEGIN _? StatementSequence? _? :";"? _? END  # BNV made StatementSequence optional.

# 6.9.3.10
    FieldDesignatorIdentifier       <- Identifier
    ConstantFieldIdentifier         <- Identifier
    SchemaDiscriminantIdentifier    <- Identifier

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
    MainProgramDeclaration  <- ProgramHeading _? ";" _? MainProgramBlock
    MainProgramBlock        <- Block
    ProgramHeading          <- PROGRAM _ BNVProgramName ( _? "(" ProgramParameterList ")" )?
    ProgramParameterList    <- IdentifierList
# BNV extensions
    BNVProgramName          <- Identifier

# 6.13
    Program             <- _? ProgramBlock _?
    ProgramBlock        <- ProgramComponent+
    ProgramComponent    <- ( MainProgramDeclaration _? "." ) #TODO/ ( ModuleDeclaration "." )

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
`;
