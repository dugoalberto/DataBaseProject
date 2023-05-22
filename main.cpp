//
// Created by Alberto Dugo on 22/05/23.
//
#include <libpq-fe.h>
#include <iostream>

//#include "dependencies/include/libpq-fe.h"
using namespace std;
#include <libpq-fe.h>

int main() {
    const char* conninfo = "host=localhost port=5432 dbname=postgres user=root password=root";
    PGconn* conn = PQconnectdb(conninfo);
    PGresult* res;

    if (PQstatus(conn) != CONNECTION_OK) {
        printf("Connection to database failed: %s\n", PQerrorMessage(conn));
        PQfinish(conn);
        return 1;
    }

    for (int i = 0; i < 100; ++i) {
        char query[100];
        snprintf(query, sizeof(query), "INSERT INTO hubs(prova) values (%d)", i);
        res = PQexec(conn, query);
        if (PQresultStatus(res) != PGRES_COMMAND_OK) {
            printf("Error executing INSERT query: %s\n", PQerrorMessage(conn));
            PQclear(res);
            PQfinish(conn);
            return 1;
        }
        PQclear(res);
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
