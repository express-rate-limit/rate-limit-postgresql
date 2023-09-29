--Migration generated Fri, 29 Sep 2023 09:22:12 +0000

ALTER TABLE rate_limit.records_aggregated
DROP CONSTRAINT records_aggregated_pkey;

ALTER TABLE rate_limit.records_aggregated
DROP CONSTRAINT unique_session_key;

ALTER TABLE rate_limit.records_aggregated
ADD CONSTRAINT unique_session_key UNIQUE (session_id, key);
