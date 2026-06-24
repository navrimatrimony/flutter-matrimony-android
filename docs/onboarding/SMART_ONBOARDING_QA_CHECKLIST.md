# Smart Matrimony Onboarding QA Checklist

Phase 6 checklist for final QA, hardening, and regression review. This document is separate from the frozen blueprint and does not change the onboarding specification.

## Route And Entry Points

- `/register` opens `SmartOnboardingScreen`.
- `/create-profile` opens `SmartOnboardingScreen`.
- `/smart-onboarding` opens `SmartOnboardingScreen`.
- Landing screen Register button opens `SmartOnboardingScreen`.
- Login screen new-user link opens `SmartOnboardingScreen`.
- Bootstrap routes authenticated users without an own profile to `/smart-onboarding`.
- `RegisterScreen` remains legacy only and must not be imported by production registration routes.
- `CreateMatrimonyProfileScreen` remains legacy/edit-adjacent only and must not be used as the production registration route.

## OTP And Account

- Mobile OTP is the first registration step after language selection.
- OTP channel is SMS/mobile OTP.
- WhatsApp alerts opt-in is separate and must not imply WhatsApp verification.
- `whatsapp_verified_at` must not be set by onboarding OTP.
- Terms and Privacy consent are required before OTP send.
- Consent version is sent with OTP send.
- Raw OTP must not be stored or logged by production backend behavior.
- Account shell is created only after successful OTP verification.
- `users.mobile` is the canonical normalized mobile field.
- Email is optional.
- No fake email is generated when email is skipped.
- Email conflict is checked only when an email is provided.
- `creator_name` maps to account holder name, not candidate name.
- Candidate full name is captured only in Basic Candidate Info.
- For `profile_for_whom=self`, account name may be offered as an explicit user action only.
- Password login/register remains backward-compatible, but onboarding does not force password.

## Onboarding Steps

- Profile for whom is selected before candidate profile details.
- Gender may be locked from profile relation metadata when backend returns it.
- Changing marital status to never married clears children data.
- Children fields are hidden for never married.
- Religion change clears caste and sub-caste.
- Caste change clears sub-caste.
- Strictness values sent to backend are `open`, `preferred`, or `required`.
- Location step only saves approved final locations to the profile.
- Pending location suggestions are draft-only and keep profile not searchable.
- Education selections are backend objects, not raw strings.
- Education selected chips stay inside the field.
- Education search text clears after selection.
- Occupation search uses backend category metadata and pagination.
- Changing `working_with` clears invalid `working_as` and income values.
- Not Working hides occupation and income fields.
- Income period supports backend options such as annual/monthly when returned.
- Lifestyle is limited to diet, smoking, and drinking.
- Family optional step does not include family type.
- Family optional step keeps sibling counts simple and does not create detailed sibling rows.
- Photo step allows continuing to activation checklist, but missing/pending photo keeps profile not searchable.
- Final summary screen is not shown; activation checklist/status is shown instead.

## Forbidden In Registration Onboarding

- No mother tongue field.
- No astrology/horoscope fields.
- No birth time or birth place fields.
- No family type field.
- No biodata/OCR production option.
- No marriage history repeater.
- No long partner preference form.
- No fake email.
- No account-level gender field.

## Activation And Searchability

- Activation checklist is backend-driven.
- `is_searchable=false` when account/mobile verification is incomplete.
- `is_searchable=false` when required profile fields are incomplete.
- `is_searchable=false` when location is missing or pending approval.
- `is_searchable=false` when photo is missing, pending, or rejected.
- `is_searchable=false` when governance conflict is pending.
- `is_searchable=true` only when backend checklist allows it.
- Flutter must display backend checklist state and must not infer searchability locally.

## Lookup And Picker UX

- Smart picker opens as a right-side slide panel.
- Default panel width is about 70% on larger screens and adjusts on small screens.
- Search input stays pinned at the top.
- Footer CTA stays keyboard-safe.
- Search uses debounce.
- Large lists use backend pagination.
- Popular options are shown when backend returns them.
- Missing translations fall back to backend label/name without breaking display.
- Request-to-add flows for location, education, and occupation create pending suggestions only.

## Backend Regression Checks

- Mobile OTP send and verify endpoints work for new and existing accounts.
- Account details endpoint accepts nullable email.
- Account details endpoint keeps existing password login compatibility.
- Onboarding draft save rejects unsupported step keys.
- Profile save uses governed `MutationService` path.
- Phase 2 profile save rejects forbidden registration fields.
- Location lookup returns hierarchy labels and final-node metadata.
- Education and occupation lookups return category labels.
- Auto partner preference preview and generation are non-blocking.

## Manual QA Flow

1. Fresh install or clear app storage.
2. Select language.
3. Enter mobile number and accept Terms/Privacy.
4. Send OTP and verify.
5. Skip email, enter creator name, and continue.
6. Choose `self` profile relation.
7. Confirm candidate name is separate and only filled if user taps the account-name action.
8. Select basic info with never married; verify children fields are hidden.
9. Change to divorced/widowed/separated; verify children fields appear.
10. Select religion, caste, sub-caste; change religion and verify caste/sub-caste clear.
11. Search approved location and save.
12. Submit a new location request and verify it remains pending/draft-only.
13. Select multiple education rows and verify chips remain inside the picker field.
14. Select Working With and Working As; change Working With and verify occupation/income clear.
15. Select Not Working and verify occupation/income fields hide.
16. Fill lifestyle and optional family details.
17. Continue without photo and verify checklist says not searchable.
18. Upload a photo and verify checklist still blocks until approval.
19. After backend approval and required fields complete, verify backend returns searchable status.

