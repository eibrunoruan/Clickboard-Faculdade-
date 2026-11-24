import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/notice_model.dart';
import '../../../providers/utils_providers.dart';
import '../repository/notice_repository.dart';
import 'notice_controller.dart';

const avisoPublicadoComSucesso = 'Aviso publicado com sucesso!';
const erroDeConexaoAoPublicar =
    'Erro de conexão ao enviar aviso. Verifique sua rede e tente novamente';
const erroDePermissaoAoPublicar =
    'Você não tem permissão para publicar avisos';
const erroInesperadoAoPublicar =
    'Não foi possível publicar o aviso. Tente novamente';

/// Sem resposta do storage neste tempo, o envio e dado como queda de rede.
/// Sem limite, um upload preso deixava o botao girando para sempre.
const tempoLimiteDaPublicacao = Duration(seconds: 30);

/// Estados da publicacao de um aviso. A tela reage a cada um: trava o botao
/// enquanto envia, fecha o formulario no sucesso e mostra o motivo no erro.
sealed class PublishNoticeState {
  const PublishNoticeState();
}

class PublishNoticeIdle extends PublishNoticeState {
  const PublishNoticeIdle();
}

class PublishNoticeLoading extends PublishNoticeState {
  const PublishNoticeLoading();
}

class PublishNoticeSuccess extends PublishNoticeState {
  const PublishNoticeSuccess(this.notice);
  final Notice notice;
}

class PublishNoticeError extends PublishNoticeState {
  const PublishNoticeError(this.message);
  final String message;
}

final publishNoticeControllerProvider = NotifierProvider.autoDispose<
    PublishNoticeController, PublishNoticeState>(PublishNoticeController.new);

class PublishNoticeController extends AutoDisposeNotifier<PublishNoticeState> {
  // O formulario pode ser fechado no meio do envio; escrever no state depois
  // do dispose lanca.
  bool _disposed = false;

  @override
  PublishNoticeState build() {
    ref.onDispose(() => _disposed = true);
    return const PublishNoticeIdle();
  }

  void _emit(PublishNoticeState next) {
    if (!_disposed) state = next;
  }

  /// Valida, envia e, no sucesso, poe o aviso no mural da turma. Nenhuma
  /// falha e engolida: toda saida termina em [PublishNoticeSuccess] ou em
  /// [PublishNoticeError] com a mensagem que a tela mostra.
  Future<void> publish({required String title, Uint8List? pdf}) async {
    if (state is PublishNoticeLoading) return;

    final recusa = _validar(title, pdf);
    if (recusa != null) {
      _emit(PublishNoticeError(recusa));
      return;
    }

    _emit(const PublishNoticeLoading());
    try {
      final notice = await ref
          .read(noticeRepositoryProvider)
          .publishNotice(title: title.trim(), pdf: pdf!)
          .timeout(tempoLimiteDaPublicacao);
      ref.read(noticeControllerProvider.notifier).addPublished(notice);
      _emit(PublishNoticeSuccess(notice));
    } catch (e) {
      _emit(PublishNoticeError(mensagemDeFalhaAoPublicar(e)));
    }
  }

  String? _validar(String title, Uint8List? pdf) {
    if (ref.read(myUserProvider)?.isAdmin != true) {
      return 'Somente a coordenação pode publicar avisos';
    }
    final titulo = title.trim();
    if (titulo.isEmpty) return 'Informe o título do aviso';
    if (titulo.length > 120 || titulo.contains('/') || titulo.contains('\\')) {
      return 'O título não pode ter barras nem passar de 120 caracteres';
    }
    if (pdf == null || pdf.isEmpty) return 'Selecione o PDF do aviso';
    return null;
  }
}

/// Traduz a excecao do envio na mensagem mostrada ao coordenador.
String mensagemDeFalhaAoPublicar(Object erro) {
  if (erro is StorageException) {
    final negado = erro.statusCode == '401' ||
        erro.statusCode == '403' ||
        erro.message.contains('row-level security');
    if (negado) return erroDePermissaoAoPublicar;
  }
  if (erro is IOException || erro is ClientException || erro is TimeoutException) {
    return erroDeConexaoAoPublicar;
  }
  return erroInesperadoAoPublicar;
}
