// Moved into `package:navri_location_engine` so the member app and the Suchak
// app share one definition instead of two copies that drift.
//
// Re-exported from its old path on purpose: every call site keeps working
// unchanged, so moving the model did not become a rename touching hundreds of
// files.
export 'package:navri_location_engine/navri_location_engine.dart'
    show OnboardingOption;
