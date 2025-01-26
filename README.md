# PostgreSQL

PostgreSQL with PgBouncer, pgx_ulid, ParadeDB, & TimescaleDB

## Generate User List

```
./generate-userlist >> userlist.txt
```

## Extension
```
CREATE EXTENSION IF NOT EXISTS ulid;
CREATE EXTENSION IF NOT EXISTS pg_search;
CREATE EXTENSION IF NOT EXISTS pg_analytics;
CREATE EXTENSION IF NOT EXISTS timescaledb;
```