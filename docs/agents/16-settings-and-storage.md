# AGENTS — SETTINGS SERVICE & FILE STORAGE ABSTRACTION

# 97. SETTINGS

Use:

    SettingsService

Hierarchy:

    System Defaults
        ↓
    Ecosystem Settings
        ↓
    Module Settings
        ↓
    Device Override
        ↓
    User Permission

---

# 98. STORAGE

Use:

    FileStorageService

Never manually construct platform-specific storage paths inside modules.

---
