all:
	g++ -std=c++11 -Wall main.cpp core.cpp utils.cpp -o time_tracker -I /usr/include/pqxx -lpqxx
utils:
	g++ -Wall utils.cpp -o utils
core:
	g++ -Wall core.cpp utils.cpp -o core -I /usr/include/pqxx -lpqxx
clean:
	rm -rf time_tracker core utils
