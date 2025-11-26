-- Phase 1: Database hardening (schema + RPC support)
-- Run this in Supabase SQL editor.
-- Safe to re-run.

begin;

-- 1) Enforce unique defects per (audit_id, item_name) to support UPSERT in RPC
--    This prevents duplicate defects when an audit is saved multiple times.
create unique index if not exists defects_audit_item_unique
  on public.defects (audit_id, item_name);

-- 2) Note:
--    The RPC definition is maintained in scripts/save_audit_rpc.sql
--    After running this migration, also (re)run scripts/save_audit_rpc.sql
--    to ensure save_audit_transaction_v2 is present/updated.

commit;


