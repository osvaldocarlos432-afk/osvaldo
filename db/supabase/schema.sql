-- Supabase schema for moving all metadata to Supabase

-- Enable pgcrypto for gen_random_uuid if not enabled
-- create extension if not exists pgcrypto;

create table if not exists public.videos (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  price numeric(10,2) not null default 0,
  duration text,
  video_file_id text,
  thumbnail_file_id text,
  thumbnail_url text,
  product_link text,
  is_active boolean not null default true,
  views int not null default 0,
  created_at timestamp with time zone default now()
);

-- Multiple sources per video (e.g., different cuts/parts for same title)
create table if not exists public.video_sources (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  source_file_id text not null, -- Wasabi key for the file
  thumbnail_file_id text,       -- optional per-source thumbnail
  position int not null default 1, -- ordering within the same title preview
  created_at timestamp with time zone default now()
);

create table if not exists public.video_relations (
  video_id uuid references public.videos(id) on delete cascade,
  related_video_id uuid references public.videos(id) on delete cascade,
  primary key (video_id, related_video_id)
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
    CREATE TYPE user_role AS ENUM ('admin','editor');
  END IF;
END
$$;

create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  name text,
  role user_role not null default 'admin',
  password_hash text not null,
  created_at timestamp with time zone default now()
);

create table if not exists public.site_config (
  id uuid primary key default gen_random_uuid(),
  site_name text,
  paypal_client_id text,
  paypal_me_username text,
  stripe_publishable_key text,
  stripe_secret_key text,
  telegram_username text,
  video_list_title text,
  crypto jsonb,
  email jsonb,
  wasabi_config jsonb,
  updated_at timestamp with time zone default now()
);

create table if not exists public.purchases (
  id uuid primary key default gen_random_uuid(),
  video_id uuid references public.videos(id) on delete cascade,
  buyer_email text,
  buyer_name text,
  transaction_id text,
  method text check (method in ('paypal','stripe','crypto')),
  created_at timestamp with time zone default now()
);

-- Sessions (auth for admin panel)
create table if not exists public.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  token text unique not null,
  user_agent text,
  expires_at timestamp with time zone not null,
  is_active boolean not null default true,
  created_at timestamp with time zone default now()
);

-- RLS DISABLED
alter table public.videos disable row level security;
drop policy if exists videos_read_public on public.videos;

alter table public.video_relations disable row level security;
drop policy if exists video_relations_read_public on public.video_relations;

alter table public.video_sources disable row level security;
drop policy if exists video_sources_read_public on public.video_sources;
drop policy if exists video_sources_insert_any on public.video_sources;
drop policy if exists video_sources_update_any on public.video_sources;
drop policy if exists video_sources_delete_any on public.video_sources;

alter table public.site_config disable row level security;
drop policy if exists site_config_read_public on public.site_config;

alter table public.users disable row level security;
drop policy if exists users_read_public on public.users;
drop policy if exists users_insert_any on public.users;

alter table public.purchases disable row level security;

alter table public.sessions disable row level security;
drop policy if exists sessions_read_public on public.sessions;
drop policy if exists sessions_insert_any on public.sessions;
drop policy if exists sessions_update_any on public.sessions;

-- Optional RPC to increment numeric column generically
create or replace function public.increment(table_name text, row_id uuid, column_name text)
returns void as $$
declare
  sql text;
begin
  sql := format('update %I set %I = %I + 1 where id = $1', table_name, column_name, column_name);
  execute sql using row_id;
end;
$$ language plpgsql security definer;

-- Seed default admin user (id auto; email unique)
insert into public.users (email, name, role, password_hash)
values ('admin@gmail.com', 'Administrator', 'admin', '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9')
on conflict (email) do nothing;


