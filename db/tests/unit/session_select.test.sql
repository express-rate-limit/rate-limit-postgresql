BEGIN;
-- Plan the tests.
SELECT plan(1);

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
    SELECT id, name_, type_, expires_at
    FROM rate_limit.session_select(
        'dedicated-test-1'::text,
        'aggregated'::text)
    $have$,
    $want$
    SELECT
    '00000000-0000-0000-0000-000000000000'::uuid AS id,
        'dedicated-test-1'::text AS name_,
        'aggregated'::text AS type_,
        '2023-09-28 06:00:00+0000'::timestamptz AS expires_at
    $want$,
    'rate_limit.session_select returns correct values'
);

-- Finish the tests and clean up.
SELECT finish FROM finish();
ROLLBACK;
