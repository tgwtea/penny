# Set up Firebase Authentication

Penny uses Firebase Auth only to prove who someone is: email and password sign-in with a verification email, and Google sign-in. Penny's own database decides what they may do (ADR 004). Until this runbook is followed, everything runs against the local Firebase Auth emulator, which needs no Firebase account.

Follow it once per environment. Use a separate Firebase project for dev and for prod, so test accounts and real ones never mix.

## What you need

- A Google account that can create Firebase projects.
- The environment's web address (for example `app.dev.<domain>`), from the open question on Penny's domain in `docs/architecture.md`.
- Access to change `deploy/overlays/<env>/kustomization.yaml`.

## 1. Create the project

1. In the [Firebase console](https://console.firebase.google.com/), add a project. Name it after the environment, such as `penny-dev`. Note the **project ID** Firebase assigns; it may have a suffix (`penny-dev-1a2b3`).
2. Google Analytics is not needed. Penny does not use it.

## 2. Turn on the sign-in methods

In **Authentication**, open **Sign-in method** and:

1. Enable **Email/Password**. Leave "Email link (passwordless sign-in)" off.
2. Enable **Google**. Set the public-facing name to "Penny" and choose the support email address people will see on Google's consent screen.
3. Under **Settings**, then **User account linking**, choose **Link accounts that use the same email**. Someone who signs up with a password and later uses Google with the same address then stays one person, and keeps their teams.
4. Under **Settings**, then **Authorized domains**, add the environment's web host (`app.dev.<domain>`). Remove `localhost` from the prod project. Keep it on dev if developers will sign in to dev from `flutter run`.
5. Under **Settings**, turn on **Email enumeration protection**. Penny's reset-password page already answers the same way whether or not an account exists; this makes Firebase's own API do the same.

## 3. Adjust the emails

In **Authentication**, open **Templates**:

1. For **Email address verification** and **Password reset**, set the sender name to "Penny" and the subject lines in Penny's voice: sentence case, no exclamation marks. For example "Confirm your email for Penny" and "Reset your Penny password".
2. Firebase sends these from its own domain by default. When Penny's sending domain exists (Phase 7, ADR 014), customise the domain here so the emails come from it, and add the DNS records Firebase lists.

## 4. Register the web app

1. In **Project settings**, then **General**, add a **Web** app named "Penny web". Firebase Hosting is not needed.
2. Firebase shows a config object. Copy these five values:

   | Firebase config | Penny setting |
   | --- | --- |
   | `apiKey` | `PENNY_FIREBASE_API_KEY` |
   | `appId` | `PENNY_FIREBASE_APP_ID` |
   | `authDomain` | `PENNY_FIREBASE_AUTH_DOMAIN` |
   | `projectId` | `PENNY_FIREBASE_PROJECT_ID` |
   | `messagingSenderId` | `PENNY_FIREBASE_MESSAGING_SENDER_ID` |

   The API key is not a secret: it identifies the project to Google, and every web app ships it to the browser. Restrict it anyway (step 6).

## 5. Configure Penny

### The API

The API needs only the project ID. It checks that every ID token was signed by Google for this project, and was issued and not expired, before trusting it.

In `deploy/overlays/<env>/kustomization.yaml`, in the patch for the `penny-api` Deployment, replace the placeholder:

```yaml
- name: PENNY_FIREBASE_PROJECT_ID
  value: penny-dev-1a2b3
```

Never set `PENNY_FIREBASE_AUTH_EMULATOR_HOST` outside local development and CI. It makes the API accept unsigned emulator tokens, so the API refuses to start with it unless the project ID starts with `demo-`, which no real project can.

### The web client

The web image is built once and promoted between environments. It reads its settings at run time from `/config.json`, which nginx writes from environment variables when the container starts (`apps/client/nginx/default.conf.template`).

In the same overlay, add the five values to the patch for the `penny-web` Deployment:

```yaml
env:
  - name: PENNY_API_URL
    value: https://api.dev.<domain>
  - name: PENNY_FIREBASE_PROJECT_ID
    value: penny-dev-1a2b3
  - name: PENNY_FIREBASE_API_KEY
    value: AIza...
  - name: PENNY_FIREBASE_APP_ID
    value: "1:1234567890:web:abc123"
  - name: PENNY_FIREBASE_AUTH_DOMAIN
    value: penny-dev-1a2b3.firebaseapp.com
  - name: PENNY_FIREBASE_MESSAGING_SENDER_ID
    value: "1234567890"
```

If any of the four values other than the API key is missing while the key is set, the app stops at start with an error naming the missing setting, rather than half-working.

### Running the client locally against a real project

The same settings work as `--dart-define`s, which take precedence over `config.json`:

```sh
cd apps/client
flutter run -d chrome --web-port 5173 \
  --dart-define=PENNY_BACKEND=http \
  --dart-define=PENNY_API_URL=http://localhost:8080 \
  --dart-define=PENNY_FIREBASE_PROJECT_ID=penny-dev-1a2b3 \
  --dart-define=PENNY_FIREBASE_API_KEY=AIza... \
  --dart-define=PENNY_FIREBASE_APP_ID=1:1234567890:web:abc123 \
  --dart-define=PENNY_FIREBASE_AUTH_DOMAIN=penny-dev-1a2b3.firebaseapp.com \
  --dart-define=PENNY_FIREBASE_MESSAGING_SENDER_ID=1234567890
```

and run the API for that project, without the emulator (`task run:api` always uses the emulator, so run the binary directly):

```sh
cd services/api
PENNY_DATABASE_URL=postgres://penny:penny@localhost:5432/penny?sslmode=disable \
PENNY_FIREBASE_PROJECT_ID=penny-dev-1a2b3 \
PENNY_CORS_ORIGINS=http://localhost:5173 \
  go run ./cmd/api
```

`localhost` must be an authorized domain of that project (step 2.4).

## 6. Restrict the API key

In the [Google Cloud console](https://console.cloud.google.com/apis/credentials) for the same project, open the browser key Firebase created and:

1. Under **Application restrictions**, choose **Websites** and list the environment's web origin (and `http://localhost:5173` for dev only).
2. Under **API restrictions**, allow only **Identity Toolkit API** and **Token Service API**, which are the two Firebase Auth uses.

## 7. Check it works

On the deployed web app (or locally, as in step 5):

1. Create an account with an email address you can read. The "Check your email" page appears and the verification email arrives.
2. Before opening the link, press "I have verified my email": Penny says the address is not verified yet.
3. Open the link, return and press it again: Penny opens on Today. The API's log shows `GET /v1/me` with status 200.
4. Sign out, then "Continue with Google" with the same address. You arrive as the same person, in the same teams.
5. On the Account page, delete the account. Signing in again starts a new, empty account.
6. Send a request with a made-up token: `curl -H 'Authorization: Bearer nonsense' https://api.dev.<domain>/v1/me` answers 401.

## Troubleshooting

| What you see | Usually means |
| --- | --- |
| Every request gets 401 after signing in | `PENNY_FIREBASE_PROJECT_ID` on the API differs from the web app's project. Tokens are only accepted for the project named on the API |
| 403 "Verify your email address" | The email is not verified, or the client still has a token from before verification. "I have verified my email" refreshes the token |
| Google popup: `auth/unauthorized-domain` | The page's host is not in **Authorized domains** (step 2.4) |
| Google popup closes at once | The browser blocked the popup. Penny says "Sign-in was cancelled"; allow popups for the site |
| The app stops at start naming a `PENNY_FIREBASE_*` setting | The web Deployment has the API key but not every other value (step 5) |
| The API stops at start: "may only be set with a demo- project ID" | `PENNY_FIREBASE_AUTH_EMULATOR_HOST` is set in a real environment. Remove it |

## Local development and CI

Nothing here is needed locally. `task dev` runs the Firebase Auth emulator (`tools/firebase-emulator`) under the demo project `demo-penny`, and both `task run:api` and `task run:client:web` use it by default. Its UI at http://localhost:4000 lists the accounts created and the emails "sent": open a verification link from there. The emulator's accounts disappear when it restarts.

`task test:api` runs the sign-in tests against it when `PENNY_TEST_FIREBASE_AUTH_EMULATOR_HOST=localhost:9099` is set, as CI does, and `task test:e2e` signs a person up through it in a real browser.

## Mobile apps, later

Mobile builds are deferred. When they are picked up, register an Android app (with the signing certificate's SHA-1 and SHA-256, which Google sign-in needs) and an iOS app in the same project, and pass their settings the same way. Google sign-in on Android cannot be tested against the emulator; it needs a real project.
