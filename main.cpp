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

    // TODO almeno 7 query interessanti
    // TODO quant'è il valore medio delle spedizioni assicurate
    // TODO QUERY sul vincolo -> tipo quelle dell'esame
    // TODO almeno una query parametrica
    return 0;
}
