/**
 * Recreate the EP parser from the grammar.
 */

import pegged.grammar;
import epgrammar;

void main()
{
	asModule!()("epparser", "epparser", EPgrammar);
}
