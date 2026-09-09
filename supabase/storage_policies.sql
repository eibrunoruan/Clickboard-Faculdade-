-- Políticas de RLS para o bucket "clickboard" (Supabase Storage).
--
-- Contexto: o app autentica os usuários no Firebase Auth, não no Supabase Auth.
-- Por isso toda requisição chega no Supabase como role "anon" (chave publishable).
-- Sem as políticas abaixo, qualquer upload falha com:
--   403 "new row violates row-level security policy"
--
-- Status: APLICADO em 2026-09-08 no projeto czlevkffqqnzrtcnyiev.
-- Este arquivo fica versionado como registro do estado esperado do bucket.
-- Para reaplicar: Supabase Dashboard > SQL Editor > Run.

-- Leitura (listar, baixar, gerar signed URL)
drop policy if exists "clickboard_select_anon" on storage.objects;
create policy "clickboard_select_anon"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'clickboard');

-- Upload
drop policy if exists "clickboard_insert_anon" on storage.objects;
create policy "clickboard_insert_anon"
on storage.objects for insert
to anon, authenticated
with check (bucket_id = 'clickboard');

-- Sobrescrever (o app usa upsert: true)
drop policy if exists "clickboard_update_anon" on storage.objects;
create policy "clickboard_update_anon"
on storage.objects for update
to anon, authenticated
using (bucket_id = 'clickboard')
with check (bucket_id = 'clickboard');

-- Deletar / renomear (move = copy + delete)
drop policy if exists "clickboard_delete_anon" on storage.objects;
create policy "clickboard_delete_anon"
on storage.objects for delete
to anon, authenticated
using (bucket_id = 'clickboard');
