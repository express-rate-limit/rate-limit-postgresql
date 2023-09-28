BEGIN;
-- Plan the tests.
SELECT plan(4);

INSERT INTO rate_limit.sessions (name_, type_)
SELECT
    md5(random()::text) AS name_,
    'individual' AS type_
FROM pg_catalog.generate_series(1, 1000);

INSERT INTO rate_limit.sessions (id, name_, type_)
SELECT
    '00000000-0000-0000-0000-000000000000'::uuid AS id,
    'dedicated-test'::text AS name_,
    'individual'::text AS type_;

INSERT INTO rate_limit.individual_records (key, session_id)
SELECT
    md5(random()::text) AS key_,
    session_.id AS session_id
FROM rate_limit.sessions AS session_
INNER JOIN pg_catalog.generate_series(1, 1000) ON true;

INSERT INTO rate_limit.individual_records (key, session_id)
VALUES ('test-count', '00000000-0000-0000-0000-000000000000'::uuid),
('test-decrement', '00000000-0000-0000-0000-000000000000'::uuid),
('test-reset-key', '00000000-0000-0000-0000-000000000000'::uuid);

SELECT performs_ok(
    $bd$
    SELECT ind_increment as count FROM rate_limit.ind_increment('test-count', '00000000-0000-0000-0000-000000000000')
    $bd$,
    250,
    'inserting record should execute under 250ms'
);

SELECT performs_ok(
    $bd$
    SELECT * FROM rate_limit.ind_decrement('test-decrement', '00000000-0000-0000-0000-000000000000');
    $bd$,
    250,
    'decrementing query execute under 250ms'
);

SELECT performs_ok(
    $bd$
    SELECT * FROM rate_limit.ind_reset_key('test-reset-key', '00000000-0000-0000-0000-000000000000');
    $bd$,
    250,
    'resetting a key should execute under 250ms'
);

SELECT performs_ok(
    $bd$
    SELECT * FROM rate_limit.ind_reset_session('00000000-0000-0000-0000-000000000000');
    $bd$,
    250,
    'resetting a session should execute under 250ms'
);

-- Finish the tests and clean up.
SELECT finish FROM finish();
ROLLBACK;
