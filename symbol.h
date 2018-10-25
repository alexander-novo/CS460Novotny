#pragma once

#include "binary_tree.hpp"
#include <string>
#include <iostream>
#include <fstream>
#include <stdexcept>

class Symbol {
	public:
		// Var type
		class SymbolType {
			public:
				SymbolType(const SymbolType& other) : name(other.name), lineNumber(other.lineNumber), scopeLevel(other.scopeLevel) {}
				bool operator < (const SymbolType& rhs) const;
				bool operator > (const SymbolType& rhs) const;
				bool operator == (const SymbolType& rhs) const;

				friend std::ostream& operator << (std::ostream& out, const SymbolType& sym);

				const std::string name;
				const unsigned lineNumber;
				const unsigned scopeLevel;
				enum Type {
					INT,
					FLOAT,
					CHAR
				} type;

				friend class Symbol;
			private:
				SymbolType(std::string key, unsigned line, unsigned scope): name(key), lineNumber(line), scopeLevel(scope) {}
		};

		enum Mode {
			READ,
			WRITE
		} mode = WRITE;

		const unsigned& scopeLevel;

		// Constructor
		Symbol();
		Symbol(const Symbol& other);

		// Operators
		Symbol& operator = (const Symbol& other);

		friend std::ostream& operator << (std::ostream& out, const Symbol& table);

		// Member functions
		unsigned pushScope();
		SymbolType* insert(const std::string& name, unsigned line);
		bool clear();
		void dumpSymbolTable();


		SymbolType* find(std::string name);
		SymbolType* findInCurrentScope(std::string name);
		unsigned popScope();

		// Destructor
		~Symbol();

	friend std::ostream& operator<< (std::ostream& stream, const Symbol& symbol);

	private:
		struct Scope {
			Scope() {}
			Scope(BinaryTree<std::string, SymbolType>* val, Scope* next_ptr): tree(val), next(next_ptr) {}
			BinaryTree<std::string, SymbolType>* tree;
			Scope* next;
		};

		Scope* head;
		unsigned _scopeLevel;
};
