BEGIN;
-- Plan the tests.
SELECT plan(2);

INSERT INTO rate_limit.sessions (id, name_, type_, expires_at)
SELECT
    '00000000-0000-0000-0000-000000000000'::uuid AS id,
    'dedicated-test'::text AS name_,
    'aggregated'::text AS type_,
    '2023-01-01 10:00:00+0' AS expires_at;

INSERT INTO rate_limit.records_aggregated (key, session_id)
SELECT
    'existing-key' AS key_,
    '00000000-0000-0000-0000-000000000000'::uuid AS session_id;

SELECT lives_ok(
    $have$
    SELECT * FROM rate_limit.agg_decrement('existing-key', 'dedicated-test', '2023-01-01 09:00:00+0')
    $have$,
    'rate_limit.agg_decrement does not throw an error'
);

SELECT results_eq(
    $have$
    SELECT count FROM rate_limit.records_aggregated
    WHERE key = 'existing-key'
    $have$,
    $want$
    SELECT 0::int AS count;
    $want$,
    'rate_limit.agg_decrement decrements count for key'
);

-- Finish the tests and clean up.
SELECT finish FROM finish();
ROLLBACK;
