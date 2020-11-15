#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    create table test(c1 text);
    insert into test values('1');
    insert into test values('3');
    commit;
EOSQL
