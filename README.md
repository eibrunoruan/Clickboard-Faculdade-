# Clickboard

Aplicativo Flutter de mural acadêmico, adaptado para a Católica SC.

O projeto parte do Clickboard, aplicativo de código aberto criado por Abhigyan Singh sob licença MIT. O arquivo de licença original segue preservado na raiz do repositório. O trabalho realizado sobre essa base está descrito no arquivo de relatório técnico.

Este documento explica como rodar o aplicativo, quais contas usar e como executar a bateria de testes automatizados.


## O que foi implementado

O aplicativo passou a exigir confirmação de endereço eletrônico e passou a aplicar permissão por dono nos documentos do mural.

**Confirmação de cadastro.** O Firebase envia a mensagem de confirmação sozinho, sem provedor externo e sem custo. Ao criar conta, o aluno recebe a mensagem e fica preso numa tela de verificação até clicar no link. A tela consulta o Firebase a cada três segundos e libera o aplicativo automaticamente quando a confirmação acontece. Quem entra pelo Google passa direto, porque o Google já entrega o endereço confirmado.

**Restrição de domínio.** Somente endereços terminados em catolicasc.edu.br conseguem criar conta. A validação acontece no formulário e também no repositório, antes de qualquer chamada ao Firebase.

**Permissão por dono.** Cada arquivo fica numa subpasta com o identificador de quem enviou. O dono pode renomear e apagar o próprio arquivo. A coordenação pode gerenciar qualquer arquivo. Os demais alunos só conseguem baixar.

**Redefinição de senha.** O botão de esquecimento de senha chamava o método errado e nunca enviava nada, apesar de mostrar mensagem de sucesso. Agora funciona.

## Contas de teste

Duas contas de demonstração existem no projeto Firebase. Ambas já estão confirmadas, então entram direto no aplicativo sem passar pela tela de verificação.

**Conta do aluno**

```
aluno.demo@catolicasc.edu.br
Clickboard@2026
```

**Conta do colega**

```
colega.demo@catolicasc.edu.br
Clickboard@2026
```

Nenhuma das duas é coordenação. As duas são alunos comuns, o que é exatamente o necessário para demonstrar a permissão por dono.

## Documentos de demonstração

O mural já contém dois arquivos no bucket, um de cada conta.

O arquivo chamado `Ata-da-Coordenacao.pdf` pertence ao colega. O arquivo chamado `Trabalho-Clickboard.pdf` pertence ao aluno.

## Como rodar o aplicativo

O projeto tem configuração de Firebase apenas para iOS e para web. Em outras plataformas a inicialização falha de propósito, com mensagem explicativa.

Para listar os aparelhos disponíveis:

```
flutter devices
```

Para subir no simulador iOS:

```
flutter run -d <identificador do aparelho>
```

Para rodar sem Firebase, útil apenas para inspecionar telas:

```
flutter run --dart-define=USE_FIREBASE=false
```

## Como testar a permissão na interface

Entre com a conta do aluno e abra a aba de documentos na barra inferior.

**Passo um.** Segure o dedo sobre o cartão do arquivo `Ata-da-Coordenacao.pdf`. O menu abre com apenas uma opção, que é baixar. Não aparece opção de renomear nem de apagar, porque esse arquivo é do colega.

**Passo dois.** Segure o dedo sobre o cartão do arquivo `Trabalho-Clickboard.pdf`. O menu abre com três opções, que são baixar, renomear e apagar. Esse arquivo é do próprio aluno.

A diferença entre os dois menus é a demonstração completa da permissão. Um toque simples apenas abre o arquivo. O menu só aparece mantendo o dedo pressionado.

Para conferir que a regra vale nos dois sentidos, saia e entre com a conta do colega. As opções se invertem.

## Como testar a restrição de domínio

Na tela de entrada, toque em criar conta. Preencha o campo de endereço com algo terminado em gmail.com e confirme. O formulário recusa na hora, com aviso pedindo endereço institucional. Nenhuma conta chega a ser criada no Firebase.

## Testes automatizados

A bateria offline roda sem rede e sem aparelho conectado:

```
flutter test
```

São 74 testes verdes e 14 pulados (os de integração, que só rodam com a variável abaixo).

O que cada camada prova, sem exagerar:

- **Testes de controller com fake** (`document_permissions_test`, `document_controller_caminho_principal_test`, `profile_controller_test`, `nome_do_perfil_test`) provam a regra **do app**: quem pode ver o botão, o que vai para o storage, o que aparece na tela quando dá erro. Não provam nada sobre o servidor.
- **Teste de aceite com o Supabase simulado** (`storage_server_authorization_test`) prova que o app manda o token do usuário em toda requisição e que uma negação do servidor vira erro na tela, e não "apagado com sucesso".
- **Testes de integração** (`storage_integration_test`, `storage_rls_integration_test`) falam com o Supabase de verdade, com contas reais, e são os únicos que provam que **o servidor** recusa o aluno B.

Para rodar a integração:

```
SUPABASE_INTEGRATION=1 \
ALUNO_A_EMAIL=... ALUNO_A_SENHA=... \
ALUNO_B_EMAIL=... ALUNO_B_SENHA=... \
flutter test test/storage_integration_test.dart test/storage_rls_integration_test.dart
```

`COORD_EMAIL` e `COORD_SENHA` são opcionais; sem elas os testes da coordenação ficam pulados. No CI essas variáveis vêm dos secrets do repositório. Os testes usam uma raiz isolada no bucket (`_testes-*`) e apagam tudo no final.

## Arquivos de teste

- `college_email_test.dart`: restrição de domínio, criação do aluno a partir do e-mail e os helpers do `Student` (smell 4).
- `auth_redirect_test.dart`: combinações de sessão e confirmação, incluindo a garantia de que não há laço de redirecionamento.
- `document_permissions_test.dart`: dono, coordenação, terceiro e visitante sem sessão, no controller.
- `document_controller_caminho_principal_test.dart`: enviar, listar, apagar e renomear com o `FakeStorageService`, conferindo o que chegou no storage.
- `storage_paths_test.dart` e `storage_paths_puro_test.dart`: montagem de caminhos no bucket (smell 1).
- `tela_erro_sliver_test.dart`: a tela de erro das listas não derruba mais o app (smell 3).
- `profile_controller_test.dart`: remover foto de perfil não finge sucesso quando falha (smell 5).
- `nome_do_perfil_test.dart`: US-02.
- `storage_server_authorization_test.dart`: teste de aceite da US-01 com o Supabase simulado no HTTP.
- `storage_integration_test.dart` e `storage_rls_integration_test.dart`: Supabase de verdade (US-01).

## Observações

Avisos continuam somente leitura no app. A interface para a coordenação enviar e apagar avisos ficou fora do Sprint 2 (é feature nova); a regra do servidor que só deixa a coordenação escrever na pasta de avisos já está aplicada e testada.

A redefinição de senha da N1 continua sem teste automatizado.

---

# Sprint 2 (N2)

## Sprint Goal

Garantir **no servidor** que só o dono e a coordenação alterem conteúdo do mural, cobrir o caminho principal com testes que exercitam as operações de verdade, e fechar o ciclo de qualidade (TDD, PR revisado e CI verde) sobre esse incremento.

## User Stories

### US-01: Permissão real, não cosmética

> **Como** coordenação, **quero** que apenas o dono de um documento, ou a coordenação, possa enviar, renomear ou apagar documentos, e que apenas a coordenação possa escrever avisos, com as regras aplicadas no servidor, **para que** ninguém altere conteúdo de outra pessoa mesmo contornando a interface do aplicativo.

Critérios de aceite:

- **Dado** um documento do aluno A, **quando** o aluno B tentar apagá-lo chamando o Supabase direto, sem passar pelo app, **então** o servidor recusa e o arquivo continua no bucket.
- **Dado** um cliente só com a chave pública, sem login, **quando** tentar enviar ou apagar qualquer arquivo, **então** o servidor recusa.
- **Dado** um documento do aluno A, **quando** o próprio A apagar pelo app, **então** o arquivo é removido e a lista recarrega.
- **Dado** uma conta de coordenação, **quando** apagar o documento de qualquer aluno, **então** o arquivo é removido.
- **Dado** a pasta de avisos, **quando** um aluno comum tentar enviar ou apagar um aviso direto no Supabase, **então** o servidor recusa.
- **Dado** um aluno comum, **quando** tentar marcar a si mesmo como coordenação no próprio perfil, **então** o servidor recusa.

INVEST: **I**ndependente da US-02. **N**egociável no mecanismo (JWT de terceiro ou Edge Function). **V**aliosa, é o pedido do cliente. **E**stimável depois do spike. **S**mall o bastante para o sprint. **T**estável por fora da interface, que é o ponto da história.

### US-02: Nome do perfil

> **Como** aluno, **quero** alterar meu nome no perfil e vê-lo salvo, **para que** meu nome apareça correto para os colegas.

Critérios de aceite:

- **Dado** que estou na tela da minha conta, **quando** alterar o nome e tocar em salvar, **então** vejo confirmação e o nome novo continua lá depois de fechar e abrir o app.
- **Dado** que o salvamento falha no servidor, **quando** a operação der erro, **então** vejo mensagem em português e o nome antigo continua na tela.
- **Dado** que deixei o campo vazio ou só com espaços, **quando** tocar em salvar, **então** vejo "Campo obrigatório" e nada é gravado.

INVEST: **I**ndependente da US-01 no código, mas depende da regra do Firestore que a US-01 mexeu. **N**egociável na forma de mostrar o erro. **V**aliosa, reclamação direta de aluno. **E**stimável, quase tudo é investigação. **S**mall. **T**estável com fake do repositório e pelo Firestore.

## Origem dos sintomas (Tasks)

**Permissão.** A trava existia só no app. `supabase/storage_policies.sql` liberava `insert`, `update` e `delete` para a role `anon` no bucket inteiro, a chave pública está no código (`supabase_storage_service.dart`), e a decisão de quem pode apagar ficava em `DocumentController.canManage`, no cliente. O `storage.rules` tinha a regra certa, mas não vale nada: o storage do app é o Supabase, não o Firebase Storage. Ou seja, não existia identidade de usuário no storage, e quem chamasse a API direto apagava qualquer arquivo.

Correção: o Firebase foi cadastrado no Supabase como provedor de terceiro (Authentication > Third-Party Auth), o app passou a mandar o token do Firebase em toda requisição (`main.dart`), e as políticas comparam a pasta do arquivo com o uid do token. Como o token do Firebase não traz o claim `role`, a requisição cai como `anon`; por isso as políticas valem para `anon, authenticated` e quem barra é o uid (sem login, não há uid e nada é escrito).

No caminho apareceram dois problemas que não estavam no plano: o SQL do PR #5 nunca tinha sido aplicado no Supabase, e o `firestore.rules` nunca tinha sido publicado no Firebase. Um aluno conseguia se promover a coordenação. As duas coisas foram aplicadas e testadas pelos endpoints.

**Nome do perfil.** Hipóteses verificadas:

1. *Regra do Firestore bloqueando o update.* Testado direto no Firestore com duas contas: o update passava. **Descartada para o estado de antes**, mas ao publicar a regra do PR #5 ela passaria a bloquear: perfis criados antes de 07/09 não têm o campo `isAdmin`, e a comparação `request.resource.data.isAdmin == resource.data.isAdmin` dá erro e nega. Corrigido com `get('isAdmin', false)` e testado com um perfil sem o campo.
2. *Nome só com espaços.* `nameValidate` só recusava `''`, então `'   '` passava e era gravado. **Confirmada.**
3. *Espaço sobrando.* O nome era gravado com espaço no começo, e a saudação do perfil usa `name.split(' ')[0]`, que vira vazio. Para o aluno, parecia que o nome não tinha salvo. **Confirmada.**
4. *Mensagem de erro.* A tela mostrava `'Coudn't update user'` em inglês e jogava fora a mensagem em português do controller. **Confirmada.**
5. *`MyTextField` perdendo o texto no rebuild.* O campo repassa `onChanged` certinho e o botão de salvar aparece. **Descartada.**

## Definition of Done

Uma história só está pronta quando:

1. Tem teste automatizado cobrindo o caminho principal, o de sucesso, não só a recusa.
2. O teste foi commitado antes da correção, no mesmo PR, com o vermelho registrado.
3. Não introduz smell conhecido e `flutter analyze` continua limpo.
4. Foi revisada por um colega, com comentário no PR.
5. CI verde no PR antes do merge.
6. Mergeada na `main`.
7. Registrada no diário de quem fez, com evidência.

## Backlog (Planning Poker e MoSCoW)

| # | Item | MoSCoW | Pts | Justificativa | PR |
|---|---|---|---|---|---|
| 1 | US-01 autorização no servidor | Must | 21 | Pedido do cliente e maior incerteza: depende do mecanismo que o Supabase aceita. Por isso começou com spike | #5, #6 |
| 2 | Pendência da N1: `isAdmin` mutável pelo próprio aluno | Must | (na US-01) | Escalada de privilégio. Sem isso a US-01 não fecha | #5, #7 |
| 3 | Cobertura do caminho principal com fake | Must | 10 | Nenhum teste exercitava uma operação de sucesso. Exige extrair a interface do storage antes | #2 |
| 4 | US-02 nome do perfil | Must | 8 | Reclamação de aluno. Os pontos são da investigação, não do conserto | #7 |
| 5 | Pipeline de CI + `flutter analyze` limpo | Must | 6 | Entrega obrigatória e pré-requisito da DoD. O analyze saía com código 1 | #1 |
| 6 | Tratamento de erro (sliver, `mounted`, `catch` vazio) | Should | 6 | Quatro smells da mesma família, revisados juntos | #3 |
| 7 | Código morto (`Student`, avisos duplicados) | Should | 5 | Pequeno e autocontido | #4 |
| 8 | Artefatos no README | Must | 5 | Exigência do enunciado | #7 |
| 9 | Interface da coordenação para avisos | Could | 5 | Feature nova; ficou fora. A regra do servidor já está aplicada | — |

### Itens da N1 que entraram como prontos

| Item | Teste que comprova |
|---|---|
| Permissão por dono na interface | `document_permissions_test.dart`. Prova a decisão do controller, não a do servidor; foi por isso que a US-01 existiu |
| Confirmação de e-mail obrigatória | `auth_redirect_test.dart` |
| Restrição de domínio institucional | `college_email_test.dart` |
| `delete` que avisa quando nada foi apagado (`f060a7d`) | `storage_server_authorization_test.dart` ("delete negado pela RLS vira erro") e `storage_integration_test.dart` ("DELETE FALSO") |
| Redefinição de senha | **Sem teste.** Fica declarado como pendência |

## Catálogo de smells

| # | Onde | Qual | Refatoração | Teste | Tipo |
|---|---|---|---|---|---|
| 1 | `supabase_storage_service.dart` | Classe com duas responsabilidades: montar caminho e fazer I/O | Extrair `StoragePaths` | `storage_paths_test.dart` (já existia, virou rede) e `storage_paths_puro_test.dart` | Refatoração |
| 2 | `profile_repository.dart` | Instanciava `SupabaseStorageService()` no construtor; impossível testar | Extrair a interface `StorageService` e injetar | Sem teste direto do repositório; a injeção é o que permite os fakes de `profile_controller_test.dart` | Refatoração |
| 3 | `documents.dart` e `result.dart` | `Center` dentro de `slivers:` derrubava a tela no erro, duplicado e com `Text('Erro')` mudo | Extrair `SliverErrorMessage` | `tela_erro_sliver_test.dart`, vermelho antes | Bug + refatoração |
| 4 | `student_model.dart` | Parâmetro nunca usado e dois ramos que retornavam o mesmo `'N/A'` | Colapsar os helpers | `college_email_test.dart` ("remover codigo morto - Smell 4") | Refatoração |
| 5 | `profile_controller.dart` (`deletePhoto`) | Exceção engolida: falha mostrava sucesso | Propagar via `Either` | `profile_controller_test.dart`, vermelho antes | Bug |
| 6 | `document_page.dart`, `documents.dart`, `my_account.dart` | `BuildContext` usado depois de `await` sem checar `mounted` | Guardar com `mounted` | Sem widget test; a regra `use_build_context_synchronously` foi religada e o analyze sai com 0 | Bug |
| 7 | `notice_repository.dart` | `getCollegeNotices` e `getDepartmentalNotices` idênticos, os dois raspando `jgec.ac.in` (faculdade do projeto original); o segundo sem chamador | Remover o que não era usado | Sem teste próprio; a remoção não muda comportamento | Código morto |
| 8 | `notice_repository.dart` | `catch` vazio: falha de rede vira lista vazia | — | — | **Não corrigido** neste sprint |

## Pull Requests

| PR | O que entrega | Revisão |
|---|---|---|
| [#1](https://github.com/eibrunoruan/Clickboard-Faculdade-/pull/1) | Pipeline de CI e analyze limpo | Rafael |
| [#2](https://github.com/eibrunoruan/Clickboard-Faculdade-/pull/2) | `StorageService`, injeção e fake; cobertura do caminho principal | Rafael |
| [#3](https://github.com/eibrunoruan/Clickboard-Faculdade-/pull/3) | Tratamento de erro (smells 3, 5 e 6) | Rafael |
| [#4](https://github.com/eibrunoruan/Clickboard-Faculdade-/pull/4) | Código morto (smells 4 e 7) | Bruno |
| [#5](https://github.com/eibrunoruan/Clickboard-Faculdade-/pull/5) | Políticas de RLS, `isAdmin` imutável, spike | Bruno |
| [#6](https://github.com/eibrunoruan/Clickboard-Faculdade-/pull/6) | Token do Firebase no Supabase e correção das políticas | Rafael |
| [#7](https://github.com/eibrunoruan/Clickboard-Faculdade-/pull/7) | US-02 e este README | |

Os PRs #2 a #5 foram abertos em pilha e mergeados de baixo para cima, então caíram em branches que já tinham sido mergeadas. O conteúdo foi levado para a `main` sem alteração depois (commits "Merge PR #N ... na main").

**Pipeline:** https://github.com/eibrunoruan/Clickboard-Faculdade-/actions/workflows/ci.yml

## Configuração do servidor

Para a autorização funcionar num projeto novo:

1. Supabase > Authentication > Third-Party Auth: adicionar o Firebase com o project ID `quiz-38ee4`.
2. Supabase > SQL Editor: rodar `supabase/storage_policies.sql`.
3. Supabase > Table Editor > `admins`: inserir o uid do Firebase de cada coordenador.
4. Firebase: `firebase deploy --only firestore:rules`.
