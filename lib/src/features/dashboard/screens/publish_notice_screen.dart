import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/utils.dart';
import '../controllers/publish_notice_controller.dart';

typedef PdfSelecionado = ({String name, Uint8List bytes});

/// Abre o seletor de arquivos. Fica num provider para que o teste de widget
/// entregue um PDF sem depender do `FilePicker`, que e estatico.
final noticePdfPickerProvider =
    Provider<Future<PdfSelecionado?> Function()>((ref) => () async {
          final file = await FilePicker.pickFile(
            type: FileType.custom,
            allowedExtensions: ['pdf'],
          );
          if (file == null) return null;
          return (name: file.name, bytes: await file.readAsBytes());
        });

class PublishNoticeScreen extends ConsumerStatefulWidget {
  const PublishNoticeScreen({super.key});

  @override
  ConsumerState<PublishNoticeScreen> createState() =>
      _PublishNoticeScreenState();
}

class _PublishNoticeScreenState extends ConsumerState<PublishNoticeScreen> {
  final _titulo = TextEditingController();
  PdfSelecionado? _pdf;

  @override
  void dispose() {
    _titulo.dispose();
    super.dispose();
  }

  Future<void> _selecionarPdf() async {
    final pdf = await ref.read(noticePdfPickerProvider)();
    if (pdf == null || !mounted) return;
    if (pdf.bytes.length > 2048 * 1024) {
      showSnackBar(
          context: context,
          title: 'O tamanho máximo do arquivo é 2 MB',
          snackBarType: SnackBarType.error);
      return;
    }
    setState(() => _pdf = pdf);
  }

  void _publicar() {
    ref
        .read(publishNoticeControllerProvider.notifier)
        .publish(title: _titulo.text, pdf: _pdf?.bytes);
  }

  @override
  Widget build(BuildContext context) {
    // No erro o formulario fica aberto e o texto e o PDF continuam onde
    // estavam: basta tocar em Publicar de novo.
    ref.listen(publishNoticeControllerProvider, (_, estado) {
      switch (estado) {
        case PublishNoticeSuccess():
          showSnackBar(
              context: context,
              title: avisoPublicadoComSucesso,
              snackBarType: SnackBarType.good);
          Navigator.of(context).pop();
        case PublishNoticeError(:final message):
          showSnackBar(
              context: context,
              title: message,
              snackBarType: SnackBarType.error);
        case PublishNoticeIdle() || PublishNoticeLoading():
          break;
      }
    });

    final estado = ref.watch(publishNoticeControllerProvider);
    final enviando = estado is PublishNoticeLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Publicar aviso')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            key: const Key('titulo-do-aviso'),
            controller: _titulo,
            enabled: !enviando,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Título do aviso',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: enviando ? null : _selecionarPdf,
            icon: const Icon(Icons.picture_as_pdf),
            label: Text(_pdf?.name ?? 'Selecionar PDF'),
          ),
          const SizedBox(height: 24),
          if (estado case PublishNoticeError(:final message)) ...[
            MaterialBanner(
              key: const Key('erro-da-publicacao'),
              leading: const Icon(Icons.error_outline),
              content: Text(message),
              backgroundColor: SnackBarType.error.backgroundColor,
              actions: const [SizedBox.shrink()],
            ),
            const SizedBox(height: 16),
          ],
          FilledButton(
            onPressed: enviando ? null : _publicar,
            child: enviando
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Publicar'),
          ),
        ],
      ),
    );
  }
}
