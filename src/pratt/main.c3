module pratt;

import std::io, std::collections::list;
import c3::lexer;

fn void print_repl() @inline
{
	io::print("pratt> ");
}

fn void main() => @pool()
{
	io::printfn("Pratt REPL -- print 'q' to quit.");
	print_repl();
	while (try s = io::treadline(io::stdin()))
	{
		if (s == "q") break;
		PrattParser p;
		p.init(s);
		if (try e = p.parse())
		{
			io::printn(e);
		}
		else
		{
			io::printfn(" -- Parse() failed");
		}
		print_repl();
	}
}

struct PrattParser
{
	Lexer     lexer;
	TokenList read;
}

alias TokenList = List{Token};

fn void PrattParser.init(&self, String s)
{
	Lexer lexer;
	lexer.init(s);
	*self = { .lexer = lexer };
	self.read.tinit();
}

fn Token PrattParser.peek(&self) => self.lookahead(0);

fn Token PrattParser.lookahead(&self, int n)
{
	while (n-- >= 0 && !self.lexer.at_end()) self.read.push(self.lexer.next()!!);
	if (!self.read.len()) return {};
	return self.read.first()!!;
}

fn Token PrattParser.consume(&self)
{
	self.lookahead(0);
	return self.read.pop_first()!!;
}

fn int PrattParser.precedence(&self)
{
	Parselet p = pratt_table[self.peek().type.ordinal];
	return p.bp;
}

fn Expr*? PrattParser.parse(&self) => parse_expr(self, 0)!;

fn Expr*? parse_expr(PrattParser *p, int min_bp)
{
	Token tok = p.consume();

	Parselet parselet = pratt_table[tok.type.ordinal];
	assert(parselet.prefix, "No prefix parselet defined for %s", tok);

	Expr *left = parselet.prefix(p, tok)!;

	while (min_bp < p.precedence())
	{
		tok = p.consume();
		parselet = pratt_table[tok.type.ordinal];
		if (parselet.infix == null) break;

		left = parselet.infix(p, left, tok)!;
	}

	return left;
}

/*
 Parslets
*/

alias PrefixParselet = fn Expr*? (PrattParser *p, Token tok);
alias InfixParselet  = fn Expr*? (PrattParser *p, Expr *left, Token tok);

enum Associativity : const inline char
{
	ASSOC_NONE  = 0,
	ASSOC_RIGHT = 0,
	ASSOC_LEFT,
}

struct Parselet
{
	PrefixParselet prefix;
	InfixParselet  infix;
	int            bp;
	Associativity  assoc;
}

Parselet[*] pratt_table = {
	[TokenType.INTEGER.ordinal] = { &parse_number, null,           0, ASSOC_NONE },
	[TokenType.PLUS.ordinal]    = { null,          &parse_binary, 10, ASSOC_LEFT },
	[TokenType.STAR.ordinal]    = { null,          &parse_binary, 20, ASSOC_LEFT },
	[TokenType.EOF.ordinal]     = {},
};

fn Expr*? parse_number(PrattParser *p, Token tok)
{
	Expr *e = mem::tnew(Expr);
	*e = { .kind = NUMBER_EXPR, .as.n = { tok } };
	return e;
}

fn Expr*? parse_binary(PrattParser *p, Expr *left, Token tok)
{
	Parselet parselet = pratt_table[tok.type.ordinal];
	int next_bp = parselet.bp + parselet.assoc; // If left assoc, add 1 to bp.

	Expr* right = parse_expr(p, next_bp)!;

	Expr *e = mem::tnew(Expr);
	*e = { .kind = BINARY_EXPR, .as.b = { tok, left, right} };

	return e;
}


/*
 Expressions
*/

struct NumberExpression
{
	Token num;
}

struct BinaryExpression
{
	Token op;
	Expr *left;
	Expr *right;
}

enum ExprKind
{
	NUMBER_EXPR,
	BINARY_EXPR
}

struct Expr (Printable)
{
	ExprKind kind;
	union as {
		NumberExpression n;
		BinaryExpression b;
	}
}

fn usz? Expr.to_format(&self, Formatter *f) @dynamic
{
	usz n;
	switch (self.kind)
	{
		case NUMBER_EXPR: n += f.printf("%s", self.as.n.num)!;
		case BINARY_EXPR: n += f.printf("( %s %s %s )", self.as.b.left, self.as.b.op, self.as.b.right)!;
	}
	return n;
}

