BEGIN;
-- Plan the tests.
SELECT plan(3);

INSERT INTO rate_limit.sessions (id, name_, type_)
SELECT
    '00000000-0000-0000-0000-000000000000'::uuid AS id,
    'dedicated-test'::text AS name_,
    'aggregated'::text AS type_
UNION
SELECT
    '00000000-1111-1111-1111-000000000000'::uuid AS id,
    'dedicated-test-2'::text AS name_,
    'aggregated'::text AS type_;;

INSERT INTO rate_limit.records_aggregated (key, session_id)
SELECT
    'existing-key' AS key_,
    '00000000-0000-0000-0000-000000000000'::uuid AS session_id;

SELECT results_eq(
    $have$
    SELECT agg_increment AS count FROM rate_limit.agg_increment('new-key', '00000000-0000-0000-0000-000000000000')
    $have$,
    $want$
    SELECT 1::int AS count;
    $want$,
    'rate_limit.agg_increment returns correct count for new key'
);

SELECT results_eq(
    $have$
    SELECT agg_increment AS count FROM rate_limit.agg_increment('new-key', '00000000-1111-1111-1111-000000000000')
    $have$,
    $want$
    SELECT 1::int AS count;
    $want$,
    'rate_limit.agg_increment returns correct count for new key on different session'
);

SELECT results_eq(
    $have$
    SELECT agg_increment AS count FROM rate_limit.agg_increment('existing-key', '00000000-0000-0000-0000-000000000000')
    $have$,
    $want$
    SELECT 2::int AS count;
    $want$,
    'rate_limit.agg_increment returns correct count for existing key'
);

-- Finish the tests and clean up.
SELECT finish FROM finish();
ROLLBACK;
