# PHASE 01 — ROUTING, NAVIGATION & DEEP LINKS

## OBJECTIVE
Implement declarative, URL-based routing (GoRouter) supporting all deep link routes across mobile, desktop, and web.

## CANONICAL DEEP LINKS
- `/products` & `/products/:productId` & `/products/:productId/ledger`
- `/sales` & `/sales/:saleId` & `/sales/:saleId/payment`
- `/returns` & `/returns/:returnId`
- `/customers` & `/customers/:customerId`
- `/suppliers` & `/suppliers/:supplierId`
- `/wallets` & `/wallets/:walletId`
- `/inventory` & `/inventory/movements/:movementId`
- `/users` & `/users/:userId`
- `/devices` & `/devices/:deviceId`
- `/cctv` & `/cctv/recordings/:recordingId`
- `/backups` & `/backups/:backupId`

## ROUTE GUARDS & SECURITY
- Unauthenticated requests redirect to `/login`.
- Unauthorized requests redirect to `/access-denied` (zero data leak).
- Missing entities redirect to `/not-found`.
