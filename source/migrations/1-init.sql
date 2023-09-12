CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE SCHEMA IF NOT EXISTS rate_limit;

CREATE TABLE IF NOT EXISTS rate_limit.sessions (
    id uuid DEFAULT uuid_generate_v1() PRIMARY KEY,
    name_ text UNIQUE,
    type_ text,
    registered_at timestamptz DEFAULT now(),
    expires_at timestamptz
);


CREATE TABLE IF NOT EXISTS rate_limit.records_aggregated (
    key text PRIMARY KEY,
    session_id uuid REFERENCES rate_limit.sessions (id) ON DELETE CASCADE,
    count integer DEFAULT 1
);

CREATE TABLE IF NOT EXISTS rate_limit.individual_records (
    id uuid DEFAULT uuid_generate_v1() PRIMARY KEY,
    key text,
    event_time timestamptz DEFAULT now(),
    session_id uuid REFERENCES rate_limit.sessions (id) ON DELETE CASCADE
);

ALTER TABLE rate_limit.records_aggregated
ADD CONSTRAINT unique_session_key UNIQUE (key, session_id);
