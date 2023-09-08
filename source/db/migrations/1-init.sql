CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

create schema if not exists rate_limit; 

create table if not exists rate_limit.sessions(
id uuid default uuid_generate_v1() primary key, 
registered_at timestamptz, 
expires_at timestamptz); 


create table if not exists rate_limit.records(
id uuid default uuid_generate_v1() primary key,
key text,
event_time timestamptz default now(),
session_id uuid references rate_limit.sessions(id) ON DELETE CASCADE 
);