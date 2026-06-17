# Flutter APK — Codex Instructions

This repository is the Flutter Android user app.

Backend reference repository:

`E:\LaravelProjects\laravel-matrimony`

Laravel is read-only reference material only.

## Edit boundary

Codex may edit files only inside:

`E:\LaravelProjects\flutter-apk`

Codex must never modify files inside:

`E:\LaravelProjects\laravel-matrimony`

## Scope

Implement user-side Flutter app only.

Do not implement or modify:
- Laravel backend code
- admin features
- suchak features
- server deployment scripts
- database migrations
- backend API behavior

## API contract rule

Laravel is the source of truth for:
- route paths
- `/api` vs `/api/v1`
- request payload keys
- validation requirements
- response JSON fields
- photo upload response behavior

Before changing Flutter API client or UI payloads, inspect the corresponding Laravel route/controller.

## Known Laravel user API facts

Laravel user auth routes are under `/api/v1`.

Profile create requires:
- `full_name`
- `date_of_birth`
- `caste`
- `highest_education`
- numeric `location_id`

Profile update accepts:
- `full_name`
- `date_of_birth`
- `caste`
- `highest_education`
- `location_id`
- `address_line`

Photo upload response returns:
- `data.profile_photo`
- `data.status`

## Mandatory verification

Before and after every task, check Laravel status:

`git -C "E:\LaravelProjects\laravel-matrimony" status --short`

Expected output is empty.

After Flutter edits, run from Flutter repo:

`git diff --check`

`flutter analyze`

If Dart/Flutter toolchain hangs, report it separately and do not claim verification passed.

Do not commit unless explicitly asked.
