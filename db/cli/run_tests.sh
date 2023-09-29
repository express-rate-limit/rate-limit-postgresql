set -e

psql --quiet -U $USER -h $HOST -p $PORT -d $DATABASE -c 'CREATE EXTENSION IF NOT EXISTS pgtap;'

pg_prove -U $USER -h $HOST -p $PORT -d $DATABASE db/tests/performance/*.test.sql

pg_prove -U $USER -h $HOST -p $PORT -d $DATABASE db/tests/unit/*.test.sql
