import 'package:flutter/material.dart';

/// Mensagem de erro para usar dentro de `CustomScrollView.slivers`.
///
/// Existe porque as telas de documentos e de resultados devolviam
/// `Center(child: Text('Erro'))` no ramo `error:` do `AsyncValue`. O mesmo
/// trecho, duplicado nos dois arquivos, com dois defeitos:
///
/// 1. `slivers:` aceita apenas `RenderSliver`. Um `Center` cru derruba a
///    arvore inteira com "RenderViewport expected a child of type
///    RenderSliver", ou seja, uma falha de leitura virava crash de tela.
/// 2. O texto fixo 'Erro' escondia a causa de quem usa e de quem depura.
///
/// Sem efeito colateral no `build`: a causa vai para a tela, que serve tanto
/// ao usuario quanto a quem desenvolve, em vez de um log invisivel.
class SliverErrorMessage extends StatelessWidget {
  const SliverErrorMessage({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(child: Text('Erro: $error')),
      ),
    );
  }
}
