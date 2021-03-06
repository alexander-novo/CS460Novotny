%{
	#include <cstdio>
	#include <iostream>
	#include <string>
	#include "errors.h"
	#include <cstdlib>

	#define YYDEBUG 1

	int yyerror(SyntaxNode*& root, char *s);
	int yylex(void);

	extern Symbol table;
	extern unsigned int parseDLevel;
	extern unsigned lineno;
	extern std::string currentLine;
	void throwWarning(const std::string& warning);
	using namespace std::string_literals;
%}

%code top {
	#include "symbol.h"
	#include "node.h"
}

%union {
	Symbol::SymbolType* sval;
	long int ival;
	double fval;
	char cval;
	std::string* strval;
	std::pair<EvalType, Symbol::SymbolType*>* esval;
	EvalType* eval;
	SyntaxNode* nval;
	OperatorNode::OpType oval;
	std::pair<std::vector<EvalType>, std::vector<Symbol::SymbolType*> >* eList;
	TypeQualifier tval;
	Object::Type suval;
}

%token DEBUG_SYMBOL_TABLE
%token DEBUG_PARSER
%token DEBUG_TOKENS
%token IDENTIFIER
%token INTEGER_CONSTANT FLOATING_CONSTANT CHARACTER_CONSTANT ENUMERATION_CONSTANT
%token STRING_LITERAL
%token SIZEOF
%token PTR_OP
%token INC_OP DEC_OP
%token LEFT_OP RIGHT_OP
%token LE_OP GE_OP EQ_OP NE_OP
%token AND_OP OR_OP LNOT
%token MUL_ASSIGN DIV_ASSIGN MOD_ASSIGN ADD_ASSIGN SUB_ASSIGN
%token LEFT_ASSIGN RIGHT_ASSIGN AND_ASSIGN XOR_ASSIGN OR_ASSIGN
%token TYPEDEF_NAME
%token SEMI
%token LBRACE RBRACE
%token LPAREN RPAREN
%token LBRACKET RBRACKET
%token COMMA
%token ASSIGN
%token COLON
%left MULT DIV ADD SUB MOD
%left BAND BOR BXOR BNOT
%left HUH
%token PERIOD
%token GTHAN LTHAN
%token TYPEDEF EXTERN STATIC AUTO REGISTER
%token CHAR SHORT INT LONG SIGNED UNSIGNED FLOAT DOUBLE CONST VOLATILE VOID
%token STRUCT UNION ENUM ELIPSIS RANGE
%token ERROR

%token CASE DEFAULT IF ELSE SWITCH WHILE DO FOR GOTO CONTINUE BREAK RETURN

%type <eval> type_specifier declaration_specifiers storage_class_specifier specifier_qualifier_list type_name pointer struct_or_union_specifier
%type <eval> direct_abstract_declarator abstract_declarator
%type <oval> unary_operator assignment_operator
%type <nval> declarator multiplicative_expression additive_expression shift_expression relational_expression struct_declarator struct_declarator_list
%type <nval> equality_expression and_expression exclusive_or_expression inclusive_or_expression logical_and_expression logical_or_expression conditional_expression assignment_expression
%type <nval> direct_declarator constant primary_expression string expression identifier declaration declaration_list struct_declaration
%type <nval> postfix_expression unary_expression cast_expression initializer init_declarator init_declarator_list struct_declaration_list
%type <nval> compound_statement function_definition external_declaration translation_unit constant_expression expression_statement
%type <nval> statement statement_list labeled_statement selection_statement iteration_statement jump_statement argument_expression_list
%type <eList> parameter_list parameter_type_list
%type <tval> type_qualifier
%type <suval> struct_or_union
%type <esval> parameter_declaration

%parse-param {SyntaxNode*& root}

%start translation_unit
%%

translation_unit: external_declaration { // Node*
		$$ = root = new SyntaxNode({0, ""}, SyntaxNode::Type::GENERIC, EvalType::EUNKNOWN, 1, $1);
		if(parseDLevel) {
			std::cout << "Found Root Node: " << $1 << '\n';
		}
	}
	| translation_unit external_declaration {
		$$ = root = $1; $$->children.push_back($2);
		if(parseDLevel) {
			std::cout << "Found Root Node: " << $2 << '\n';
		}
	}
	;

external_declaration: function_definition { // Node*
		table.mode = Symbol::Mode::READ;
		$$ = $1;
	}
	| declaration {
		// Actually there shouldn't be any code generated for a declaration
		$$ = nullptr;
		if($1 != nullptr) delete $1;
		table.popBackToGlobal();
	}
	;

function_definition: declarator compound_statement
	| declarator declaration_list compound_statement
	| declaration_specifiers declarator compound_statement {
		/*
		  TODO: Apply declaration specifiers
		  Should be easy, just need to traverse tree and find identifier
		  Also need to find the eval type of the function
		*/
		//$$ = new SyntaxNode(SyntaxNode::Type::FUNCTION, EUNKNOWN, 2, $2, $3);
		if($2->type == SyntaxNode::Type::FUNCTION) {
			$$ = new FunctionNode({$2->line, $2->source}, ((FunctionNode*) $2), $3);
			delete $2;
			((FunctionNode*)$$)->func->defined = true;
			((FunctionNode*)$$)->func->functionDefLine =  lineno;
		} else {
			std::cout << $2->type << " " << $2 << std::endl;
			throw std::logic_error("Function not found where it should be");
		}

		table.popBackToGlobal();

		if(parseDLevel) {
			std::cout << "Found function: \n"
			          << $2 << '\n' << $3 << '\n';
		}
	}
	| declaration_specifiers declarator declaration_list compound_statement
	;

declaration: declaration_specifiers SEMI { // Node*
		// Ignore this
		// TODO - come back to this maybe? No use AFAIK...
		$$ = nullptr;
	}
	| declaration_specifiers init_declarator_list SEMI {
		/*
		  TODO: Apply declaration specifiers
		  This should be fairly easy, we just need to traverse the tree until we find identifiers
		*/
		EvalType tmp_type = *$1;

		if($1->isTypeDef) {
			tmp_type.isTypeDef = false;
			for (auto i : $2->children) {
				if (i->type == SyntaxNode::Type::IDENTIFIER) {
					IdentifierNode* tmp = (IdentifierNode*)i;
					tmp->etype = tmp_type;
					tmp->sym->etype = tmp_type;
					tmp->sym->itype = Symbol::SymbolType::TYPEDEF;
				}  else {
					std::cout << "Found type: " << i->type << std::endl;
					throw ParserError("Expected type IDENTIFIER for typedef");
				}
			}

			$$ = nullptr;
		} else {
			for (auto i : $2->children) {
				if (i->type == SyntaxNode::Type::IDENTIFIER) {
				IdentifierNode* tmp = (IdentifierNode*)i;
				tmp->etype |= tmp_type;
				tmp->sym->etype |= tmp_type;
				tmp->sym->itype = Symbol::SymbolType::VARIABLE;
				} else if (i->type == SyntaxNode::Type::DECLARE_AND_INIT) {
					IdentifierNode* tmp = (IdentifierNode*)i->children[0];
					tmp->etype |= tmp_type;
					tmp->sym->etype |= tmp_type;
					tmp->sym->itype = Symbol::SymbolType::VARIABLE;
				} else if (i->type == SyntaxNode::Type::FUNCTION) {
					FunctionNode* tmp = (FunctionNode*)i;
					tmp->etype |= tmp_type;
					tmp->func->returnType = tmp_type;
					tmp->sym->itype = Symbol::SymbolType::FUNCTION;
				} else {
					std::cout << "Found type: " << i->type << std::endl;
					throw ParserError("001: Expected type IDENTIFIER, FUNCTION, or DECLARE_AND_INIT");
				}
			}
			$$ = $2;
		}
	}
	;

declaration_list: declaration { // Node*
		table.mode = Symbol::Mode::READ;
		$$ = new SyntaxNode({0, ""}, SyntaxNode::Type::GENERIC, EvalType::EUNKNOWN, 1, $1);
		if(parseDLevel){
			std::cout << "declaration_list\n";
			std::cout << "GENERIC:\n"
			          << $1 << std::endl << std::endl;
		}
	}
	| declaration_list declaration {
		table.mode = Symbol::Mode::READ;
		$$ = $1;
		$1->children.push_back($2);
	}
	;

declaration_specifiers: storage_class_specifier { // EvalType*
		$$ = $1;
	}
	| storage_class_specifier declaration_specifiers {
		$$ = new EvalType(*$1 | *$2); delete $1; delete $2;
	}
	| type_specifier { $$ = $1; }
	| type_specifier declaration_specifiers {
		$$ = new EvalType(*$1 | *$2);
		delete $1;
		delete $2;
	}
	| type_qualifier {
		$$ = new EvalType(EvalType::EUNKNOWN, $1);
	}
	| type_qualifier declaration_specifiers {
		$$ = new EvalType(*$2, $1);
	}
	;

storage_class_specifier: AUTO { // EvalType*
		// TODO Actually do this
		throw ParserError("We don't handle auto");
		$$ = new EvalType(EvalType::EVOID);
	}
	| REGISTER {
		// TODO Actually do this
		throw ParserError("We don't handle register");
		$$ = new EvalType(EvalType::EVOID);
	}
	| STATIC {
		// TODO Actually do this
		throw ParserError("We don't handle static");
		$$ = new EvalType(EvalType::EVOID);
	}
	| EXTERN {
		// TODO Actually do this
		throw ParserError("We don't handle extern");
		$$ = new EvalType(EvalType::EVOID);
	}
	| TYPEDEF {
		$$ = new EvalType();
		$$->isTypeDef = true;
	}
	;

type_specifier: VOID { // EvalType*
		table.mode = Symbol::Mode::WRITE;
		$$ = new EvalType(EvalType::EVOID);
	}
	| CHAR {
		table.mode = Symbol::Mode::WRITE;
		$$ = new EvalType(EvalType::ECHAR);
	}
	| SHORT {
		table.mode = Symbol::Mode::WRITE;
		$$ = new EvalType(EvalType::ESHORT);
	}
	| INT {
		table.mode = Symbol::Mode::WRITE;
		$$ = new EvalType(EvalType::EINT);
	}
	| LONG {
		table.mode = Symbol::Mode::WRITE;
		$$ = new EvalType(EvalType::ELONG);
	}
	| FLOAT {
		table.mode = Symbol::Mode::WRITE;
		$$ = new EvalType(EvalType::EFLOAT);
	}
	| DOUBLE {
		table.mode = Symbol::Mode::WRITE;
		$$ = new EvalType(EvalType::EDOUBLE);
	}
	| SIGNED {
		table.mode = Symbol::Mode::WRITE;
		throw ParserError("Please doesn't used signed.");
	}
	| UNSIGNED {
		table.mode = Symbol::Mode::WRITE; $$ = new EvalType(EvalType::EUNSIGNED);
	}
	| struct_or_union_specifier { $$ = $1; }
	| enum_specifier {
		// TODO Actually do this
		$$ = new EvalType(EvalType::EVOID);
	}
	| TYPEDEF_NAME {
		table.mode = Symbol::Mode::WRITE;
		std::cout << yylval.sval->etype << std::endl;
		$$ = new EvalType(yylval.sval->etype);
	}
	;

type_qualifier: CONST { // TypeQualifier
		$$ = TCONST;
	}
	| VOLATILE {
		$$ = TVOLATILE;
	}
	;

struct_or_union_specifier: struct_or_union identifier LBRACE struct_declaration_list RBRACE { // EvalType*
		$$ = new EvalType();
		$$->type = EvalType::OBJECT;
		$$->obj = new Object(table, ((IdentifierNode*) $2)->sym);
		delete $2;
		delete $4;
		table.mode = Symbol::Mode::WRITE;
	}
	| struct_or_union LBRACE struct_declaration_list RBRACE {
		/* TODO: Actually do this */
		$$ = new EvalType(EvalType::EVOID);
		throw ParserError("Please do not use unnamed structs");
		table.mode = Symbol::Mode::WRITE;
	}
	| struct_or_union identifier {
		if(((IdentifierNode*) $2)->sym->itype == Symbol::SymbolType::STRUCT) {
			$$ = new EvalType();
			$$->type = EvalType::OBJECT;
			$$->obj = ((IdentifierNode*) $2)->sym->obj;

			delete $2;
			table.mode = Symbol::Mode::WRITE;
		} else {
			throw ParserError("Struct \"" + ((IdentifierNode*) $2)->sym->name + "\" has not been defined.");
		}
	}
	;

struct_or_union: STRUCT { // Object::Type
		$$ = Object::STRUCT;
		table.mode = Symbol::Mode::OBJECT;
	}
	| UNION {
		$$ = Object::UNION;
		table.mode = Symbol::Mode::OBJECT;
	}
	;

struct_declaration_list: struct_declaration { // Node*
		$$ = new SyntaxNode({lineno, currentLine}, SyntaxNode::GENERIC, EvalType::EUNKNOWN, 1, $1);
	}
	| struct_declaration_list struct_declaration {
		$$ = $1; $$->children.push_back($2);
	}
	;

init_declarator_list: init_declarator { // Node*
		table.mode = Symbol::Mode::WRITE;
		$$ = new SyntaxNode({0, ""}, SyntaxNode::Type::GENERIC, EvalType::EUNKNOWN, 1, $1);
		if(parseDLevel){
			std::cout << "init_declarator_list\n"
			          << "GENERIC:\n"
			          << $1 << std::endl;
		}
	}
	| init_declarator_list COMMA init_declarator {
		$$ = $1;
		$1->children.push_back($3);
		table.mode = Symbol::Mode::WRITE;
	}
	;

init_declarator: declarator { // Node*
		$$ = $1;
	}
	| declarator ASSIGN initializer {
		$$ = new SyntaxNode({lineno, currentLine}, SyntaxNode::Type::DECLARE_AND_INIT, EvalType::EUNKNOWN, 2, $1, $3);
		if(parseDLevel){
			std::cout << "DECLARE_AND_INIT:\n"
			          << $1 << '\n'
			          << $3 << std::endl;
		}
	}
	;

struct_declaration: specifier_qualifier_list struct_declarator_list SEMI { // Node*
		$$ = $2;

		// Apply eval types to all variables
		for(SyntaxNode* s : $2->children) {
			if(s->type != SyntaxNode::IDENTIFIER) {
				throw std::logic_error("Struct identifier not found where it should be");
			}

			((IdentifierNode*) s)->sym->etype = *$1;
			delete $1;
		}
	}
	;

specifier_qualifier_list: type_specifier { // EvalType*
		$$ = $1;
	}
	| type_specifier specifier_qualifier_list {
		$$ = new EvalType(*$1 | *$2);
		delete $1;
		delete $2;
	}
	| type_qualifier {
		throw ParserError("Please don't use const or volatile");
	}
	| type_qualifier specifier_qualifier_list {
		throw ParserError("Please don't use const or volatile");
	}
	;

struct_declarator_list: struct_declarator { // Node*
		$$ = new SyntaxNode({lineno, currentLine}, SyntaxNode::Type::GENERIC, EvalType::EUNKNOWN, 1, $1);
	}
	| struct_declarator_list COMMA struct_declarator {
		$$ = $1; $$->children.push_back($3);
	}
	;

struct_declarator: declarator { // Node*
		$$ = $1;
	}
	| COLON constant_expression {
		throw "WE WILL NEVER DO THIS GO BACK TO HELL YOU DEMON";
	}
	| declarator COLON constant_expression {
		throw "WE WILL NEVER DO THIS GO BACK TO HELL YOU DEMON";
	}
	;

enum_specifier: ENUM LBRACE enumerator_list RBRACE
	| ENUM identifier LBRACE enumerator_list RBRACE
	| ENUM identifier
	;

enumerator_list: enumerator
	| enumerator_list COMMA enumerator
	;

enumerator: identifier
	| identifier ASSIGN constant_expression
	;

declarator: direct_declarator { // Node*
		$$ = $1;
		table.mode = Symbol::Mode::READ;
	}
	| pointer direct_declarator {
		$$ = $2;
		if ($$->type == SyntaxNode::IDENTIFIER) {
			IdentifierNode* tmp = (IdentifierNode*)$$;
			tmp->sym->etype |= *$1;
			tmp->etype = tmp->sym->etype;
			std::cout << "POINTER ETYPE: " << *$1 << std::endl;
			std::cout << "ID TYPE: " << tmp->etype << std::endl;
		} else {
			throw "Error pointer";
		}
		table.mode = Symbol::Mode::READ;
	}
	;

direct_declarator: identifier { // Node*
		$$ = $1;
	}
	| LPAREN declarator RPAREN { /* Parentheses don't do anything...? */ $$ = $2; }
	| direct_declarator LBRACKET RBRACKET {
		$$ = $1;
		if($$->type == SyntaxNode::Type::IDENTIFIER) {
			IdentifierNode* node = (IdentifierNode*) $$;
			node->sym->itype = Symbol::SymbolType::VARIABLE;
			node->sym->v.isArray = true;
			node->sym->v.arrayDimensions.push_back(-1);
			++node->sym->etype;
		} else {
			throw "Error 1";
		}
	}
	| direct_declarator LBRACKET constant_expression RBRACKET {
		$$ = $1;
		if($$->type == SyntaxNode::Type::IDENTIFIER) {
			IdentifierNode* node = (IdentifierNode*) $$;
			node->sym->itype = Symbol::SymbolType::VARIABLE;
			node->sym->v.isArray = true;

			try {
				node->sym->v.arrayDimensions.push_back(evalConst($3)->i);
			} catch(ParserError e) {
				std::cout << "Error in constant evaluation: " << e.what() << std::endl;
			}

			++node->sym->etype;

			// TODO Figure this shit out
			// node->children.push_back(new ArrayNode({lineno, currentLine}, EvalType::EUNKNOWN, $3));
		} else {
			throw "Error 2";
		}
	}
	| direct_declarator LPAREN RPAREN {
		if($1->type == SyntaxNode::Type::IDENTIFIER) {
			IdentifierNode* inode = (IdentifierNode*) $1;
			inode->sym->itype = Symbol::SymbolType::FUNCTION;

			FunctionNode* fnode = nullptr;

			// See if this function already exists
			for(auto& f : inode->sym->functions) {
				if(f.paramTypes.empty()) {
					fnode = new FunctionNode({lineno, currentLine}, inode, &f);
					table.setNextScopeFunction(&f);
					break;
				}
			}

			if(fnode == nullptr) {
				// Found a new function
				Symbol::FunctionType f;
				f.name = ((IdentifierNode*) $1)->sym->name;
				inode->sym->functions.push_back(f);
				fnode = new FunctionNode({lineno, currentLine}, inode, &inode->sym->functions.back());
				table.setNextScopeFunction(&inode->sym->functions.back());
			}

			$$ = fnode;
			// TODO - set paramters
		} else {
			throw "Error 3";
		}
	}
	| direct_declarator LPAREN parameter_type_list RPAREN {
		// Passing up a FunctionNode* here, but since it inherits from IdentifierNode, we're good
		// Probably
		if($1->type == SyntaxNode::Type::IDENTIFIER) {
			int level = table.unPopScope();
			IdentifierNode* inode = (IdentifierNode*) $1;
			inode->sym->itype = Symbol::SymbolType::FUNCTION;

			FunctionNode* fnode = nullptr;

			// See if this function already exists
			for(auto& f : inode->sym->functions) {
				if(f.paramTypes == $3->first) {
					fnode = new FunctionNode({lineno, currentLine}, inode, &f);
					if(level != 0)
						table.setLastScopeFunction(&f);
					else
						table.setNextScopeFunction(&f);

					f.params = $3->second;
					break;
				}
			}

			if(fnode == nullptr) {
				// Found a new function
				Symbol::FunctionType f;
				f.name = ((IdentifierNode*) $1)->sym->name;
				f.paramTypes = $3->first;
				std::cout << std::endl;
				f.params = $3->second;
				inode->sym->functions.push_back(f);
				fnode = new FunctionNode({lineno, currentLine}, inode, &inode->sym->functions.back());
				if(level != 0)
					table.setLastScopeFunction(&inode->sym->functions.back());
				else
					table.setNextScopeFunction(&inode->sym->functions.back());
			}

			delete $3;

			$$ = fnode;
			// TODO - set paramters
		} else {
			throw "Error 4";
		}
	}
	| direct_declarator LPAREN identifier_list RPAREN {
		/* Ignore this, it won't be a feature of our language */
		$$ = nullptr;
	}
	;

pointer: MULT { // EvalType*
		$$ = new EvalType();
		$$->operator++();
	}
	| MULT type_qualifier_list {
		// TODO: figure this out
		$$ = new EvalType();
		$$->operator++();

	}
	| MULT pointer {
		$$ = $2;
		$$->operator++();

	}
	| MULT type_qualifier_list pointer {
		// TODO: figure this out
		$$ = $3;
		$$->operator++();

	}
	;

type_qualifier_list // TypeQualifier
	: type_qualifier { throw ParserError("Not dealing with this yet"); }
	| type_qualifier_list type_qualifier { throw ParserError("Not dealing with this yet"); }
	;

parameter_type_list // std::pair<std::vector<EvalType>, std::vector<Symbol::SymbolType*> >*
	: parameter_list { $$ = $1; table.mode = Symbol::Mode::READ; }
	| parameter_list COMMA ELIPSIS { throw "We ain't dealing with this shit"; table.mode = Symbol::Mode::READ; }
	;

parameter_list // std::pair<std::vector<EvalType>, std::vector<Symbol::SymbolType*> >*
	: parameter_declaration {
		// std::cout << "The thing happened" << std::endl;
		$$ = new std::pair<std::vector<EvalType>, std::vector<Symbol::SymbolType*>>();
		$$->first.push_back($1->first);
		$$->second.push_back($1->second);
		delete $1;
	}
	| parameter_list COMMA parameter_declaration {
		$$ = $1;
		$$->first.push_back($3->first);
		$$->second.push_back($3->second);
		delete $3;
	}
	;

// We only need to pass the types up the tree, for prototype matching
parameter_declaration // std::pair<EvalType*, Symbol::SymbolType*>*
	: declaration_specifiers declarator {
		IdentifierNode* tmp = (IdentifierNode*)$2;
		tmp->sym->etype = *$1 | tmp->sym->etype;
		tmp->etype = tmp->sym->etype;
		$$ = new std::pair<EvalType, Symbol::SymbolType*>(tmp->etype, tmp->sym);
	}
	| declaration_specifiers {
		$$ = new std::pair<EvalType, Symbol::SymbolType*>(*$1, nullptr);
	}
	| declaration_specifiers abstract_declarator {
		$$ = new std::pair<EvalType, Symbol::SymbolType*>(*$1, nullptr);

	}
	;

identifier_list
	: identifier
	| identifier_list COMMA identifier
	;

initializer // Node*
	: assignment_expression { $$ = $1; }
	| LBRACE initializer_list RBRACE
	| LBRACE initializer_list COMMA RBRACE
	;

initializer_list
	: initializer
	| initializer_list COMMA initializer
	;

type_name
	: specifier_qualifier_list
	| specifier_qualifier_list abstract_declarator
	;

abstract_declarator: pointer {
		$$ = new EvalType(EvalType::EUNKNOWN);
		*$$++;
	}
	| direct_abstract_declarator {
		$$ = new EvalType(*$1);
		delete $1;
	}
	| pointer direct_abstract_declarator {
		$$ = new EvalType(*$2);
		delete $2;
		*$$++;
	}
	;

direct_abstract_declarator: LPAREN abstract_declarator RPAREN { // EvalType*

	}
	| LBRACKET RBRACKET {

	}
	| LBRACKET constant_expression RBRACKET {

	}
	| direct_abstract_declarator LBRACKET RBRACKET {

	}
	| direct_abstract_declarator LBRACKET constant_expression RBRACKET {

	}
	| LPAREN RPAREN {

	}
	| LPAREN parameter_type_list RPAREN {

	}
	| direct_abstract_declarator LPAREN RPAREN {

	}
	| direct_abstract_declarator LPAREN parameter_type_list RPAREN {

	}
	;

statement // Node*
	: labeled_statement { throw ParserError("Not handling labels"); $$ = nullptr; /* TODO */ }
	| compound_statement { $$ = $1; }
	| expression_statement { $$ = $1; }
	| selection_statement { $$ = $1; }
	| iteration_statement { $$ = $1; }
	| jump_statement { $$ = $1; }
	;

labeled_statement // Node*
	: identifier COLON statement
	| CASE constant_expression COLON statement
	| DEFAULT COLON statement
	;

expression_statement // Node*
	: SEMI { $$ = nullptr; }
	| expression SEMI { $$ = $1; }
	;

compound_statement // Node*
	: LBRACE RBRACE { $$ = nullptr; }
	| LBRACE statement_list RBRACE { $$ = $2; }
	| LBRACE declaration_list RBRACE { $$ = $2; }
	| LBRACE declaration_list statement_list RBRACE { $$ = new SyntaxNode({0, ""}, SyntaxNode::Type::GENERIC, EvalType::EUNKNOWN, 2, $2, $3); }
	;

statement_list // Node*
	: statement { $$ = new SyntaxNode({0, ""}, SyntaxNode::Type::GENERIC, EvalType::EUNKNOWN, 1, $1); }
	| statement_list statement { $$ = $1; $$->children.push_back($2); }
	;

selection_statement // Node*
	: IF LPAREN expression RPAREN statement { $$ = new SyntaxNode({$3->line, $3->source}, SyntaxNode::Type::CONDITIONAL, EvalType::EVOID, 2, $3, $5); }
	| IF LPAREN expression RPAREN statement ELSE statement { $$ = new SyntaxNode({$3->line, $3->source}, SyntaxNode::Type::CONDITIONAL, EvalType::EVOID, 3, $3, $5, $7); }
	| SWITCH LPAREN expression RPAREN statement { $$ = nullptr; /* TODO: Switch Statements */ }
	;

iteration_statement // Node*
	: WHILE LPAREN expression RPAREN statement { $$ = new LoopNode({$3->line, $3->source}, $3, $5); }
	| DO statement WHILE LPAREN expression RPAREN SEMI { $$ = new LoopNode({$2->line, $2->source}, $5, $2, false); }
	| FOR LPAREN SEMI SEMI RPAREN statement { $$ = new LoopNode({lineno, currentLine}, nullptr, nullptr, nullptr, $6); }
	| FOR LPAREN SEMI SEMI expression RPAREN statement { $$ = new LoopNode({$5->line, $5->source}, nullptr, nullptr, $5, $7); }
	| FOR LPAREN SEMI expression SEMI RPAREN statement { $$ = new LoopNode({$4->line, $4->source}, nullptr, $4, nullptr, $7); }
	| FOR LPAREN SEMI expression SEMI expression RPAREN statement { $$ = new LoopNode({$4->line, $4->source}, nullptr, $4, $6, $8); }
	| FOR LPAREN expression SEMI SEMI RPAREN statement { $$ = new LoopNode({$3->line, $3->source}, $3, nullptr, nullptr, $7); }
	| FOR LPAREN expression SEMI SEMI expression RPAREN statement { $$ = new LoopNode({$3->line, $3->source}, $3, nullptr, $6, $8); }
	| FOR LPAREN expression SEMI expression SEMI RPAREN statement { $$ = new LoopNode({$3->line, $3->source}, $3, $5, nullptr, $8); }
	| FOR LPAREN expression SEMI expression SEMI expression RPAREN statement { $$ = new LoopNode({$3->line, $3->source}, $3, $5, $7, $9); }
	;

jump_statement // Node*
	: GOTO identifier SEMI { throw ParserError("We aren't handling GOTO statements"); }
	| CONTINUE SEMI { throw ParserError("We aren't handling continue statements yet"); /*TODO: Continue statements */ $$ = nullptr; }
	| BREAK SEMI { throw ParserError("We aren't handling break statements yet"); /*TODO: Break statements */ $$ = nullptr; }
	| RETURN SEMI { $$ = new SyntaxNode({lineno, currentLine}, SyntaxNode::Type::RETURN, EvalType::EVOID, 0); }
	| RETURN expression SEMI { $$ = new SyntaxNode({lineno, currentLine}, SyntaxNode::Type::RETURN, EvalType::EVOID, 1, $2); }
	;

expression // Node*
	: assignment_expression {
		$$ = $1;
	}
	| expression COMMA assignment_expression { $$ = $1; $$->children.push_back($3); }
	;

assignment_expression // Node*
	: conditional_expression { $$ = $1; }
	| unary_expression assignment_operator assignment_expression {
		bool shouldCoerce = $1->etype != $3->etype;
		EvalType from, to;
		if (shouldCoerce) {
			from = $3->etype;
			to = $1->etype;
		}
		if($2 == OperatorNode::OpType::OTERNARY) {
			if (shouldCoerce) {
				CoercionNode* coerce = new CoercionNode({lineno, currentLine}, from, to, $3);
				$$ = new SyntaxNode({lineno, currentLine}, SyntaxNode::Type::ASSIGN, $1->etype, 2, $1, coerce);
			} else {
				$$ = new SyntaxNode({lineno, currentLine}, SyntaxNode::Type::ASSIGN, $1->etype, 2, $1, $3);
			}
		} else {
			if(shouldCoerce) {
				$$ = new OperatorNode({lineno, currentLine}, to, $2, 2, $1, new CoercionNode({lineno, currentLine}, from, to, $3));
			} else {
				$$ = new OperatorNode({lineno, currentLine}, to, $2, 2, $1, $3);
			}
		}
	}
	;

assignment_operator // OperatorNode::OpType
	: ASSIGN { $$ = OperatorNode::OpType::OTERNARY; }
	| MUL_ASSIGN { $$ = OperatorNode::OpType::OMULTEQ; }
	| DIV_ASSIGN { $$ = OperatorNode::OpType::ODIVEQ; }
	| MOD_ASSIGN { $$ = OperatorNode::OpType::OMODEQ; }
	| ADD_ASSIGN { $$ = OperatorNode::OpType::OADDEQ; }
	| SUB_ASSIGN { $$ = OperatorNode::OpType::OSUBEQ; }
	| LEFT_ASSIGN { $$ = OperatorNode::OpType::OLEFTEQ; }
	| RIGHT_ASSIGN { $$ = OperatorNode::OpType::ORIGHTEQ; }
	| AND_ASSIGN { $$ = OperatorNode::OpType::OANDEQ; }
	| XOR_ASSIGN { $$ = OperatorNode::OpType::OXOREQ; }
	| OR_ASSIGN { $$ = OperatorNode::OpType::OOREQ; }
	;

conditional_expression // Node*
	: logical_or_expression { $$ = $1; }
	| logical_or_expression HUH expression COLON conditional_expression {
		$$ = new OperatorNode({lineno, currentLine}, EvalType::EINT, OperatorNode::OpType::OTERNARY, 3, $1, $3, $5);
	}
	;

constant_expression // Node*
	: conditional_expression { $$ = $1; }
	;

logical_or_expression // Node*
	: logical_and_expression { $$ = $1; }
	| logical_or_expression OR_OP logical_and_expression {
		if ($1->etype != $3->etype) {
			if ($1->etype.type == EvalType::OBJECT || $3->etype.type == EvalType::OBJECT) {
				throw ParserError("Cannot perform operation '||' on non primative types.");
			}
			if ($1->etype > $3->etype) {
				$$ = new OperatorNode({lineno, currentLine}, EvalType::EINT, OperatorNode::OpType::OLOR, 2, $1, new CoercionNode({lineno, currentLine}, $3->etype, $1->etype, $3));
			} else {
				$$ = new OperatorNode({lineno, currentLine}, EvalType::EINT, OperatorNode::OpType::OLOR, 2, new CoercionNode({lineno, currentLine}, $1->etype, $3->etype, $1), $3);
			}
		} else {
			$$ = new OperatorNode({lineno, currentLine}, EvalType::EINT, OperatorNode::OpType::OLOR, 2, $1, $3);
		}
	}
	;

logical_and_expression // Node*
	: inclusive_or_expression { $$ = $1; }
	| logical_and_expression AND_OP inclusive_or_expression {
		if ($1->etype != $3->etype) {
			if ($1->etype.type == EvalType::OBJECT || $3->etype.type == EvalType::OBJECT) {
				throw ParserError("Cannot perform operation '&&' on non primative types.");
			}
			if ($1->etype > $3->etype) {
				$$ = new OperatorNode({lineno, currentLine}, EvalType::EINT, OperatorNode::OpType::OLAND, 2, $1, new CoercionNode({lineno, currentLine}, $3->etype, $1->etype, $3));
			} else {
				$$ = new OperatorNode({lineno, currentLine}, EvalType::EINT, OperatorNode::OpType::OLAND, 2, new CoercionNode({lineno, currentLine}, $1->etype, $3->etype, $1), $3);
			}
		} else {
			$$ = new OperatorNode({lineno, currentLine}, EvalType::EINT, OperatorNode::OpType::OLAND, 2, $1, $3);
		}
	}
	;

inclusive_or_expression // Node*
	: exclusive_or_expression { $$ = $1; }
	| inclusive_or_expression BOR exclusive_or_expression {
		if (!($1->etype.type == EvalType::INTEGER) || !($3->etype.type == EvalType::INTEGER)) {
			throw ParserError("Cannot perform operation '|' on non integral types.");
		}
		if ($1->etype != $3->etype) {
			if ($1->etype.type == EvalType::OBJECT || $3->etype.type == EvalType::OBJECT) {
				throw ParserError("Cannot perform operation '|' on non primative types.");
			}
			if ($1->etype > $3->etype) {
				$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::OBOR, 2, $1, new CoercionNode({lineno, currentLine}, $3->etype, $1->etype, $3));
			} else {
				$$ = new OperatorNode({lineno, currentLine}, $3->etype, OperatorNode::OpType::OBOR, 2, new CoercionNode({lineno, currentLine}, $1->etype, $3->etype, $1), $3);
			}
		} else {
			$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::OBOR, 2, $1, $3);
		}
	}
	;

exclusive_or_expression // Node*
	: and_expression { $$ = $1; }
	| exclusive_or_expression BXOR and_expression {
		if (!($1->etype.type == EvalType::INTEGER) || !($3->etype.type == EvalType::INTEGER)) {
			throw ParserError("Cannot perform operation '^' on non integral types.");
		}
		if ($1->etype != $3->etype) {
			if ($1->etype.type == EvalType::OBJECT || $3->etype.type == EvalType::OBJECT) {
				throw ParserError("Cannot perform operation '^' on non primative types.");
			}
			if ($1->etype > $3->etype) {
				$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::OBXOR, 2, $1, new CoercionNode({lineno, currentLine}, $3->etype, $1->etype, $3));
			} else {
				$$ = new OperatorNode({lineno, currentLine}, $3->etype, OperatorNode::OpType::OBXOR, 2, new CoercionNode({lineno, currentLine}, $1->etype, $3->etype, $1), $3);
			}
		} else {
			$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::OBXOR, 2, $1, $3);
		}
	}
	;

and_expression // Node*
	: equality_expression { $$ = $1; }
	| and_expression BAND equality_expression {
		if (!($1->etype.type == EvalType::INTEGER) || !($3->etype.type == EvalType::INTEGER)) {
			throw ParserError("Cannot perform operation '&' on non integral types.");
		}
		if ($1->etype != $3->etype) {
			if ($1->etype.type == EvalType::OBJECT || $3->etype.type == EvalType::OBJECT) {
				throw ParserError("Cannot perform operation '&' on non primative types.");
			}
			if ($1->etype > $3->etype) {
				$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::OBAND, 2, $1, new CoercionNode({lineno, currentLine}, $3->etype, $1->etype, $3));
			} else {
				$$ = new OperatorNode({lineno, currentLine}, $3->etype, OperatorNode::OpType::OBAND, 2, new CoercionNode({lineno, currentLine}, $1->etype, $3->etype, $1), $3);
			}
		} else {
			$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::OBAND, 2, $1, $3);
		}
	}
	;

equality_expression // Node*
	: relational_expression { $$ = $1; }
	| equality_expression EQ_OP relational_expression {
		if ($1->etype != $3->etype) {
			if ($1->etype.type == EvalType::OBJECT || $3->etype.type == EvalType::OBJECT) {
				throw ParserError("Cannot perform operation '==' on non primative types.");
			}
			if ($1->etype > $3->etype) {
				$$ = new OperatorNode({lineno, currentLine}, EvalType::EINT, OperatorNode::OpType::OEQUAL, 2, $1, new CoercionNode({lineno, currentLine}, $3->etype, $1->etype, $3));
			} else {
				$$ = new OperatorNode({lineno, currentLine}, EvalType::EINT, OperatorNode::OpType::OEQUAL, 2, new CoercionNode({lineno, currentLine}, $1->etype, $3->etype, $1), $3);
			}
		} else {
			$$ = new OperatorNode({lineno, currentLine}, EvalType::EINT, OperatorNode::OpType::OEQUAL, 2, $1, $3);
		}
	}
	| equality_expression NE_OP relational_expression {
		if ($1->etype != $3->etype) {
			if ($1->etype.type == EvalType::OBJECT || $3->etype.type == EvalType::OBJECT) {
				throw ParserError("Cannot perform operation '!=' on non primative types.");
			}
			if ($1->etype > $3->etype) {
				$$ = new OperatorNode({lineno, currentLine}, EvalType::EINT, OperatorNode::OpType::ONEQ, 2, $1, new CoercionNode({lineno, currentLine}, $3->etype, $1->etype, $3));
			} else {
				$$ = new OperatorNode({lineno, currentLine}, EvalType::EINT, OperatorNode::OpType::ONEQ, 2, new CoercionNode({lineno, currentLine}, $1->etype, $3->etype, $1), $3);
			}
		} else {
			$$ = new OperatorNode({lineno, currentLine}, EvalType::EINT, OperatorNode::OpType::ONEQ, 2, $1, $3);
		}
	}
	;

relational_expression // Node*
	: shift_expression { $$ = $1; }
	| relational_expression LTHAN shift_expression {
		if ($1->etype != $3->etype) {
			if ($1->etype.type == EvalType::OBJECT || $3->etype.type == EvalType::OBJECT) {
				throw ParserError("Cannot perform operation '<' on non primative types.");
			}
			if ($1->etype > $3->etype) {
				$$ = new OperatorNode({lineno, currentLine}, EvalType::EINT, OperatorNode::OpType::OLESS, 2, $1, new CoercionNode({lineno, currentLine}, $3->etype, $1->etype, $3));
			} else {
				$$ = new OperatorNode({lineno, currentLine}, EvalType::EINT, OperatorNode::OpType::OLESS, 2, new CoercionNode({lineno, currentLine}, $1->etype, $3->etype, $1), $3);
			}
		} else {
			$$ = new OperatorNode({lineno, currentLine}, EvalType::EINT, OperatorNode::OpType::OLESS, 2, $1, $3);
		}
	}
	| relational_expression GTHAN shift_expression {
		if ($1->etype != $3->etype) {
			if ($1->etype.type == EvalType::OBJECT || $3->etype.type == EvalType::OBJECT) {
				throw ParserError("Cannot perform operation '>' on non primative types.");
			}
			if ($1->etype > $3->etype) {
				$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::OGREAT, 2, $1, new CoercionNode({lineno, currentLine}, $3->etype, $1->etype, $3));
			} else {
				$$ = new OperatorNode({lineno, currentLine}, $3->etype, OperatorNode::OpType::OGREAT, 2, new CoercionNode({lineno, currentLine}, $1->etype, $3->etype, $1), $3);
			}
		} else {
			$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::OGREAT, 2, $1, $3);
		}
	}
	| relational_expression LE_OP shift_expression {
		if ($1->etype != $3->etype) {
			if ($1->etype.type == EvalType::OBJECT || $3->etype.type == EvalType::OBJECT) {
				throw ParserError("Cannot perform operation '<=' on non primative types.");
			}
			if ($1->etype > $3->etype) {
				$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::OLEQ, 2, $1, new CoercionNode({lineno, currentLine}, $3->etype, $1->etype, $3));
			} else {
				$$ = new OperatorNode({lineno, currentLine}, $3->etype, OperatorNode::OpType::OLEQ, 2, new CoercionNode({lineno, currentLine}, $1->etype, $3->etype, $1), $3);
			}
		} else {
			$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::OLEQ, 2, $1, $3);
		}
	}
	| relational_expression GE_OP shift_expression {
		if ($1->etype != $3->etype) {
			if ($1->etype.type == EvalType::OBJECT || $3->etype.type == EvalType::OBJECT) {
				throw ParserError("Cannot perform operation '>=' on non primative types.");
			}
			if ($1->etype > $3->etype) {
				$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::OGEQ, 2, $1, new CoercionNode({lineno, currentLine}, $3->etype, $1->etype, $3));
			} else {
				$$ = new OperatorNode({lineno, currentLine}, $3->etype, OperatorNode::OpType::OGEQ, 2, new CoercionNode({lineno, currentLine}, $1->etype, $3->etype, $1), $3);
			}
		} else {
			$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::OGEQ, 2, $1, $3);
		}
	}
	;

shift_expression // Node*
	: additive_expression { $$ = $1; }
	| shift_expression LEFT_OP additive_expression {
		if (!($1->etype.type == EvalType::INTEGER) || !($3->etype.type == EvalType::INTEGER)) {
			throw ParserError("Operator '<<' not valid on non integral types.");
		}
		if ($1->etype != $3->etype) {
			if ($1->etype.type == EvalType::OBJECT || $3->etype.type == EvalType::OBJECT) {
				throw ParserError("Cannot perform operation '<<' on non primative types.");
			}
			if ($1->etype > $3->etype) {
				$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::OLSHIFT, 2, $1, new CoercionNode({lineno, currentLine}, $3->etype, $1->etype, $3));
			} else {
				$$ = new OperatorNode({lineno, currentLine}, $3->etype, OperatorNode::OpType::OLSHIFT, 2, new CoercionNode({lineno, currentLine}, $1->etype, $3->etype, $1), $3);
			}
		} else {
			$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::OLSHIFT, 2, $1, $3);
		}
	}
	| shift_expression RIGHT_OP additive_expression {
		if (!($1->etype.type == EvalType::INTEGER) || !($3->etype.type == EvalType::INTEGER)) {
			throw ParserError("Operator '>>' not valid on non integral types.");
		}
		if ($1->etype != $3->etype) {
			if ($1->etype.type == EvalType::OBJECT || $3->etype.type == EvalType::OBJECT) {
				throw ParserError("Cannot perform operation '>>' on non primative types.");
			}
			if ($1->etype > $3->etype) {
				$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::ORSHIFT, 2, $1, new CoercionNode({lineno, currentLine}, $3->etype, $1->etype, $3));
			} else {
				$$ = new OperatorNode({lineno, currentLine}, $3->etype, OperatorNode::OpType::ORSHIFT, 2, new CoercionNode({lineno, currentLine}, $1->etype, $3->etype, $1), $3);
			}
		} else {
			$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::ORSHIFT, 2, $1, $3);
		}
	}
	;

additive_expression // Node*
	: multiplicative_expression { $$ = $1; }
	| additive_expression ADD multiplicative_expression {
		if ($1->etype != $3->etype) {
			if ($1->etype.type == EvalType::OBJECT || $3->etype.type == EvalType::OBJECT) {
				throw ParserError("Cannot perform operation '+' on non primative types.");
			}
			if ($1->etype > $3->etype) {
				$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::OADD, 2, $1, new CoercionNode({lineno, currentLine}, $3->etype, $1->etype, $3));
			} else {
				$$ = new OperatorNode({lineno, currentLine}, $3->etype, OperatorNode::OpType::OADD, 2, new CoercionNode({lineno, currentLine}, $1->etype, $3->etype, $1), $3);
			}
		} else {
			$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::OADD, 2, $1, $3);
		}
	}
	| additive_expression SUB multiplicative_expression {
		if ($1->etype != $3->etype) {
			if ($1->etype.type == EvalType::OBJECT || $3->etype.type == EvalType::OBJECT) {
				throw ParserError("Cannot perform operation '-' on non primative types.");
			}
			if ($1->etype > $3->etype) {
				$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::OSUB, 2, $1, new CoercionNode({lineno, currentLine}, $3->etype, $1->etype, $3));
			} else {
				$$ = new OperatorNode({lineno, currentLine}, $3->etype, OperatorNode::OpType::OSUB, 2, new CoercionNode({lineno, currentLine}, $1->etype, $3->etype, $1), $3);
			}
		} else {
			$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::OSUB, 2, $1, $3);
		}
	}
	;

multiplicative_expression // Node*
	: cast_expression { $$ = $1; }
	| multiplicative_expression MULT cast_expression {
		if ($1->etype != $3->etype) {
			if ($1->etype.type == EvalType::OBJECT || $3->etype.type == EvalType::OBJECT) {
				throw ParserError("Cannot perform operation '*' on non primative types.");
			}
			if ($1->etype > $3->etype) {
				$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::OMULT, 2, $1, new CoercionNode({lineno, currentLine}, $3->etype, $1->etype, $3));
			} else {
				$$ = new OperatorNode({lineno, currentLine}, $3->etype, OperatorNode::OpType::OMULT, 2, new CoercionNode({lineno, currentLine}, $1->etype, $3->etype, $1), $3);
			}
		} else {
			$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::OMULT, 2, $1, $3);
		}
	}
	| multiplicative_expression DIV cast_expression {
		if ($1->etype != $3->etype) {
			if ($1->etype.type == EvalType::OBJECT || $3->etype.type == EvalType::OBJECT) {
				throw ParserError("Cannot perform operation '/' on non primative types.");
			}
			if ($1->etype > $3->etype) {
				$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::ODIV, 2, $1, new CoercionNode({lineno, currentLine}, $3->etype, $1->etype, $3));
			} else {
				$$ = new OperatorNode({lineno, currentLine}, $3->etype, OperatorNode::OpType::ODIV, 2, new CoercionNode({lineno, currentLine}, $1->etype, $3->etype, $1), $3);
			}
		} else {
			$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::ODIV, 2, $1, $3);
		}
	}
	| multiplicative_expression MOD cast_expression {
		if (!$1->etype.integral() || !$3->etype.integral()) {
			std::cout << $1->etype << '\n' << $3->etype << std::endl;
			throw ParserError("Operator '%' not valid on non integral types.");
		}
		if ($1->etype != $3->etype) {
			if ($1->etype.type == EvalType::OBJECT || $3->etype.type == EvalType::OBJECT) {
				throw ParserError("Cannot perform operation '%' on non primative types.");
			}
			if ($1->etype > $3->etype) {
				$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::OMOD, 2, $1, new CoercionNode({lineno, currentLine}, $3->etype, $1->etype, $3));
			} else {
				$$ = new OperatorNode({lineno, currentLine}, $3->etype, OperatorNode::OpType::OMOD, 2, new CoercionNode({lineno, currentLine}, $1->etype, $3->etype, $1), $3);
			}
		} else {
			$$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OpType::OMOD, 2, $1, $3);
		}
	}
	;

cast_expression: unary_expression { // Node*
		$$ = $1;
	}
	| LPAREN type_name {table.mode = Symbol::READ;} RPAREN cast_expression { $$ = new CoercionNode({lineno, currentLine}, $5->etype, *$2, $5); delete $2; }
	;

unary_expression: postfix_expression { // Node*
		$$ = $1;
	}
	| INC_OP unary_expression { $$ = new OperatorNode({lineno, currentLine}, $2->etype, OperatorNode::OINC, 1, $2); }
	| DEC_OP unary_expression { $$ = new OperatorNode({lineno, currentLine}, $2->etype, OperatorNode::ODEC, 1, $2); }
	| unary_operator cast_expression {
		EvalType _type;
		switch($1) {
			case OperatorNode::OREF:
				_type = $2->etype;
				std::cout << "OLD TYPE: " << _type << std::endl;
				_type.operator++();
				std::cout << "NEW TYPE: " << _type << std::endl;
				break;
			case OperatorNode::ODEREF:
				_type = $2->etype;
				_type.operator--();
				break;
			case OperatorNode::OADD:
				throw ParserError("Not handling the unary '+' operator");
				break;
			case OperatorNode::OSUB:
				if (!$2->etype.sign) {
					throwWarning("Taking 2's complement of unsigned type.");
				}
			case OperatorNode::OBNOT:
			case OperatorNode::OLNOT:
				_type = $2->etype;
				break;
			default:
				break;
		}
		$$ = new OperatorNode({lineno, currentLine}, _type, $1, 1, $2);
	}
	| SIZEOF unary_expression { $$ = new OperatorNode({lineno, currentLine}, EvalType::EINT | EvalType::EUNSIGNED, OperatorNode::OSIZE, 1, $2); }
	| SIZEOF LPAREN type_name RPAREN { $$ = new OperatorNode({lineno, currentLine}, EvalType::EINT | EvalType::EUNSIGNED, OperatorNode::OSIZE, 1, $3); }
	;

unary_operator // OperatorNode::OpType
	: BAND { $$ = OperatorNode::OREF; }
	| MULT { $$ = OperatorNode::ODEREF; }
	| ADD { /* https://docs.microsoft.com/en-us/cpp/c-language/unary-arithmetic-operators?view=vs-2017 */ $$ = OperatorNode::OADD; }
	| SUB { $$ = OperatorNode::OSUB; }
	| BNOT { $$ = OperatorNode::OBNOT; }
	| LNOT { $$ = OperatorNode::OLNOT; }
	;

postfix_expression: primary_expression { // Node*
		$$ = $1;
	}
	| postfix_expression LBRACKET expression RBRACKET {
		if ($1->type == SyntaxNode::ACCESS) {
			if ($1->children[0]->type == SyntaxNode::IDENTIFIER) {
				if(((IdentifierNode*) $1->children[0])->sym->v.arrayDimensions.size() < $1->children.size()) {
					throw ParserError("Array dimensions not large enough for level of dereference");
				}
				$1->children.push_back($3);
				$$ = $1;
				$$->etype.operator--();
			} else if ($1->children[0]->type == SyntaxNode::STRUCT_ACCESS) {
				if (((IdentifierNode*) $1->children[0]->children[1])->sym->v.arrayDimensions.size() < $1->children[0]->children.size()) {
					throw ParserError("Array dimensions not large enough for level of dereference");
				}

				$1->children.push_back($3);
				$$ = $1;
				$$->etype.operator--();
			}

		} else if ($1->type == SyntaxNode::IDENTIFIER) {
			if(((IdentifierNode*) $1)->sym->v.arrayDimensions.size() == 0) {
				throw ParserError("Trying to dereference variable of non-pointer type");
			}

			$$ = new SyntaxNode({lineno, currentLine}, SyntaxNode::ACCESS, $1->etype, 2, $1, $3);
			$$->etype.operator--();
		} else if ($1->type == SyntaxNode::STRUCT_ACCESS) {
			if(((IdentifierNode*) $1->children[1])->sym->v.arrayDimensions.size() == 0) {
				throw ParserError("Trying to dereference variable of non-pointer type");
			}
			$$ = new SyntaxNode({lineno, currentLine}, SyntaxNode::ACCESS, $1->etype, 2, $1, $3);
		} else {
			throw ParserError("Expected identifier for array access");
		}
	}
	| postfix_expression LPAREN RPAREN {
		if ($1->type != SyntaxNode::Type::IDENTIFIER) {
			throw ParserError("002: Expected type IDENTIFIER.");
		}
		IdentifierNode* tmp = (IdentifierNode*)$1;
		$$ = nullptr;
		for (auto& f : tmp->sym->functions) {
			if (f.paramTypes.empty()) {
				$$ = new FunctionCallNode({lineno, currentLine}, tmp->sym, &f);
			}
		}
		if ($$ == nullptr) {
			std::cout << tmp->sym->name << std::endl;
			throw ParserError("No matching function to call.");
		}
	}
	| postfix_expression LPAREN argument_expression_list RPAREN {
		if ($1->type != SyntaxNode::Type::IDENTIFIER) {
			throw ParserError("003: Expected type IDENTIFIER.");
		}
		IdentifierNode* tmp = (IdentifierNode*)$1;
		$$ = nullptr;
		std::vector<EvalType> paramTypes;
		for (const auto& i : $3->children) {
			paramTypes.push_back(i->etype);
		}

		std::cout << "PARAM TYPES: ";
		for (const auto& i : paramTypes) { std::cout << i << "; "; }
		std::cout << std::endl;
		for (auto& f : tmp->sym->functions) {
			std::cout << "FUNCTION TYPES: ";
			for (const auto& i : f.paramTypes) { std::cout << i << "; "; }
			std::cout << std::endl;
			if (f.paramTypes == paramTypes) {
				$$ = new FunctionCallNode({lineno, currentLine}, tmp->sym, &f, $3);
				break;
			}
		}
		if ($$ == nullptr) {
			std::cout << tmp->sym->name << std::endl;
			throw ParserError("No matching function to call.");
		}
	}
	| postfix_expression PERIOD {
		if($1->etype.type != EvalType::OBJECT) {
			throw ParserError("Attempted to use '.' operator on non-object type.");
		}
		table.setCurrentObject($1->etype.obj);
	} identifier {
		$$ = new SyntaxNode({lineno, currentLine}, SyntaxNode::STRUCT_ACCESS, $4->etype, 2, $1, $4);
		table.setCurrentObject(nullptr);
	}
	| postfix_expression PTR_OP {
		if ($1->etype.type != EvalType::OBJECT || $1->etype.pointer() != 1) {
			throw ParserError("Attempted to use '->' operator on non-object or non pointer type.");
		}
		table.setCurrentObject($1->etype.obj);
	} identifier {
		OperatorNode* tmp = new OperatorNode({lineno, currentLine}, --($1->etype), OperatorNode::ODEREF, 1, $1);
		$$ = new SyntaxNode({lineno, currentLine}, SyntaxNode::STRUCT_ACCESS, $4->etype, 2, tmp, $4);
		table.setCurrentObject(nullptr);
	}
	| postfix_expression INC_OP { $$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::OINCPOST, 1, $1); }
	| postfix_expression DEC_OP { $$ = new OperatorNode({lineno, currentLine}, $1->etype, OperatorNode::ODECPOST, 1, $1); }
	;

primary_expression // Node*
	: identifier { $$ = $1; }
	| constant { $$ = $1; }
	| string { $$ = $1; }
	| LPAREN expression RPAREN { $$ = $2; }
	;

argument_expression_list // Node*
	: assignment_expression { $$ = new SyntaxNode({0, ""}, SyntaxNode::Type::GENERIC, EvalType::EUNKNOWN, 1, $1); }
	| argument_expression_list COMMA assignment_expression { $$ = $1; $$->children.push_back($3); }
	;

constant
	: INTEGER_CONSTANT { $$ = new ConstantNode({lineno, currentLine}, EvalType::EINT, yylval.ival); }
	| CHARACTER_CONSTANT { $$ = new ConstantNode({lineno, currentLine}, EvalType::ECHAR, (long int)(yylval.cval)); }
	| FLOATING_CONSTANT { $$ = new ConstantNode({lineno, currentLine}, EvalType::EFLOAT, yylval.fval); }
	| ENUMERATION_CONSTANT { /* TODO(Rowan) -- Fix later. */ $$ = nullptr; }
	;

string
	: STRING_LITERAL { $$ = new ConstantNode({lineno, currentLine}, EvalType::ESTRING, yylval.strval); }
	;

identifier
	: IDENTIFIER {
		$$ = new IdentifierNode({lineno, currentLine}, yylval.sval);
		if(parseDLevel) {
			std::cout << "Found new identifier node: " << yylval.sval->name << std::endl;
		}
	}
	;

%%
