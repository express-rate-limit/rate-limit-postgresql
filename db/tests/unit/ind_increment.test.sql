BEGIN;
-- Plan the tests.
SELECT plan(3);

INSERT INTO rate_limit.sessions (id, name_, type_)
SELECT
    '00000000-0000-0000-0000-000000000000'::uuid AS id,
    'dedicated-test'::text AS name_,
    'individual'::text AS type_;

INSERT INTO rate_limit.individual_records (key, session_id)
SELECT
    'existing-key' AS key_,
    '00000000-0000-0000-0000-000000000000'::uuid AS session_id;

SELECT results_eq(
    $have$
    SELECT ind_increment AS count FROM rate_limit.ind_increment('new-key', '00000000-0000-0000-0000-000000000000')
    $have$,
    $want$
    SELECT 1::int AS count;
    $want$,
    'rate_limit.ind_increment returns correct count for new key'
);

SELECT results_eq(
    $have$
    SELECT ind_increment AS count FROM rate_limit.ind_increment('existing-key', '00000000-0000-0000-0000-000000000000')
    $have$,
    $want$
    SELECT 2::int AS count;
    $want$,
    'rate_limit.ind_increment returns correct count for existing key'
);

SELECT bag_eq(
    $have$
    SELECT key FROM rate_limit.individual_records
    WHERE session_id = '00000000-0000-0000-0000-000000000000'
    $have$,
    $want$
    SELECT 'existing-key'::text as key 
    UNION ALL
    SELECT 'existing-key'::text as key
    UNION ALL
    SELECT 'new-key'::text as key;
    $want$,
    'rate_limit.ind_increment applies correct logic on table rows'
);

-- Finish the tests and clean up.
SELECT finish FROM finish();
ROLLBACK;
