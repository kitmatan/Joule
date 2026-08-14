# Firebase setup

Joule is an **offline-first** app: you can immediately log sessions, view dashboards, and export data locally without any cloud setup. 

If you wish to enable **Cloud Sync** across your iPhone, iPad, and Mac, Joule uses Firebase Authentication (Google Sign-In) and stores sessions under `users/{uid}/sessions`. Two backend steps configure the cloud synchronization:

Project: `chargelog-5714d` · Bundle ID: `com.kmatan.ChargeLog`

> Google Sign-In rather than Sign in with Apple: the latter requires a paid Apple Developer Program
> membership, and this app is signed by a personal team. Google needs no entitlement, so nothing
> here depends on a paid membership.

## 1. Enable the Google provider and refresh GoogleService-Info.plist

- Firebase console → **Authentication**. If the page shows marketing cards ("Learn more", "More
  products for developers") and no tabs, the product has not been initialised yet: click
  **Get started** at the top. The `Users / Sign-in method / Templates / Usage / Settings` tab bar
  only appears afterwards.
- **Sign-in method** → **Add new provider** → **Google** → Enable, set a support email → Save.
- Then **Project settings** → your iOS app → **Download GoogleService-Info.plist**, and replace
  `Sources/GoogleService-Info.plist` with it.

The re-download matters. Enabling the provider creates an OAuth client, and the refreshed file is
the only place `CLIENT_ID` and `REVERSED_CLIENT_ID` appear — the file currently in the repo predates
the provider and has neither. Without `CLIENT_ID` the app cannot configure the SDK; without
`REVERSED_CLIENT_ID` the OAuth callback has nowhere to return to.

You do **not** need to edit `Info.plist` by hand. A build phase ("Configure Google Sign-In URL
scheme", declared in `project.yml`) copies `REVERSED_CLIENT_ID` into the built app's
`CFBundleURLTypes` on every build, so the two files cannot drift. Until you replace the plist, every
build prints:

```text
warning: GoogleService-Info.plist has no REVERSED_CLIENT_ID. Enable the Google provider in the
Firebase console and re-download the file — Google Sign-In cannot complete until you do.
```

That warning disappearing is your confirmation the step worked.

## 2. Verify sign-in

Run the app, tap **Sign in with Google**, and confirm a user appears under Authentication → Users.

## 3. Deploy the security rules

`firestore.rules` in the repo root is the source of truth. Either paste it into
Firebase console → **Firestore Database** → **Rules** → Publish, or:

```sh
firebase deploy --only firestore:rules --project chargelog-5714d
```

Until this is published the database is still in whatever mode it was in before — most likely open
test mode, which is what prompted this work.

## 4. Retire the legacy collection

On first sign-in the app copies the old top-level `sessions` collection into
`users/{uid}/sessions`. It is deliberately non-destructive:

- The originals are left in place.
- A legacy document whose ID already exists under your user is skipped, never overwritten. This is
  what makes the pass safe to repeat.
- Completion is recorded on `users/{uid}` as `legacySessionsMigrated`, alongside a timestamp and a
  short note, so you can confirm it ran.

Once you have checked your history looks right on every device:

1. Export a CSV from the app as a belt-and-braces backup.
2. Delete the top-level `sessions` collection in the Firebase console.
3. Delete the legacy `match /sessions/{sessionID}` block from `firestore.rules` and re-deploy.

Step 3 matters: while that block is present, **any** signed-in Firebase user can read the old
collection. It is the last remaining piece of the original open-access problem.

## Note on the account

The Firestore UID is tied to the Google account you sign in with. Signing in with a *different*
Google account creates a new, empty UID — the old data is still there but nothing reads it. If you
ever need to move accounts, export a CSV first and import it after signing in as the new user.
