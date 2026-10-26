import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:file_picker/file_picker.dart';
import 'excel_file_saver.dart';

class ExcelImportResult {
  final List<Map<String, String>> validRows;
  final List<String> errors;
  final int duplicateCount;
  final int detectedHeaderRow;
  final Map<String, String> detectedColumns;
  const ExcelImportResult({
    required this.validRows,
    required this.errors,
    required this.duplicateCount,
    this.detectedHeaderRow = 1,
    this.detectedColumns = const {},
  });
}

class ExcelCoordinatorOption {
  final String id;
  final String name;
  final String municipality;
  const ExcelCoordinatorOption({required this.id, required this.name, required this.municipality});
}

class ExcelGroupOption {
  final String id;
  final String number;
  final String name;
  final String coordinatorId;
  const ExcelGroupOption({required this.id, required this.number, required this.name, required this.coordinatorId});

  String get label {
    final n = number.trim();
    final g = name.trim();
    if (n.isNotEmpty && g.isNotEmpty) return 'مجموعة $n — $g';
    if (n.isNotEmpty) return 'مجموعة $n';
    return g.isNotEmpty ? g : id;
  }
}

class ExcelService {
  static const fieldAliases = <String, List<String>>{
    'name': [
      'الاسم الرباعي', 'الاسم رباعي', 'الاسم الرباعى', 'الاسم الكامل', 'اسم العامل', 'اسم الموظف',
      'الاسم', 'full name', 'name', 'employee name', 'worker name',
    ],
    'job': [
      'المسمى الوظيفي', 'المسمى الوظيفى', 'الوظيفة', 'المهنة', 'العمل', 'الوظيفة الحالية',
      'job title', 'job', 'position', 'occupation',
    ],
    'id': [
      'رقم الهوية', 'رقم الهويه', 'الهوية', 'الهوية الشخصية', 'رقم الهوية الشخصية', 'رقم هوية',
      'هوية', 'id number', 'national id', 'identity number', 'id',
    ],
    'phone': [
      'رقم الجوال', 'رقم الهاتف', 'الجوال', 'الهاتف', 'رقم المحمول', 'المحمول',
      'phone', 'phone number', 'mobile', 'mobile number', 'telephone',
    ],
    'municipality': ['اسم البلدية', 'البلدية', 'municipality', 'municipality name'],
    'group': ['رقم المجموعة', 'المجموعة', 'مجموعة', 'group number', 'group no', 'group'],
  };

  static String _normalize(String value) {
    return value
        .replaceAll('\uFEFF', '')
        .replaceAll('\u00A0', ' ')
        .replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه').replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'[ـ\-_/\\.:،,()\[\]{}]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  static String _cleanCell(Object? value) {
    if (value == null) return '';
    return '$value'.replaceAll('\uFEFF', '').replaceAll('\u00A0', ' ').trim();
  }

  static String _canonicalField(String header) {
    final h = _normalize(header);
    if (h.isEmpty) return '';
    String? best;
    var bestScore = 0;
    for (final entry in fieldAliases.entries) {
      for (final alias in entry.value) {
        final a = _normalize(alias);
        if (h == a) return entry.key;
        var score = 0;
        if (h.contains(a) || a.contains(h)) score = a.length >= 4 ? a.length : 3;
        if (score > bestScore) {
          bestScore = score;
          best = entry.key;
        }
      }
    }
    return bestScore >= 4 ? best! : '';
  }

  static int _detectHeaderRow(Sheet sheet) {
    final limit = sheet.maxRows < 50 ? sheet.maxRows : 50;
    var bestRow = -1;
    var bestScore = 0;
    for (var r = 0; r < limit; r++) {
      final row = sheet.row(r);
      var score = 0;
      final found = <String>{};
      for (final cell in row) {
        final field = _canonicalField(_cleanCell(cell?.value));
        if (field.isNotEmpty && found.add(field)) score++;
      }
      // A real roster header normally contains at least two recognizable fields.
      if (score > bestScore) {
        bestScore = score;
        bestRow = r;
      }
      if (score >= 4) return r;
    }
    if (bestRow < 0 || bestScore < 2) {
      throw Exception('تعذر اكتشاف صف العناوين تلقائيًا. ضع عناوين مثل: الاسم، الوظيفة، رقم الهوية، الجوال في صف واحد ثم حاول مرة أخرى.');
    }
    return bestRow;
  }

  ExcelCoordinatorOption _coordinatorFromData(String id, Map<String, dynamic> x) {
    final name = '${x['name'] ?? x['displayName'] ?? x['username'] ?? id}'.trim();
    var municipality = '${x['municipalityName'] ?? x['municipality'] ?? x['municipalityScope'] ?? ''}'.trim();
    if (municipality.isEmpty) {
      final scope = '${x['scope'] ?? ''}'.trim();
      if (scope.isNotEmpty && scope != 'assigned_only') municipality = scope;
    }
    // Backward compatibility for older records that explicitly contain a phrase such as
    // "منسق بلدية نابلس". We do not guess from an ordinary person's name.
    if (municipality.isEmpty) {
      final municipalityMatch = RegExp(r'بلدية\s+(.+)', caseSensitive: false).firstMatch(name);
      if (municipalityMatch != null) {
        municipality = municipalityMatch.group(1)!.trim();
      } else {
        final coordinatorMatch = RegExp(r'منسق(?:ة)?\s+(.+)', caseSensitive: false).firstMatch(name);
        if (coordinatorMatch != null && coordinatorMatch.group(1)!.trim().isNotEmpty) {
          municipality = coordinatorMatch.group(1)!.trim();
        }
      }
    }
    return ExcelCoordinatorOption(id: id, name: name, municipality: municipality);
  }

  Future<List<ExcelCoordinatorOption>> loadMunicipalityCoordinators({required String actorId, required String actorRole}) async {
    if (actorRole == 'municipality_coordinator') {
      final doc = await FirebaseFirestore.instance.collection('users').doc(actorId).get();
      if (!doc.exists || doc.data() == null) return const [];
      return [_coordinatorFromData(doc.id, doc.data()!)];
    }
    final snap = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'municipality_coordinator').limit(200).get();
    final list = <ExcelCoordinatorOption>[];
    for (final doc in snap.docs) {
      if (doc.data()['isActive'] == false) continue;
      list.add(_coordinatorFromData(doc.id, doc.data()));
    }
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<List<ExcelGroupOption>> loadGroupsForCoordinator(String coordinatorId) async {
    if (coordinatorId.trim().isEmpty) return const [];
    // Read the group registry once and normalize legacy/current field names. Older
    // groups may have groupId/number/createdBy but no municipalityCoordinatorId.
    final snap = await FirebaseFirestore.instance
        .collection('operations')
        .limit(1500)
        .get();
    final coordinatorDoc = await FirebaseFirestore.instance.collection('users').doc(coordinatorId).get();
    final coordinator = coordinatorDoc.data() ?? const <String, dynamic>{};
    var coordinatorMunicipality = '${coordinator['municipalityName'] ?? coordinator['municipality'] ?? coordinator['municipalityScope'] ?? coordinator['scope'] ?? ''}'.trim().toLowerCase();
    if (coordinatorMunicipality == 'assigned_only' || coordinatorMunicipality == 'all' || coordinatorMunicipality == 'null') coordinatorMunicipality = '';
    final map = <String, ExcelGroupOption>{};
    for (final doc in snap.docs) {
      final x = doc.data();
      final entity = '${x['_entity'] ?? ''}';
      if (x['isDeleted'] == true || x['isActive'] == false || '${x['status'] ?? ''}'.toLowerCase() == 'deleted') continue;
      if (entity != 'group' && entity != 'worker') continue;
      final owner = '${x['municipalityCoordinatorId'] ?? x['coordinatorId'] ?? x['createdBy'] ?? ''}'.trim();
      final municipality = '${x['municipalityName'] ?? x['municipality'] ?? x['scope'] ?? ''}'.trim().toLowerCase();
      final ownedByCoordinator = owner == coordinatorId.trim();
      final belongsToMunicipality = coordinatorMunicipality.isNotEmpty && municipality.isNotEmpty && municipality == coordinatorMunicipality;
      if (!ownedByCoordinator && !belongsToMunicipality) continue;
      final number = entity == 'worker'
          ? '${x['groupId'] ?? x['groupNumber'] ?? x['group'] ?? ''}'.trim()
          : '${x['number'] ?? x['groupNumber'] ?? x['groupId'] ?? ''}'.trim();
      final name = entity == 'worker'
          ? '${x['groupName'] ?? x['groupLabel'] ?? number}'.trim()
          : '${x['name'] ?? x['groupName'] ?? x['title'] ?? number}'.trim();
      if (number.isEmpty && name.isEmpty) continue;
      final optionId = entity == 'group' ? doc.id : 'legacy:${number.isNotEmpty ? number : name}';
      final option = ExcelGroupOption(id: optionId, number: number, name: name, coordinatorId: coordinatorId);
      final key = (number.isNotEmpty ? number : name).toLowerCase();
      // Prefer the real group document when both a group record and worker records
      // reference the same group; otherwise keep a recoverable legacy option.
      if (!map.containsKey(key) || entity == 'group') map[key] = option;
    }
    final list = map.values.toList();
    list.sort((a, b) => a.number.compareTo(b.number));
    return list;
  }

  Future<PlatformFile?> pickWorkersFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv', 'xls'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return null;
    final file = picked.files.first;
    if (file.bytes == null || file.bytes!.isEmpty) {
      throw Exception('تعذر قراءة الملف «${file.name}»: الملف فارغ أو لم يتم تحميل محتواه.');
    }
    return file;
  }

  static String _stripBom(String value) => value.replaceFirst('\uFEFF', '');

  static List<String> _parseCsvLine(String line, String delimiter) {
    final cells = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (ch == delimiter && !quoted) {
        cells.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    if (quoted) {
      throw const FormatException('CSV يحتوي على اقتباس غير مغلق في أحد الحقول.');
    }
    cells.add(buffer.toString().trim());
    return cells;
  }

  static int _columnIndexFromCellReference(String reference) {
    final match = RegExp(r'^[A-Z]+', caseSensitive: false).firstMatch(reference);
    if (match == null) return 0;
    var result = 0;
    for (final code in match.group(0)!.toUpperCase().codeUnits) {
      result = result * 26 + code - 64;
    }
    return result - 1;
  }

  /// Defensive XLSX reader used when the `excel` package encounters malformed
  /// optional/shared cells and throws an internal null-check error. It reads the
  /// worksheet XML directly and treats absent cells as empty strings.
  static List<List<String>> _decodeXlsxDefensively(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final files = <String, ArchiveFile>{for (final f in archive.files) f.name: f};
    List<int>? content(String path) {
      final f = files[path];
      if (f == null || !f.isFile) return null;
      final data = f.content;
      if (data is List<int>) return data;
      return null;
    }
    final sheetBytes = content('xl/worksheets/sheet1.xml');
    if (sheetBytes == null) throw const FormatException('لم أجد ورقة Excel الأولى داخل الملف.');
    final sharedBytes = content('xl/sharedStrings.xml');
    final shared = <String>[];
    if (sharedBytes != null) {
      final sharedDoc = XmlDocument.parse(utf8.decode(sharedBytes, allowMalformed: true));
      for (final item in sharedDoc.findAllElements('si')) {
        shared.add(item.findAllElements('t').map((e) => e.innerText).join());
      }
    }
    final doc = XmlDocument.parse(utf8.decode(sheetBytes, allowMalformed: true));
    final rows = <List<String>>[];
    for (final rowElement in doc.findAllElements('row')) {
      final cells = <int, String>{};
      var maxColumn = -1;
      for (final cell in rowElement.findAllElements('c')) {
        final ref = cell.getAttribute('r') ?? '';
        final column = _columnIndexFromCellReference(ref);
        if (column < 0) continue;
        maxColumn = column > maxColumn ? column : maxColumn;
        final type = cell.getAttribute('t') ?? '';
        final value = cell.getElement('v')?.innerText ?? '';
        String text;
        if (type == 's') {
          final index = int.tryParse(value);
          text = index != null && index >= 0 && index < shared.length ? shared[index] : '';
        } else if (type == 'inlineStr') {
          text = cell.findAllElements('t').map((e) => e.innerText).join();
        } else if (type == 'b') {
          text = value == '1' ? 'TRUE' : 'FALSE';
        } else {
          text = value;
        }
        cells[column] = text.trim();
      }
      final row = List<String>.filled(maxColumn + 1, '');
      for (final entry in cells.entries) { row[entry.key] = entry.value; }
      rows.add(row);
    }
    if (rows.isEmpty) throw const FormatException('ورقة Excel فارغة.');
    return rows;
  }

  static List<List<String>> _decodeCsv(Uint8List bytes) {
    String text;
    try {
      text = utf8.decode(bytes, allowMalformed: false);
    } catch (e) {
      throw FormatException('تعذر فك ترميز CSV بصيغة UTF-8. تأكد أن الملف محفوظ بصيغة CSV UTF-8. التفاصيل: $e');
    }
    text = _stripBom(text).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = text.split('\n');
    while (lines.isNotEmpty && lines.last.trim().isEmpty) { lines.removeLast(); }
    if (lines.isEmpty || lines.every((line) => line.trim().isEmpty)) {
      throw const FormatException('ملف CSV فارغ ولا يحتوي على بيانات.');
    }
    final sample = lines.take(20).where((x) => x.trim().isNotEmpty).join('\n');
    final candidates = [',', ';', '\t'];
    String delimiter = ',';
    var best = -1;
    for (final candidate in candidates) {
      final count = sample.split(candidate).length - 1;
      if (count > best) { best = count; delimiter = candidate; }
    }
    final rows = <List<String>>[];
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;
      try {
        rows.add(_parseCsvLine(lines[i], delimiter));
      } catch (e) {
        throw FormatException('خطأ في CSV عند السطر ${i + 1}: $e');
      }
    }
    return rows;
  }

  Future<ExcelImportResult> parseWorkersBytes(
    Uint8List bytes, {
    required String municipality,
    required String group,
    String? coordinatorId,
    String? fileName,
  }) async {
    final cleanMunicipality = municipality.trim();
    final cleanGroup = group.trim();
    if (cleanMunicipality.isEmpty) throw Exception('لم يتم تحديد البلدية المرتبطة بمنسق البلدية.');
    if (cleanGroup.isEmpty) throw Exception('اختر رقم المجموعة قبل استيراد الملف.');

    final extension = (fileName ?? '').toLowerCase().split('.').last;
    final rows = <List<String>>[];
    if (extension == 'csv') {
      try {
        rows.addAll(_decodeCsv(bytes));
      } catch (e) {
        throw Exception('فشل استيراد CSV «${fileName ?? 'الملف'}»: $e');
      }
    } else {
      try {
        final book = Excel.decodeBytes(bytes);
        if (book.tables.isEmpty) throw const FormatException('الملف لا يحتوي على ورقة عمل قابلة للقراءة.');
        final sheet = book.tables.values.first;
        if (sheet.maxRows < 1) throw const FormatException('ورقة العمل فارغة.');
        for (var r = 0; r < sheet.maxRows; r++) {
          rows.add(sheet.row(r).map((cell) => _cleanCell(cell?.value)).toList());
        }
      } catch (primaryError) {
        try {
          rows.addAll(_decodeXlsxDefensively(bytes));
        } catch (fallbackError) {
          throw Exception('فشل قراءة Excel «${fileName ?? 'الملف'}»: تعذر تحليل بنية XLSX. جرّب حفظ الملف من جديد بصيغة Excel Workbook (.xlsx). التفاصيل: $primaryError؛ $fallbackError');
        }
      }
    }
    if (rows.isEmpty) throw Exception('فشل الاستيراد: الملف لا يحتوي على صفوف قابلة للقراءة.');

    var headerRow = -1;
    var bestScore = 0;
    for (var r = 0; r < rows.length && r < 50; r++) {
      final found = <String>{};
      var score = 0;
      for (final value in rows[r]) {
        final field = _canonicalField(value);
        if (field.isNotEmpty && found.add(field)) score++;
      }
      if (score > bestScore) { bestScore = score; headerRow = r; }
      if (score >= 4) break;
    }
    if (headerRow < 0 || bestScore < 2) {
      throw Exception('فشل الاستيراد: تعذر اكتشاف صف العناوين تلقائيًا. ضع عناوين مثل «الاسم»، «الوظيفة»، «رقم الهوية»، «الجوال» ثم أعد المحاولة.');
    }

    final rawHeaders = rows[headerRow];
    final indexes = <String, int>{};
    final detected = <String, String>{};
    for (var i = 0; i < rawHeaders.length; i++) {
      final raw = _cleanCell(rawHeaders[i]);
      final field = _canonicalField(raw);
      if (field.isNotEmpty && !indexes.containsKey(field)) {
        indexes[field] = i;
        detected[field] = raw;
      }
    }

    const coreRequired = ['name', 'job', 'id', 'phone'];
    final missing = coreRequired.where((f) => !indexes.containsKey(f)).toList();
    if (missing.isNotEmpty) {
      final labels = {'name': 'الاسم', 'job': 'المسمى الوظيفي', 'id': 'رقم الهوية', 'phone': 'رقم الجوال'};
      throw Exception('لم أجد أعمدة: ${missing.map((x) => labels[x]).join('، ')}. ترتيب الأعمدة لا يهم، ويمكن أن تكون في أي مكان داخل الملف.');
    }

    String cell(List<String> row, String field) {
      final index = indexes[field];
      if (index == null || index < 0 || index >= row.length) return '';
      return _cleanCell(row[index]);
    }

    final seenIds = <String>{};
    final valid = <Map<String, String>>[];
    final errors = <String>[];
    var duplicates = 0;

    for (var r = headerRow + 1; r < rows.length; r++) {
      final row = rows[r];
      final name = cell(row, 'name');
      final job = cell(row, 'job');
      final id = cell(row, 'id').replaceAll(RegExp(r'\D'), '');
      final phone = cell(row, 'phone');
      if ([name, job, id, phone].every((v) => v.isEmpty)) continue;

      final rowErrors = <String>[];
      if (name.isEmpty) rowErrors.add('الاسم مفقود');
      if (job.isEmpty) rowErrors.add('المسمى الوظيفي مفقود');
      if (!RegExp(r'^\d{9}$').hasMatch(id)) rowErrors.add('رقم الهوية يجب أن يتكون من 9 أرقام');
      if (phone.isEmpty) rowErrors.add('رقم الجوال مفقود');
      if (id.isNotEmpty && RegExp(r'^\d{9}$').hasMatch(id) && !seenIds.add(id)) {
        duplicates++;
        rowErrors.add('رقم الهوية مكرر في الملف');
      }
      if (rowErrors.isNotEmpty) {
        errors.add('الصف ${r + 1}: ${rowErrors.join('، ')}');
        continue;
      }
      valid.add({
        'name': name,
        'job': job,
        'id': id,
        'phone': phone,
        'municipality': cleanMunicipality,
        'group': cleanGroup,
        'municipalityCoordinatorId': coordinatorId?.trim() ?? '',
      });
    }
    return ExcelImportResult(validRows: valid, errors: errors, duplicateCount: duplicates, detectedHeaderRow: headerRow + 1, detectedColumns: detected);
  }

  Future<ExcelImportResult> importWorkers({
    required String municipality,
    required String group,
    String? coordinatorId,
  }) async {
    final file = await pickWorkersFile();
    if (file == null) return const ExcelImportResult(validRows: [], errors: [], duplicateCount: 0);
    return parseWorkersBytes(file.bytes!, municipality: municipality, group: group, coordinatorId: coordinatorId, fileName: file.name);
  }

  Future<String?> exportWorkers(List<Map<String, String>> workers) async {
    final book = Excel.createExcel();
    final sheet = book['Workers'];
    const headers = ['الاسم الرباعي', 'المسمى الوظيفي', 'رقم الهوية', 'رقم الجوال', 'اسم البلدية', 'رقم المجموعة'];
    sheet.appendRow(headers.map(TextCellValue.new).toList());
    for (final w in workers) {
      sheet.appendRow([
        TextCellValue(w['name'] ?? ''), TextCellValue(w['job'] ?? ''), TextCellValue(w['id'] ?? ''),
        TextCellValue(w['phone'] ?? ''), TextCellValue(w['municipality'] ?? ''), TextCellValue(w['group'] ?? ''),
      ]);
    }
    final bytes = book.encode();
    if (bytes == null || bytes.isEmpty) return null;
    return saveExcelBytes(Uint8List.fromList(bytes), 'workers_${DateTime.now().millisecondsSinceEpoch}.xlsx');
  }
}


/// Backward/semantic alias for callers that refer to this module as ExcelImportService.
typedef ExcelImportService = ExcelService;
