-- Políticas de RLS para o bucket "clickboard" (Supabase Storage).
--
-- Contexto (PR 5 - feat/autorizacao-no-servidor):
-- Anteriormente, todas as operações de escrita (insert, update, delete) eram
-- abertas para a role "anon", delegando a trava apenas para a interface do cliente.
-- 
-- Nesta versão:
-- 1. A role "anon" tem permissão revogada para insert, update e delete.
-- 2. Documentos (/Documents/<uid>/...): apenas o dono (<uid>) ou a coordenação (admins)
--    podem enviar, sobrescrever ou apagar.
-- 3. Avisos (/Notice/...): apenas a coordenação (admins) pode enviar ou apagar.
-- 4. Fotos de perfil (/Profile/<uid>/...): apenas o próprio usuário ou admins.
-- 5. Leitura (select): permanece aberta para visualização/download de murais institucionais.
--
-- Para aplicar: Supabase Dashboard > SQL Editor > Run.

-- 1. Tabela de administradores (coordenação) no Supabase
create table if not exists public.admins (
  uid text primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.admins enable row level security;

drop policy if exists "admins_select_auth" on public.admins;
create policy "admins_select_auth"
on public.admins for select
to authenticated, anon
using (true);

-- Funções utilitárias
create or replace function public.current_uid()
returns text
language sql
stable
as $$
  select coalesce(auth.jwt() ->> 'sub', auth.uid()::text);
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
as $$
  select exists (
    select 1 from public.admins
    where uid = coalesce(auth.jwt() ->> 'sub', auth.uid()::text)
  );
$$;

-- 2. Revogação de permissões irrestritas da role anon
drop policy if exists "clickboard_insert_anon" on storage.objects;
drop policy if exists "clickboard_update_anon" on storage.objects;
drop policy if exists "clickboard_delete_anon" on storage.objects;

-- 3. Leitura pública/autenticada (listar, baixar, gerar signed URL)
drop policy if exists "clickboard_select_anon" on storage.objects;
drop policy if exists "clickboard_select_policy" on storage.objects;
create policy "clickboard_select_policy"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'clickboard');

-- 4. Upload (Insert): Dono para seus documentos ou Admin para qualquer pasta (incluindo Avisos)
drop policy if exists "clickboard_insert_auth" on storage.objects;
create policy "clickboard_insert_auth"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'clickboard'
  and (
    -- Coordenação (Admin) tem permissão irrestrita (inclusive /Notice/)
    public.is_admin()
    -- Dono inserindo documento na sua pasta: <dept>/Documents/<uid>/<arquivo>
    or (
      name ~ ('/Documents/' || public.current_uid() || '/.+')
    )
    -- Dono inserindo foto de perfil: Profile/<uid>/<arquivo>
    or (
      name ~ ('^Profile/' || public.current_uid() || '/.+')
    )
  )
);

-- 5. Atualização (Update / Upsert): Dono para seus documentos ou Admin
drop policy if exists "clickboard_update_auth" on storage.objects;
create policy "clickboard_update_auth"
on storage.objects for update
to authenticated
using (
  bucket_id = 'clickboard'
  and (
    public.is_admin()
    or (name ~ ('/Documents/' || public.current_uid() || '/.+'))
    or (name ~ ('^Profile/' || public.current_uid() || '/.+'))
  )
)
with check (
  bucket_id = 'clickboard'
  and (
    public.is_admin()
    or (name ~ ('/Documents/' || public.current_uid() || '/.+'))
    or (name ~ ('^Profile/' || public.current_uid() || '/.+'))
  )
);

-- 6. Exclusão / Renomeação (Delete / Move): Dono para seus documentos ou Admin
drop policy if exists "clickboard_delete_auth" on storage.objects;
create policy "clickboard_delete_auth"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'clickboard'
  and (
    public.is_admin()
    or (name ~ ('/Documents/' || public.current_uid() || '/.+'))
    or (name ~ ('^Profile/' || public.current_uid() || '/.+'))
  )
);
