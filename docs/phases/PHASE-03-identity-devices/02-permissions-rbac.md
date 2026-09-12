# PHASE 03 — PERMISSION RESOLVER & RBAC ENGINE

## RESOLUTION ALGORITHM
```
DENY BY DEFAULT
      ↓
ROLE TEMPLATE PERMISSIONS
      ↓
USER-SPECIFIC OVERRIDES
      ↓
VALUE CONSTRAINTS (e.g. max discount %)
      ↓
FINAL DECISION (ALLOW / DENY)
```

## SERVICE-LAYER ENFORCEMENT
Hiding UI widgets is NOT security. Permissions must be verified inside Application/Service layer methods.
