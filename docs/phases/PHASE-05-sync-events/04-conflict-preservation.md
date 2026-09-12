# PHASE 05 — CONFLICT PRESERVATION & GOLDEN TEST 101

## NO LAST-WRITE-WINS (LWW)
Independent offline transactions survive.
Multi-Device Golden Test (#101):
Device A offline: Sale -20
Device B offline: Sale -30
Sync reconnect: Final stock = 50. Both sales preserved.
