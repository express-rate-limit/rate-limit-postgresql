set -e

pg_prove -U $USER -h $HOST -p $PORT -d $DATABASE db/tests/performance/*.test.sql
