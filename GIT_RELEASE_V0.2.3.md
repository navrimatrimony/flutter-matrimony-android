# Release v0.2.3

## Summary

- Persisted the selected Marathi/English language choice.
- Persisted the login/register auth token for app session restore.
- Added startup restore flow: language gate, landing flow, or dashboard based on saved state.
- Logout now clears the saved session token while keeping the selected language.
- Added `flutter_secure_storage` for secure token storage.
- Updated Android `minSdk` to 23 for secure storage compatibility.
- Kept Laravel backend read-only with no API route, payload, or server behavior changes.
