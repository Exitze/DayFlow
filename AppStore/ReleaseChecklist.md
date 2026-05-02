# Dayflow App Store Release Checklist

Current project-side items:

- Privacy manifest added at `Dayflow/PrivacyInfo.xcprivacy`.
- UserDefaults required reason declared as `CA92.1`.
- Tracking disabled in the privacy manifest.
- Collected data list is empty for the current local-only version.
- Export compliance flag `ITSAppUsesNonExemptEncryption` is set to false.
- Settings include local data deletion controls.
- Settings include local Privacy Policy, Terms, Support, and release readiness sections.

External items still required before App Review:

- Active Apple Developer Program account.
- Real bundle signing team and distribution certificate/profile.
- Public Privacy Policy URL.
- Public Support URL.
- Final app name, subtitle, description, keywords, category, age rating, and privacy label in App Store Connect.
- Clean App Store screenshots for required iPhone sizes.
- TestFlight build tested on a real device.
- Final check that no debug text, placeholder support email, or temporary screenshots remain.

Official Apple references:

- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- App privacy details: https://developer.apple.com/app-store/app-privacy-details/
- Privacy manifest files: https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
- Account deletion guidance: https://developer.apple.com/support/offering-account-deletion-in-your-app/
