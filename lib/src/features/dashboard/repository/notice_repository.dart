import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';

import '../../../models/notice_model.dart';
import '../../../providers/supabase_storage_service.dart';
import '../../../providers/utils_providers.dart';

final noticeRepositoryProvider = Provider<NoticeRepository>((ref) {
  final user = ref.watch(myUserProvider);
  return NoticeRepository(
    department: user?.dept ?? '',
    session: user?.session ?? '',
  );
});

class NoticeRepository {
  final StorageService _storageService;
  final String _noticesFolder;
  final String department, session;

  NoticeRepository({
    StorageService? storageService,
    required this.department,
    required this.session,
  })  : _storageService = storageService ?? SupabaseStorageService(),
        _noticesFolder = '$department/$session/Notice';

  Future<List<Notice>> getAllNotices() async {
    List<Notice> notices = [];
    notices.addAll(await getFBNotices());
    notices.addAll(await getCollegeNotices());
    notices = notices
        .sortWithDate((instance) => instance.timeCreated ?? DateTime.now())
        .reversed
        .toList();
    return notices;
  }

  Future<List<Notice>> getFBNotices() async {
    List<Notice> fbNotices = [];
    try {
      final files = await _storageService.list(_noticesFolder);
      for (var file in files) {
        fbNotices.add(Notice(
          name: file.name.split('.pdf')[0],
          downloadUrl: await _storageService.signedUrl(file.path),
          timeCreated: file.timeCreated,
        ));
      }
    } catch (e) {
      // Ignora falha de listagem para manter compatibilidade quando a pasta ainda não existe
    }
    return fbNotices;
  }

  Future<List<Notice>> getCollegeNotices() async {
    List<Notice> webNotices = [];
    final url = Uri.parse('https://jgec.ac.in/announcement/1');
    try {
      final Response response = await get(url);
      var document = parse(response.body);
      webNotices = document.querySelectorAll('div.notice-info').map((e) {
        return Notice(
            name: e.querySelector('a')?.innerHtml.trim() ?? '',
            downloadUrl: e.querySelector('a')?.attributes['href']?.trim() ?? '',
            timeCreated: DateFormat('dd MMMM yyyy')
                .parse(e.querySelector('span')!.innerHtml.trim()));
      }).toList();
    } catch (e) {
      // Falha na fonte web legada não deve derrubar os avisos acadêmicos
    }
    return webNotices;
  }

  /// Publica um novo comunicado acadêmico no storage.
  ///
  /// Lança exceção caso ocorra falha de rede ou de storage, garantindo
  /// que a falha não seja engolida silenciosamente.
  Future<void> publishNotice({
    required String title,
    String? content,
    PlatformFile? file,
    Uint8List? fileBytes,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw ArgumentError('O título do aviso não pode ser vazio');
    }

    final fileName =
        cleanTitle.toLowerCase().endsWith('.pdf') ? cleanTitle : '$cleanTitle.pdf';

    if (file != null) {
      await _storageService.uploadPlatformFile(_noticesFolder, file);
    } else if (fileBytes != null) {
      await _storageService.uploadBytes(
        folder: _noticesFolder,
        fileName: fileName,
        bytes: fileBytes,
        contentType: 'application/pdf',
      );
    } else {
      final body = content != null && content.trim().isNotEmpty
          ? content.trim()
          : cleanTitle;
      final bytes = Uint8List.fromList(utf8.encode(body));
      await _storageService.uploadBytes(
        folder: _noticesFolder,
        fileName: fileName,
        bytes: bytes,
        contentType: 'application/pdf',
      );
    }
  }
}
