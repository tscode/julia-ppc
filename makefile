all: ppc.cpp
	g++ -g -O3 -march=native -std=c++17 -shared -fPIC ppc.cpp -o ppc-gcc.so
	clang -g -O3 -march=native -std=c++17 -shared -fPIC ppc.cpp -o ppc-clang.so
