-- Runs once, when the data volume is first initialised.
-- Creates the development and test databases (SPEC §3.1).
-- Both are owned by POSTGRES_USER (the connecting superuser), so migrations
-- can create extensions such as pg_trgm.
CREATE DATABASE healthtick_dev;
CREATE DATABASE healthtick_test;
