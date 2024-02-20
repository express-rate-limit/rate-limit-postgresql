--Migration generated Sat, 17 Feb 2024 15:02:12 +0000

DROP FUNCTION IF EXISTS rate_limit.ind_increment(key_ text, session_id_ uuid);
DROP FUNCTION IF EXISTS rate_limit.ind_decrement(key_ text, session_id_ uuid);
DROP FUNCTION IF EXISTS rate_limit.ind_reset_key(key_ text, session_id_ uuid);
DROP FUNCTION IF EXISTS rate_limit.ind_reset_session(session_id_ uuid);

CREATE OR REPLACE FUNCTION rate_limit.ind_increment(key_ text, prefix text, window_ms double precision, reference_time timestamptz DEFAULT now())
RETURNS record AS
$bd$
    DECLARE
        in_session_id uuid;
        in_session_expiration timestamptz;
        session_type text = 'individual';
        record_count int = 0;
        ret RECORD;
    BEGIN

    LOCK TABLE rate_limit.sessions;
    
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


    INSERT INTO rate_limit.individual_records(key, session_id) VALUES ($1, in_session_id);
    
    SELECT count(id)::int AS count FROM rate_limit.individual_records WHERE key = $1 AND session_id = in_session_id
    INTO record_count;
   
   	ret:= (record_count, in_session_expiration);

    RETURN ret;
    END; 
$bd$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rate_limit.ind_decrement(key_ text, prefix text, reference_time timestamptz DEFAULT now())
RETURNS void AS
$bd$
    DECLARE 
        in_session_id uuid;
        session_type text = 'individual';
    BEGIN
    
    SELECT id
    FROM rate_limit.session_select($2, session_type)
    WHERE expires_at > $3
    INTO in_session_id;

    WITH 
    rows_to_delete AS (
        SELECT id FROM rate_limit.individual_records
        WHERE key = $1 and session_id = in_session_id ORDER BY event_time LIMIT 1
        )
    DELETE FROM rate_limit.individual_records 
    USING rows_to_delete WHERE individual_records.id = rows_to_delete.id;
    END;
$bd$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rate_limit.ind_reset_key(key_ text, prefix text, reference_time timestamptz DEFAULT now())
RETURNS void AS
$bd$
    DECLARE 
        in_session_id uuid;
        session_type text = 'individual';
    BEGIN
    
    SELECT id
    FROM rate_limit.session_select($2, session_type)
    WHERE expires_at > $3
    INTO in_session_id;

    DELETE FROM rate_limit.individual_records
    WHERE key = $1 AND session_id = in_session_id;
    END;
$bd$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rate_limit.ind_reset_session(prefix text, reference_time timestamptz DEFAULT now())
RETURNS void AS
$bd$
    DECLARE 
        in_session_id uuid;
        session_type text = 'individual';
    BEGIN
    
    SELECT id
    FROM rate_limit.session_select($1, session_type)
    WHERE expires_at > $2
    INTO in_session_id;

    DELETE FROM rate_limit.individual_records
    WHERE session_id = in_session_id;
    END;
$bd$
LANGUAGE plpgsql;
