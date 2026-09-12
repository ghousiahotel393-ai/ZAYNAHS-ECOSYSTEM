# PHASE 02 — DATABASE VERIFICATION TESTS & DOD

## VERIFICATION TESTS
- [ ] Fresh database initialization passes without errors.
- [ ] Foreign key constraint violation test throws DatabaseException.
- [ ] Rollback test: forced failure mid-transaction leaves DB in pristine state.
- [ ] Migration upgrade test from empty to v1 passes.
