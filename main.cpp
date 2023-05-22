#include <iostream>
#include "dependencies/include/libpq-fe.h"

int main (int argc, char **argv) {
    PGconn *conn = PQconnectdb("host=<localhost> port=<5432> user=<root> password=<root> dbname=<test_db>");
    PGresult *res;
    res = PQexec(conn, "SELECT * FROM hubs");
    int tuple = PQntuples(res);
    int campi = PQnfields(res);
    for (int i = 0; i < campi; ++i) {
        std::cout << PQfname(res, i) << "\t\t";
    }
    std::cout << std::endl;
    for(int i=0;i<tuple;++i){
        for (int j = 0; j < campi; ++j) {
            std::cout << PQgetvalue(res, i, j) << "\t\t";
        }
        std::cout << std::endl;
    }
}