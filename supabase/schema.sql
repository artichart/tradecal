-- TradeCal · Supabase schema
-- วางทั้งไฟล์ใน Dashboard → SQL Editor → Run (รันซ้ำได้ ไม่ทำข้อมูลหาย)

-- ---------- บัญชี ----------
create table if not exists public.accounts (
  user_id   uuid not null default auth.uid() references auth.users on delete cascade,
  id        text not null,
  name      text not null,
  cur       text not null check (cur in ('USD','THB')),
  created_at timestamptz not null default now(),
  primary key (user_id, id)
);

-- ---------- ไม้ ----------
create table if not exists public.trades (
  user_id   uuid not null default auth.uid() references auth.users on delete cascade,
  id        text not null,
  acc       text not null,
  date      date not null,
  time      text,
  pnl       numeric(12,2) not null,
  -- ฟิลด์วิเคราะห์ (ไม่ใส่ก็ได้)
  system    text check (system in ('garand','v5','manual')),
  session   text check (session in ('asia','eu','ny','other')),
  side      text check (side in ('buy','sell')),
  lot       numeric(6,2),
  entry     numeric(10,2),
  sl        numeric(10,2),
  tp        numeric(10,2),
  outcome   text check (outcome in ('tp','sl','manual','be')),
  followed  boolean,          -- ทำตามระบบ?
  balance_before numeric(12,2),
  note      text default '',
  lesson    text default '',
  img       boolean not null default false,  -- ภาพอยู่ที่ storage: charts/<user_id>/<id>.jpg
  updated_at timestamptz not null default now(),
  primary key (user_id, id),
  foreign key (user_id, acc) references public.accounts (user_id, id) on delete cascade
);
create index if not exists trades_user_date on public.trades (user_id, date);

-- ---------- ค่าตั้ง + เป้า (แถวเดียวต่อคน) ----------
create table if not exists public.prefs (
  user_id uuid primary key default auth.uid() references auth.users on delete cascade,
  goals   jsonb not null default '{}',
  set     jsonb not null default '{}',
  updated_at timestamptz not null default now()
);

-- ---------- RLS: เห็นแค่ของตัวเอง ----------
alter table public.accounts enable row level security;
alter table public.trades   enable row level security;
alter table public.prefs    enable row level security;

drop policy if exists own on public.accounts;
drop policy if exists own on public.trades;
drop policy if exists own on public.prefs;
create policy own on public.accounts for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy own on public.trades   for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy own on public.prefs    for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------- ภาพ: bucket ส่วนตัว ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('charts', 'charts', false, 2097152, array['image/jpeg'])
on conflict (id) do nothing;

drop policy if exists charts_own on storage.objects;
create policy charts_own on storage.objects for all to authenticated
  using (bucket_id = 'charts' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'charts' and (storage.foldername(name))[1] = auth.uid()::text);
