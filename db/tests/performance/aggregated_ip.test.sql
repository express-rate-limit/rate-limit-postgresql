BEGIN;
-- Plan the tests.
SELECT plan(4);

INSERT INTO rate_limit.sessions (name_, type_)
SELECT
    md5(random()::text) AS name_,
    'aggregated' AS type_
FROM pg_catalog.generate_series(1, 1000);

INSERT INTO rate_limit.sessions (id, name_, type_)
SELECT
    '00000000-0000-0000-0000-000000000000'::uuid AS id,
    'dedicated-test'::text AS name_,
    'aggregated'::text AS type_;

INSERT INTO rate_limit.records_aggregated (key, session_id, count)
SELECT
    md5(random()::text) AS key_,
    id AS session_id,
    random() * 1000 + 1 AS count
FROM rate_limit.sessions;

INSERT INTO rate_limit.records_aggregated (key, session_id, count)
VALUES ('test-update', '00000000-0000-0000-0000-000000000000'::uuid, 20),
('test-decrement', '00000000-0000-0000-0000-000000000000'::uuid, 30),
('test-reset-key', '00000000-0000-0000-0000-000000000000'::uuid, 40);

SELECT performs_ok(
    $bd$
    SELECT * from rate_limit.agg_increment('test-update', 'dedicated-test', 1000) AS (count int, expires_at timestamptz);
    $bd$,
    250,
    'inserting record should execute under 250ms'
);

SELECT performs_ok(
    $bd$
    SELECT * FROM rate_limit.agg_decrement('test-decrement', 'dedicated-test');
    $bd$,
    250,
    'decrementing query execute under 250ms'
);

SELECT performs_ok(
    $bd$
    SELECT * FROM rate_limit.agg_reset_key('test-reset-key', 'dedicated-test')
    $bd$,
    250,
    'resetting a key should execute under 250ms'
);

SELECT performs_ok(
    $bd$
    SELECT * FROM rate_limit.agg_reset_session('dedicated-test');
    $bd$,
    250,
    'resetting a session should execute under 250ms'
);

-- Finish the tests and clean up.
SELECT finish FROM finish();
ROLLBACK;
