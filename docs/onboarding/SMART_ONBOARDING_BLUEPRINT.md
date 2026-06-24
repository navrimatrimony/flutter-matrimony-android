# Smart Matrimony Onboarding Blueprint

## Core Direction

Mobile registration must be an OTP-first Smart Matrimony Onboarding flow. Laravel remains the source of truth. Flutter must reuse existing backend lookup APIs, profile API contracts, and governed mutation paths instead of duplicating master-data or profile-write logic.

The production registration route must lead to Smart Onboarding. The old simple registration screen must not remain reachable as a production bypass through normal navigation, deep links, or auth guard fallbacks.

## Non-Negotiables

- Locale/language must be detected or selected first, before mobile OTP.
- Primary WhatsApp/mobile number is compulsory and must be OTP verified.
- Email is optional. The user can skip email and add or verify it later.
- Missing or unverified email must not block profile activation or searchability unless a future backend policy explicitly requires it.
- Fake or placeholder email addresses must not be generated.
- Creator/account name and candidate/profile name are separate fields and must not be silently mixed.
- Phase 1 allows one candidate matrimony profile per account.
- Laravel enum values and API contracts are the source of truth.
- Missing translations should fall back to English labels.
- Phase 1 must not add mother tongue, astrology, horoscope, family type, biodata upload, or OCR.
- Onboarding must not include a long partner preference form. Partner preferences should be generated as an editable draft from onboarding data.
- Final summary screen must not be shown. Show only the Activation Checklist/status screen after profile creation.

## Account And Profile Policy

Phase 1 policy:

- One account can create only one matrimony candidate profile.
- If a profile already exists, onboarding should resume or edit that profile instead of creating a duplicate.
- Multiple candidate profiles per account are Phase 2 only.

Account/user fields:

- `creator_name` required
- `mobile` required
- `mobile_normalized` required
- `mobile_verified_at` required
- `whatsapp_number` default same as mobile
- `whatsapp_same_as_mobile = true` in Phase 1
- `whatsapp_verified_at = null` unless WhatsApp OTP is actually used
- `email` nullable / optional
- `email_verified_at` nullable
- `locale` required
- password only if current Laravel auth requires it

Profile/candidate fields:

- `profile_for_whom` / backend `registering_for`
- `full_name`
- `gender`
- `dob`
- `height`
- `marital_status`
- religion, caste, location, education, career, lifestyle, family, and photo fields

Google/account name must never be saved silently as candidate full name. If `profile_for_whom = self`, the account name may be shown only as a suggestion that the user explicitly confirms.

## OTP And Existing User Flow

1. Detect or select locale.
2. Show the mobile field as `WhatsApp mobile number *`.
3. Send OTP with resend cooldown and rate limits.
4. Verify OTP with attempt limits.
5. If the mobile number already exists, verify OTP, log the user in, and resume onboarding or open the dashboard.
6. If the mobile number is new, create an account shell and start onboarding.
7. If email is provided and belongs to another account, show a conflict/login/merge flow.
8. If email is skipped, continue onboarding.
9. Mask mobile/email in logs. Never log OTP values.

If OTP is sent through SMS, only `mobile_verified_at` should be set. Do not set `whatsapp_verified_at` unless WhatsApp OTP verification is actually used.

## Consent

Terms/privacy consent must be stored with:

- `consent_version`
- `accepted_at`
- IP address and user agent if available
- `whatsapp_alerts_opt_in` separately

Transactional OTP verification and promotional/profile-alert consent must be treated separately.

## Onboarding Steps

### 1. Language / Locale

Detect device locale and allow user override. The OTP screen should respect the selected locale and may include a language switch.

### 2. Mobile OTP

Mobile/WhatsApp number is the mandatory identity. Onboarding cannot proceed until OTP verification succeeds.

### 3. Account Details

Collect:

- creator name
- optional email
- locale confirmation
- password only if current backend auth still requires it

Email skip must not block profile creation, activation, or searchability.

### 4. Profile For Whom

Use backend enum values as the submitted contract. Flutter may localize labels, but must not invent values.

Gender and text logic:

- `self`: ask gender
- `son` / `brother`: gender = male
- `daughter` / `sister`: gender = female
- `relative` / `friend`: ask gender

This step also controls pronoun text and candidate-name suggestion behavior.

### 5. Basic Candidate Info

Collect:

- candidate full name
- date of birth
- height
- marital status

DOB must be validated using backend age policy/config. Underage, future, or impossible dates must be blocked.

Children logic:

- Never married: children fields hidden and cleared.
- Divorced, separated, widowed, annulled, awaiting divorce: children fields allowed.
- Marital status changes must clear invalid children fields.
- Marriage history repeater is not part of registration Phase 1.

### 6. Religion / Caste

Use existing backend dependency:

- religion -> caste -> sub-caste

Preference toggles:

- same religion required/preferred
- same caste required/preferred
- same sub-caste required optional

Strictness mapping:

- required -> `must_match`
- preferred -> `preferred`
- unchecked -> `open` or backend default

Changing religion must clear invalid caste and sub-caste values. Changing caste must clear invalid sub-caste values.

### 7. Location

Display location using Laravel hierarchy:

- Rural: village, taluka, district, state, pincode
- City: city + district/state
- Suburb/area: suburb/area + parent city + district/state

The final selected node must be an allowed final location node such as village, city, or suburb/area. State-only or district-only selection must not make a profile active/searchable.

If location is not found, allow an Add Location request. Pending location can be saved for a draft profile, but must keep `is_searchable=false`.

### 8. Education

Education picker must support multi-select chips. Selected items must be stored as objects, not strings, with backend-provided metadata such as:

- `id`
- `label`
- `category_label`
- `level_rank`

Categories must come from backend data. Do not hardcode categories in Flutter.

UX rules:

- Selected chips must appear inside the original field.
- Do not show a separate selected list below the field.
- After selecting a search result, clear the search text.
- Search results should be server-driven and paginated where needed.

Phase 1 not-found behavior:

- Do not save arbitrary custom education text directly as a master value.
- Show `Not found? Request to add` or use an existing backend-approved custom mapping flow only if already available.

### 9. Career

Career dependency:

- `working_with` is the parent field.
- `working_as` is a dependent grouped occupation picker.
- Changing `working_with` must clear invalid `working_as`.

Occupation categories must come from backend data. Do not hardcode categories in Flutter.

If occupation is not found:

- Do not save arbitrary custom occupation text directly as a master value.
- Show `Not found? Request to add` or use an existing backend-approved custom mapping flow only if already available.

If `Not Working` is selected, occupation and income should be hidden or made optional as backend policy requires.

Income must support the backend contract, including:

- monthly/annual period if supported
- amount/range/undisclosed modes if supported
- income privacy checkbox

Income may be used for matching, but public display must respect privacy settings.

### 10. Lifestyle

Collect diet according to backend policy. Smoking and drinking are optional. Candidate lifestyle fields and partner-preference fields must remain separate; preference diet can be auto-generated as `preferred`.

### 11. Family Optional

Optional fields may include, only if backend supports them:

- father occupation
- mother occupation
- brothers count
- sisters count
- native/parents location

These fields should not block onboarding. They may contribute to profile completion scoring.

### 12. Photo

Photo upload can happen after or near profile creation.

Status behavior:

- Photo skipped or missing: `awaiting_photo_upload`, `is_searchable=false`
- Photo uploaded: `awaiting_photo_approval`, `is_searchable=false`
- Photo approved: active/searchable guard may pass if all other backend requirements pass

Server/admin approval remains authoritative. Client-side checks such as file size, image format, and quality hints are helpful but not sufficient.

### 13. Activation Checklist

Do not show a final summary screen. Show an Activation Checklist/status screen with backend-driven statuses:

- mobile verified
- email added, optional
- required fields complete
- valid location
- photo uploaded
- photo approved
- governance clear
- profile active/searchable

## Required Fields Policy

Required fields and completion status must come from Laravel/backend policy/status. Flutter must not hardcode activation-required fields. Flutter should display backend-provided required/completion state and guide the user to missing items.

## SmartPickerPanel

SmartPickerPanel must be a common reusable component, not a new custom picker per field.

Requirements:

- right-side slide panel
- default width 70%
- usable width may adjust on very small screens or accessibility large-text modes
- SafeArea safe
- keyboard/viewInsets safe
- pinned search box
- frequently used/popular section when backend provides it
- grouped/all-list section
- server-side search and pagination for large lists
- 250-300ms debounce
- multi-select chip mode for education
- selected chips visible in the original field
- footer/CTA must not hide below the keyboard

The default interaction pattern should remain a right-side slide panel, not a bottom dropdown.

## Partner Preference Auto-Generation

Onboarding should generate a draft partner preference profile instead of asking the user to fill a long preference form.

Auto-generate from registration data:

- gender
- age range
- height range
- marital status
- religion/caste/sub-caste strictness from explicit toggles
- location nearby/same district/state
- education equivalent/higher category
- occupation broad category
- income broad range, privacy respected
- diet preferred

Preference metadata:

- `source = auto_from_registration`
- strictness: `must_match`, `preferred`, `open`

`must_match` must only be created from explicit user choices. Auto-generated preferences must be editable later from dashboard/profile edit.

## Backend Principles

- Laravel remains the source of truth.
- Profile create/update must use MutationService or the existing governed mutation path.
- Controllers should not directly update the profile model if that bypasses governance.
- Laravel must support optional email properly if mobile-first registration is adopted. Do not generate fake email values.
- `profile_status` and `is_searchable` should remain separate.
- Search/list queries must use `is_searchable=true`.
- Draft/resume is a Phase 1 minimum:
  - local draft after every step
  - server draft after major steps
  - `last_completed_step`
  - resume onboarding route

## Privacy Defaults

- Mobile number hidden publicly.
- Email hidden publicly.
- Parent/contact numbers hidden from other profiles.
- Income display respects privacy.
- Contact visibility follows existing unlock/mutual/admin rules.
- My Profile may show own data so users can correct mistakes.

## Additional UX / Dependency Acceptance Rules

- Final summary screen must not be shown; Activation Checklist/status screen only.
- Pending photo upload or pending photo approval must keep `is_searchable=false`.
- Location display must follow Laravel hierarchy:
  - Rural: village, taluka, district, state, pincode
  - City: city + district/state
  - Suburb/area: suburb/area + parent city + district/state
- Parent field changes must clear invalid child fields:
  - religion changes -> caste/sub-caste clear
  - caste changes -> sub-caste clear
  - marital status changes -> invalid children fields clear
  - working_with changes -> invalid working_as clear
- Education multi-select selected chips must appear inside the original field.
- Do not show a separate selected education list below the field.
- Education/occupation search result selection must clear the search text.
- SmartPickerPanel may adjust usable width on small/accessibility screens, but the default right-side slide pattern must remain.

## Phase 1 Scope

Phase 1 includes:

- OTP-first onboarding
- compulsory WhatsApp/mobile number
- optional email
- locale/language selection
- account/profile separation
- one candidate profile per account
- profile_for_whom gender logic
- basic info
- religion/caste/sub-caste dependency
- location hierarchy and add-location request
- education picker
- career picker with income period/privacy
- lifestyle basics
- optional family fields
- photo upload and approval gate
- Activation Checklist/status screen
- draft/resume
- auto-generated partner preference draft

## Phase 2 Scope

Phase 2 may include:

- multiple candidate profiles per account
- passwordless/PIN/biometric refinement
- biodata upload/OCR/manual review
- deeper preference editor
- admin approval dashboards if missing
- advanced onboarding analytics

## Final Acceptance Criteria

- Mobile OTP verification is required before onboarding proceeds.
- Existing mobile number logs in and resumes instead of creating a duplicate user.
- Existing candidate profile resumes/edits instead of creating a duplicate profile.
- Email can be skipped and onboarding continues.
- Unverified email does not block activation/searchability unless a future backend policy explicitly requires it.
- If email is provided, conflicts are handled.
- Candidate and creator names are never silently mixed.
- Old RegisterScreen is not reachable through production navigation, deep links, or auth guard fallback.
- Education/occupation arbitrary custom text is not saved directly as a master value.
- Pending/missing photo upload or pending photo approval keeps `is_searchable=false`.
- Pending location keeps `is_searchable=false`.
- Required fields are not hardcoded in Flutter.
- Dependent parent field changes clear invalid child values.
- Education chips stay inside the field and search text clears after selection.
- Missing translations fall back to English.
- Onboarding resume works after app close.
