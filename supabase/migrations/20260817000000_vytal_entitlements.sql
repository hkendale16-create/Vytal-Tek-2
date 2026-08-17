-- Vytal Tek entitlement store
-- Dedicated project sdeifrzdkiiexawwzfvb (not FirstVue).

create table if not exists public.vytal_entitlements (
  user_id uuid primary key references auth.users (id) on delete cascade,
  tier text not null check (tier in ('free', 'plus', 'pro')),
  product_id text,
  lifecycle text not null default 'active',
  will_renew boolean not null default false,
  renews_at timestamptz,
  expires_at timestamptz,
  platform text check (platform in ('apple', 'google', 'unknown')),
  original_transaction_id text,
  last_verified_at timestamptz not null default now(),
  snapshot jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.vytal_purchase_events (
  id bigserial primary key,
  user_id uuid references auth.users (id) on delete set null,
  platform text not null,
  product_id text,
  event_type text not null,
  payload jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.vytal_entitlements enable row level security;
alter table public.vytal_purchase_events enable row level security;

create policy vytal_entitlements_select_own
  on public.vytal_entitlements
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy vytal_purchase_events_select_own
  on public.vytal_purchase_events
  for select
  to authenticated
  using (auth.uid() = user_id);
