//
// Created by Alberto Dugo on 22/05/23.
//
#include <iostream>
using namespace std;
#include "dependencies/include/libpq-fe.h"

int main() {
    const char* conninfo = "host=localhost port=5432 dbname=postgres user=root password=root";
    PGconn* conn = PQconnectdb(conninfo);
    PGresult* res;

    if (PQstatus(conn) != CONNECTION_OK) {
        printf("Connection to database failed: %s\n", PQerrorMessage(conn));
        PQfinish(conn);
        return 1;
    }

    res = PQexec(conn, "SELECT * FROM hubs");
    if (PQresultStatus(res) != PGRES_TUPLES_OK) {
        printf("Error executing SELECT query: %s\n", PQerrorMessage(conn));
        PQclear(res);
        PQfinish(conn);
        return 1;
    }

    int rows = PQntuples(res);
    int cols = PQnfields(res);

    for (int i = 0; i < rows; ++i) {
        for (int j = 0; j < cols; ++j) {
            printf("%s\t", PQgetvalue(res, i, j));
        }
        printf("\n");
    }

    PQclear(res);
    PQfinish(conn);
    return 0;
}
