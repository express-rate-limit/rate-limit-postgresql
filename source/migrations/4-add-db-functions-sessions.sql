--Migration generated Fri, 29 Sep 2023 09:12:12 +0000

CREATE OR REPLACE FUNCTION rate_limit.session_select(name_ TEXT, type_ TEXT)
RETURNS TABLE (id UUID, name_ TEXT, type_ TEXT, expires_at TIMESTAMPTZ) AS
$bd$
    SELECT id, name_, type_, expires_at
    FROM rate_limit.sessions
    WHERE name_ = $1 AND type_ = $2
    LIMIT 1;
$bd$
LANGUAGE sql;

CREATE OR REPLACE FUNCTION rate_limit.session_reset(
    name_ TEXT, type_ TEXT, expires_at_ TIMESTAMPTZ
)
RETURNS TABLE (id UUID, name_ TEXT, type_ TEXT) AS
$bd$
    DELETE FROM rate_limit.sessions 
    WHERE name_ = $1 AND type_ = $2;

    INSERT INTO rate_limit.sessions(name_, type_, expires_at) 
    SELECT $1, $2, $3 
    RETURNING id, name_, type_;
$bd$
LANGUAGE sql;
