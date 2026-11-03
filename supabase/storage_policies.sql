-- Politicas de RLS do bucket "clickboard" (US-01)
--
-- O app manda o token do Firebase em cada requisicao (main.dart) e o Firebase
-- esta cadastrado em Authentication > Third-Party Auth. O uid vem no "sub".
--
-- As politicas sao "to anon, authenticated" porque o token do Firebase nao tem
-- o claim "role" e cai como anon. Quem barra e o current_uid(): sem login ele
-- e nulo e nenhuma escrita passa.
--
-- Documentos: <dept>/Documents/<uid>/<arquivo> -> dono ou coordenacao
-- Avisos:     <dept>/<session>/Notice/...      -> so coordenacao
-- Foto:       Profile/<uid>.<ext>              -> dono ou coordenacao
--
-- Coordenacao = uids na tabela public.admins.
-- Aplicar em: SQL Editor > Run.

create table if not exists public.admins (
  uid text primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.admins enable row level security;

-- is_admin() e security definer, entao ninguem precisa ler a tabela pela API
drop policy if exists "admins_select_auth" on public.admins;

create or replace function public.current_uid()
returns text
language sql
stable
as $$
  select nullif(auth.jwt() ->> 'sub', '');
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_uid() is not null
     and exists (select 1 from public.admins where uid = public.current_uid());
$$;

create or replace function public.is_owner_path(object_name text)
returns boolean
language sql
stable
as $$
  select public.current_uid() is not null
     and (
       object_name ~ ('/Documents/' || public.current_uid() || '/[^/]+$')
       or object_name ~ ('^Profile/' || public.current_uid() || '\.[^/.]+$')
     );
$$;

-- remove as politicas antigas que liberavam escrita pro anon
drop policy if exists "clickboard_insert_anon" on storage.objects;
drop policy if exists "clickboard_update_anon" on storage.objects;
drop policy if exists "clickboard_delete_anon" on storage.objects;

-- leitura continua aberta
drop policy if exists "clickboard_select_anon" on storage.objects;
drop policy if exists "clickboard_select_policy" on storage.objects;
create policy "clickboard_select_policy"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'clickboard');

drop policy if exists "clickboard_insert_auth" on storage.objects;
create policy "clickboard_insert_auth"
on storage.objects for insert
to anon, authenticated
with check (
  bucket_id = 'clickboard'
  and (public.is_admin() or public.is_owner_path(name))
);

-- rename usa move, que e update do nome
drop policy if exists "clickboard_update_auth" on storage.objects;
create policy "clickboard_update_auth"
on storage.objects for update
to anon, authenticated
using (
  bucket_id = 'clickboard'
  and (public.is_admin() or public.is_owner_path(name))
)
with check (
  bucket_id = 'clickboard'
  and (public.is_admin() or public.is_owner_path(name))
);

drop policy if exists "clickboard_delete_auth" on storage.objects;
create policy "clickboard_delete_auth"
on storage.objects for delete
to anon, authenticated
using (
  bucket_id = 'clickboard'
  and (public.is_admin() or public.is_owner_path(name))
);
