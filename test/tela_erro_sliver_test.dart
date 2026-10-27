import 'package:clickboard/src/features/documents/controllers/document_controller.dart';
import 'package:clickboard/src/features/documents/screens/documents.dart';
import 'package:clickboard/src/features/result/controllers/result_controller.dart';
import 'package:clickboard/src/features/result/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Quando a leitura do mural falha, a tela tem de mostrar o erro. Hoje ela
/// derruba a arvore inteira: o ramo `error:` devolve um `Center` cru dentro de
/// `slivers:`, que so aceita `RenderSliver`.
void main() {
  testWidgets('tela de documentos mostra o erro em vez de derrubar a arvore',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentFutureProvider()
              .overrideWith((ref) => Future<void>.error('bucket fora do ar')),
        ],
        child: const MaterialApp(home: DocumentScreen()),
      ),
    );

    // Primeiro frame e o loading; o segundo entrega o erro.
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: 'o ramo de erro nao pode derrubar a arvore');
    expect(find.textContaining('bucket fora do ar'), findsOneWidget,
        reason: 'a causa precisa aparecer na tela, nao um "Erro" mudo');
  });

  testWidgets('tela de resultados mostra o erro em vez de derrubar a arvore',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          resultFutureProvider()
              .overrideWith((ref) => Future<void>.error('rede caiu')),
        ],
        child: const MaterialApp(home: ResultScreen()),
      ),
    );

    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('rede caiu'), findsOneWidget);
  });
}
