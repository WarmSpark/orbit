# Deploying Orbit to Heroku

The monorepo holds everything, but only `hangout-backend/` is deployed. The Go
binary embeds the landing page (served at `/`) and exposes the API, so a single
web dyno serves both.

## One-time setup

You run these yourself (they need your interactive Heroku login and create
billing resources).

### 1. Log in and create the app

```bash
heroku login
heroku create orbit-ncr --stack container   # pick any free name
```

`--stack container` tells Heroku to build from `Dockerfile` via `heroku.yml`.

### 2. Set config vars (these replace the local .env)

```bash
heroku config:set \
  ORBIT_ENV=production \
  DATABASE_URL='postgres://USER:PASSWORD@HOST/DB?sslmode=require' \
  JWT_SECRET="$(openssl rand -hex 32)" \
  GOOGLE_CLIENT_ID='81704897904-qs2j4m7326j4b5qkmtco60j8ri7r77q4.apps.googleusercontent.com' \
  ALLOWED_ORIGINS='https://orbit-ncr.herokuapp.com' \
  --app orbit-ncr
```

- `ORBIT_ENV=production` makes the server refuse to boot if dev-auth is on or
  the Google client ID is missing.
- Never set `ORBIT_DEV_AUTH` in production.
- `JWT_SECRET` must be set (otherwise sessions reset on every restart).

### 3. Deploy (push only the backend subtree)

`heroku.yml` and `Dockerfile` live inside `hangout-backend/`, so Heroku must
receive that folder as the repo root. Push the subtree:

```bash
git remote add heroku https://git.heroku.com/orbit-ncr.git
git subtree push --prefix hangout-backend heroku main
```

Re-run the `git subtree push` line for every future deploy.

## Cost-abuse guards (protect the $312 credit)

Heroku bills by **dyno-hour and paid add-ons**, not by request count. Your app
already rate-limits requests; these guards cap what can actually cost money.

1. **One small dyno, never scaled up.**
   ```bash
   heroku ps:scale web=1:basic --app orbit-ncr
   ```
   A `basic` dyno is ~$7/mo, so the $312 credit lasts years. Never use
   `standard-2x`/`performance` dynos.

2. **No autoscaling.** Autoscaling is off by default — do not enable it. It is
   the single biggest way a traffic spike turns into a bill.

3. **A hard monthly spend cap + alert.** In the Heroku dashboard →
   *Account settings → Billing*, set a monthly budget/alert well under $312 (a
   $20 alert gives you months of warning). Heroku emails you when you cross it.

4. **No accidental paid add-ons.** The database is external (Neon), so you need
   **zero** Heroku add-ons. Don't provision Heroku Postgres/Redis — they bill
   separately.

5. **Watch dyno count.** `heroku ps --app orbit-ncr` should always show exactly
   one `web` dyno. Anything more is either a mistake or abuse.

## Verify after deploy

```bash
heroku open --app orbit-ncr           # landing page loads at /
curl https://orbit-ncr.herokuapp.com/health
heroku logs --tail --app orbit-ncr    # watch startup: "Server running ... prod=true"
```

The startup log must say `prod=true`. If it says `prod=false`, `ORBIT_ENV` is
not set and the production guards are off.

## Before go-live (deferred, do not skip)

- Rotate the Neon database password (the current one was exposed in chat) and
  update `DATABASE_URL`.
- Build the signed release APK with dev-auth OFF, pointing `ORBIT_BASE_URL` at
  the Heroku HTTPS URL.
