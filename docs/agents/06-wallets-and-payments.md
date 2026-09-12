# AGENTS — WALLETS, TRANSFERS, SPLIT PAYMENTS & ATOMICITY

# 27. WALLET RULE

Wallet formula:

    Opening
    + IN
    - OUT
    = Current Balance

Wallet types:

    CASH
    BANK
    ONLINE

Do not invent additional core wallets without explicit architecture change.

---

# 28. WALLET TRANSFER

Example:

    Cash → Bank
    10,000

Create:

    Cash OUT 10,000
    Bank IN 10,000

Do not count it as revenue.

---

# 29. SPLIT PAYMENT

If invoice:

    10,000

and:

    Cash 4,000
    Bank 3,000
    Online 3,000

the allocation total MUST equal:

    10,000

---

# 30. SALE ATOMICITY

Sale creation must atomically create:

    sale
    sale items
    inventory OUT
    payment allocations
    wallet transactions
    customer ledger where applicable
    audit event
    sync event

If a required step fails:

    rollback

Do not leave partial sale state.

---

# 31. RETURN RULE

Return must NOT rewrite original sale.

Create:

    return
    return items
    inventory IN
    refund
    wallet OUT
    customer ledger update
    audit
    sync event

---

# 32. REPLACEMENT RULE

Replacement must link:

    original sale
    return
    returned item
    replacement item
    inventory IN
    inventory OUT
    price difference
    refund/additional payment
    audit
    sync

---

# 33. HISTORICAL PRICE RULE

Sale items must snapshot:

    product name
    SKU
    variant
    quantity
    unit price
    discount
    tax
    final line total

Later product changes must not modify historical sales.

---

# 34. FINANCIAL IMMUTABILITY

Completed financial records normally must not be hard deleted.

Use:

    VOID
    reversal
    correction
    return
    replacement
    adjustment

as appropriate.

---

# 35. IDEMPOTENCY

Every retriable state-changing operation must have:

    idempotency_key

Duplicate retry must not create duplicate:

    sales
    payments
    wallet transactions
    inventory events
    expenses
    transfers
    backups

---

# 36. GLOBAL IDS

Use:

    UUIDv7
    or equivalent globally unique ID

Never use:

    array index
    timestamp alone
    local incremental integer

as global identity.

---
