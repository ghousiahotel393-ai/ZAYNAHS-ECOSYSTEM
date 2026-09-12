# PHASE 01 — ARCHITECTURE FOUNDATION OVERVIEW

## OBJECTIVE
Establish the permanent, immutable architecture base.
Once completed, this foundational layer will NEVER be rewritten or touched by future feature phases.

## LAYER TAXONOMY
```
Presentation Layer (UI / Screens / ViewModels)
       ↓
Application Layer (Use Cases / Orchestration / State)
       ↓
Domain Layer (Entities / Business Rules / Value Objects)
       ↓
Infrastructure Layer (Database / Storage / Network)
       ↓
Platform Layer (Native OS Hardware Adapters)
```

## STRICT CONSTRAINTS
- Strict dependency flow: Higher layers depend on abstractions of lower layers.
- Domain layer has ZERO Flutter widget dependencies.
- No branch tables, branch IDs, or branch managers anywhere in the architecture.
