# Quantix-Mobile-Shared — Changelog

All notable changes to the shared package are documented here.

Format: `[version] YYYY-MM-DD — description`

---

## [1.0.0] 2026-05-24

- Initial release extracted from Quantix-Mobile-Master Phase 4
- `api/` — Dio HTTP client with auth interceptor
- `branding/` — BrandConfig (Freezed), BrandLoader, ThemeFactory, FeatureFlags, BusinessType
- `config/` — AppConfig (base URL, timeouts)
- `constants/` — AppConstants
- `exceptions/` — AppException hierarchy
- `sockets/` — SocketService (Socket.IO, 4 tracking events)
- `storage/` — SecureStorage (flutter_secure_storage)
- `theme/` — AppTheme (static fallback)
- `widgets/` — AppScaffold, FeatureGuard

---

## How to update downstream business repos

See [UPDATE_GUIDE.md](../Quantix-Mobile-Master/UPDATE_GUIDE.md) in master.

```bash
# In a business repo (e.g. Arbaz-Mobile/)
git submodule update --remote shared
git add shared
git commit -m "Update shared to latest"
```
