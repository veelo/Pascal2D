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
  CommentOpen    <-  "{" / "(*"
  CommentClose   <-  "}" / "*)"
  CommentContent <- (Comment / !CommentClose .)*
  Comment        <- CommentOpen CommentContent CommentClose
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
                assert(p.children.length == 3);
                assert(equal(p.children[1].name, "EP.CommentContent"));
                return parseToCode(p.children[1]);
			case "EP.CommentContent":
                if(p.children.length == 0)  // No nested comments.
                    return "/*" ~ p.input[p.begin .. p.end] ~ "*/";
                // There are nested comments. All p.children are "EP.Comment".
                string contents;
                size_t begin = p.begin;
                foreach(child; p.children) {  // For each nested comment, do
                    assert(equal(child.name, "EP.Comment"));
                    contents ~= p.input[begin .. child.begin];      // Content before nested comment.
                    contents ~= parseToCode(child);                 // Nested comment.
                    begin = child.end;                              // Continue after nested comment.
                }
                contents ~= p.input[begin .. p.end];    // Content after last nested comment.
                return "/+" ~ contents ~ "+/";
			default:
				return "";
		}
	}

	return parseToCode(p);
}

void test(string pascal)
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
    test("(* Here comes a {nested} comment.}");
}
