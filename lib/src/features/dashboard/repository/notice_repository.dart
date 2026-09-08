import 'package:fpdart/fpdart.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';

import '../../../models/notice_model.dart';
import '../../../providers/supabase_storage_service.dart';

class NoticeRepository {
  final SupabaseStorageService _storageService;
  final String _noticesFolder;
  final String department, session;
  NoticeRepository({
    SupabaseStorageService? storageService,
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
      //
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
      //
    }
    return webNotices;
  }

  Future<List<Notice>> getDepartmentalNotices() async {
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
      //
    }
    return webNotices;
  }
}
