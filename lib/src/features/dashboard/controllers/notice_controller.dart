import 'dart:io';

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

@riverpod
Future<void> noticeFuture(NoticeFutureRef ref, {bool isRefreshed = false}) {
  return ref
      .watch(noticeControllerProvider.notifier)
      .getAllNotices(isRefreshed: isRefreshed);
}

@Riverpod(keepAlive: true)
class NoticeController extends _$NoticeController {
  NoticeRepository get _noticeRepository => ref.read(noticeRepositoryProvider);

  @override
  List<Notice> build() {
    return [];
  }

  Future<void> getAllNotices({bool isRefreshed = false}) async {
    if (!isRefreshed && state.isNotEmpty) return;
    state = await _noticeRepository.getAllNotices();
  }

  /// Coloca o aviso recem-publicado no topo do mural. Trocar o `state` e o
  /// que faz a Dashboard redesenhar na hora, sem puxar para atualizar.
  void addPublished(Notice notice) {
    state = [notice, ...state.where((n) => n.name != notice.name)];
  }

  FutureEither<String> saveNoticeFile(Notice notice) async {
    String appTempDir = (await getTemporaryDirectory()).path;
    // Path : /data/user/0/com.example.jgec_notice/cache/
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
