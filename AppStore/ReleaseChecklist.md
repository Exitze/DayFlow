# Dayflow App Store Release Checklist

Last updated: May 3, 2026

## Project-Side Release Items

- [x] Main app bundle ID is `com.exitze.dayflow`.
- [x] Widget extension bundle ID is `com.exitze.dayflow.widget`.
- [x] App Group is `group.com.exitze.dayflow`.
- [x] Main app and widget entitlements include the App Group.
- [x] Widget extension is embedded in the main app target.
- [x] App and widget privacy manifests are included.
- [x] Privacy manifests declare no tracking and no collected data for the current local-only build.
- [x] Required reason API declaration exists for `UserDefaults` with reason `CA92.1`.
- [x] `ITSAppUsesNonExemptEncryption` is set to `false`.
- [x] In-app Settings include Privacy Policy, Terms, and Support.
- [x] In-app Settings include local data reset controls.
- [x] Public Privacy Policy, Terms, and Support pages exist under GitHub Pages.
- [x] Test notification UI and test notification scheduling code are removed from the production interface.
- [x] App Store metadata draft is prepared in `AppStore/AppStoreMetadata.md`.

## App Store Connect Items

These cannot be completed only from the repository:

- [ ] Confirm the paid Apple Developer Program membership is active.
- [ ] Confirm App Groups are enabled for both identifiers in Apple Developer.
- [ ] Confirm `group.com.exitze.dayflow` is attached to both the app ID and widget extension app ID.
- [ ] Select the correct Apple signing team in Xcode.
- [ ] Create an archive from the `Dayflow` scheme.
- [ ] Upload the build to App Store Connect.
- [ ] Add screenshots for required iPhone sizes.
- [ ] Fill App Information, category, age rating, copyright, and support contact.
- [ ] Paste metadata from `AppStore/AppStoreMetadata.md`.
- [ ] Add Privacy Policy URL: `https://exitze.github.io/DayFlow/privacy.html`.
- [ ] Add Support URL: `https://exitze.github.io/DayFlow/support.html`.
- [ ] Fill App Privacy as "Data Not Collected" for the current implementation.
- [ ] Add accessibility information in App Store Connect if ready.
- [ ] Test the build through TestFlight on a real device.
- [ ] Submit for App Review.

## Final Pre-Submission Checks

- [ ] No simulator chrome, debug overlays, placeholder text, or personal data in screenshots.
- [ ] No test-only buttons or test notification flows in the production UI.
- [ ] Privacy policy matches the binary exactly.
- [ ] App privacy label matches the binary exactly.
- [ ] Support URL opens publicly without login.
- [ ] Privacy Policy URL opens publicly without login.
- [ ] Widget extension appears in the iOS widget gallery.
- [ ] App Group storage works on a real device.
- [ ] Local notifications request permission and schedule real reminders.
- [ ] Reset controls remove local data as described.
- [ ] Build number is incremented before upload.

## Official Apple References

- App Store submission overview: https://developer.apple.com/app-store/submitting/
- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- App privacy details: https://developer.apple.com/app-store/app-privacy-details/
- App Store Connect privacy management: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy
- Privacy manifest files: https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
