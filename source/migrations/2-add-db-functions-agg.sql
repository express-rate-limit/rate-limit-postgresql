--Migration generated Fri, 29 Sep 2023 09:11:13 +0000

CREATE OR REPLACE FUNCTION rate_limit.agg_increment(key_ text, session_id_ uuid)
RETURNS int AS
$bd$
    INSERT INTO rate_limit.records_aggregated(key, session_id)
    VALUES ($1, $2)
    ON CONFLICT ON CONSTRAINT unique_session_key DO UPDATE
    SET count = records_aggregated.count + 1
    RETURNING count;
$bd$
LANGUAGE SQL;

CREATE OR REPLACE FUNCTION rate_limit.agg_decrement(key_ text, session_id_ uuid)
RETURNS void AS
$bd$
    UPDATE rate_limit.records_aggregated
    SET count = greatest(0, count-1)
    WHERE key = $1 and session_id = $2;
$bd$
LANGUAGE SQL;

CREATE OR REPLACE FUNCTION rate_limit.agg_reset_key(key_ text, session_id_ uuid)
RETURNS void AS
$bd$
    DELETE FROM rate_limit.records_aggregated
    WHERE key = $1 and session_id = $2
$bd$
LANGUAGE SQL;

CREATE OR REPLACE FUNCTION rate_limit.agg_reset_session(session_id_ uuid)
RETURNS void AS
$bd$
    DELETE FROM rate_limit.records_aggregated
    WHERE session_id = $1
$bd$
LANGUAGE SQL;
