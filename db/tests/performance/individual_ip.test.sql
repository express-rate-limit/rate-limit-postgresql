BEGIN;
-- Plan the tests.
SELECT plan(5);

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

PREPARE insert_individual_record as
INSERT INTO rate_limit.individual_records (key, session_id)
VALUES ('test', '00000000-0000-0000-0000-000000000000'::uuid);

SELECT performs_ok(
    'insert_individual_record',
    250,
    'inserting record should execute under 250ms'
);

PREPARE retrieve_count AS
SELECT count(id) AS count
FROM rate_limit.individual_records
WHERE
    key = 'test-count'
    AND session_id = '00000000-0000-0000-0000-000000000000'::uuid;

SELECT performs_ok(
    'retrieve_count',
    250,
    'retrieving count should execute under 250ms'
);


PREPARE decrement_records as
WITH
rows_to_delete AS (
    SELECT id FROM rate_limit.individual_records
    WHERE
        key = 'test-decrement'
        AND session_id = '00000000-0000-0000-0000-000000000000'
    ORDER BY event_time
    LIMIT 1
)
DELETE FROM rate_limit.individual_records
USING rows_to_delete WHERE individual_records.id = rows_to_delete.id;

SELECT performs_ok(
    'decrement_records',
    250,
    'decrementing query execute under 250ms'
);

PREPARE reset_key as 
DELETE FROM rate_limit.individual_records
WHERE
    key = 'test-reset-key'
    AND session_id = '00000000-0000-0000-0000-000000000000';


SELECT performs_ok(
    'reset_key',
    250,
    'resetting a key should execute under 250ms'
);

PREPARE reset_all as 
DELETE FROM rate_limit.individual_records
WHERE session_id = '00000000-0000-0000-0000-000000000000';


SELECT performs_ok(
    'reset_all',
    250,
    'resetting a session should execute under 250ms'
);

DEALLOCATE insert_individual_record;
DEALLOCATE retrieve_count;
DEALLOCATE decrement_records;
DEALLOCATE reset_key;
DEALLOCATE reset_all;

-- Finish the tests and clean up.
SELECT finish FROM finish();
ROLLBACK;
