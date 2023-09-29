echo 'Applying migrations'
for f in `ls -v source/migrations/*.sql`;
do
    if test -f "$f"; then
    psql -U $USER -h $HOST -p $PORT -d $DATABASE -v "ON_ERROR_STOP=1" -f "$f"
    echo 'Applied migration -' $f
    fi
done