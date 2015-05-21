import pegged.grammar;
import std.stdio;
/*
mixin(grammar(`
Comment:
  CommentOpen  <-  "{" / "(*"
  CommentClose <-  "}" / "*)"
  Comment      <- CommentOpen (Comment / !CommentClose .)* CommentClose
`));
*/

mixin(grammar(`
EP:
  CompileUnit  <- Comment eoi

# Comments can be nested:
  CommentOpen  <-  "{" / "(*"
  CommentClose <-  "}" / "*)"
  Comment      <- CommentOpen (Comment / !CommentClose .)* CommentClose
`));



unittest // Extended Pascal comments
{
	assert(EP("(* Mixed. }").successful);
	assert(EP("{Multi word comment.}").successful);
	assert(EP("{Multi line
	           comment. With \n
               \"escapes\"}").successful);
}


string toD(ParseTree p)
{
	string parseToCode(ParseTree p)
	{
		string parseComment(ParseTree p)
		{
			switch(p.name) {
				case "EP.Comment":
					assert(equal(p.children[0].name,   "EP.CommentOpen"));
					assert(equal(p.children[$-1].name, "EP.CommentClose"));
					if (p.children.length < 3)    // Not a nested commment.
						return "/*" ~ p.input[p.children[0].end .. p.children[1].begin] ~ "*/";
					// There are nested comments.
					string contents;
                    size_t begin = p.children[0].end;   // Start after own CommentOpen.
                    size_t end;
					foreach(child; p.children[1 .. $-1]) {  // For each nested comment, do
                        end = child.children[0].begin;          // Upto nested CommentOpen.
                        contents ~= p.input[begin .. end];      // Content before nested comment.
                        contents ~= parseComment(child);        // Nested comment.
                        begin = child.children[$ - 1].end;      // Continue after nested CommentClose.
                    }
                    contents ~= p.input[begin .. p.children[$ - 1].begin];   // Content after last nested comment.
                    return "/+" ~ contents ~ "+/";
                default:
                    assert(false);
			}
		}

		switch(p.name)
		{
			case "EP":
				return parseToCode(p.children[0]);	// The grammar result has only one child: the start rule's parse tree.
			case "EP.CompileUnit":
				string result;
				foreach(child; p.children)	// child is a ParseTree.
					result ~= parseToCode(child);
				return result;
			case "EP.Comment":
                return parseComment(p);
			default:
				return "";
		}
	}

	return parseToCode(p);
}

void testPascal(string pascal)
{
    auto parseTree = EP(pascal);
    writeln(parseTree);
    writeln("PASCAL:");
    writeln(pascal);
    writeln("\nD:");
    writeln(toD(parseTree));
}

/+ This is a /+ Nested +/ coment.+/
/+ This is also a /* nested */ comment +/
/* This cannot contain nested comments. */
void main()
{
    testPascal("(* Here comes a {nested} comment.}");
}
