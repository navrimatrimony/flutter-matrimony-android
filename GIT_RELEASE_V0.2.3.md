# Release v0.2.3

## Summary

- Persisted the selected Marathi/English language choice.
- Persisted the login/register auth token for app session restore.
- Added startup restore flow: language gate, landing flow, or dashboard based on saved state.
- Logout now clears the saved session token while keeping the selected language.
- Added `flutter_secure_storage` for secure token storage.
- Updated Android `minSdk` to 23 for secure storage compatibility.
- Kept Laravel backend read-only with no API route, payload, or server behavior changes.

## Matches UI polish

- Redesigned the Matches screen into a professional photo-first discovery UI.
- Added match tabs: New, Daily, My Matches, Near Me, More Matches.
- Added Marathi and English labels for the Matches screen tabs.
- Uses backend `display.card` and `display.actions` when available.
- Keeps fallback rendering for the older list payload.
- Moved search fields into collapsible filters.
- Added a mini profile carousel for discovery sections.
- Retained existing profile detail navigation.
- Retained existing send-interest flow.
- No fake chat, payment, premium, or near-me backend logic was added.
