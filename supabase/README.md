# Supabase setup for RuangUsaha

This folder contains the first database migration for the multi-business version of RuangUsaha.

## Important status

- This migration defines the database schema and Row Level Security (RLS) policies.
- It does not connect the current website to Supabase.
- It does not import or delete data from browser `localStorage`.
- It does not implement checkout RPCs, authentication UI, or subscription payment processing yet.
- Do not apply it to a production project before reviewing and testing it in a separate Supabase project.

## Apply in a development Supabase project

1. Create a Supabase project and keep its database credentials private.
2. Open **SQL Editor** in the Supabase dashboard.
3. Review and run `migrations/202610190001_initial_schema.sql`.
4. In **Authentication**, enable the sign-in method you intend to support.
5. Test with two separate test accounts and verify that neither can read or modify the other account's business data.
6. Do not expose the `service_role` key in browser code.

## Main tables

- `profiles`: user profile linked to Supabase Auth.
- `businesses`: owner and business metadata.
- `products`: products and current stock.
- `transactions`: the existing RuangUsaha transaction types.
- `transaction_items`: line-item snapshots so historical prices/costs do not change when a product is edited.
- `stock_movements`: audit trail for inventory changes.
- `subscriptions`: subscription status; client users can read but cannot directly set their own status.

Money is stored as whole Rupiah in `BIGINT`. Quantities support three decimal places for use cases such as perfume sold by milliliter. Before migrating real data, map the existing localStorage object shapes to these tables and compare totals and stock counts before and after import.
