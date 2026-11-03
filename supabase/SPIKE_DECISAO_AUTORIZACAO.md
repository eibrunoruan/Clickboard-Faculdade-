# Decisão Técnica do Spike: Autorização no Servidor (Supabase Storage RLS)

**Data:** 28/10/2026  
**Contexto:** US-01 (PR 5 — `feat/autorizacao-no-servidor`)  
**Participantes:** Dev C (Driver), Dev A (Navigator)

---

## 1. Problema Identificado
Até o Sprint 1, todas as operações no bucket `clickboard` eram efetuadas utilizando a chave pública (`anon`) com políticas que permitiam inserção, alteração e deleção irrestritas (`storage_policies.sql`). A restrição de permissão residia exclusivamente no cliente (`DocumentController.canManage`), permitindo que qualquer usuário com conhecimento da API ou acesso ao cliente realizasse bypass e apagasse/modificasse arquivos de outros usuários ou da coordenação.

## 2. Opções Avaliadas

### Caminho A (Selecionado): Supabase com Terceiro Provedor (Firebase Auth JWT) + RLS
- **Arquitetura:** O Supabase aceita o ID token JWT emitido pelo Firebase Authentication (configurado no Supabase via JWKS / Third-Party Auth). O token carrega o `sub` contendo o UID do Firebase.
- **Políticas de Storage:** O RLS verifica o `current_uid()` através de `coalesce(auth.jwt() ->> 'sub', auth.uid()::text)`. As subpastas de documentos seguem a convenção estruturada `<dept>/Documents/<uid>/<arquivo>`.
- **Coordenação:** Para evitar complexidade e necessidade de deploy de Firebase Admin SDK com Custom Claims, a lista de coordenadores é mantida na tabela interna `public.admins(uid)`. A função `public.is_admin()` consulta essa tabela de forma performática.
- **Vantagens:**
  - Mantém a comunicação direta cliente-storage com alta performance e sem intermediários desnecessários.
  - Elimina qualquer brecha na camada de banco/storage.
  - Alinhado com a convenção de pastas já desenhada no projeto.

### Caminho B (Fallback / Alternativa Avaliada): Edge Function Proxy com Service Role
- **Arquitetura:** As requisições de escrita passariam por uma Supabase Edge Function intermediária, que valida o ID Token do Firebase via biblioteca JWT e executa a operação usando a `service_role_key`.
- **Desvantagens em relação ao Caminho A:** Maior latência (hop adicional), custos computacionais de Edge Functions e necessidade de reimplementar streaming de upload em TypeScript/Deno.
- **Status:** Mantido como plano de contingência caso o provedor JWT de terceiro não estivesse disponível.

---

## 3. Decisão Final e Regras Estabelecidas
1. **Revogação do `anon`:** Nenhuma escrita (insert, update, delete) é aceita pela role anônima.
2. **Documentos de Alunos:** O usuário só pode inserir, atualizar ou apagar arquivos dentro da pasta `<dept>/Documents/<uid>/`.
3. **Avisos Institucionais (`/Notice/`):** Apenas usuários contidos na tabela `admins` possuem permissão de escrita/exclusão.
4. **Imutabilidade de `isAdmin` no Firestore:** Fechamento da escalada de privilégio onde alunos poderiam se auto-promover a administradores no Firestore.
