now=$(TZ=UTC date -R)
count=$(ls source/migrations/ | wc -l)
((count++))
echo '--Migration generated '$now > source/migrations/$count-$1.sql