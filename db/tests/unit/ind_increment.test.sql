BEGIN;
-- Plan the tests.
SELECT plan(6);

INSERT INTO rate_limit.sessions (id, name_, type_, expires_at)
SELECT
    '00000000-0000-0000-0000-000000000000'::uuid AS id,
    'dedicated-test'::text AS name_,
    'individual'::text AS type_,
    '2023-01-01 10:00:00+0'::timestamptz AS expires_at
UNION
SELECT
    '00000000-1111-1111-1111-000000000000'::uuid AS id,
    'dedicated-test-2'::text AS name_,
    'individual'::text AS type_,
    '2023-01-01 10:00:00+0'::timestamptz AS expires_at
UNION
SELECT
    '00000000-2222-2222-2222-000000000000'::uuid AS id,
    'dedicated-test-expired'::text AS name_,
    'individual'::text AS type_,
    '2023-01-01 08:00:00+0'::timestamptz AS expires_at;;

INSERT INTO rate_limit.individual_records (key, session_id)
SELECT
    'existing-key' AS key_,
    '00000000-0000-0000-0000-000000000000'::uuid AS session_id;

SELECT results_eq(
    $have$
    SELECT * FROM rate_limit.ind_increment('new-key', 'dedicated-test', 1000, '2023-01-01 09:00:00+0'::timestamptz) AS (count int, expires_at timestamptz);
    $have$,
    $want$
    SELECT 1::int AS count, '2023-01-01 10:00:00+0'::timestamptz as expires_at;
    $want$,
    'rate_limit.ind_increment returns correct count for new key'
);

SELECT results_eq(
    $have$
    SELECT * FROM rate_limit.ind_increment('new-key', 'dedicated-test-2', 1000, '2023-01-01 09:00:00+0'::timestamptz) AS (count int, expires_at timestamptz);
    $have$,
    $want$
    SELECT 1::int AS count, '2023-01-01 10:00:00+0'::timestamptz as expires_at;
    $want$,
    'rate_limit.ind_increment returns correct count for new key on another session'
);

SELECT results_eq(
    $have$
    SELECT * FROM rate_limit.ind_increment('existing-key', 'dedicated-test', 1000, '2023-01-01 09:00:00+0'::timestamptz) AS (count int, expires_at timestamptz);
    $have$,
    $want$
    SELECT 2::int AS count, '2023-01-01 10:00:00+0'::timestamptz as expires_at;
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

SELECT results_eq(
    $have$
    SELECT * FROM rate_limit.ind_increment('existing-key', 'dedicated-test-expired', 1000, '2023-01-01 09:00:00+0') AS (count int, expires_at timestamptz);
    $have$,
    $want$
    SELECT 1::int AS count, '2023-01-01 09:00:01+0'::timestamptz as expires_at;
    $want$,
    'rate_limit.ind_increment returns correct count for existing key for expired session'
);

SELECT bag_hasnt(
    $have$
    SELECT id, name_, type_, expires_at FROM rate_limit.sessions
    $have$,
    $miss$
    SELECT
    '00000000-2222-2222-2222-000000000000'::uuid AS id,
    'dedicated-test-expired'::text AS name_,
    'individual'::text AS type_,
    '2023-01-01 08:00:00+0'::timestamptz as expires_at;
    $miss$,
    'expired session should not be reset after increment invoke'
);

-- Finish the tests and clean up.
SELECT finish FROM finish();
ROLLBACK;
