module p2d;

import std.stdio;

import epparser;
import std.string: strip, stripLeft;
import std.algorithm: equal;
import std.uni : icmp;
import std.ascii : newline;

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
            import std.algorithm.iteration: filter;
            import std.conv;
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
                    return contents(p).filter!(a => a != '\r').to!string; // Remove '\r', is inserted depending on platform. 
                case "fail":
                    writeln("PARSE ERROR: " ~ p.toString);
                    assert(0, "Parse unsuccessful");
                default:
                    if(startsWith(p.name, "Literal") || startsWith(p.name, "CILiteral"))   // Disregard keywords etc.
                    {
                        writeln("LOG: Found literal ", contents(p));
                        return "";
                    }
                    writeln(p.name ~ " is unhandled at ", __FILE__, ":", __LINE__);
                    return "";
            }
        } // parseDefaults

        // In parseToCode.
        import std.typecons: Tuple, tuple;
        Tuple!(string, "name", string, "matches")[] readIdentifierList(const ref ParseTree p)
        in {
            assert(p.name == "EP.IdentifierList");
        }
        do {
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
        // TypeDenoter is used in TypeDefinition, (array) ComponentType, RecordSection, SchemaDefinition, VariableDeclaration
        // The problem is that D does not have the simple type denoter from Pascal where everything is to the right of ':' or '='.
        // In D the /kind/ of type (enum, class, struct) comes first, then the identifier (unless anonymous), then the definition.
        enum TypeDenoterKind {Alias, Enum}
        void readTypeDenoter(const ref ParseTree p, ref string type, ref string initialValue, ref string additional_statements, ref string annotation, ref TypeDenoterKind kind)
        in {
            assert(p.name == "EP.TypeDenoter");
        }
        do {
            // In readTypeDenoter.
            string parseArrayType(const ref ParseTree p)
            in {
                assert(p.name == "EP.ArrayType");
            }
            do {
                string lastIndex, result, component, comments;
                string readIndexType(const ref ParseTree p)
                in {
                    assert(p.name == "EP.IndexType" ||
                           p.name == "EP.OrdinalType" ||
                           p.name == "EP.NewOrdinalType");
                }
                do {
                    string result;
                    foreach (child; p.children)
                    {
                        switch (child.name)
                        {
                            case "EP.OrdinalType", "EP.NewOrdinalType":
                                return readIndexType(child);
                            case "EP.SubrangeType": {
                                short boundCount = 0;
                                foreach (subrangeChild; child.children)
                                {
                                    final switch (subrangeChild.name)
                                    {
                                        case "EP._":
                                            result ~= strip(parseDefaults(subrangeChild));
                                            break;
                                        case "EP.SubrangeBound":
                                            if (boundCount++ > 0)
                                                result ~= ", ";
                                            result ~= parseToCode(subrangeChild);
                                            break;
                                    }
                                }
                                break;
                            }
                            default:
                                result ~= parseToCode(child);
                                break;
                        }
                    }
                    return result;
                }

                foreach(child; p.children)
                {
                    final switch (child.name)
                    {
                        case "EP.IndexType":
                            lastIndex = readIndexType(child);
                            break;
                        case "EP.COMMA":
                            assert(0, "Multi-dimansional array needs work.");
                            //if (comments.length > 0) {
                            //    lastIndex ~= " " ~ comments;
                            //    comments = "";
                            //}
                            //indices ~= indices;
                            //lastIndex = "";
                            //break;
                        case "EP.ComponentType": {
                            string ini, add, ann;
                            TypeDenoterKind kind;
                            assert(child.children[0].name == "EP.TypeDenoter");
                            readTypeDenoter(child.children[0], component, ini, add, ann, kind);
                            // We don't really know what to do with these yet, but we probably don't need to:
                            assert(ini.length == 0);
                            assert(add.length == 0);
                            assert(ann.length == 0);
                            break;
                        }
                        case "EP._":
                            comments ~= strip(parseDefaults(child)); //TODO
                    }
                }
                imports.insert("epcompat");
                return "StaticArray!(" ~ component ~ ", " ~ lastIndex ~ ")";
            } // parseArrayType

            bool isBindable = false;
            kind = TypeDenoterKind.Alias;
            foreach (child; p.children) // Children of TypeDenoter
            {
                switch (child.name)
                {
                    case "EP.BINDABLE":
                        isBindable = true;
                        break;
                    case "EP.DiscriminatedSchema": {
                        assert(child.children[0].name == "EP.SchemaName");
                        auto schemaname = contents(child.children[0]);
                        import std.algorithm.searching;
                        auto c = countUntil!"a.name == b"(child.children, "EP.ActualDiscriminantPart");
                        assert(c >= 0);
                        assert(child.children[c].name == "EP.ActualDiscriminantPart");
                        if (icmp(schemaname, "string") == 0) {
                            imports.insert("epcompat");
                            annotation = "@EPString" ~ contents(child.children[c]);
                            type = "string";
                        }
                        else if (icmp(schemaname, "shortstring") == 0) {
                            imports.insert("epcompat");
                            annotation = "@EPShortString" ~ contents(child.children[c]);
                            type = "string";
                        }
                        else
                            type ~= parseToCode(child); // Other discriminated schema.
                        break;
                    }
                    case "EP.InitialStateSpecifier":
                        initialValue ~= parseToCode(child);
                        break;
                    case "EP.NewType": {
                        auto newTypeChild = child.children[0];
                        switch (newTypeChild.name) {
                            case "EP.NewOrdinalType": {
                                auto newOrdinalChild = newTypeChild.children[0];
                                final switch (newOrdinalChild.name) {
                                    case "EP.EnumeratedType": {
                                        kind = TypeDenoterKind.Enum;
                                        type ~= "{";
                                        foreach (enumChild; newOrdinalChild.children) {
                                            final switch (enumChild.name) {
                                                case "EP._":
                                                    type ~= strip(parseDefaults(enumChild));
                                                    break;
                                                case "EP.IdentifierList": {
                                                    foreach(i, ident; readIdentifierList(enumChild))
                                                    {
                                                        if (i > 0)
                                                            type ~= ", ";
                                                        type ~= ident.matches;
                                                    }
                                                    break;
                                                }
                                            }
                                        }
                                        type ~= "}";
                                        break;
                                    }
                                    case "EP.SubrangeType":
                                        writeln(newOrdinalChild.name ~ " is unhandled at ", __FILE__, ":", __LINE__);
                                        break;
                                }
                                break;
                            }
                            case "EP.NewStructuredType": {
                                foreach (newStructuredChild; newTypeChild.children)
                                    final switch (newStructuredChild.name) {
                                        case "EP._":
                                            type ~= strip(parseDefaults(newStructuredChild));
                                            break;
                                        case "EP.UnpackedStructuredType": {
                                            auto unpackedStructuredChild = newStructuredChild.children[0];
                                            final switch (unpackedStructuredChild.name) {
                                                case "EP.ArrayType":
                                                    type ~= parseArrayType(unpackedStructuredChild);
                                                    break;
                                                case "EP.FileType":
                                                    assert(isBindable);
                                                    foreach (fileChild; unpackedStructuredChild.children)
                                                        final switch (fileChild.name) {
                                                            case "EP._":
                                                                type ~= strip(parseDefaults(fileChild));
                                                                break;
                                                            case "EP.IndexType":
                                                                writeln("EP.IndexType is unhandled at ", __FILE__, ":", __LINE__);
                                                                break;
                                                            case "EP.ComponentType":
                                                                string ini, add, ann, component;
                                                                TypeDenoterKind componentKind;
                                                                assert(fileChild.children[0].name == "EP.TypeDenoter");
                                                                readTypeDenoter(fileChild.children[0], component, ini, add, ann, componentKind);
                                                                // We don't really know what to do with these yet, but we probably don't need to:
                                                                assert(ini.length == 0);
                                                                assert(add.length == 0);
                                                                assert(ann.length == 0);
                                                                assert(componentKind == TypeDenoterKind.Alias);
                                                                type ~= "Bindable!" ~ component;
                                                                break;
                                                        }
                                                    break;
                                                case "EP.RecordType", "EP.SetType":
                                                    writeln(unpackedStructuredChild.name ~ " is unhandled at ", __FILE__, ":", __LINE__);
                                                    break;
                                            }
                                        }
                                    }
                                break;
                            }
                            default:
                                writeln(newTypeChild.name ~ " is unhandled at ", __FILE__, ":", __LINE__);
                        }
                        break;
                    }
                    default:
                        type ~= parseToCode(child);
                        break;
                }
            }
        } // readTypeDenoter

        // In parseToCode.
        string parseTypeDefinition(const ref ParseTree p)
        in {
            assert(p.name == "EP.TypeDefinition");
        }
        do {
            string typeDefName;

            // Body parseTypeDefinition
            string comments, type, initialValue, additional_statements, annotation;
            TypeDenoterKind kind;
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
                        readTypeDenoter(child, type, initialValue /*TODO*/, additional_statements, annotation, kind);
                        break;
                    default:
                        assert(0);
                }
            }

            final switch (kind)
            {
                case TypeDenoterKind.Alias: {
                    if (annotation.length > 0) annotation ~= " ";
                    if (comments.length > 0) comments ~= " ";
                    string result = annotation ~ "alias " ~ typeDefName ~ " = " ~ comments ~ type ~ ";";
                    return result ~ additional_statements ~ newline;                    
                }
                case TypeDenoterKind.Enum: {
                    imports.insert("epcompat");
                    return "enum " ~ typeDefName ~ " " ~ type ~ ";" ~ newline ~
                           "mixin withEnum!" ~ typeDefName ~ ";";
                }
            }
        } // parseTypeDefinition

        // In parseToCode.
        string parseTypeInquiry(const ref ParseTree p)
        in {
            assert(p.name == "EP.TypeInquiry");
        }
        do {
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
        do {
            // TODO We could keep a list of declared variables and correct any deviations of case in
            // subsequent uses, to convert from the case-insensitive Pascal to case-sensitive D.

            import std.range.primitives;
            string comments, type, initialValue, additional_statements, annotation;
            string[] variables;
            TypeDenoterKind kind;

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
                    readTypeDenoter(child, type, initialValue, additional_statements /*TODO*/, annotation /*TODO*/, kind /*TODO*/);
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
        do {
            bool first = true;
            string parseFormalParameterSection(const ref ParseTree p)
            in {
                assert(p.name == "EP.FormalParameterSection");
            }
            do {
                string parseValueParameterSpecification(const ref ParseTree p)
                in {
                    assert(p.name == "EP.ValueParameterSpecification");
                }
                do {
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
        do {
            string result, name, resultVariable, resultType, block;

            string parseHeading(const ref ParseTree p)
            in {
                assert(p.name == "EP.FunctionHeading");
            }
            do {
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
                        writeln(child.name ~ " is unhandled at ", __FILE__, ":", __LINE__);
                }
            }

            return result;
        }   // parseFunctionDeclaration

        // In parseToCode.
        string parseForStatement(const ref ParseTree p)
        in {
            assert(p.name == "EP.ForStatement");
        }
        do {
            string result = "for ";
            string variable;

            string parseSequenceIteration(const ref ParseTree iteration)
            {
                string initial_val, final_val, comment;
                bool increasing = true;
                foreach (child; iteration.children)
                    final switch (child.name)
                    {
                        case "EP.InitialValue":
                            initial_val = parseToCode(child.children[0]);
                            break;
                        case "EP.TO":
                            break;
                        case "EP.DOWNTO":
                            increasing = false;
                            break;
                        case "EP.FinalValue":
                            final_val = parseToCode(child.children[0]);
                            break;
                        case "EP._":
                            comment ~= stripLeft(parseDefaults(child));
                            break;
                    }
                    return "(" ~ variable ~ " = " ~ initial_val ~ "; " ~
                                 variable ~ (increasing ? " <= " : " >= ") ~ final_val ~ "; " ~
                                 variable ~ (increasing ? "++" : "--") ~ ")" ~ comment;
            }

            foreach (child; p.children)
                final switch (child.name)
                {
                    case "EP.ControlVariable":
                        variable = contents(child);
                        break;
                    case "EP.IterationClause":
                        final switch (child.children[0].name)
                        {
                            case "EP.SequenceIteration":
                                result ~= parseSequenceIteration(child.children[0]);
                                break;
                            case "EP.SetMemberIteration":
                                writeln(child.children[0].name ~ " is unhandled at ", __FILE__, ":", __LINE__);
                                break;
                        }
                        break;
                    case "EP.Statement":
                        result ~= parseToCode(child);
                        break;
                    case "EP._":
                        result ~= parseDefaults(child);
                        break;
                }
            return result;
        } // parseForStatement

        // In parseToCode.
        string parseIfStatement(const ref ParseTree p)
        in {
            assert(p.name == "EP.IfStatement");
        }
        do {
            string result;
            foreach (child; p.children)
                final switch (child.name)
                {
                    case "EP.IF":
                        result ~= "if";
                        break;
                    case "EP.BooleanExpression":
                        result ~= "(" ~ parseToCode(child) ~ ")";
                        break;
                    case "EP.Statement":
                        result ~= parseToCode(child);
                        break;
                    case "EP._":
                        result ~= parseDefaults(child);
                        break;
                    case "EP.ELSE":
                        result ~= "else";
                        break;
                    case "EP.ElsePart":
                        result ~= parseIfStatement(child);
                        break;
                }
            return result;
        } // parseIfStatement

        // In parseToCode.
        string parseLocalSizeof(const ref ParseTree p)
        in {
            assert(p.name == "EP.LocalSizeof");
        }
        do {
            string comment, subject;
            foreach (child; p.children)
                final switch (child.name)
                {
                    case "EP._":
                        comment ~= strip(parseDefaults(child));
                        break;
                    case "EP.VariableAccess",
                         "EP.TypeName":
                        subject = contents(child);
                        break;
                }
            return subject ~ ".sizeof" ~ comment;
        } // parseLocalSizeof

        // In parseToCode.
        string parseWriteParameter(const ref ParseTree p)
        {
            import std.string;
            string[] expressions;
            string comment;
            foreach (child; p.children)
                final switch (child.name)
                {
                    case "EP.Expression":
                        expressions ~= parseToCode(child);
                        break;
                    case "EP._":
                        comment ~= stripLeft(parseDefaults(child));
                        break;
                }
            if (expressions.length == 1) {
                bool numeric = expressions[0].isNumeric;
                bool floating = numeric && expressions[0].indexOf('.') >= 0;
                if (floating)   // default width for reals: 14
                    return expressions[0] ~ ".format!\"%14g\"";
                if (numeric)    // default width for integers: 6
                    return expressions[0] ~ ".format!\"%6d\"";
                return expressions[0];
            }
            if (expressions.length == 2) {
                if (cmp(expressions[1], "1") == 0)
                    return expressions[0];
                return expressions[0] ~ ".format!\"%" ~ expressions[1] ~ "s\"";
            }
            assert(expressions.length == 3);
            return expressions[0] ~ ".format!\"%" ~ expressions[1] ~ "." ~ expressions[2] ~ "g\"";
        }

        // In parseToCode.
        string parseMainProgramBlock(const ref ParseTree p)
        in {
            assert(p.name == "EP.MainProgramBlock" || p.name == "EP.Block");
        }
        do {
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
                 "EP.WriteParameterList",
                 "EP.WritelnParameterList",
                 "EP.FileVariable",
                 "EP.Expression", "EP.SimpleExpression", "EP.Term", "EP.Factor",
                 "EP.Primary", "EP.UnsignedConstant", "EP.StringElement",
                 "EP.TypeDefinitionPart", "EP.VariableDeclarationPart",
                 "EP.ProcedureAndFunctionDeclarationPart",
                 "EP.StatementPart",
                 "EP.TypeInquiryObject",
                 "EP.VariableName",
                 "EP.SubrangeBound",
                 "EP.TypeName",
                 "EP.OrdinalTypeName",
                 "EP.TypeIdentifier",
                 "EP.RequiredTypeIdentifier",
                 "EP.ConstantIdentifier",
                 "EP.RequiredConstantIdentifier",
                 "EP.UnsignedNumber",
                 "EP.UnsignedInteger",
                 "EP.ConstantDefinitionPart",
                 "EP.StructuredStatement",
                 "EP.RepetitiveStatement",
                 "EP.AssignmentStatement",
                 "EP.VariableAccess",
                 "EP.ComponentVariable",
                 "EP.IndexedVariable",
                 "EP.ArrayVariable",
                 "EP.FieldDesignator",
                 "EP.FieldDesignatorIdentifier",
                 "EP.IndexExpression",
                 "EP.FunctionAccess",
                 "EP.EntireFunctionAccess",
                 "EP.FunctionDesignator",
                 "EP.FunctionName",
                 "EP.FunctionIdentifier",
                 "EP.ActualParameterList",
                 "EP.ActualParameter",
                 "EP.ConditionalStatement",
                 "EP.BooleanExpression",
                 "EP.LocalFunctionAccess":
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
            case "EP.WriteParameter":
                return parseWriteParameter(p);
            case "EP.DiscriminatedSchema":
                {
                    assert(icmp(contents(p.children[0]), "string") != 0, "string schema should have been handled in readTypeDenoter");
                    writeln("generic " ~ p.name ~ " is unhandled at ", __FILE__, ":", __LINE__);
                    return "";
                }
            case "EP.VariableDeclaration":
                return parseVariableDeclaration(p);
            case "EP.FunctionDeclaration":
                return parseFunctionDeclaration(p);
            case "EP.ForStatement":
                return parseForStatement(p);
            case "EP.IfStatement":
                return parseIfStatement(p);
            case "literal!(\":=\")":
                return "=";
            case "EP.LocalSizeof":
                return parseLocalSizeof(p);

            // These translate verbally
            case "EP.ProcedureName",
                 "EP.StringCharacter",
                 "EP.Identifier",
                 "EP.ParameterIdentifier",
                 "EP.ImportedInterfaceIdentifier",
                 "EP.DOT",
                 "EP.DigitSequence",
                 "literal!(\",\")",
                 "literal!(\"(\")",
                 "literal!(\")\")",
                 "literal!(\"[\")",
                 "literal!(\"]\")":
                return contents(p);

            // These are ignored
            case "EP.PROGRAM", "EP.BEGIN", "EP.END", "EP.EmptyStatement":
                return "";

            // Required procedures
            case "EP.WRITE":
                return "epcompat.write";
            case "EP.WRITELN":
                return "writeln";

            // Required simple type identifiers
            case "EP.INTEGER": return "int";
            case "EP.REAL":    return "double";
            case "EP.BOOLEAN": return "bool";
            case "EP.CHAR":    return "char";
            case "EP.COMPLEX": 
                writeln(p.name ~ " is unhandled at ", __FILE__, ":", __LINE__);
                return "";

            // Required constant identifiers
            case "EP.MAXINT":  return "int.max";
            case "EP.MINREAL": return "double.min_normal";
            case "EP.MAXREAL": return "double.max";
            case "EP.EPSREAL": return "double.epsilon";
            case "EP.FALSE":   return "false";
            case "EP.TRUE":    return "true";
            case "EP.MINCHAR": return "char.min";
            case "EP.MAXCHAR": return "char.max";

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
