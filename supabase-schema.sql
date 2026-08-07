-- ============================================================
-- Wage Code CTC Calculator — Supabase schema
-- Run this once in Supabase: Project → SQL Editor → New Query
-- ============================================================

-- 1) PROFILES — every signed-up user gets a row here.
--    is_admin decides who can open the admin panel.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

-- auto-create a profile row whenever someone signs up
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email);
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 2) STATE MINIMUM WAGE TABLE — admin-editable
create table if not exists public.mw_rates (
  state text primary key,
  monthly_mw numeric not null,
  updated_at timestamptz not null default now()
);

insert into public.mw_rates (state, monthly_mw) values
  ('Delhi', 17234),
  ('Maharashtra', 14000),
  ('Karnataka', 14000),
  ('Tamil Nadu', 13000),
  ('Haryana', 11000),
  ('Uttar Pradesh', 9600)
on conflict (state) do nothing;
-- ⚠ these are placeholder figures — replace with your actual
--   state-wise minimum wage notifications from the admin panel.

-- 3) FORMULA CONFIG — every rate/threshold the calculator uses,
--    editable from the admin panel instead of being hardcoded.
create table if not exists public.formula_config (
  key text primary key,
  value numeric not null,
  label text,
  updated_at timestamptz not null default now()
);

insert into public.formula_config (key, value, label) values
  ('basic_pct_of_remuneration', 0.50, 'Basic as % of Remuneration'),
  ('epf_employer_pct',          0.12, 'Employer PF % of Basic'),
  ('epf_employee_pct',          0.12, 'Employee PF % of Basic'),
  ('esic_employer_pct',         0.0325, 'Employer ESIC % of Gross'),
  ('esic_employee_pct',         0.0075, 'Employee ESIC % of Gross'),
  ('esic_wage_ceiling_monthly', 21000, 'ESIC applicability ceiling (monthly gross)'),
  ('bonus_pct',                 0.0833, 'Statutory Bonus % of Basic'),
  ('bonus_wage_ceiling_monthly',21000, 'Bonus applicability ceiling (monthly Basic)'),
  ('gratuity_pct',              0.0481, 'Gratuity % of Basic')
on conflict (key) do nothing;

-- 4) ROW LEVEL SECURITY
alter table public.profiles enable row level security;
alter table public.mw_rates enable row level security;
alter table public.formula_config enable row level security;

-- profiles: a user can read their own row (to check is_admin)
create policy "read own profile" on public.profiles
  for select using (auth.uid() = id);

-- mw_rates & formula_config: any logged-in user can READ
create policy "logged in users can read mw_rates" on public.mw_rates
  for select using (auth.role() = 'authenticated');

create policy "logged in users can read formula_config" on public.formula_config
  for select using (auth.role() = 'authenticated');

-- mw_rates & formula_config: only admins can WRITE
create policy "admins can modify mw_rates" on public.mw_rates
  for all using (
    exists (select 1 from public.profiles where id = auth.uid() and is_admin = true)
  );

create policy "admins can modify formula_config" on public.formula_config
  for all using (
    exists (select 1 from public.profiles where id = auth.uid() and is_admin = true)
  );

-- ============================================================
-- AFTER running this file:
-- 1. Create your first user normally by signing up on the site.
-- 2. In Table Editor → profiles, tick "is_admin" = true for that
--    user's row. That's how you become the admin.
-- ============================================================
