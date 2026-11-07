# Deferred IELTS study-center sources

These two files were uploaded to `Sources/LumaReader/` in commit `9305437`.
They are preserved here, outside the main LumaReader application target, while
immersive-reader acceptance is completed. The uploaded `Package.swift` describes
a separate package but lived inside the app's source folder; SwiftPM therefore
tried to compile it as application Swift and failed to import `PackageDescription`.

The all-in-one source also has syntax errors in the uploaded version (for
example invalid escape sequences, unterminated strings, and malformed
declarations). It is **not** integrated, fixed, or tested by this reader PR.
The original content is retained for a separate, properly structured study
center integration with its own resources and tests.
