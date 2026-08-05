# U9b Implementation Contract — Member app: meetings list (read-only)

**Unit:** U9b  
**Authority:** `docs/MARKETPLACE-MASTER-EXECUTION-SSOT.md` §U9b (laravel)  
**Schema:** none · depends U9a  

## Runtime truths referenced by U9b

| RT | Validation |
|---|---|
| **RT-9** | List consumes U9a `GET /api/v1/suchak-meetings`. |
| **RT-13** | ARB strings inserted as text (no JSON rewrite of the whole file). |

## Behaviour

1. API client + route for `GET /suchak-meetings`.
2. New `SuchakMeetingsScreen` — read-only list; honest empty state.
3. Entry from existing Suchak-requests screen; route in `main.dart`.
4. Confirm/dispute actions deferred to U10/U11.

## Tests

- `flutter analyze` clean on touched files.
- Widget test: renders list + empty state.
- `flutter build apk --debug`.

## Rollback

`git revert <sha>`
