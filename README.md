<br/>
<p align="center">
  <a href="https://github.com/Abhigyan103/Clickboard">
    <img src="assets/logo/logo.png" alt="Logo" width="200">
  </a>

  <h3 align="center">ClickBoard</h3>

  <p align="center">
    Streamlining your academic experience.
    <br/>
    <br/>
    <a href="https://github.com/Abhigyan103/Clickboard"><strong>Explore the docs »</strong></a>
    <br/>
    <br/>
    <a href="https://github.com/Abhigyan103/Clickboard">View Demo</a>
    .
    <a href="https://github.com/Abhigyan103/Clickboard/issues">Report Bug</a>
    .
    <a href="https://github.com/Abhigyan103/Clickboard/issues">Request Feature</a>
  </p>
</p>

![Downloads](https://img.shields.io/github/downloads/Abhigyan103/Clickboard/total) ![Contributors](https://img.shields.io/github/contributors/Abhigyan103/Clickboard?color=dark-green) ![Stargazers](https://img.shields.io/github/stars/Abhigyan103/Clickboard?style=social) ![Issues](https://img.shields.io/github/issues/Abhigyan103/Clickboard) ![License](https://img.shields.io/github/license/Abhigyan103/Clickboard) 

## Table Of Contents

* [About the Project](#about-the-project)
* [Built With](#built-with)
* [Getting Started](#getting-started)
  * [Prerequisites](#prerequisites)
  * [Installation](#installation)
* [Usage](#usage)
* [Contributing](#contributing)
* [Authors](#authors)
* [Acknowledgements](#acknowledgements)

## About The Project

Clickboard is a powerful Flutter app, seamlessly integrated with Firebase, designed to streamline your academic experience. It offers a range of features including secure authentication, intuitive carousel navigation, term-specific notices, roll number-based academic results, engaging Lottie animations, and convenient account management options like password reset, updates, and deactivation. Simplify your academic journey with Clickboard.
<br/>
<br/>
  <img width="24%" src="https://github.com/Abhigyan103/Clickboard/assets/91414842/d83513f6-2172-4987-9d9d-8a8c6eaa80d1">
  <img width="24%" src="https://github.com/Abhigyan103/Clickboard/assets/91414842/c6c1d511-9f4a-4e11-91f1-fdc895dcbd9b">
  <img width="24%" src="https://github.com/Abhigyan103/Clickboard/assets/91414842/bc33c88a-cb88-449b-9cdf-5ab38e6bcd98">
  <img width="24%" src="https://github.com/Abhigyan103/Clickboard/assets/91414842/68449dd2-bdb7-4442-b9b5-2f8ec1d56ec7">
  <img width="24%" src="https://github.com/Abhigyan103/Clickboard/assets/91414842/450c49da-0e9a-4d6b-b27c-550d6a14e398">
  <img width="24%" src="https://github.com/Abhigyan103/Clickboard/assets/91414842/ae183bce-34dc-4db8-a18e-ec5ef7c077bb">
  <img width="24%" src="https://github.com/Abhigyan103/Clickboard/assets/91414842/00a83f2b-66dd-4427-8b55-7d5ae11e59fd">
  <img width="24%" src="https://github.com/Abhigyan103/Clickboard/assets/91414842/819aea40-5583-4ea1-a28b-2122886a08e9">
  <img width="24%" src="https://github.com/Abhigyan103/Clickboard/assets/91414842/be6d397a-8fe6-4df5-ab6a-5dc32fa44bb7">

## Built With

- Flutter
- Firebase : *As a BaaS for this project*
- Riverpod : *As a state management tool*
- Go router : *For routing between pages*

## Getting Started

This is how you may set up your project locally.
To get a local copy up and running follow these simple steps.

### Prerequisites

This is an example of how to list things you need to use the software and how to install them.

### Installation

1. Create  a flutter project
```sh
flutter create app-name
```
2. Clone the repo

```sh
git clone https://github.com/Abhigyan103/Clickboard.git
```

3. Install pub modules

```sh
pub get
```

4. Configure firebase database


## Usage

Use this space to show useful examples of how a project can be used. Additional screenshots, code examples and demos work well in this space. You may also link to more resources.

_For more examples, please refer to the [Documentation](https://example.com)_

## Contributing

Contributions are what make the open source community such an amazing place to be learn, inspire, and create. Any contributions you make are **greatly appreciated**.
* If you have suggestions for adding or removing projects, feel free to [open an issue](https://github.com/Abhigyan103/Clickboard/issues/new) to discuss it, or directly create a pull request after you edit the *README.md* file with necessary changes.
* Please make sure you check your spelling and grammar.
* Create individual PR for each suggestion.
* Please also read through the [Code Of Conduct](https://github.com/Abhigyan103/Clickboard/blob/main/CODE_OF_CONDUCT.md) before posting your first idea as well.

### Creating A Pull Request

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feat/AmazingFeature`) or Bug Fix Feature (`git checkout -b fix/BugName`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'` or `git commit -m 'Fixes #issueNumber`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request to main

## Authors

* **Abhigyan Singh** - *Comp Sci Student* - [Abhigyan Singh](https://github.com/Abhigyan103) - *Owner*

## Guia de testes do Clickboard

Este documento explica como rodar o aplicativo, quais contas usar e como executar a bateria de testes automatizados.

### O que foi implementado

O aplicativo passou a exigir confirmação de endereço eletrônico e passou a aplicar permissão por dono nos documentos do mural.

**Confirmação de cadastro.** O Firebase envia a mensagem de confirmação sozinho, sem provedor externo e sem custo. Ao criar conta, o aluno recebe a mensagem e fica preso numa tela de verificação até clicar no link. A tela consulta o Firebase a cada três segundos e libera o aplicativo automaticamente quando a confirmação acontece. Quem entra pelo Google passa direto, porque o Google já entrega o endereço confirmado.

**Restrição de domínio.** Somente endereços terminados em catolicasc.edu.br conseguem criar conta. A validação acontece no formulário e também no repositório, antes de qualquer chamada ao Firebase.

**Permissão por dono.** Cada arquivo fica numa subpasta com o identificador de quem enviou. O dono pode renomear e apagar o próprio arquivo. A coordenação pode gerenciar qualquer arquivo. Os demais alunos só conseguem baixar.

**Redefinição de senha.** O botão de esquecimento de senha chamava o método errado e nunca enviava nada, apesar de mostrar mensagem de sucesso. Agora funciona.

### Contas de teste

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

### Documentos de demonstração

O mural já contém dois arquivos no bucket, um de cada conta.

O arquivo chamado `Ata-da-Coordenacao.pdf` pertence ao colega. O arquivo chamado `Trabalho-Clickboard.pdf` pertence ao aluno.

### Como rodar o aplicativo

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

### Como testar a permissão na interface

Entre com a conta do aluno e abra a aba de documentos na barra inferior.

**Passo um.** Segure o dedo sobre o cartão do arquivo `Ata-da-Coordenacao.pdf`. O menu abre com apenas uma opção, que é baixar. Não aparece opção de renomear nem de apagar, porque esse arquivo é do colega.

**Passo dois.** Segure o dedo sobre o cartão do arquivo `Trabalho-Clickboard.pdf`. O menu abre com três opções, que são baixar, renomear e apagar. Esse arquivo é do próprio aluno.

A diferença entre os dois menus é a demonstração completa da permissão. Um toque simples apenas abre o arquivo. O menu só aparece mantendo o dedo pressionado.

Para conferir que a regra vale nos dois sentidos, saia e entre com a conta do colega. As opções se invertem.

### Como testar a restrição de domínio

Na tela de entrada, toque em criar conta. Preencha o campo de endereço com algo terminado em gmail.com e confirme. O formulário recusa na hora, com aviso pedindo endereço institucional. Nenhuma conta chega a ser criada no Firebase.

### Testes automatizados

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

### Arquivos de teste

O diretório de testes contém cinco arquivos.

`college_email_test.dart` cobre a restrição de domínio e a criação de aluno a partir do endereço.

`auth_redirect_test.dart` cobre todas as combinações de sessão e confirmação, incluindo uma varredura que garante ausência de laço infinito de redirecionamento.

`document_permissions_test.dart` cobre dono, coordenação, terceiro e visitante sem sessão.

`storage_paths_test.dart` cobre a montagem de caminhos dentro do bucket.

`storage_integration_test.dart` é a bateria que fala com o Supabase de verdade.

### Observações

A autorização de documentos é aplicada no aplicativo. As políticas do bucket permitem escrita e exclusão para a chave pública, portanto a trava é de interface e não de servidor. Fechar isso no servidor exigiria validar o token do Firebase dentro do Supabase, por meio de uma função de borda.

A regra atual do Firestore permite que cada pessoa edite o próprio documento de perfil, inclusive o campo que marca coordenação. Vale revisar antes de colocar em produção.
