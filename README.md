# Smart Cemetery

Flutter mobile services and web administration. With no Firebase options, the app opens a **local preview** that stores data on each device or browser separately. Preview records are illustrative and do not represent a real cemetery.

See the [feature coverage checklist](docs/feature-coverage.md) for every mobile and admin page from the reference image, its current verification, and the remaining live checks.

## Setup guide: mobile app and web admin

Both apps are built from this **one Flutter project**. An Android or iOS run opens the visitor app; a web run opens the administrator/staff sign-in screen. Choose one of these modes:

| Mode | What you need | Where data goes |
| --- | --- | --- |
| Local preview | Flutter only | This device or browser; accounts and devices do not sync |
| Connected local demo | Flutter, Node.js/npm, Java, Firebase emulators | Local Auth, Firestore, and Storage emulators; sample accounts and records |
| Real deployment | Flutter and your own Firebase project | Your Firebase Authentication, Firestore, and Storage services |

### 1. Install the development tools

1. Install the Flutter SDK and ensure `flutter` is on your `PATH`. This project requires **Dart 3.13 or newer, below 4.0**; use a Flutter release that includes a compatible Dart SDK.
2. For Android, install Android Studio, the Android SDK, an emulator or a USB-connected Android phone, and a JDK compatible with your installed Android Gradle tooling. For iOS, use a Mac with Xcode, its command-line tools, and an iOS simulator or signed device. The Xcode project targets **iOS 15.0 or later**.
3. For web, install Chrome or another browser supported by `flutter run -d`. An internet connection is needed to download Flutter packages and display map tiles.
4. For the optional connected local demo, install Node.js/npm and a JDK supported by the Firebase Emulator Suite. The Firebase CLI is supplied by `tool/security/package.json` after `npm ci --prefix tool/security`.
5. From the repository root, check the environment and install dependencies:

   ```sh
   flutter doctor
   flutter pub get
   flutter devices
   ```

Fix any `flutter doctor` issue for the platform you intend to run. Use a device ID shown by `flutter devices` in the commands below.

### 2. Start immediately with local preview

No Firebase project, login account, map API key, or database installation is needed for this mode.

```sh
flutter run -d chrome            # Web admin preview
flutter run -d <device-id>      # Android or iOS visitor preview
```

Run these in separate terminals if you want both apps open at once. In the web app, select **Open Admin Preview**. On mobile, select **Explore Local Preview**. To inspect the visitor layout in Chrome, use `flutter run -d chrome --dart-define=MOBILE_WEB_PREVIEW=true`; this is a development view, and native camera scanning and scheduled notifications still need a phone. Preview content is sample data stored separately in each browser/device. Clearing browser storage or app data can remove it. The preview entrance is open to anyone with its URL, so do not publish it as a real admin site.

### 3. Connect your own Firebase project

Use the **same Firebase project ID** for the web and mobile builds so their records sync. This app passes Firebase options through Flutter's Dart defines (see [firebase_setup.dart](lib/services/firebase_setup.dart)); it does not read a `.env` file or a generated `firebase_options.dart`.

1. Create a Firebase project. Register a **Web app** for the admin build and the relevant **Android/iOS apps** for the visitor build. The current development identifiers are `com.example.capstone_project` in [Android Gradle](android/app/build.gradle.kts) and `com.example.capstoneProject` in the [Xcode project](ios/Runner.xcodeproj/project.pbxproj); replace those example identifiers before registering/releasing your own app. Each registered platform has its own App ID and may have its own API key. Copy the values from each platform's Firebase app configuration. The Web SDK `appId` is not the Android/iOS `appId`.
2. In Firebase **Authentication → Sign-in method**, enable **Email/Password**. For the web app, ensure its hosting domain is in **Authentication → Settings → Authorized domains**. `localhost` may need to be added for local development, depending on your Firebase project settings. Visitor registration is available in the mobile app; the web app offers sign-in for existing admin/staff accounts.
3. Create a **Cloud Firestore** database in the Firebase console. Select your intended region. Deploy this repository's [Firestore rules](firestore.rules) before entering real data; console defaults may not match the app's roles.
4. For the full feature set, enable **Cloud Storage for Firebase** and choose a bucket. Deploy [Storage rules](storage.rules) for profile, grave, and maintenance photos plus payment supporting documents. Cloud uploads fail when `FIREBASE_STORAGE_BUCKET` is omitted. Firestore stores records and file references; Storage holds uploaded files. If you are deliberately running without uploads, deploy only `firestore:rules` in the next step.
5. Install and sign in to the Firebase CLI, then deploy the checked-in rules from the repository root. Replace `YOUR_PROJECT_ID` with your project ID and inspect the target project before deployment:

   ```sh
   npm install -g firebase-tools
   firebase login
   firebase deploy --only firestore:rules,storage --project YOUR_PROJECT_ID
   ```

6. Create **one initial administrator**. In Firebase Authentication, add an Email/Password user. Copy that user's **UID**. In Firestore, create document `users/<UID>` with string fields `name`, `email`, and `role`, where `role` is exactly `admin`. The document ID must match the Authentication UID. Then sign in through the web app. A visitor who registers in the mobile app gets `role: visitor`; only an existing administrator can grant staff/admin roles through User Management. **Create staff login** makes a Firebase account and shows a unique temporary password once. **Add staff contact** adds directory information without login access.
7. In the web app, open **System Settings** and enter the real visiting hours, emergency contact, guidelines, and cemetery map center. Set the center by tapping or dragging the marker on the map, then choose tombstone or standard grave markers. Add or import verified grave records and place their map pins before giving visitors the app. Payment reminders need payment records linked to a visitor's account UID and a due date. A new Firebase project starts with no cemetery records; the sample data in local preview and emulator mode is not copied into it.

The rules recognize these roles: `visitor` can read grave/announcement information and access their own requests, visits, payments, feedback, and profile photo; `staff` can manage graves, map pins, and maintenance; `admin` can also manage payments, leases, announcements, settings, users, reports, and staff directory data. The web entry screen checks the `users/<UID>` role, and the Firestore/Storage rules protect the underlying data. Review both rule files for your organization's policy before production use.

### 4. Supply Firebase options to each build

Create one JSON file **outside this repository** for each platform, for example `../smart-cemetery-web.json` and `../smart-cemetery-android.json`. Fill these fields with the Firebase console values for that platform:

```json
{
  "FIREBASE_API_KEY": "YOUR_PLATFORM_API_KEY",
  "FIREBASE_APP_ID": "YOUR_PLATFORM_APP_ID",
  "FIREBASE_MESSAGING_SENDER_ID": "YOUR_SENDER_ID",
  "FIREBASE_PROJECT_ID": "YOUR_PROJECT_ID",
  "FIREBASE_AUTH_DOMAIN": "YOUR_PROJECT_ID.firebaseapp.com",
  "FIREBASE_STORAGE_BUCKET": "YOUR_ACTUAL_BUCKET_NAME"
}
```

`FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, and `FIREBASE_PROJECT_ID` are required to switch on Firebase mode. `FIREBASE_AUTH_DOMAIN` is used by Firebase web auth; `FIREBASE_STORAGE_BUCKET` is required for cloud photo upload. Copy the **actual** bucket name shown by Firebase, since its suffix can vary. Use the Web app's values in the web file and the Android/iOS app's values in separate mobile files. These are client configuration values, not an administrator password or service account key; do not put private credentials in these files. The sample files in `tool/security/` target local emulators only and cannot connect to your live project.

```sh
flutter run -d chrome --dart-define-from-file=../smart-cemetery-web.json
flutter run -d <android-device-id> --dart-define-from-file=../smart-cemetery-android.json
flutter run -d <ios-device-id> --dart-define-from-file=../smart-cemetery-ios.json
```

For a production web artifact, run `flutter build web --release --no-tree-shake-icons --dart-define-from-file=../smart-cemetery-web.json` and serve **`build/web/`** from an HTTPS static host. Keep `--no-tree-shake-icons`: the admin pages choose some icons dynamically, and tree shaking can remove those glyphs. Hosting configuration and deployment are not included in this repository. For Android/iOS release builds, use the matching platform file and configure your own app identifier and release signing in Android Studio/Xcode. The main Android manifest includes Internet access for connected release builds. Cleartext traffic to local Firebase emulators is enabled only in the Android debug manifest; production traffic must use HTTPS. Dart defines are compiled into the client; they do not provide secret storage.

### 5. Optional: run both apps against local Firebase emulators

This exercises real login and cross-device data flow without creating a live Firebase project. The demo project ID must start with `demo-`, and these commands use `demo-smart-cemetery`. Run each long-lived command in its **own terminal**, from the repository root:

```sh
npm ci --prefix tool/security
npm run emulators --prefix tool/security
```

After Auth (port `9098`), Firestore (`8188`), and Storage (`9198`) are ready, seed the example accounts and records in another terminal. Keep all three emulators in the **same suite**: Storage rules check Firestore roles.

```sh
npm run seed --prefix tool/security
flutter run -d chrome --dart-define-from-file=tool/security/web_emulator_defines.json
```

Run the mobile app with an emulator define file. The iOS example is ready to use:

```sh
flutter run -d <ios-simulator-id> --dart-define-from-file=tool/security/ios_emulator_defines.json
```

For an Android emulator, use the checked-in Android demo configuration:

```sh
flutter run -d <android-emulator-id> --dart-define-from-file=tool/security/android_emulator_defines.json
```

It uses `10.0.2.2`, the Android emulator's route to your computer. For an iOS simulator or Chrome on the same computer, the default host is `127.0.0.1`. A physical phone needs your computer's reachable LAN IP instead, plus firewall/network access to all three emulator ports. These local credentials work only while the emulators are running:

| Role | Email | Password |
| --- | --- | --- |
| Administrator | `admin@demo.test` | `Admin123!` |
| Staff | `staff@demo.test` | `Staff123!` |
| Visitor | `visitor@demo.test` | `Visitor123!` |

Use the admin/staff accounts in the web app and the visitor account on mobile. The seed script writes illustrative records, including a Manila map pin; never import them as live cemetery data. To verify access rules separately, run `npm test --prefix tool/security`. To check the web login flow after launching Chrome on port `8087` (add `--web-port=8087` to its `flutter run` command), run `npm run smoke:admin --prefix tool/security` in another terminal.

### 6. Configure the cemetery map and device features

- **Embedded map:** The default map uses `flutter_map` and OpenStreetMap tile URLs without a Google Maps SDK key. Android and iOS can instead use the optional Google Maps SDK setup described below. The default tile URL is `https://tile.openstreetmap.org/{z}/{x}/{y}.png`; for production traffic, choose a tile provider whose usage terms cover your deployment and set `--dart-define=MAP_TILE_URL=https://YOUR_PROVIDER/{z}/{x}/{y}.png` at run/build time. Keep the map attribution visible. Web hosting must allow network access to the chosen tile server.
- **Grave coordinates:** In web **System Settings**, set the actual cemetery map center on the map. In **Grave Management** or **Map Management**, tap or drag a pin to the verified grave location. The admin map legend identifies occupied, reserved, and available plots, the proposed pin, and the current location. Visitor markers show occupied graves with valid coordinates. Until this is done, routing to real graves is unavailable or misleading; preview coordinates are illustrative.
- **Walking directions:** **Start Navigation** opens a Google Maps URL using the device's location as the origin. It requires location permission, internet access, and an available browser or Google Maps app. No Google Maps API key is used for this URL handoff. Google Maps can route only on paths it knows about; check the cemetery's internal paths on site.
- **Camera and photos:** QR scanning needs camera access. Taking or choosing photos needs camera/photo-library access. The Android manifest and iOS `Info.plist` contain the current permission declarations. Cloud photos also need the Storage bucket and deployed rules. Uploaded images must be JPEG, PNG, or WebP and under the rule's 2 MiB limit after app compression.
- **Payment documents:** Admins can attach PDF, DOC, DOCX, JPEG, PNG, or WebP files to payment records. Connected uploads require Storage and the deployed rules; each file must be under 10 MiB. Only administrators can read payment files through the app. Local preview accepts files under 500 KiB because it stores them in the browser's local data.
- **Reminders:** Visitors can opt into **local phone notifications** for account-linked unpaid payments with due dates. The app schedules alerts for seven days before and on the due date at 9 a.m. after it sees the payment record. Grant notification permission on the phone. Web browsers do not get these scheduled alerts; the app does not send remote push notifications or collect payments automatically.

### Common setup problems

| Symptom | Check |
| --- | --- |
| The app opens preview instead of Firebase login | All four required `FIREBASE_*` values are present in the build's define file; restart/rebuild after changing them. |
| Web user signs in but cannot open administration | The Authentication UID has a matching `users/<UID>` document with exact role `admin` or `staff`; Firestore rules are deployed. |
| Permission denied when viewing/saving records | Deploy the matching rules to the intended project; confirm the signed-in user's role and ownership fields. |
| Photos fail to upload | Storage is enabled, `FIREBASE_STORAGE_BUCKET` matches the actual bucket, Storage rules are deployed, and the image is a supported type/size. |
| Payment receipt or document fails to upload | Keep Auth, Firestore, and Storage emulators in one suite for local testing; in a live project, deploy `storage.rules`, confirm the admin role, bucket, file type, and 10 MiB limit. |
| Emulator connection refused | Start/seed the emulators, check ports `9098`, `8188`, `9198`, and use `10.0.2.2` from an Android emulator. |
| Map tiles are blank or pins are missing | Check internet/tile-provider access, the configured map center, and each grave's coordinates. |
| Directions or QR scanning do not work | Grant location/camera permission and test on a device with a browser or Google Maps app. |

The project does not include a SQL server, payment gateway, or push-notification server. The Google Maps SDK integration is optional and requires platform keys. Firebase is the connected backend; the preview works without either service configured.

## Run the preview

```sh
flutter pub get
flutter run -d chrome
flutter run -d <device-id>
```

To inspect the mobile layout in a browser while developing, run
`flutter run -d chrome --dart-define=MOBILE_WEB_PREVIEW=true`. This switches
the web entry screen to the visitor app; camera scanning and scheduled phone
notifications still require a mobile device. Omit the define for the admin web
app.

The web target opens an **Admin Preview** entry screen; choose **Open Admin Preview** to inspect the dashboard and use **Logout** to return to that screen. This preview entry is not authentication: anyone who can open the local URL can enter. On mobile, choose **Explore Local Preview**. The preview includes sample graves, a fictional generated memorial portrait, and an illustrative map near Manila North Cemetery. Replace the preview photos and coordinates before using the app for a real site.

## Connect Firebase

The app reads Firebase settings from Dart defines: `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`, and optionally `FIREBASE_AUTH_DOMAIN` and `FIREBASE_STORAGE_BUCKET`. Enable Email/Password in Firebase Authentication and deploy [firestore.rules](firestore.rules). To save grave, maintenance, and profile photos in cloud mode, configure `FIREBASE_STORAGE_BUCKET`, enable Firebase Storage, and deploy [storage.rules](storage.rules). Never ship administrator access based on UI checks alone.

An administrator account must have a `users/{uid}` document with `role: admin`, created through the Firebase console or a privileged backend. Mobile sign-up creates `role: visitor` and cannot grant admin access. The web admin requires this role before loading records. User Management can change the roles of registered accounts after confirmation. **Create staff login** creates an Auth user and a staff role document, then shows a unique temporary password once; share it securely with that user. **Add staff contact** is a directory entry and does not create a sign-in account. Preview role changes demonstrate the UI but do not restrict access to the local preview.

Both connected login pages offer **Forgot password?** after an email address is entered. Firebase Authentication sends the reset email; the app shows the same confirmation whether or not the address has an account. Configure the password reset email template and sender in the production Firebase project before launch.

To check access rules locally, run `npm ci --prefix tool/security` followed by `npm test --prefix tool/security` before starting the persistent demo emulators. This starts the Firestore and Storage emulators under a demo project and checks anonymous, visitor, and administrator permissions. It does not deploy rules or verify your live Firebase project. Storage download URLs are bearer links: someone who receives an existing URL can still use it, so avoid sharing sensitive memorial or maintenance photos through such links.

To check the connected **web** login and logout flow without production credentials, use three terminals:

```sh
npm run emulators --prefix tool/security
# In another terminal, after the emulators say they are ready:
npm run seed --prefix tool/security
flutter run -d chrome --web-port=8087 --dart-define-from-file=tool/security/web_emulator_defines.json
# In a third terminal, while the web app is open:
npm run smoke:admin --prefix tool/security
```

The emulator web app uses `admin@demo.test` / `Admin123!`, `staff@demo.test` / `Staff123!`, and `visitor@demo.test` / `Visitor123!`. The visitor is denied access to web administration. Staff can manage burial records, graves, map pins, and maintenance; only administrators can access payments, reports, user roles, and settings. `smoke:admin` checks visitor denial, admin and staff sign-in, logout, and live loss of admin access after a role change. `npm run smoke:role-ui --prefix tool/security` checks account search and promotes then restores the seeded visitor through the connected admin UI. `npm run smoke:new-admin-features --prefix tool/security` creates a temporary staff login, checks its password and role, then deletes it. `npm run smoke:payment-attachment --prefix tool/security` uploads and downloads a temporary PDF, then restores the payment record. Run these connected checks with all three Firebase emulators in the same suite because Storage rules inspect Firestore roles. `npm run smoke:reset --prefix tool/security` checks that a reset request from the phone-width admin login reaches the Auth emulator. The seed data includes 20 illustrative grave and plot records with enough dated burials to show the forecast, plus sample payment, lease, and maintenance records. It must never be treated as actual cemetery data. The tests use the installed Google Chrome by default; set `CHROME_PATH` for another Chromium binary. Emulator mode accepts only a project ID beginning with `demo-`.

For a connected Android emulator, keep the Firebase emulators running and use `flutter run -d <android-emulator-id> --dart-define-from-file=tool/security/android_emulator_defines.json`. Android reaches the host emulators through `10.0.2.2`. The debug manifest permits this local HTTP connection. Run `maestro test -p android --udid <android-emulator-id> .maestro/android_emulator_login.yaml` to check login and grave search against the seeded data. The Android Maestro flows for maintenance, reminders, and phone alert opt-in are alongside it in `.maestro/`; run the alert opt-in flow when phone alerts are still off. Set a nearby demo location with `adb emu geo fix 120.9894 14.6323`, then run `.maestro/android_emulator_navigation.yaml` with the same Maestro options to check the Google Maps walking route. On a fresh emulator, accept Android's Location Accuracy prompt and skip Google Maps sign-in once before that automated route check.

Run `.maestro/android_emulator_password_reset.yaml` with the same Maestro options to verify the visitor reset confirmation. The Auth emulator's `/emulator/v1/projects/demo-smart-cemetery/oobCodes` endpoint records the reset request; it does not send a real email.

Run `.maestro/android_emulator_share.yaml` with the same Maestro options to sign in and open the system share sheet from Grave Details and Map & Navigation. Shared text includes the grave location, a Google Maps walking-directions link when the grave has a pin, and an explicit warning for demo coordinates.

To check QR decoding on the Android emulator, push the demo grave code into its photo library, then run the scanner flow. The flow selects the first recent photo, so keep this fixture as the first image in a clean emulator gallery:

```sh
adb push tool/security/fixtures/pedro-grave-qr.png /sdcard/Pictures/cemetery-demo-grave.png
adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Pictures/cemetery-demo-grave.png
maestro test -p android --udid <android-emulator-id> .maestro/android_emulator_scanner.yaml
```

The visitor scanner also has **Scan from Photo** for a saved QR image. The Android flow verifies that the code opens Pedro Dela Cruz's memorial. The camera preview opens in the emulator, but scanning a printed marker still needs a physical device.

For a connected iOS simulator build, leave the local emulators running and start `flutter run -d <simulator-id> --dart-define-from-file=tool/security/ios_emulator_defines.json`. The iOS configuration contains a syntactically valid, nonproduction Firebase app ID and API key required by the native SDK. The seeded visitor account can sign in, search for Pedro Dela Cruz, submit a maintenance request, and see the sample annual-fee reminder. These flows are in `.maestro/mobile_emulator_login.yaml`, `.maestro/mobile_emulator_maintenance.yaml`, and `.maestro/mobile_emulator_reminders.yaml`; `.maestro/mobile_emulator_logout.yaml` signs out. iOS may preserve Firebase Auth in the keychain after clearing app state, so run the logout flow when a test needs the welcome screen.

After `.maestro/mobile_emulator_maintenance.yaml`, run `npm run demo:request-progress --prefix tool/security`, then `maestro test .maestro/mobile_emulator_request_update.yaml` to check that the changed status and priority reach the visitor app. This helper writes only to the local demo Firestore emulator. `.maestro/mobile_emulator_home.yaml` checks session restoration and Home layout after a cold launch.

To check registration and the first login against the local emulators, sign out first, then run `maestro test -e SIGNUP_EMAIL=unique-name@demo.test .maestro/mobile_emulator_signup.yaml`. Use a new email for each run.

## Map data

The mobile marker map can use the Google Maps Flutter SDK when configured as described below. Without a key, mobile uses the existing OpenStreetMap map; web Map Management also uses OpenStreetMap. The visitor map opens with the first occupied grave that has valid coordinates selected; visitors see occupied-grave markers only. **Start Navigation** opens Google Maps walking directions to the selected grave, using the device's current location as the route origin. It can launch Google Maps navigation or a route preview, depending on device location and Google Maps availability. The app does not draw an invented route line. Google Maps can only route along paths present in its map data; it cannot promise a walkable route inside a cemetery whose internal paths are unmapped.

For a real deployment, set a verified cemetery map center in System Settings by tapping the map or dragging its marker. In Grave Management, use the **Map** step to tap or drag each grave pin into place. Map Management can place the first pin even when no graves have coordinates: filter plots by block or those needing a pin, select a grave or plot, tap its location on the map, review the proposed coordinates, and save the pin. System Settings also offers tombstone and standard pin styles; the Map Management legend labels occupied, reserved, available, proposed, and current-location markers. Preview records use sample coordinates and show a warning before opening Google Maps. The Google Maps URL route needs no app API key.

To enable the **embedded Google map on Android or iOS**, create a Google Maps Platform project with billing, enable Maps SDK for Android and Maps SDK for iOS, and use separate platform-restricted API keys. For Android, set `GOOGLE_MAPS_API_KEY` as an environment variable or Gradle property when building. For iOS, copy `ios/Flutter/GoogleMaps.xcconfig.example` to `ios/Flutter/GoogleMaps.xcconfig` and put the iOS key there; the real file is ignored by Git. Then build or run Flutter with `--dart-define=GOOGLE_MAPS_ENABLED=true`. Enable this switch only when the native key for that platform is configured. These keys load map tiles and markers in the app; **Start Navigation** still opens Google Maps for the route. A key alone cannot verify the location of a grave or add missing internal cemetery paths. The web admin map remains on OpenStreetMap. For production OpenStreetMap tile traffic, set `MAP_TILE_URL` to a provider you are authorized to use, and keep attribution visible. If using the public OSM tile server, follow its [tile usage policy](https://operations.osmfoundation.org/policies/tiles/).

Connected grave saves claim a unique block, lot, and grave number in the same Firestore transaction as the grave record. Before deploying the updated rules to a project with existing graves, check and backfill those claims using Admin SDK credentials:

```sh
FIREBASE_PROJECT_ID=your-project-id npm run plots:backfill --prefix tool/security
FIREBASE_PROJECT_ID=your-project-id npm run plots:backfill --prefix tool/security -- --apply
```

The first command is read-only. It stops on duplicate plot identities or stale claims so they can be reconciled before applying changes. Keep Firestore exports of the existing records before a production backfill.
The connected emulator check `npm run smoke:plot-move --prefix tool/security` edits a temporary plot in the browser, verifies that its old claim is removed and new claim is saved, and cleans up the fixture.

## Current feature behavior

- Visitors can search graves, open memorial details and photos, scan grave QR codes, see map markers, request maintenance with a photo, review their request history and status, read announcements, see payment reminders linked to their account, record visits, and send feedback. A configured emergency phone number opens the device dialer when tapped. The Home and Profile portrait updates when a visitor chooses a photo.
- Administrators can search burial and grave records, filter plots by availability, edit graves, deceased portraits, tomb photos, and memorial gallery photos, download a printable PNG of a grave's QR code, place grave map markers, and manage requests, payments and leases, announcements, staff contacts, login accounts, user roles, and settings. Adding a burial starts with occupied status. Maintenance requests can be assigned to any registered account and triaged by status and priority; visitors see status updates in their request history. The portrait appears in the memorial header while the tomb photo appears on the map card. Payments can include supporting PDFs, Word files, and screenshots; connected files are stored in Firebase Storage with administrator-only access. Payment details and reminder links can be corrected without creating a duplicate payment. Announcements can be published, corrected, and withdrawn after confirmation. The dashboard separates occupied plots with expired leases in its overview and map; those plots still count as burials. Reports use stored records and can download burial, maintenance, and payment CSV files. The Space Demand forecast appears only when there are at least 12 dated burials across six months; it is an estimate from the recorded trend, not a guarantee.
- Local preview saves records and compressed photos on that device or browser. Devices do not sync with each other until Firebase is configured. Visitors can opt into local phone alerts from **Reminders**: unpaid payments with a due date are scheduled for 9 a.m. seven days before and on the due date. The app updates these alerts when it receives payment changes while open or next launches. This requires phone notification permission; web browsers do not support scheduled alerts. Remote push notifications and automatic payment collection are not configured. Administrator staff entries are directory records, separate from Firebase Authentication accounts.

## Backups

In the web preview, **System Settings → Download backup** saves an encrypted copy of that browser's records. **Restore backup** reads the file, shows record counts, and asks before replacing local preview data. The passphrase must be at least 12 characters and cannot be recovered by the app. Files use AES-256-GCM with a unique salt and PBKDF2-HMAC-SHA256 key derivation (600,000 iterations). Keep the file and passphrase in separate safe places. This is a manual backup of one browser's preview data, not an automatic backup of mobile data or Firebase.

For a connected Firebase project, follow the [production backup setup guide](docs/production-backup.md). It covers managed Firestore backup schedules, Storage photo protection, separate Authentication exports, and a read-only status command. The project owner must configure and verify these protections in the actual Google Cloud project.

For a connected Firebase project, configure scheduled Firestore exports and retention in Google Cloud. The app does not offer browser-side restore into Firestore, since that would require a privileged, audited server operation.

## Checks

```sh
flutter analyze
flutter test
flutter build web --no-tree-shake-icons
maestro test .maestro/mobile_preview.yaml
maestro test .maestro/mobile_maintenance.yaml
maestro test .maestro/mobile_reminders.yaml
maestro test .maestro/mobile_payment_alerts.yaml
maestro test .maestro/mobile_information.yaml
maestro test .maestro/mobile_home_visual.yaml
maestro test .maestro/mobile_map_visual.yaml
maestro test .maestro/mobile_maintenance_submit.yaml
maestro test .maestro/mobile_visit_history.yaml
maestro test .maestro/mobile_logout.yaml
```

These Maestro flows check the native preview, all nine Home actions' layout, grave search and memorial, the map's tomb photo, request submission, visit history, logout and re-entry, reminders, and information pages on an iOS simulator. `.maestro/google_maps_handoff.yaml` also taps through to a Google Maps walking route preview. For a nearby route in the simulator, first set a Manila sample location with `xcrun simctl location booted set 14.6323,120.9894`. Turn-by-turn navigation requires the Google Maps app on the device. A local web server can serve `build/web` for browser UI testing.
