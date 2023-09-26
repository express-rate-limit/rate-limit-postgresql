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

PREPARE update_aggregation as
INSERT INTO rate_limit.records_aggregated (key, session_id)
VALUES ('test-update', '00000000-0000-0000-0000-000000000000')
ON CONFLICT ON CONSTRAINT unique_session_key DO UPDATE
SET count = records_aggregated.count + 1
RETURNING count;

SELECT performs_ok(
    'update_aggregation',
    250,
    'inserting record should execute under 250ms'
);


PREPARE decrement_records as
UPDATE rate_limit.records_aggregated
SET count = greatest(0, count - 1)
WHERE
    key = 'test-decrement'
    AND session_id = '00000000-0000-0000-0000-000000000000';

SELECT performs_ok(
    'decrement_records',
    250,
    'decrementing query execute under 250ms'
);

PREPARE reset_key as 
DELETE FROM rate_limit.records_aggregated
WHERE
    key = 'test-reset-key'
    AND session_id = '00000000-0000-0000-0000-000000000000';


SELECT performs_ok(
    'reset_key',
    250,
    'resetting a key should execute under 250ms'
);

PREPARE reset_all as 
DELETE FROM rate_limit.records_aggregated
WHERE session_id = '00000000-0000-0000-0000-000000000000';


SELECT performs_ok(
    'reset_all',
    250,
    'resetting a session should execute under 250ms'
);

DEALLOCATE update_aggregation;
DEALLOCATE decrement_records;
DEALLOCATE reset_key;
DEALLOCATE reset_all;

-- Finish the tests and clean up.
SELECT finish FROM finish();
ROLLBACK;
