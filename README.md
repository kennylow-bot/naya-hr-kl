# Naya HR

Leave, claims and a shared team calendar for Naya staff in Kuala Lumpur.
It is built with Node.js, Express and SQLite: one small server, one database file, nothing else to install.

## Quick start (on your computer)

1. Install **Node.js 22.13 or newer** (https://nodejs.org, pick the LTS version).
2. In this folder, run:
   ```bash
   npm install
   cp .env.example .env      # on Windows: copy .env.example .env
   ```
3. Edit `.env`:
   - `NODE_ENV=development` for a local trial (production mode requires HTTPS for cookies)
   - `APP_URL=http://localhost:3000`
   - Optional: `OWNER_INITIAL_PASSWORD=` with a first password for kennylow@naya.asia
4. Start the app with `npm start`. On first start the terminal prints the owner login. If you left `OWNER_INITIAL_PASSWORD` empty, it prints a random password.
5. Open http://localhost:3000 and sign in as **kennylow@naya.asia**. You'll be asked to set your own password straight away.

## Day-to-day flow

| Step | Who | What happens |
|---|---|---|
| Add a staff member | Owner → Staff → Add staff | The system generates a temporary password and shows it once, with a Copy button. You can also tick "Email the sign-in details". The temporary password expires after 7 days. |
| First sign-in | Staff | They sign in with the temporary password and must set their own password before they can do anything else. |
| Apply for leave or submit a claim | Any user | The owner gets an **email + in-app notification**. Super admins get the in-app notification. |
| Approve or reject | Owner only | The applicant gets an **email + in-app notification**. Rejecting requires a reason. |
| Mark a claim as paid | Owner | The applicant is notified that the reimbursement has been processed. |
| Calendar | Everyone | Shows KL public holidays and approved leave for all staff. Staff see their own pending leave; owner and super admins see everyone's pending leave. |

## Roles

| Permission | Staff | Super Admin | Owner (you) |
|---|:-:|:-:|:-:|
| Apply leave, submit claims, cancel own pending ones | ✓ | ✓ | ✓ |
| Team calendar and public holidays | ✓ | ✓ | ✓ |
| See own balances, leave and claims | ✓ | ✓ | ✓ |
| View **everyone's** leave, claims, receipts, staff list, audit log, CSV export | — | ✓ | ✓ |
| Approve / reject / revoke / mark paid | — | — | ✓ |
| Edit / delete any record | — | — | ✓ |
| Create staff, reset passwords, deactivate, set entitlements | — | — | ✓ |
| Manage holidays, leave types, claim categories | — | — | ✓ |

There is exactly one owner: the account in `OWNER_EMAIL`. Nobody can demote, deactivate or delete it from inside the app.
These rules are enforced on the server for every request, not only by hiding buttons. The automated tests check that a super admin who sends an approve or delete request directly gets **403 Forbidden**.

## Leave rules

- **Working days** = Monday–Friday, minus the KL public holidays in the system. A single day can be taken as a half day (AM or PM).
- **Default entitlements** follow the minimums in Malaysia's Employment Act 1955:
  - Annual leave (s.60E): **8 days** for under 2 years of service, **12** for 2–5 years, **16** for 5+ years. The system calculates this from the staff member's join date.
  - Sick leave (s.60F): **14 / 18 / 22 days** on the same service bands.
  - Hospitalisation: **60 days** (s.60F).
  - Maternity: **98 days** (s.37, as amended in 2022).
  - Paternity: **7 days** (s.60FA).
  - Compassionate leave: **3 days**. This is a company-policy placeholder, not a statutory figure, so change it to match your policy.
  - Unpaid leave: no cap.
- You can override any entitlement per person per year on their staff page. You can change the defaults in Settings.
- Leave is counted against the year it **starts** in. The app blocks a request that overlaps the person's existing leave or exceeds their remaining balance (pending requests count against the balance).
- Carry-forward of unused leave is not automated. To carry days forward, add them through the per-person override.

## Public holidays

The app comes with Kuala Lumpur holidays for **2026** and **2027**. The 2027 list comes from the Prime Minister's Department schedule, as circulated by FMM on 27 Aug 2026. It includes the "in lieu" days that apply when a holiday falls on a Sunday or on another holiday.
The official schedule marks Hari Raya Puasa, Hari Raya Haji and Deepavali as subject to change. Check those dates when they are officially confirmed, and add any special holidays the government announces. Use **Admin → Public holidays** for both.

## Email setup

Fill in the SMTP lines in `.env`. While `SMTP_HOST` is empty, emails are written to `data/outbox.log` so you can still test the whole flow.

- **Google Workspace**: `SMTP_HOST=smtp.gmail.com`, `SMTP_PORT=465`, `SMTP_SECURE=true`. Use a mailbox such as hr@naya.asia with 2-Step Verification on, and put an **App Password** in `SMTP_PASS`.
- **Microsoft 365**: `SMTP_HOST=smtp.office365.com`, `SMTP_PORT=587`, `SMTP_SECURE=false`. The mailbox needs SMTP AUTH enabled.
- Or use a transactional email service such as Brevo, Mailgun or Amazon SES, with the SMTP details it gives you.

## Security measures

| Measure | Setting | Why this value |
|---|---|---|
| Password hashing | bcrypt, cost **12** | OWASP Password Storage Cheat Sheet: bcrypt with a work factor of at least 10. 12 takes about 0.25 s per check, which slows attackers without slowing sign-in noticeably. |
| Password policy | **10+ characters**, upper + lower + number, must not contain the email name | Above NIST SP 800-63B's 8-character minimum, because these accounts hold personal and pay data. |
| Forced change of temporary passwords | Required before any other page works. Temporary passwords expire after **7 days** (`TEMP_PASSWORD_DAYS`). | Company choice: long enough for someone on leave to receive it, short enough to limit an unused password lying around. |
| Account lockout | **5** failed attempts → locked for **15 minutes** | Follows OWASP Authentication Cheat Sheet guidance on throttling. The owner can unlock early. |
| Rate limit on sign-in | **20** attempts per 15 minutes per IP address | Stops password-guessing scripts that spread attempts across many accounts. |
| Sessions | Stored in SQLite. Cookie is HttpOnly, SameSite=Lax, Secure in production. Expires after **8 hours** (`SESSION_HOURS`). The session ID is regenerated at sign-in. | 8 hours is one working day. A new session ID at sign-in prevents session fixation. |
| Sign-out everywhere | Changing or resetting a password ends that user's sessions on every device. So does deactivating an account. | |
| CSRF protection | A secret per-session token is checked on every form submission | |
| Security headers | Helmet: strict Content-Security-Policy (no inline scripts, no third-party resources), clickjacking protection, nosniff, HSTS in production | |
| File uploads | Max **5 MB**. File type is checked from the file's actual bytes (only PDF, JPG, PNG and WEBP pass). Files get random names, are stored outside the public folder, and are served only to the owner of the claim, the owner and super admins. | 5 MB comfortably fits a phone photo of a receipt. |
| Data access | Every query is parameterised (no SQL injection). Every page checks ownership or role on the server. | |
| Audit log | Records sign-ins, failed sign-ins, approvals, edits, deletions and exports, with IP address | |
| No user enumeration | The same error message, and the same response time, whether the email exists or not | |

## Deploying for the team

You need a server with HTTPS and a **persistent disk** for the `data/` and `uploads/` folders. Some options:

- **A small VPS** (e.g. DigitalOcean, AWS Lightsail, or a Malaysian host): install Node 22, run with `pm2 start src/server.js --name naya-hr`, and put Nginx or Caddy in front for HTTPS.
- **Docker**: use the included `Dockerfile`. Mount volumes at `/app/data` and `/app/uploads`.
- **Render / Railway / Fly.io**: attach a persistent volume. Without one, the database is wiped on every deploy.

Production checklist:
1. `NODE_ENV=production`, a long random `SESSION_SECRET`, `TRUST_PROXY=true` if behind a proxy, and `APP_URL` set to the real https URL.
2. Configure SMTP and send yourself a test by creating a staff account.
3. **Back up** `data/naya-hr.db` and the `uploads/` folder every day, for example with a nightly copy to Google Drive or S3. That's the whole system.

## Project layout

```
src/server.js         app setup, security headers, sessions
src/security.js       roles, CSRF, auth guards, password policy, audit
src/routes/           auth, dashboard, leaves, claims, calendar, notifications, admin
src/notify.js         email (SMTP) + in-app notifications
src/seed.js           first-run data: owner, leave types, claim types, KL holidays
views/                EJS templates
public/               CSS, JS, logo assets
```
