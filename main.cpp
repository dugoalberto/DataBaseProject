//
// Created by Alberto Dugo on 22/05/23.
//
#include <iostream>
using namespace std;
#include "dependencies/include/libpq-fe.h"

#include <iostream>
#include <libpq-fe.h>
void checkResults(PGresult* res, const PGconn* conn) {
    if (PQresultStatus(res) != PGRES_TUPLES_OK) {
        cout << "Risultati inconsistenti" << PQerrorMessage(conn);
        PQclear(res);
        exit(1);
    }
}
void checkResultsViews(PGresult* res, const PGconn* conn) {
    if (PQresultStatus(res) != PGRES_COMMAND_OK) {
        std::cout << "Errore durante la creazione della vista: " << PQerrorMessage(conn) << std::endl;
        PQclear(res);
        exit(1);
    }
}
static void createNumeroServiziPerOgniTrackingView() {
    const char* conninfo = "host=localhost port=5432 dbname=postgres user=root password=root";

    // Connessione al database
    PGconn *conn = PQconnectdb(conninfo);

    // Verifica dello stato della connessione
    if (PQstatus(conn) != CONNECTION_OK) {
        std::cout << "Connessione al database fallita: " << PQerrorMessage(conn) << std::endl;
        PQfinish(conn);
        return;
    }

    // Creazione della vista NumeroServiziPerOgniTracking
    std::string createViewQuery = "DROP VIEW IF EXISTS NumeroServiziPerOgniTracking; "
                                  "CREATE VIEW NumeroServiziPerOgniTracking(numeroDiServizi, tracking) AS "
                                  "SELECT COUNT(*), tracking "
                                  "FROM \"Spedizione_Premium_Servizi\" "
                                  "GROUP BY tracking;";

    PGresult *createViewResult = PQexec(conn, createViewQuery.c_str());
    checkResultsViews(createViewResult, conn);

    PQclear(createViewResult);

    std::string avgQuery = "SELECT avg(costo) "
                           "FROM \"Spedizione_Premium\" "
                           "JOIN NumeroServiziPerOgniTracking NSPOT ON \"Spedizione_Premium\".tracking = NSPOT.tracking "
                           "WHERE assicurazione_totale = true "
                           "AND numeroDiServizi > (SELECT avg(numeroDiServizi) FROM NumeroServiziPerOgniTracking);";

    PGresult *avgResult = PQexec(conn, avgQuery.c_str());
    checkResults(avgResult, conn);
    int numRows = PQntuples(avgResult);
    if (numRows > 0) {
        double averageCost = std::stod(PQgetvalue(avgResult, 0, 0));
        std::cout << "Media dei costi: " << averageCost << std::endl;
    }

    PQclear(avgResult);

    // Chiusura della connessione al database
    PQfinish(conn);
}
static void p2(){
    int param;
    cout << "Inserire prezzo soglia: ";
    cin >> param;

    const char* conninfo = "host=localhost port=5432 dbname=postgres user=root password=root";

    // Connessione al database
    PGconn *conn = PQconnectdb(conninfo);

    // Verifica dello stato della connessione
    if (PQstatus(conn) != CONNECTION_OK) {
        std::cout << "Connessione al database fallita: " << PQerrorMessage(conn) << std::endl;
        PQfinish(conn);
        return;
    }
    std::string query = "SELECT \"Spedizione_Economica\".tracking, \"Spedizione_Economica\".costo, SES.nome_servizio, SES.costo "
                        "FROM \"Spedizione_Economica\" "
                        "JOIN \"Spedizione_Economica_Servizi\" SES ON \"Spedizione_Economica\".tracking = SES.tracking "
                        "WHERE \"Spedizione_Economica\".costo >" + std::to_string(param) + " "
                        "ORDER BY tracking ASC;";
    PGresult *result = PQprepare(conn,"query_spedizioneEconomica", query.c_str(), 1, NULL);


    checkResults(result, conn);
    int numRows = PQntuples(result);
    if (numRows > 0) {
        double averageCost = std::stod(PQgetvalue(result, 0, 0));
        std::cout << "Media dei costi: " << averageCost << std::endl;
    }

    PQclear(result);

}
int main() {
    createNumeroServiziPerOgniTrackingView();
    p2();

    return 0;
}
