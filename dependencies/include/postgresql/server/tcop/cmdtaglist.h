/*----------------------------------------------------------------------
 *
 * cmdtaglist.h
 *    Command tags
 *
 * The command tag list is kept in its own source file for possible use
 * by automatic tools.  The exact representation of a command tag is
 * determined by the PG_CMDTAG macro, which is not defined in this file;
 * it can be defined by the caller for special purposes.
 *
 * Portions Copyright (c) 1996-2022, PostgreSQL Global Development Group
 * Portions Copyright (c) 1994, Regents of the University of California
 *
 * src/include/tcop/cmdtaglist.h
 *
 *----------------------------------------------------------------------
 */

/* there is deliberately not an #ifndef CMDTAGLIST_H here */

/*
 * List of command tags.  The entries must be sorted alphabetically on their
 * textual name, so that we can bsearch on it; see GetCommandTagEnum().
 */

/* symbol name, textual name, event_trigger_ok, table_rewrite_ok, rowcount */
PG_CMDTAG(CMDTAG_UNKNOWN, "???", false, false, false)
PG_CMDTAG(CMDTAG_ALTER_ACCESS_METHOD, "ALTER ACCESS METHOD", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_AGGREGATE, "ALTER AGGREGATE", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_CAST, "ALTER CAST", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_COLLATION, "ALTER COLLATION", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_CONSTRAINT, "ALTER CONSTRAINT", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_CONVERSION, "ALTER CONVERSION", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_DATABASE, "ALTER DATABASE", false, false, false)
PG_CMDTAG(CMDTAG_ALTER_DEFAULT_PRIVILEGES, "ALTER DEFAULT PRIVILEGES", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_DOMAIN, "ALTER DOMAIN", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_EVENT_TRIGGER, "ALTER EVENT TRIGGER", false, false, false)
PG_CMDTAG(CMDTAG_ALTER_EXTENSION, "ALTER EXTENSION", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_FOREIGN_DATA_WRAPPER, "ALTER FOREIGN DATA WRAPPER", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_FOREIGN_TABLE, "ALTER FOREIGN TABLE", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_FUNCTION, "ALTER FUNCTION", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_INDEX, "ALTER INDEX", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_LANGUAGE, "ALTER LANGUAGE", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_LARGE_OBJECT, "ALTER LARGE OBJECT", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_MATERIALIZED_VIEW, "ALTER MATERIALIZED VIEW", true, true, false)
PG_CMDTAG(CMDTAG_ALTER_OPERATOR, "ALTER OPERATOR", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_OPERATOR_CLASS, "ALTER OPERATOR CLASS", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_OPERATOR_FAMILY, "ALTER OPERATOR FAMILY", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_POLICY, "ALTER POLICY", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_PROCEDURE, "ALTER PROCEDURE", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_PUBLICATION, "ALTER PUBLICATION", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_ROLE, "ALTER ROLE", false, false, false)
PG_CMDTAG(CMDTAG_ALTER_ROUTINE, "ALTER ROUTINE", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_RULE, "ALTER RULE", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_SCHEMA, "ALTER SCHEMA", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_SEQUENCE, "ALTER SEQUENCE", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_SERVER, "ALTER SERVER", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_STATISTICS, "ALTER STATISTICS", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_SUBSCRIPTION, "ALTER SUBSCRIPTION", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_SYSTEM, "ALTER SYSTEM", false, false, false)
PG_CMDTAG(CMDTAG_ALTER_TABLE, "ALTER TABLE", true, true, false)
PG_CMDTAG(CMDTAG_ALTER_TABLESPACE, "ALTER TABLESPACE", false, false, false)
PG_CMDTAG(CMDTAG_ALTER_TEXT_SEARCH_CONFIGURATION, "ALTER TEXT SEARCH CONFIGURATION", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_TEXT_SEARCH_DICTIONARY, "ALTER TEXT SEARCH DICTIONARY", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_TEXT_SEARCH_PARSER, "ALTER TEXT SEARCH PARSER", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_TEXT_SEARCH_TEMPLATE, "ALTER TEXT SEARCH TEMPLATE", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_TRANSFORM, "ALTER TRANSFORM", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_TRIGGER, "ALTER TRIGGER", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_TYPE, "ALTER TYPE", true, true, false)
PG_CMDTAG(CMDTAG_ALTER_USER_MAPPING, "ALTER USER MAPPING", true, false, false)
PG_CMDTAG(CMDTAG_ALTER_VIEW, "ALTER VIEW", true, false, false)
PG_CMDTAG(CMDTAG_ANALYZE, "ANALYZE", false, false, false)
PG_CMDTAG(CMDTAG_BEGIN, "BEGIN", false, false, false)
PG_CMDTAG(CMDTAG_CALL, "CALL", false, false, false)
PG_CMDTAG(CMDTAG_CHECKPOINT, "CHECKPOINT", false, false, false)
PG_CMDTAG(CMDTAG_CLOSE, "CLOSE", false, false, false)
PG_CMDTAG(CMDTAG_CLOSE_CURSOR, "CLOSE CURSOR", false, false, false)
PG_CMDTAG(CMDTAG_CLOSE_CURSOR_ALL, "CLOSE CURSOR ALL", false, false, false)
PG_CMDTAG(CMDTAG_CLUSTER, "CLUSTER", false, false, false)
PG_CMDTAG(CMDTAG_COMMENT, "COMMENT", true, false, false)
PG_CMDTAG(CMDTAG_COMMIT, "COMMIT", false, false, false)
PG_CMDTAG(CMDTAG_COMMIT_PREPARED, "COMMIT PREPARED", false, false, false)
PG_CMDTAG(CMDTAG_COPY, "COPY", false, false, true)
PG_CMDTAG(CMDTAG_COPY_FROM, "COPY FROM", false, false, false)
PG_CMDTAG(CMDTAG_CREATE_ACCESS_METHOD, "CREATE ACCESS METHOD", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_AGGREGATE, "CREATE AGGREGATE", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_CAST, "CREATE CAST", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_COLLATION, "CREATE COLLATION", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_CONSTRAINT, "CREATE CONSTRAINT", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_CONVERSION, "CREATE CONVERSION", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_DATABASE, "CREATE DATABASE", false, false, false)
PG_CMDTAG(CMDTAG_CREATE_DOMAIN, "CREATE DOMAIN", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_EVENT_TRIGGER, "CREATE EVENT TRIGGER", false, false, false)
PG_CMDTAG(CMDTAG_CREATE_EXTENSION, "CREATE EXTENSION", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_FOREIGN_DATA_WRAPPER, "CREATE FOREIGN DATA WRAPPER", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_FOREIGN_TABLE, "CREATE FOREIGN TABLE", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_FUNCTION, "CREATE FUNCTION", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_INDEX, "CREATE INDEX", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_LANGUAGE, "CREATE LANGUAGE", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_MATERIALIZED_VIEW, "CREATE MATERIALIZED VIEW", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_OPERATOR, "CREATE OPERATOR", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_OPERATOR_CLASS, "CREATE OPERATOR CLASS", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_OPERATOR_FAMILY, "CREATE OPERATOR FAMILY", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_POLICY, "CREATE POLICY", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_PROCEDURE, "CREATE PROCEDURE", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_PUBLICATION, "CREATE PUBLICATION", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_ROLE, "CREATE ROLE", false, false, false)
PG_CMDTAG(CMDTAG_CREATE_ROUTINE, "CREATE ROUTINE", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_RULE, "CREATE RULE", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_SCHEMA, "CREATE SCHEMA", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_SEQUENCE, "CREATE SEQUENCE", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_SERVER, "CREATE SERVER", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_STATISTICS, "CREATE STATISTICS", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_SUBSCRIPTION, "CREATE SUBSCRIPTION", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_TABLE, "CREATE TABLE", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_TABLE_AS, "CREATE TABLE AS", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_TABLESPACE, "CREATE TABLESPACE", false, false, false)
PG_CMDTAG(CMDTAG_CREATE_TEXT_SEARCH_CONFIGURATION, "CREATE TEXT SEARCH CONFIGURATION", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_TEXT_SEARCH_DICTIONARY, "CREATE TEXT SEARCH DICTIONARY", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_TEXT_SEARCH_PARSER, "CREATE TEXT SEARCH PARSER", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_TEXT_SEARCH_TEMPLATE, "CREATE TEXT SEARCH TEMPLATE", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_TRANSFORM, "CREATE TRANSFORM", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_TRIGGER, "CREATE TRIGGER", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_TYPE, "CREATE TYPE", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_USER_MAPPING, "CREATE USER MAPPING", true, false, false)
PG_CMDTAG(CMDTAG_CREATE_VIEW, "CREATE VIEW", true, false, false)
PG_CMDTAG(CMDTAG_DEALLOCATE, "DEALLOCATE", false, false, false)
PG_CMDTAG(CMDTAG_DEALLOCATE_ALL, "DEALLOCATE ALL", false, false, false)
PG_CMDTAG(CMDTAG_DECLARE_CURSOR, "DECLARE CURSOR", false, false, false)
PG_CMDTAG(CMDTAG_DELETE, "DELETE", false, false, true)
PG_CMDTAG(CMDTAG_DISCARD, "DISCARD", false, false, false)
PG_CMDTAG(CMDTAG_DISCARD_ALL, "DISCARD ALL", false, false, false)
PG_CMDTAG(CMDTAG_DISCARD_PLANS, "DISCARD PLANS", false, false, false)
PG_CMDTAG(CMDTAG_DISCARD_SEQUENCES, "DISCARD SEQUENCES", false, false, false)
PG_CMDTAG(CMDTAG_DISCARD_TEMP, "DISCARD TEMP", false, false, false)
PG_CMDTAG(CMDTAG_DO, "DO", false, false, false)
PG_CMDTAG(CMDTAG_DROP_ACCESS_METHOD, "DROP ACCESS METHOD", true, false, false)
PG_CMDTAG(CMDTAG_DROP_AGGREGATE, "DROP AGGREGATE", true, false, false)
PG_CMDTAG(CMDTAG_DROP_CAST, "DROP CAST", true, false, false)
PG_CMDTAG(CMDTAG_DROP_COLLATION, "DROP COLLATION", true, false, false)
PG_CMDTAG(CMDTAG_DROP_CONSTRAINT, "DROP CONSTRAINT", true, false, false)
PG_CMDTAG(CMDTAG_DROP_CONVERSION, "DROP CONVERSION", true, false, false)
PG_CMDTAG(CMDTAG_DROP_DATABASE, "DROP DATABASE", false, false, false)
PG_CMDTAG(CMDTAG_DROP_DOMAIN, "DROP DOMAIN", true, false, false)
PG_CMDTAG(CMDTAG_DROP_EVENT_TRIGGER, "DROP EVENT TRIGGER", false, false, false)
PG_CMDTAG(CMDTAG_DROP_EXTENSION, "DROP EXTENSION", true, false, false)
PG_CMDTAG(CMDTAG_DROP_FOREIGN_DATA_WRAPPER, "DROP FOREIGN DATA WRAPPER", true, false, false)
PG_CMDTAG(CMDTAG_DROP_FOREIGN_TABLE, "DROP FOREIGN TABLE", true, false, false)
PG_CMDTAG(CMDTAG_DROP_FUNCTION, "DROP FUNCTION", true, false, false)
PG_CMDTAG(CMDTAG_DROP_INDEX, "DROP INDEX", true, false, false)
PG_CMDTAG(CMDTAG_DROP_LANGUAGE, "DROP LANGUAGE", true, false, false)
PG_CMDTAG(CMDTAG_DROP_MATERIALIZED_VIEW, "DROP MATERIALIZED VIEW", true, false, false)
PG_CMDTAG(CMDTAG_DROP_OPERATOR, "DROP OPERATOR", true, false, false)
PG_CMDTAG(CMDTAG_DROP_OPERATOR_CLASS, "DROP OPERATOR CLASS", true, false, false)
PG_CMDTAG(CMDTAG_DROP_OPERATOR_FAMILY, "DROP OPERATOR FAMILY", true, false, false)
PG_CMDTAG(CMDTAG_DROP_OWNED, "DROP OWNED", true, false, false)
PG_CMDTAG(CMDTAG_DROP_POLICY, "DROP POLICY", true, false, false)
PG_CMDTAG(CMDTAG_DROP_PROCEDURE, "DROP PROCEDURE", true, false, false)
PG_CMDTAG(CMDTAG_DROP_PUBLICATION, "DROP PUBLICATION", true, false, false)
PG_CMDTAG(CMDTAG_DROP_ROLE, "DROP ROLE", false, false, false)
PG_CMDTAG(CMDTAG_DROP_ROUTINE, "DROP ROUTINE", true, false, false)
PG_CMDTAG(CMDTAG_DROP_RULE, "DROP RULE", true, false, false)
PG_CMDTAG(CMDTAG_DROP_SCHEMA, "DROP SCHEMA", true, false, false)
PG_CMDTAG(CMDTAG_DROP_SEQUENCE, "DROP SEQUENCE", true, false, false)
PG_CMDTAG(CMDTAG_DROP_SERVER, "DROP SERVER", true, false, false)
PG_CMDTAG(CMDTAG_DROP_STATISTICS, "DROP STATISTICS", true, false, false)
PG_CMDTAG(CMDTAG_DROP_SUBSCRIPTION, "DROP SUBSCRIPTION", true, false, false)
PG_CMDTAG(CMDTAG_DROP_TABLE, "DROP TABLE", true, false, false)
PG_CMDTAG(CMDTAG_DROP_TABLESPACE, "DROP TABLESPACE", false, false, false)
PG_CMDTAG(CMDTAG_DROP_TEXT_SEARCH_CONFIGURATION, "DROP TEXT SEARCH CONFIGURATION", true, false, false)
PG_CMDTAG(CMDTAG_DROP_TEXT_SEARCH_DICTIONARY, "DROP TEXT SEARCH DICTIONARY", true, false, false)
PG_CMDTAG(CMDTAG_DROP_TEXT_SEARCH_PARSER, "DROP TEXT SEARCH PARSER", true, false, false)
PG_CMDTAG(CMDTAG_DROP_TEXT_SEARCH_TEMPLATE, "DROP TEXT SEARCH TEMPLATE", true, false, false)
PG_CMDTAG(CMDTAG_DROP_TRANSFORM, "DROP TRANSFORM", true, false, false)
PG_CMDTAG(CMDTAG_DROP_TRIGGER, "DROP TRIGGER", true, false, false)
PG_CMDTAG(CMDTAG_DROP_TYPE, "DROP TYPE", true, false, false)
PG_CMDTAG(CMDTAG_DROP_USER_MAPPING, "DROP USER MAPPING", true, false, false)
PG_CMDTAG(CMDTAG_DROP_VIEW, "DROP VIEW", true, false, false)
PG_CMDTAG(CMDTAG_EXECUTE, "EXECUTE", false, false, false)
PG_CMDTAG(CMDTAG_EXPLAIN, "EXPLAIN", false, false, false)
PG_CMDTAG(CMDTAG_FETCH, "FETCH", false, false, true)
PG_CMDTAG(CMDTAG_GRANT, "GRANT", true, false, false)
PG_CMDTAG(CMDTAG_GRANT_ROLE, "GRANT ROLE", false, false, false)
PG_CMDTAG(CMDTAG_IMPORT_FOREIGN_SCHEMA, "IMPORT FOREIGN SCHEMA", true, false, false)
PG_CMDTAG(CMDTAG_INSERT, "INSERT", false, false, true)
PG_CMDTAG(CMDTAG_LISTEN, "LISTEN", false, false, false)
PG_CMDTAG(CMDTAG_LOAD, "LOAD", false, false, false)
PG_CMDTAG(CMDTAG_LOCK_TABLE, "LOCK TABLE", false, false, false)
PG_CMDTAG(CMDTAG_MERGE, "MERGE", false, false, true)
PG_CMDTAG(CMDTAG_MOVE, "MOVE", false, false, true)
PG_CMDTAG(CMDTAG_NOTIFY, "NOTIFY", false, false, false)
PG_CMDTAG(CMDTAG_PREPARE, "PREPARE", false, false, false)
PG_CMDTAG(CMDTAG_PREPARE_TRANSACTION, "PREPARE TRANSACTION", false, false, false)
PG_CMDTAG(CMDTAG_REASSIGN_OWNED, "REASSIGN OWNED", false, false, false)
PG_CMDTAG(CMDTAG_REFRESH_MATERIALIZED_VIEW, "REFRESH MATERIALIZED VIEW", true, false, false)
PG_CMDTAG(CMDTAG_REINDEX, "REINDEX", false, false, false)
PG_CMDTAG(CMDTAG_RELEASE, "RELEASE", false, false, false)
PG_CMDTAG(CMDTAG_RESET, "RESET", false, false, false)
PG_CMDTAG(CMDTAG_REVOKE, "REVOKE", true, false, false)
PG_CMDTAG(CMDTAG_REVOKE_ROLE, "REVOKE ROLE", false, false, false)
PG_CMDTAG(CMDTAG_ROLLBACK, "ROLLBACK", false, false, false)
PG_CMDTAG(CMDTAG_ROLLBACK_PREPARED, "ROLLBACK PREPARED", false, false, false)
PG_CMDTAG(CMDTAG_SAVEPOINT, "SAVEPOINT", false, false, false)
PG_CMDTAG(CMDTAG_SECURITY_LABEL, "SECURITY LABEL", true, false, false)
PG_CMDTAG(CMDTAG_SELECT, "SELECT", false, false, true)
PG_CMDTAG(CMDTAG_SELECT_FOR_KEY_SHARE, "SELECT FOR KEY SHARE", false, false, false)
PG_CMDTAG(CMDTAG_SELECT_FOR_NO_KEY_UPDATE, "SELECT FOR NO KEY UPDATE", false, false, false)
PG_CMDTAG(CMDTAG_SELECT_FOR_SHARE, "SELECT FOR SHARE", false, false, false)
PG_CMDTAG(CMDTAG_SELECT_FOR_UPDATE, "SELECT FOR UPDATE", false, false, false)
PG_CMDTAG(CMDTAG_SELECT_INTO, "SELECT INTO", true, false, false)
PG_CMDTAG(CMDTAG_SET, "SET", false, false, false)
PG_CMDTAG(CMDTAG_SET_CONSTRAINTS, "SET CONSTRAINTS", false, false, false)
PG_CMDTAG(CMDTAG_SHOW, "SHOW", false, false, false)
PG_CMDTAG(CMDTAG_START_TRANSACTION, "START TRANSACTION", false, false, false)
PG_CMDTAG(CMDTAG_TRUNCATE_TABLE, "TRUNCATE TABLE", false, false, false)
PG_CMDTAG(CMDTAG_UNLISTEN, "UNLISTEN", false, false, false)
PG_CMDTAG(CMDTAG_UPDATE, "UPDATE", false, false, true)
PG_CMDTAG(CMDTAG_VACUUM, "VACUUM", false, false, false)
