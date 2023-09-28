CREATE OR REPLACE FUNCTION rate_limit.ind_increment(key_ text, session_id_ uuid)
RETURNS int AS
$bd$
    INSERT INTO rate_limit.individual_records(key, session_id) VALUES ($1, $2);

    SELECT count(id)::int AS count FROM rate_limit.individual_records WHERE key = $1 AND session_id = $2;
$bd$
LANGUAGE SQL;

CREATE OR REPLACE FUNCTION rate_limit.ind_decrement(key_ text, session_id_ uuid)
RETURNS void AS
$bd$
    WITH 
    rows_to_delete AS (
        SELECT id FROM rate_limit.individual_records
        WHERE key = $1 and session_id = $2 ORDER BY event_time LIMIT 1
        )
    DELETE FROM rate_limit.individual_records 
    USING rows_to_delete WHERE individual_records.id = rows_to_delete.id
$bd$
LANGUAGE SQL;

CREATE OR REPLACE FUNCTION rate_limit.ind_reset_key(key_ text, session_id_ uuid)
RETURNS void AS
$bd$
    DELETE FROM rate_limit.individual_records
    WHERE key = $1 AND session_id = $2
$bd$
LANGUAGE SQL;

CREATE OR REPLACE FUNCTION rate_limit.ind_reset_session(session_id_ uuid)
RETURNS void AS
$bd$
    DELETE FROM rate_limit.individual_records
    WHERE session_id = $1
$bd$
LANGUAGE SQL;
