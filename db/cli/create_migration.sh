now=$(TZ=UTC date -R)
unix_time=$(date +%s)
echo '--Migration generated '$now > source/migrations/$unix_time-$1.sql