BEGIN;
-- Plan the tests.
SELECT plan(3);

INSERT INTO rate_limit.sessions (id, name_, type_, expires_at)
SELECT
    '00000000-0000-0000-0000-000000000000'::uuid AS id,
    'dedicated-test-1'::text AS name_,
    'aggregated'::text AS type_,
    '2023-09-28 06:00:00+0000'::timestamptz AS expires_at
UNION
SELECT
    '00000000-1111-1111-1111-000000000000'::uuid AS id,
    'dedicated-test-2'::text AS name_,
    'aggregated'::text AS type_,
    '2023-09-28 08:00:00+0000'::timestamptz AS expires_at;


SELECT results_eq(
    $have$
    SELECT name_, type_
    FROM rate_limit.session_reset(
        'dedicated-test-1'::text,
        'aggregated'::text,
        '2023-09-29 06:00:00+0000'::timestamptz)
    $have$,
    $want$
    SELECT
        'dedicated-test-1'::text AS name_,
        'aggregated'::text AS type_
    $want$,
    'rate_limit.session_reset returns correct values'
);

SELECT results_eq(
    $have$
    SELECT name_, type_, expires_at
    FROM rate_limit.sessions
    WHERE name_  = 'dedicated-test-1'
    $have$,
    $want$
    SELECT
        'dedicated-test-1'::text AS name_,
        'aggregated'::text AS type_,
        '2023-09-29 06:00:00+0000'::timestamptz AS expires_at
    $want$,
    'rate_limit.session_reset persists correct entries to table'
);

SELECT results_ne(
    $have$
    SELECT id
    FROM rate_limit.sessions
    WHERE name_  = 'dedicated-test-1'
    $have$,
    $want$
    SELECT '00000000-0000-0000-0000-000000000000'::uuid AS id;
    $want$,
    'rate_limit.session_reset forces change of id while keeping name'
);
-- Finish the tests and clean up.
SELECT finish FROM finish();
ROLLBACK;
