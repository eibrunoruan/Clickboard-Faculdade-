import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/utils.dart';
import '../../../models/notice_model.dart';
import '../../../providers/type_defs.dart';
import '../repository/notice_repository.dart';

part 'notice_controller.g.dart';

enum NoticePublishStatus { initial, loading, success, error }

class NoticePublishState {
  final NoticePublishStatus status;
  final String? errorMessage;
  final String? successMessage;

  const NoticePublishState({
    this.status = NoticePublishStatus.initial,
    this.errorMessage,
    this.successMessage,
  });

  const NoticePublishState.initial() : this(status: NoticePublishStatus.initial);
  const NoticePublishState.loading() : this(status: NoticePublishStatus.loading);
  const NoticePublishState.success([String message = 'Aviso publicado com sucesso!'])
      : this(status: NoticePublishStatus.success, successMessage: message);
  const NoticePublishState.error(String message)
      : this(status: NoticePublishStatus.error, errorMessage: message);

  bool get isLoading => status == NoticePublishStatus.loading;
  bool get isSuccess => status == NoticePublishStatus.success;
  bool get isError => status == NoticePublishStatus.error;
}

class NoticePublishStateNotifier extends StateNotifier<NoticePublishState> {
  NoticePublishStateNotifier() : super(const NoticePublishState.initial());

  void setInitial() => state = const NoticePublishState.initial();
  void setLoading() => state = const NoticePublishState.loading();
  void setSuccess([String message = 'Aviso publicado com sucesso!']) =>
      state = NoticePublishState.success(message);
  void setError(String message) => state = NoticePublishState.error(message);
}

final noticePublishStateProvider =
    StateNotifierProvider<NoticePublishStateNotifier, NoticePublishState>((ref) {
  return NoticePublishStateNotifier();
});

@riverpod
Future<void> noticeFuture(NoticeFutureRef ref, {bool isRefreshed = false}) {
  return ref
      .watch(noticeControllerProvider.notifier)
      .getAllNotices(isRefreshed: isRefreshed);
}

@Riverpod(keepAlive: true)
class NoticeController extends _$NoticeController {
  NoticeRepository? _customRepository;

  NoticeRepository get _noticeRepository =>
      _customRepository ?? ref.read(noticeRepositoryProvider);

  @visibleForTesting
  set repository(NoticeRepository repo) => _customRepository = repo;

  init() {
    // Inicialização mantida para compatibilidade
  }

  @override
  List<Notice> build() {
    init();
    return [];
  }

  Future<void> getAllNotices({bool isRefreshed = false}) async {
    if (!isRefreshed && state.isNotEmpty) return;
    state = await _noticeRepository.getAllNotices();
  }

  /// Publica um comunicado acadêmico gerenciando reativamente os estados
  /// de Loading, Success e Error, sem engolir exceções.
  FutureEither<void> publishNotice({
    required String title,
    String? content,
    PlatformFile? file,
    Uint8List? fileBytes,
  }) async {
    final publishNotifier = ref.read(noticePublishStateProvider.notifier);
    publishNotifier.setLoading();

    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      const msg = 'Informe o título do aviso';
      publishNotifier.setError(msg);
      return left(msg);
    }

    try {
      await _noticeRepository.publishNotice(
        title: cleanTitle,
        content: content,
        file: file,
        fileBytes: fileBytes,
      );

      // Atualiza o mural da Dashboard na hora
      await getAllNotices(isRefreshed: true);

      const successMsg = 'Aviso publicado com sucesso!';
      publishNotifier.setSuccess(successMsg);
      return right(null);
    } catch (e) {
      const errorMsg =
          'Erro de conexão ao enviar aviso. Verifique sua rede e tente novamente';
      publishNotifier.setError(errorMsg);
      return left(errorMsg);
    }
  }

  FutureEither<String> saveNoticeFile(Notice notice) async {
    String appTempDir = (await getTemporaryDirectory()).path;
    String name = '${notice.name}.pdf';
    String filePath = '$appTempDir/$name';
    final file = File(filePath);
    try {
      Response resp = await get(Uri.parse(notice.downloadUrl));
      await file.writeAsBytes(resp.bodyBytes);
    } catch (e) {
      return left(e.toString());
    }
    return right(filePath);
  }

  FutureEither<String> downloadNotice(Notice doc) async {
    String filePath = (await getDownloadPath())!;
    String name = '${doc.name}.pdf';
    final file = File('$filePath/$name');
    try {
      if (await Permission.manageExternalStorage.request().isGranted) {
        Response resp = await get(Uri.parse(doc.downloadUrl));
        await file.writeAsBytes(resp.bodyBytes);
        return right(filePath);
      }
    } catch (e) {
      return left(e.toString());
    }
    return left('Permita o acesso aos arquivos para baixar o aviso');
  }
}
