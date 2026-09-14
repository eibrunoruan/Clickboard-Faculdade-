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

A bateria offline roda sem rede e sem aparelho conectado.

```
flutter test
```

São vinte e nove testes verdes. Eles cobrem a validação de domínio, a decisão de redirecionamento entre entrada, verificação e aplicativo, a regra de permissão do controlador e a montagem dos caminhos dentro do bucket.

Existe ainda uma bateria de integração que conversa com o Supabase de verdade. Ela fica desligada por padrão para não depender de rede. Para executar:

```
SUPABASE_INTEGRATION=1 flutter test test/storage_integration_test.dart
```

São sete testes. Eles enviam um arquivo, conferem tipo e tamanho, baixam e comparam byte a byte, apagam pelo dono, apagam pela coordenação, recusam a exclusão feita por outro aluno e verificam que apagar algo inexistente vira erro visível em vez de falso sucesso.

Essa bateria usa uma raiz isolada dentro do bucket, fora da pasta real do mural, e limpa tudo ao final. Nenhum arquivo de teste aparece para os usuários.

## Arquivos de teste

O diretório de testes contém cinco arquivos.

`college_email_test.dart` cobre a restrição de domínio e a criação de aluno a partir do endereço.

`auth_redirect_test.dart` cobre todas as combinações de sessão e confirmação, incluindo uma varredura que garante ausência de laço infinito de redirecionamento.

`document_permissions_test.dart` cobre dono, coordenação, terceiro e visitante sem sessão.

`storage_paths_test.dart` cobre a montagem de caminhos dentro do bucket.

`storage_integration_test.dart` é a bateria que fala com o Supabase de verdade.

## Observações

A autorização de documentos é aplicada no aplicativo. As políticas do bucket permitem escrita e exclusão para a chave pública, portanto a trava é de interface e não de servidor. Fechar isso no servidor exigiria validar o token do Firebase dentro do Supabase, por meio de uma função de borda.

A regra atual do Firestore permite que cada pessoa edite o próprio documento de perfil, inclusive o campo que marca coordenação. Vale revisar antes de colocar em produção.
