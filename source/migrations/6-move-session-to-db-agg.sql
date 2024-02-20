--Migration generated Sat, 17 Feb 2024 14:02:12 +0000

DROP FUNCTION IF EXISTS rate_limit.agg_increment(key_ text, session_id_ uuid);
DROP FUNCTION IF EXISTS rate_limit.agg_decrement(key_ text, session_id_ uuid);
DROP FUNCTION IF EXISTS rate_limit.agg_reset_key(key_ text, session_id_ uuid);
DROP FUNCTION IF EXISTS rate_limit.agg_reset_session(session_id_ uuid);

CREATE OR REPLACE FUNCTION rate_limit.agg_increment(key_ text, prefix text, window_ms double precision, reference_time timestamptz DEFAULT now())
RETURNS record AS
$bd$
    DECLARE
        in_session_id uuid;
        in_session_expiration timestamptz;
        session_type text = 'aggregated';
        record_count int = 0;
        ret RECORD;
    BEGIN

	Lock table rate_limit.sessions;
	    
    SELECT id, expires_at
    FROM rate_limit.session_select($2, session_type)
    WHERE expires_at > $4
    INTO in_session_id, in_session_expiration;
  
    IF in_session_id is null THEN
        in_session_expiration = to_timestamp(extract (epoch from $4)+ $3/1000.0);
        SELECT id, in_session_expiration
        FROM rate_limit.session_reset(
            $2, session_type, in_session_expiration
        ) 
        INTO in_session_id;
    END IF;


    INSERT INTO rate_limit.records_aggregated(key, session_id)
    VALUES ($1, in_session_id)
    ON CONFLICT ON CONSTRAINT unique_session_key DO UPDATE
    SET count = records_aggregated.count + 1
    RETURNING count INTO record_count;
   
   	ret:= (record_count, in_session_expiration);

    RETURN ret;
    END; 
$bd$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rate_limit.agg_decrement(key_ text, prefix text, reference_time timestamptz DEFAULT now())
RETURNS void AS
$bd$
    DECLARE 
        in_session_id uuid;
        session_type text = 'aggregated';
    BEGIN
    
	select id
    FROM rate_limit.session_select($2, session_type)
    WHERE expires_at > $3
    INTO in_session_id;

    UPDATE rate_limit.records_aggregated
    SET count = greatest(0, count-1)
    WHERE key = $1 and session_id = in_session_id;
    END;
$bd$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rate_limit.agg_reset_key(key_ text, prefix text, reference_time timestamptz DEFAULT now())
RETURNS void AS
$bd$
    DECLARE 
        in_session_id uuid;
        session_type text = 'aggregated';
    BEGIN
    
    SELECT id
    FROM rate_limit.session_select($2, session_type)
    WHERE expires_at > $3
    INTO in_session_id;

    DELETE FROM rate_limit.records_aggregated
    WHERE key = $1 and session_id = in_session_id;
    END;
$bd$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rate_limit.agg_reset_session(prefix text, reference_time timestamptz DEFAULT now())
RETURNS void AS
$bd$
    DECLARE 
        in_session_id uuid;
        session_type text = 'aggregated';
    BEGIN
    
    SELECT id
    FROM rate_limit.session_select($1, session_type)
    WHERE expires_at > $2
    INTO in_session_id;

    DELETE FROM rate_limit.records_aggregated
    WHERE session_id = in_session_id;
    END;
$bd$
LANGUAGE plpgsql;
