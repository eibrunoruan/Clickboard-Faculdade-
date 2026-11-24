import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/utils.dart';
import '../../controllers/notice_controller.dart';

class PublishNoticeDialog extends ConsumerStatefulWidget {
  const PublishNoticeDialog({super.key});

  @override
  ConsumerState<PublishNoticeDialog> createState() =>
      _PublishNoticeDialogState();
}

class _PublishNoticeDialogState extends ConsumerState<PublishNoticeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  PlatformFile? _selectedFile;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result.isNotEmpty) {
      setState(() {
        _selectedFile = result.first;
        if (_titleController.text.trim().isEmpty) {
          _titleController.text =
              _selectedFile!.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final result = await ref
        .read(noticeControllerProvider.notifier)
        .publishNotice(
          title: _titleController.text,
          content: _contentController.text,
          file: _selectedFile,
        );

    if (!mounted) return;

    result.fold(
      (errorMessage) {
        // Erro: Mantém os dados digitados e exibe feedback explícito
        showSnackBar(
          context: context,
          title: errorMessage,
          snackBarType: SnackBarType.error,
        );
      },
      (_) {
        // Sucesso: fecha o formulário e exibe feedback de sucesso
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).maybePop();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text(
                'Aviso publicado com sucesso!',
                style: TextStyle(fontSize: 15),
              ),
              backgroundColor: SnackBarType.good.backgroundColor,
            ),
          );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final publishState = ref.watch(noticePublishStateProvider);
    final isLoading = publishState.isLoading;

    return AlertDialog(
      title: const Text('Publicar Novo Aviso'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (publishState.isError && publishState.errorMessage != null) ...[
                Container(
                  key: const Key('publish_error_banner'),
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0x33CF6679),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCF6679)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFFCF6679), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          publishState.errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFCF6679),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              TextFormField(
                key: const Key('notice_title_field'),
                controller: _titleController,
                enabled: !isLoading,
                decoration: const InputDecoration(
                  labelText: 'Título do aviso *',
                  hintText: 'Ex: Comunicado sobre Prova Final',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o título do aviso';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('notice_content_field'),
                controller: _contentController,
                enabled: !isLoading,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Conteúdo do aviso (opcional)',
                  hintText: 'Digite a descrição ou detalhes adicionais',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    key: const Key('attach_file_button'),
                    onPressed: isLoading ? null : _pickFile,
                    icon: const Icon(Icons.attach_file),
                    label: Text(
                        _selectedFile == null ? 'Anexar PDF' : 'Trocar arquivo'),
                  ),
                  const SizedBox(width: 8),
                  if (_selectedFile != null)
                    Expanded(
                      child: Text(
                        _selectedFile!.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
              if (isLoading) ...[
                const SizedBox(height: 16),
                const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Publicando aviso...'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('cancel_publish_button'),
          onPressed: isLoading ? null : () => Navigator.of(context).maybePop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          key: const Key('submit_publish_button'),
          onPressed: isLoading ? null : _submit,
          child: const Text('Publicar'),
        ),
      ],
    );
  }
}
