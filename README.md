# Wage Code CTC Calculator — setup guide

This is a static site (no server needed) with login and an admin panel,
backed by a free Supabase project for auth + storing the minimum-wage
table and formula constants.

## Files
- `index.html` — the calculator (login required)
- `admin.html` — admin panel to edit MW rates & formula %s
- `wage-logic.js` — the actual calculation formula
- `config.js` — **you edit this** with your Supabase keys
- `styles.css` — styling
- `supabase-schema.sql` — run this once in Supabase

## Step 1 — Create a free Supabase project
1. Go to https://supabase.com → Sign up → New project.
2. Wait ~2 minutes for it to provision.
3. Go to **Project Settings → API**. Copy the **Project URL** and the
   **anon public key**.

## Step 2 — Run the schema
1. In Supabase, open **SQL Editor → New query**.
2. Paste the entire contents of `supabase-schema.sql` and click **Run**.
3. This creates the tables, seeds placeholder minimum-wage figures
   (⚠ replace these with your real state notifications from the
   admin panel), and sets up security rules so only admins can edit.

## Step 3 — Connect the site to Supabase
Open `config.js` and replace the two placeholder values:
```js
window.SUPABASE_URL = "https://YOUR-PROJECT-REF.supabase.co";
window.SUPABASE_ANON_KEY = "YOUR-ANON-PUBLIC-KEY";
```
(The anon key is safe to expose in a static site — it only allows what
your Row Level Security rules permit, which the schema already sets up.)

## Step 4 — Deploy (pick one, all free)

### Option A — Netlify (drag & drop, easiest)
1. Go to https://app.netlify.com/drop
2. Drag the whole `wage-calculator` folder onto the page.
3. You get a live URL immediately. Done.

### Option B — Vercel
1. `npm i -g vercel` (or use the Vercel dashboard "Add New Project" →
   "Upload" if you don't want the CLI).
2. From inside the folder: `vercel --prod`.

### Option C — GitHub Pages
1. Push this folder to a GitHub repo.
2. Repo → Settings → Pages → Deploy from branch → `main` / root.
3. Your site is live at `https://<username>.github.io/<repo>/`.

## Step 5 — Create your admin account
1. Open your deployed `index.html`, click **Create account**, sign up
   with your email.
2. In Supabase → **Table Editor → profiles**, find your row and tick
   `is_admin` to `true`.
3. Reload the site — you'll now see an **Admin panel** link.
4. Go to `admin.html` to set the real state-wise minimum wages and
   confirm the formula constants (PF %, ESIC %, bonus %, gratuity %).

## Formula implemented (edit rates, not logic, from the admin panel)
- **Basic** = max( 50% of Remuneration, State Minimum Wage )
- **Remuneration** = Basic + HRA + Other Excluded Allowance +
  Employer PF + Statutory Bonus
- **Statutory Bonus** applies only if Basic < ₹21,000/month (rate and
  ceiling both editable)
- **CTC** = Remuneration + Employer ESIC + Gratuity
- **Cash in Hand** = Basic + HRA + Other Allowance − Employee PF −
  Employee ESIC

Because Basic and Remuneration reference each other, the app solves
this by iteration (see `wage-logic.js` — `solveBasic()`), not a
hardcoded shortcut, so it stays correct if you change any % in the
admin panel.

## Notes / things to sanity-check before relying on this for payroll
- The seeded minimum wage figures are **placeholders** — replace them
  with your actual current state notifications (these change
  periodically and vary further by skill category/zone within a
  state, which this simple version does not yet model).
- ESIC ceiling, PF ceiling treatment (capped vs uncapped wage), and
  gratuity % all default to common assumptions — confirm each against
  current rules before use.
- This tool does not yet handle PF wage ceiling (₹15,000) capping —
  if your organisation applies that cap, let me know and I'll add it
  as another admin-editable toggle.
