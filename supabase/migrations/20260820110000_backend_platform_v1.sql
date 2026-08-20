-- Backend platform: Complete tier, profiles, sync, marketplace, gym partners
-- Applied to project sdeifrzdkiiexawwzfvb as migration backend_platform_v1

alter table public.vytal_entitlements
  drop constraint if exists vytal_entitlements_tier_check;

alter table public.vytal_entitlements
  add constraint vytal_entitlements_tier_check
  check (tier = any (array['free'::text, 'plus'::text, 'pro'::text, 'complete'::text]));

alter table public.vytal_entitlements
  drop constraint if exists vytal_entitlements_platform_check;

alter table public.vytal_entitlements
  add constraint vytal_entitlements_platform_check
  check (platform = any (array['apple'::text, 'google'::text, 'sandbox'::text, 'unknown'::text]));

create table if not exists public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy profiles_select_own on public.profiles
  for select to authenticated using (auth.uid() = user_id);
create policy profiles_insert_own on public.profiles
  for insert to authenticated with check (auth.uid() = user_id);
create policy profiles_update_own on public.profiles
  for update to authenticated using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (user_id, email, display_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)))
  on conflict (user_id) do nothing;
  insert into public.vytal_entitlements (user_id, tier, lifecycle, snapshot)
  values (new.id, 'free', 'none', '{}'::jsonb)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create table if not exists public.fitness_sync_batches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  source text not null default 'vytal_tek_mobile',
  event_count int not null check (event_count >= 0),
  received_at timestamptz not null default now(),
  raw jsonb not null default '{}'::jsonb
);

create table if not exists public.fitness_sync_events (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.fitness_sync_batches (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  client_event_id text not null,
  kind text not null,
  queued_at timestamptz,
  payload jsonb not null default '{}'::jsonb,
  received_at timestamptz not null default now(),
  unique (user_id, client_event_id)
);

create index if not exists fitness_sync_events_user_received_idx
  on public.fitness_sync_events (user_id, received_at desc);

alter table public.fitness_sync_batches enable row level security;
alter table public.fitness_sync_events enable row level security;

create policy fitness_sync_batches_select_own on public.fitness_sync_batches
  for select to authenticated using (auth.uid() = user_id);
create policy fitness_sync_events_select_own on public.fitness_sync_events
  for select to authenticated using (auth.uid() = user_id);

create table if not exists public.trainer_programs (
  id text primary key,
  trainer_display_name text not null,
  title text not null,
  tagline text not null default '',
  weeks int not null default 4,
  days_per_week text not null default '3',
  focus_areas text[] not null default '{}',
  platform_fee_bps int not null default 1000 check (platform_fee_bps >= 0 and platform_fee_bps <= 10000),
  price_cents int not null default 0 check (price_cents >= 0),
  currency text not null default 'usd',
  store_product_id text,
  advanced boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.trainer_program_interest (
  user_id uuid not null references auth.users (id) on delete cascade,
  program_id text not null references public.trainer_programs (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, program_id)
);

create table if not exists public.trainer_purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  program_id text not null references public.trainer_programs (id),
  store_product_id text,
  platform text not null,
  purchase_token text,
  status text not null default 'pending'
    check (status = any (array['pending'::text, 'paid'::text, 'refunded'::text, 'failed'::text])),
  gross_cents int not null default 0,
  platform_fee_bps int not null default 1000,
  platform_fee_cents int not null default 0,
  trainer_net_cents int not null default 0,
  currency text not null default 'usd',
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, program_id, purchase_token)
);

create table if not exists public.platform_fee_ledger (
  id bigserial primary key,
  purchase_id uuid not null references public.trainer_purchases (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  program_id text not null,
  fee_cents int not null,
  currency text not null default 'usd',
  settled boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.trainer_programs enable row level security;
alter table public.trainer_program_interest enable row level security;
alter table public.trainer_purchases enable row level security;
alter table public.platform_fee_ledger enable row level security;

create policy trainer_programs_select_active on public.trainer_programs
  for select to authenticated, anon using (active = true);
create policy trainer_interest_select_own on public.trainer_program_interest
  for select to authenticated using (auth.uid() = user_id);
create policy trainer_interest_insert_own on public.trainer_program_interest
  for insert to authenticated with check (auth.uid() = user_id);
create policy trainer_purchases_select_own on public.trainer_purchases
  for select to authenticated using (auth.uid() = user_id);
create policy platform_fee_ledger_select_own on public.platform_fee_ledger
  for select to authenticated using (auth.uid() = user_id);

insert into public.trainer_programs (
  id, trainer_display_name, title, tagline, weeks, days_per_week, focus_areas,
  platform_fee_bps, price_cents, store_product_id, advanced
) values
  ('trainer-maya-strength', 'Maya Chen', 'Foundations Strength',
   'Barbell patterns for busy schedules', 6, '3', array['Strength','Full body'],
   1000, 0, 'vytal.trainer.maya_strength', false),
  ('trainer-jordan-engine', 'Jordan Blake', 'Engine Builder',
   'Conditioning without outcome guarantees', 5, '4', array['Conditioning','Cardio'],
   1000, 0, 'vytal.trainer.jordan_engine', false),
  ('trainer-aria-cali', 'Aria Okonkwo', 'Calisthenics Path',
   'Pull · Push · Core progressions', 8, '3–4', array['Calisthenics','Mobility'],
   1000, 2499, 'vytal.trainer.aria_cali', true)
on conflict (id) do update set
  title = excluded.title,
  tagline = excluded.tagline,
  price_cents = excluded.price_cents,
  store_product_id = excluded.store_product_id,
  advanced = excluded.advanced,
  active = true;

create table if not exists public.gym_claims (
  id uuid primary key default gen_random_uuid(),
  place_id text not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  business_name text not null,
  contact_email text,
  status text not null default 'pending'
    check (status = any (array['pending'::text, 'approved'::text, 'rejected'::text])),
  verified boolean not null default false,
  partner boolean not null default false,
  promoted boolean not null default false,
  offer_labels text[] not null default '{}',
  review_notes text,
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by text,
  unique (place_id, user_id)
);

create table if not exists public.gym_membership_offers (
  id uuid primary key default gen_random_uuid(),
  place_id text not null,
  claim_id uuid references public.gym_claims (id) on delete set null,
  title text not null,
  description text not null default '',
  price_label text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.gym_sponsored_placements (
  id uuid primary key default gen_random_uuid(),
  place_id text not null unique,
  label text not null default 'Sponsored',
  active boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists gym_claims_place_idx on public.gym_claims (place_id);
create index if not exists gym_offers_place_idx on public.gym_membership_offers (place_id);

alter table public.gym_claims enable row level security;
alter table public.gym_membership_offers enable row level security;
alter table public.gym_sponsored_placements enable row level security;

create policy gym_claims_select_own on public.gym_claims
  for select to authenticated using (auth.uid() = user_id);
create policy gym_claims_insert_own on public.gym_claims
  for insert to authenticated with check (auth.uid() = user_id);
create policy gym_offers_select_active on public.gym_membership_offers
  for select to authenticated, anon using (active = true);
create policy gym_sponsored_select_active on public.gym_sponsored_placements
  for select to authenticated, anon using (active = true);
