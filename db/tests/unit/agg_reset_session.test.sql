BEGIN;
-- Plan the tests.
SELECT plan(2);

INSERT INTO rate_limit.sessions (id, name_, type_)
SELECT
    '00000000-0000-0000-0000-000000000000'::uuid AS id,
    'dedicated-test'::text AS name_,
    'aggregated'::text AS type_;

INSERT INTO rate_limit.records_aggregated (key, session_id)
SELECT
    'existing-key' AS key_,
    '00000000-0000-0000-0000-000000000000'::uuid AS session_id
UNION
SELECT
    'another-existing-key' AS key_,
    '00000000-0000-0000-0000-000000000000'::uuid AS session_id;

SELECT lives_ok(
    $have$
    SELECT * FROM rate_limit.agg_reset_session('00000000-0000-0000-0000-000000000000')
    $have$,
    'rate_limit.agg_reset_session does not throw an error'
);

SELECT is_empty(
    $have$
    SELECT * FROM rate_limit.records_aggregated
    WHERE session_id = '00000000-0000-0000-0000-000000000000'
    $have$,
    'rate_limit.agg_reset_session removes all keys of session'
);

-- Finish the tests and clean up.
SELECT finish FROM finish();
ROLLBACK;
