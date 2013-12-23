all:
	g++ main.cpp core.cpp utils.cpp -o time_tracker -I /usr/include/pqxx -lpqxx
utils:
	g++ utils.cpp -o utils
core:
	g++ core.cpp utils.cpp -o core -I /usr/include/pqxx -lpqxx
clean:
	rm -rf time_tracker core utils
