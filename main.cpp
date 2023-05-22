//
// Created by Alberto Dugo on 22/05/23.
//
#include <libpq-fe.h>
#include <iostream>

//#include "dependencies/include/libpq-fe.h"
using namespace std;
int main(){
    const char* conninfo = "host=localhost port=5432 dbname=test_db user=root password=root";
    PGconn * conn = PQconnectdb(conninfo);
    if(PQstatus(conn) != CONNECTION_OK){
        cout<<"Errore di connessione "<<PQerrorMessage(conn);
        PQfinish(conn);
        exit(1);
    }else{
        cout<<"Connessione avvenuta correttamente";
        PQfinish(conn);
    }
    return 0;
}