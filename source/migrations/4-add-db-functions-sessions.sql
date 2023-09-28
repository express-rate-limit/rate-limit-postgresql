CREATE OR REPLACE FUNCTION rate_limit.session_select(name_ text, type_ text)
RETURNS TABLE(id uuid, name_ text, type_ text, expires_at timestamptz) AS
$bd$
    SELECT id, name_, type_, expires_at
    FROM rate_limit.sessions
    WHERE name_ = $1 and type_ = $2
    LIMIT 1;
$bd$
LANGUAGE SQL;

CREATE OR REPLACE FUNCTION rate_limit.session_reset(name_ text, type_ text, expires_at_ timestamptz)
RETURNS TABLE(id uuid, name_ text, type_ text) AS
$bd$
    DELETE FROM rate_limit.sessions 
    WHERE name_ = $1 and type_ = $2;

    INSERT INTO rate_limit.sessions(name_, type_, expires_at) 
    SELECT $1, $2, $3 
    RETURNING id, name_, type_;
$bd$
LANGUAGE SQL;