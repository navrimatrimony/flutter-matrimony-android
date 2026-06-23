# Flutter Edit Profile Parity

Inspection date: 2026-06-23

Sources inspected:

- Laravel `config/field_catalog.php`
- Laravel `app/Http/Controllers/ProfileWizardController.php`
- Laravel `app/Http/Controllers/Api/MatrimonyProfileApiController.php`
- Laravel `docs/MOBILE_API_CONTRACT.md`
- Laravel wizard section blades and shared engines listed in the task
- Flutter `lib/features/matrimony_profile/edit_full_profile_screen.dart`
- Flutter `lib/features/matrimony_profile/create_profile_screen.dart`
- Flutter `lib/features/home/home_screen.dart`
- Flutter `lib/core/api_client.dart`
- Flutter `lib/core/api_routes.dart`

## Parity Matrix

### `basic-info`

| Laravel field/key | Mobile API accepts? | Flutter state/prefill exists? | Flutter UI exists? | Flutter payload sends it? | Result |
| --- | --- | --- | --- | --- | --- |
| `full_name` | yes | yes | yes | yes | complete |
| `gender_id` | yes | yes | yes | yes | complete |
| `date_of_birth` | yes | yes | yes | yes | complete |
| `religion_id` | yes | yes | yes | yes | complete |
| `caste_id`, `caste` | yes | yes | yes | yes | complete |
| `sub_caste_id` | yes | yes | yes | yes | complete |
| `location_id` | yes | yes | yes | yes | complete |
| `address_line` | yes, PUT only | yes | yes | yes | complete |
| `birth_time` | yes | yes | yes | yes | complete |
| `birth_city_id`, `birth_place_text` | yes | yes | yes | yes | complete |
| `mother_tongue_id` | yes | yes | yes | yes | complete |
| `marital_status_id`, `has_children` | yes | yes | yes | yes | complete |
| `self_addresses[*]` repeater | no | no | no | no | backend contract missing |
| `marriages[*]` details | no | no | no | no | backend contract missing |
| `children[*]` rows | no | no | no | no | backend contract missing |

### `physical`

| Laravel field/key | Mobile API accepts? | Flutter state/prefill exists? | Flutter UI exists? | Flutter payload sends it? | Result |
| --- | --- | --- | --- | --- | --- |
| `height_cm` | yes | yes | yes | yes | complete |
| `weight_kg` | yes | yes | yes | yes | complete |
| `complexion_id` | yes | yes | yes | yes | complete |
| `blood_group_id` | yes | yes | yes | yes | complete |
| `physical_build_id` | yes | yes | yes | yes | complete |
| `spectacles_lens` | yes | yes | yes | yes | complete |
| `physical_condition` | yes | yes | yes | yes | complete |
| `diet_id` | yes | yes | yes | yes | complete |
| `smoking_status_id` | yes | yes | yes | yes | complete |
| `drinking_status_id` | yes | yes | yes | yes | complete |

### `education-career`

| Laravel field/key | Mobile API accepts? | Flutter state/prefill exists? | Flutter UI exists? | Flutter payload sends it? | Result |
| --- | --- | --- | --- | --- | --- |
| `highest_education` | yes | yes | yes | yes | complete |
| `education_slots` | yes | yes | yes | yes | complete |
| `occupation_master_id`, `occupation_custom_id` | yes | yes | yes | yes | complete |
| `company_name` | yes | yes | yes | yes | complete |
| `work_location_text` | yes | yes | yes | yes | complete |
| `highest_education_other` | no | no | no | no | backend contract missing |
| `working_with_type_id`, `profession_id` | no | no | no | no | backend contract missing |
| `work_city_id`, `work_state_id` | no | no | no | no | backend contract missing |
| personal income engine keys: `income_value_type`, `income_amount`, `income_min_amount`, `income_max_amount`, `income_currency_id`, `income_period`, `income_private` | no | no | no | no | backend contract missing |
| legacy income keys: `annual_income`, `income_range_id` | no write contract | no | no | no | backend contract missing |

### `family-details`

| Laravel field/key | Mobile API accepts? | Flutter state/prefill exists? | Flutter UI exists? | Flutter payload sends it? | Result |
| --- | --- | --- | --- | --- | --- |
| `father_name` | yes | yes | yes | yes | complete |
| `father_occupation`, `father_occupation_master_id`, `father_occupation_custom_id` | yes | yes | yes | yes | complete |
| `father_extra_info` | yes | yes | yes | yes | complete |
| `mother_name` | yes | yes | yes | yes | complete |
| `mother_occupation`, `mother_occupation_master_id`, `mother_occupation_custom_id` | yes | yes | yes | yes | complete |
| `mother_extra_info` | yes | yes | yes | yes | complete |
| `father_contact_*`, `mother_contact_*` | no | no | no | no | backend contract missing |
| `parents_addresses[*]` repeater | no | no | no | no | backend contract missing |

### `siblings`

| Laravel field/key | Mobile API accepts? | Flutter state/prefill exists? | Flutter UI exists? | Flutter payload sends it? | Result |
| --- | --- | --- | --- | --- | --- |
| `has_siblings` | yes | yes | yes | yes | complete |
| `siblings[*]` repeater rows | no | no | no | no | backend contract missing |

### `family-details` overview fields

| Laravel field/key | Mobile API accepts? | Flutter state/prefill exists? | Flutter UI exists? | Flutter payload sends it? | Result |
| --- | --- | --- | --- | --- | --- |
| `family_type_id` | yes | yes | yes | yes | complete |
| `family_status` | yes | yes | yes | yes | complete |
| `family_values` | yes | yes | yes | yes | complete |
| family income engine keys: `family_income_value_type`, `family_income_amount`, `family_income_min_amount`, `family_income_max_amount`, `family_income_currency_id`, `family_income_period`, `family_income_private` | no | no | no | no | backend contract missing |

### `relatives`

| Laravel field/key | Mobile API accepts? | Flutter state/prefill exists? | Flutter UI exists? | Flutter payload sends it? | Result |
| --- | --- | --- | --- | --- | --- |
| `relatives_parents_family[*]` repeater rows | no | no | no | no | backend contract missing |

### `alliance`

| Laravel field/key | Mobile API accepts? | Flutter state/prefill exists? | Flutter UI exists? | Flutter payload sends it? | Result |
| --- | --- | --- | --- | --- | --- |
| `other_relatives_text` | yes | yes | yes | yes | complete |
| `relatives_maternal_family[*]` repeater rows | no | no | no | no | backend contract missing |
| `alliance_networks[*]` rows | no | no | no | no | backend contract missing |

### `property`

| Laravel field/key | Mobile API accepts? | Flutter state/prefill exists? | Flutter UI exists? | Flutter payload sends it? | Result |
| --- | --- | --- | --- | --- | --- |
| `property_details` | yes | yes | yes | yes | complete |
| structured property summary/assets fields | no | no | no | no | backend contract missing |

### `horoscope`

| Laravel field/key | Mobile API accepts? | Flutter state/prefill exists? | Flutter UI exists? | Flutter payload sends it? | Result |
| --- | --- | --- | --- | --- | --- |
| `rashi_id` | yes | yes | yes | yes | complete |
| `nakshatra_id` | yes | yes | yes | yes | complete |
| `charan` | yes | yes | yes | yes | complete |
| `gan_id` | yes | yes | yes | yes | complete |
| `nadi_id` | yes | yes | yes | yes | complete |
| `yoni_id` | yes | yes | yes | yes | complete |
| `varna_id` | yes | yes | yes | yes | complete |
| `vashya_id` | yes | yes | yes | yes | complete |
| `rashi_lord_id` | yes | yes | yes | yes | complete |
| `mangal_dosh_type_id` | yes | yes | yes | yes | complete |
| `devak`, `kul`, `gotra`, `navras_name`, `birth_weekday` | yes | yes | yes | yes | complete |

### `about-me`

| Laravel field/key | Mobile API accepts? | Flutter state/prefill exists? | Flutter UI exists? | Flutter payload sends it? | Result |
| --- | --- | --- | --- | --- | --- |
| `narrative_about_me` | yes | yes | yes | yes | complete |
| `narrative_expectations` | yes | yes | yes | yes | complete |
| `additional_notes` | no | no | no | no | backend contract missing |

### `about-preferences`

| Laravel field/key | Mobile API accepts? | Flutter state/prefill exists? | Flutter UI exists? | Flutter payload sends it? | Result |
| --- | --- | --- | --- | --- | --- |
| `preferred_age_min`, `preferred_age_max` | yes | yes | yes | yes | complete |
| `preferred_height_min_cm`, `preferred_height_max_cm` | yes | yes | yes | yes | complete |
| `preferred_income_min`, `preferred_income_max` | yes | yes | yes | yes | complete |
| `marriage_type_preference_id` | yes | yes | yes | yes | complete |
| `partner_profile_with_children` | yes | yes | yes | yes | complete |
| `preferred_profile_managed_by` | yes | yes | yes | yes | complete |
| `willing_to_relocate` | yes | yes | yes | yes | complete |
| `preferred_religion_ids`, `preferred_caste_ids`, `preferred_intercaste` | yes | yes | yes | yes | complete |
| `preferred_education_degree_ids`, `preferred_occupation_master_ids` | yes | yes | yes | yes | complete |
| `preferred_marital_status_ids`, `preferred_diet_ids` | yes | yes | yes | yes | complete |
| `preferred_country_ids`, `preferred_state_ids`, `preferred_district_ids`, `preferred_taluka_ids` | yes | yes | yes | yes | complete |
| `preference_preset` | no | no | no | no | backend contract missing |

### `photo`

| Laravel field/key | Mobile API accepts? | Flutter state/prefill exists? | Flutter UI exists? | Flutter payload sends it? | Result |
| --- | --- | --- | --- | --- | --- |
| `profile_photo` | yes, separate `POST /api/v1/matrimony-profile/photo` | yes | yes | yes, via existing multipart upload screen | complete |

## Completed Flutter Sections

- Basic details now cover all mobile-accepted scalar fields, including `address_line`.
- Photo is available from the Edit All section list and opens the existing `PhotoUploadScreen`.
- Edit entry point inspection found `home_screen.dart` opens `EditFullProfileScreen`; no live call-site opens `CreateMatrimonyProfileScreen(existingProfile: ...)`.
- Section saves call `ApiClient.updateMatrimonyProfile()`, and successful saves refresh through `ApiClient.getMyProfile()`.

## Remaining Backend-Contract Gaps

- Structured self address and parents address repeaters.
- Parent contact number fields.
- Sibling repeater rows.
- Paternal and maternal relative repeater rows.
- Alliance network rows.
- Marriage history rows and children rows.
- Personal income and family income engines.
- Structured property summary/assets.
- About-me `additional_notes`.
- Web-only partner preference preset.

## Income Contract Note

The mobile API supports partner preference income keys only:

- `preferred_income_min`
- `preferred_income_max`

The mobile API does not currently accept personal income or family income engine keys. To support Laravel income-engine parity, the backend mobile contract would need explicit accepted keys for personal income and family income, plus GET response fields that preserve the selected value type, amount or range, currency, period, and privacy flag.

## Manual Test Checklist

- Open Home drawer -> Edit Profile and confirm it opens `EditFullProfileScreen`.
- Confirm Basic details prefill `address_line` when the API returns it.
- Edit Basic details, save section, and confirm `PUT /api/v1/matrimony-profile` includes `address_line`.
- Open the Photo card from Edit Profile and confirm it navigates to `PhotoUploadScreen`.
- Upload a photo and return to Edit Profile; confirm the Photo card summary updates after refresh.
- Confirm `CreateMatrimonyProfileScreen` is used only for first-time profile creation.
- Confirm no sibling, relative, parent contact, structured address, personal income, or family income fake fields were added to Flutter.
