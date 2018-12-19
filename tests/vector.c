int readInt();
void printInt(int);
void printChar(char);
void printString(const char* string);

struct Vec3 {
	int x;
	int y;
	int z;
};

struct Vec3 readVec();
void writeVec(struct Vec3 v);

void main(void) {
	// void (*foo)(int) = &printInt;
	struct Vec3 vec;
	const char* foo = "Hello world!";

	printString(foo);

	printChar('v');
	printChar(':');
	printChar((char) 10);

	vec = readVec();
	writeVec(vec);
}

struct Vec3 readVec() {
	struct Vec3 v;
	v.x = readInt();
	v.y = readInt();
	v.z = readInt();

	return v;
}

void writeVec(struct Vec3 v) {
	printChar('<');
	printInt(v.x);
	printChar(',');
	printChar(' ');
	printInt(v.y);
	printChar(',');
	printChar(' ');
	printInt(v.z);
	printChar('>');
	printChar((char) 10);
}