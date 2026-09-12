# PHASE 02 — CORE SCHEMAS & MIGRATION ENGINE

## SCHEMA TABLES
- `ecosystems` & `devices` & `device_trusts` & `pairing_sessions`
- `users` & `roles` & `permissions` & `role_permissions` & `user_permissions`
- `products` & `product_variants` & `categories` & `brands` & `units`
- `inventory_movements` & `inventory_balances`
- `sales` & `sale_items` & `returns` & `return_items` & `replacements`
- `wallets` & `wallet_transactions` & `payment_allocations` & `expenses`
- `customers` & `customer_ledger` & `suppliers` & `supplier_ledger`
- `sync_events` & `sync_cursors` & `sync_conflicts` & `audit_events`

## MIGRATION WORKFLOW
1. Schema v1 creation script.
2. Auto-migration test verifying upgrades without data loss.
3. Keep `MASTER_SCHEMA.md` synchronized.
