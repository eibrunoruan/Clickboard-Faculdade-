import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:clickboard/src/features/dashboard/controllers/carousel_controller.dart'
    as carrossel;
import 'package:clickboard/src/features/dashboard/controllers/publish_notice_controller.dart';
import 'package:clickboard/src/features/dashboard/repository/notice_repository.dart';
import 'package:clickboard/src/features/dashboard/screens/dashboard.dart';
import 'package:clickboard/src/features/dashboard/screens/publish_notice_screen.dart';
import 'package:clickboard/src/models/student_model.dart';
import 'package:clickboard/src/providers/utils_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes/fake_storage_service.dart';

/// Os dois criterios de aceite da publicacao, pela interface:
///
/// - com conexao: Publicar mostra sucesso, fecha o formulario e o aviso
///   aparece no mural na hora;
/// - com queda de conexao: a tela nao congela nem engole o erro, mostra a
///   mensagem e mantem o que foi digitado para tentar de novo.
void main() {
  final pdf = Uint8List.fromList('%PDF-1.4 aviso'.codeUnits);

  Student usuario({bool isAdmin = true}) => Student(
        name: 'Coordenação',
        roll: 'N/A',
        reg: '',
        email: 'coordenacao@catolicasc.edu.br',
        dept: 'CATOLICASC',
        session: 'N/A',
        isAdmin: isAdmin,
        uid: 'coordenacao',
      );

  Future<void> abrirDashboard(
    WidgetTester tester, {
    FakeStorageService? storage,
    bool isAdmin = true,
  }) async {
    final container = ProviderContainer(overrides: [
      noticeRepositoryProvider.overrideWithValue(NoticeRepository(
        storageService: storage ?? FakeStorageService(),
        httpClient: MockClient((_) async => http.Response('', 404)),
        department: 'CATOLICASC',
        session: 'N/A',
      )),
      // O carrossel real busca imagens no Supabase, que nao sobe no teste.
      carrossel.carouselControllerProvider.overrideWith(_CarrosselVazio.new),
      noticePdfPickerProvider
          .overrideWithValue(() async => (name: 'aviso.pdf', bytes: pdf)),
    ]);
    addTearDown(container.dispose);
    container.read(myUserProvider.notifier).update(usuario(isAdmin: isAdmin));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Dashboard()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> preencherFormulario(WidgetTester tester, String titulo) async {
    await tester.tap(find.byTooltip('Publicar aviso'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('titulo-do-aviso')), titulo);
    await tester.tap(find.text('Selecionar PDF'));
    await tester.pumpAndSettle();
  }

  FilledButton botaoPublicar(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  testWidgets(
      'com conexao: mostra sucesso, fecha o formulario e o aviso aparece '
      'no mural', (tester) async {
    await abrirDashboard(tester);
    expect(find.text('No Notices'), findsOneWidget);

    await preencherFormulario(tester, 'Prova de Calculo');
    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();

    expect(find.text(avisoPublicadoComSucesso), findsOneWidget);
    expect(find.byType(PublishNoticeScreen), findsNothing,
        reason: 'o formulario fecha no sucesso');
    expect(find.text('Prova de Calculo'), findsOneWidget,
        reason: 'o aviso aparece no mural sem reiniciar nem puxar a lista');
    expect(find.text('No Notices'), findsNothing);
  });

  testWidgets(
      'queda de conexao: mostra o motivo, nao fecha e mantem o que foi '
      'digitado', (tester) async {
    final storage = FakeStorageService()
      ..falhas['uploadBytes'] = const SocketException('Network is down');
    await abrirDashboard(tester, storage: storage);

    await preencherFormulario(tester, 'Prova de Calculo');
    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('erro-da-publicacao')), findsOneWidget,
        reason: 'o alerta fica no formulario mesmo depois do snackbar sumir');
    expect(find.text(erroDeConexaoAoPublicar), findsWidgets);
    expect(find.byType(PublishNoticeScreen), findsOneWidget,
        reason: 'o formulario continua aberto para tentar de novo');
    expect(find.text('Prova de Calculo'), findsOneWidget,
        reason: 'o titulo digitado continua no campo');
    expect(find.text('aviso.pdf'), findsOneWidget,
        reason: 'o PDF escolhido continua selecionado');
    expect(botaoPublicar(tester).onPressed, isNotNull,
        reason: 'a tela nao congela: o botao volta a responder');
  });

  testWidgets('enquanto envia o botao trava, mas a tela segue respondendo',
      (tester) async {
    final envio = Completer<void>();
    await abrirDashboard(tester, storage: _StorageLento(envio.future));

    await preencherFormulario(tester, 'Aviso');
    await tester.tap(find.text('Publicar'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(botaoPublicar(tester).onPressed, isNull,
        reason: 'segundo toque nao dispara um segundo envio');

    envio.complete();
    await tester.pumpAndSettle();
    expect(find.text(avisoPublicadoComSucesso), findsOneWidget);
  });

  testWidgets('aluno comum nao ve o botao de publicar', (tester) async {
    await abrirDashboard(tester, isAdmin: false);

    expect(find.byTooltip('Publicar aviso'), findsNothing);
  });
}

class _CarrosselVazio extends carrossel.CarouselController {
  @override
  List<Image> build() => [];
}

/// Storage cujo upload so termina quando o teste mandar.
class _StorageLento extends FakeStorageService {
  _StorageLento(this._liberado);

  final Future<void> _liberado;

  @override
  Future<String> uploadBytes({
    required String folder,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
  }) async {
    await _liberado;
    return super.uploadBytes(
        folder: folder,
        fileName: fileName,
        bytes: bytes,
        contentType: contentType);
  }
}
