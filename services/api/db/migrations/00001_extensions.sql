-- Extensions every later migration may rely on.
--
-- postgis    geography points on saved locations (ADR 010)
-- btree_gist time-range indexes for clash queries
-- citext     case-insensitive email addresses
--
-- In the cluster, CloudNativePG creates these at bootstrap as a superuser
-- (deploy/base/database/cluster.yaml), because PostGIS is not a trusted
-- extension and the migrator role cannot create it. IF NOT EXISTS makes this
-- file a no-op there; locally and in tests it does the work.

-- +goose Up
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS citext;
