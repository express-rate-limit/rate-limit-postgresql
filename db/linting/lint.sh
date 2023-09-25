echo 'Linting migrations folder'
sqlfluff lint source/migrations/ --dialect postgres --ignore parsing --config db/linting/.sqlfluff 
