-- RuangUsaha: initial multi-tenant database foundation
-- Apply to a NEW Supabase project only after reviewing this migration.
-- Existing browser localStorage data is NOT migrated by this file.
-- Currency values are whole Rupiah (BIGINT); quantities support decimals (e.g. perfume per ml).

begin;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete restrict,
  business_name text not null check (length(trim(business_name)) between 1 and 120),
  business_type text,
  currency_code text not null default 'IDR' check (currency_code = 'IDR'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, owner_user_id)
);

create index if not exists businesses_owner_user_id_idx
  on public.businesses(owner_user_id);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  legacy_id text,
  name text not null check (length(trim(name)) between 1 and 180),
  sku text,
  selling_price bigint not null check (selling_price >= 0),
  cost_price bigint not null default 0 check (cost_price >= 0),
  stock numeric(14,3) not null default 0 check (stock >= 0),
  unit text not null default 'unit' check (length(trim(unit)) between 1 and 24),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, id),
  unique (business_id, legacy_id)
);

create index if not exists products_business_name_idx
  on public.products(business_id, lower(name));

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  legacy_id text,
  type text not null check (type in ('sale','expense','capital','withdrawal','stockPurchase','collection','payablePayment')),
  transaction_date date not null,
  description text not null default '',
  category text,
  amount bigint not null check (amount >= 0),
  cogs bigint not null default 0 check (cogs >= 0),
  nature text check (nature is null or nature in ('fixed','variable')),
  paid_amount bigint check (paid_amount is null or paid_amount >= 0),
  due_date date,
  product_id uuid,
  related_transaction_id uuid,
  payment_method text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, id),
  unique (business_id, legacy_id),
  constraint transactions_paid_amount_not_over_amount
    check (paid_amount is null or paid_amount <= amount),
  constraint transactions_product_same_business
    foreign key (business_id, product_id)
    references public.products(business_id, id) on delete restrict,
  constraint transactions_related_same_business
    foreign key (business_id, related_transaction_id)
    references public.transactions(business_id, id) on delete restrict
);

create index if not exists transactions_business_date_idx
  on public.transactions(business_id, transaction_date desc);
create index if not exists transactions_business_type_date_idx
  on public.transactions(business_id, type, transaction_date desc);
create index if not exists transactions_related_transaction_idx
  on public.transactions(business_id, related_transaction_id)
  where related_transaction_id is not null;

create table if not exists public.transaction_items (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  transaction_id uuid not null,
  product_id uuid,
  product_name text not null,
  quantity numeric(14,3) not null check (quantity > 0),
  unit_price bigint not null check (unit_price >= 0),
  unit_cost bigint not null default 0 check (unit_cost >= 0),
  line_total bigint generated always as (round(quantity * unit_price)::bigint) stored,
  line_cogs bigint generated always as (round(quantity * unit_cost)::bigint) stored,
  created_at timestamptz not null default now(),
  constraint transaction_items_transaction_same_business
    foreign key (business_id, transaction_id)
    references public.transactions(business_id, id) on delete restrict,
  constraint transaction_items_product_same_business
    foreign key (business_id, product_id)
    references public.products(business_id, id) on delete restrict
);

create index if not exists transaction_items_transaction_idx
  on public.transaction_items(business_id, transaction_id);

create table if not exists public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  product_id uuid not null,
  transaction_id uuid,
  movement_type text not null check (movement_type in ('sale','restock','adjustment','sale_reversal','restock_reversal','opening_balance')),
  quantity_change numeric(14,3) not null check (quantity_change <> 0),
  note text,
  created_at timestamptz not null default now(),
  constraint stock_movements_product_same_business
    foreign key (business_id, product_id)
    references public.products(business_id, id) on delete restrict,
  constraint stock_movements_transaction_same_business
    foreign key (business_id, transaction_id)
    references public.transactions(business_id, id) on delete restrict
);

create index if not exists stock_movements_business_product_date_idx
  on public.stock_movements(business_id, product_id, created_at desc);

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null unique references public.businesses(id) on delete restrict,
  plan_code text not null default 'starter',
  status text not null default 'trial' check (status in ('trial','active','past_due','expired','cancelled')),
  current_period_start timestamptz,
  current_period_end timestamptz,
  provider text,
  provider_customer_id text,
  provider_subscription_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (current_period_end is null or current_period_start is null or current_period_end > current_period_start)
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
drop trigger if exists businesses_set_updated_at on public.businesses;
create trigger businesses_set_updated_at before update on public.businesses
for each row execute function public.set_updated_at();
drop trigger if exists products_set_updated_at on public.products;
create trigger products_set_updated_at before update on public.products
for each row execute function public.set_updated_at();
drop trigger if exists transactions_set_updated_at on public.transactions;
create trigger transactions_set_updated_at before update on public.transactions
for each row execute function public.set_updated_at();
drop trigger if exists subscriptions_set_updated_at on public.subscriptions;
create trigger subscriptions_set_updated_at before update on public.subscriptions
for each row execute function public.set_updated_at();

-- Profiles: each authenticated user may access only their own profile.
alter table public.profiles enable row level security;
drop policy if exists profiles_select_self on public.profiles;
create policy profiles_select_self on public.profiles for select to authenticated
using (id = (select auth.uid()));
drop policy if exists profiles_insert_self on public.profiles;
create policy profiles_insert_self on public.profiles for insert to authenticated
with check (id = (select auth.uid()));
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

-- Business owner is bound to the authenticated user.
alter table public.businesses enable row level security;
drop policy if exists businesses_select_owner on public.businesses;
create policy businesses_select_owner on public.businesses for select to authenticated
using (owner_user_id = (select auth.uid()));
drop policy if exists businesses_insert_owner on public.businesses;
create policy businesses_insert_owner on public.businesses for insert to authenticated
with check (owner_user_id = (select auth.uid()));
drop policy if exists businesses_update_owner on public.businesses;
create policy businesses_update_owner on public.businesses for update to authenticated
using (owner_user_id = (select auth.uid()))
with check (owner_user_id = (select auth.uid()));

-- Shared policy helper expression: a row is visible only when its business belongs to auth.uid().
alter table public.products enable row level security;
drop policy if exists products_owner_all on public.products;
create policy products_owner_all on public.products for all to authenticated
using (exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid())))
with check (exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid())));

alter table public.transactions enable row level security;
drop policy if exists transactions_owner_all on public.transactions;
create policy transactions_owner_all on public.transactions for all to authenticated
using (exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid())))
with check (exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid())));

alter table public.transaction_items enable row level security;
drop policy if exists transaction_items_owner_all on public.transaction_items;
create policy transaction_items_owner_all on public.transaction_items for all to authenticated
using (exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid())))
with check (exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid())));

alter table public.stock_movements enable row level security;
drop policy if exists stock_movements_owner_all on public.stock_movements;
create policy stock_movements_owner_all on public.stock_movements for all to authenticated
using (exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid())))
with check (exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid())));

-- Subscription records are readable by their owner. Client-side users cannot set their own paid status.
alter table public.subscriptions enable row level security;
drop policy if exists subscriptions_select_owner on public.subscriptions;
create policy subscriptions_select_owner on public.subscriptions for select to authenticated
using (exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid())));

commit;
