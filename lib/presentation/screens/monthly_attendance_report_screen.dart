import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../core/services/auth_service.dart';
import '../../core/localization.dart';
import '../../core/services/data_service.dart';
import '../../core/services/pdf_file_saver.dart';
import '../widgets/app_design.dart';

/// Calendar-style attendance matrix. Rows are people; columns are calendar days.
/// It uses real attendance operations already stored in the offline-first cache.
class MonthlyAttendanceReportScreen extends StatefulWidget {
  const MonthlyAttendanceReportScreen({super.key});
  @override
  State<MonthlyAttendanceReportScreen> createState() => _MonthlyAttendanceReportScreenState();
}

class _MonthlyAttendanceReportScreenState extends State<MonthlyAttendanceReportScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String exportLanguage = 'ar';
  bool exporting = false;
  List<Map<String, dynamic>> roster = [];

  @override
  void initState() { super.initState(); _loadRoster(); }
  Future<void> _loadRoster() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null || Firebase.apps.isEmpty) return;
    try {
      final collected = <Map<String, dynamic>>[];
      for (final role in ['worker', 'group_supervisor']) {
        Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('users').where('role', isEqualTo: role).limit(1500);
        if (user.role == 'municipality_coordinator') query = query.where('municipalityCoordinatorId', isEqualTo: user.id);
        else if (user.role != 'donor_manager' && user.role != 'jsc_coordinator') continue;
        final snap = await query.get();
        for (final d in snap.docs) { final x = d.data(); if (x['isActive'] == false) continue; collected.add({'id': d.id, ...x, 'workerRole': role}); }
      }
      if (mounted) setState(() => roster = collected);
    } catch (_) { /* Cached attendance remains available when roster access is offline. */ }
  }

  @override
  Widget build(BuildContext context) {
    final arabic = context.watch<LocaleController>().isArabic;
    final data = context.watch<DataService>();
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final first = DateTime(month.year, month.month, 1);
    final records = data.operations.where((e) {
      if (e['_entity'] != 'attendance' || e['isDeleted'] == true) return false;
      final raw = e['createdAt'] ?? e['date'] ?? e['timestamp'];
      final date = raw is DateTime ? raw : DateTime.tryParse('$raw');
      return date != null && date.year == month.year && date.month == month.month;
    }).toList();

    final names = <String>{};
    final statusByPersonDay = <String, String>{};
    final displayNameById = <String, String>{};
    for (final person in roster) {
      final id = '${person['id'] ?? ''}';
      final rawName = '${person['name'] ?? person['username'] ?? id}';
      final role = '${person['workerRole'] ?? person['role'] ?? ''}';
      final name = _displayName(rawName, role);
      names.add(name);
      if (id.isNotEmpty) displayNameById[id] = name;
    }
    for (final r in records) {
      final id = '${r['workerId'] ?? ''}';
      final rawName = '${r['workerName'] ?? r['name'] ?? r['workerId'] ?? 'غير محدد'}';
      final role = '${r['workerRole'] ?? ''}';
      final name = displayNameById[id] ?? _displayName(rawName, role);
      final raw = r['createdAt'] ?? r['date'] ?? r['timestamp'];
      final date = raw is DateTime ? raw : DateTime.tryParse('$raw');
      if (date == null) continue;
      names.add(name);
      statusByPersonDay['$name|${date.day}'] = '${r['status'] ?? ''}';
    }
    final sortedNames = names.toList()..sort();
    final headerBg = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Directionality(
      textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: const AppText('التقرير الشهري للحضور')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              IconButton(tooltip: 'الشهر السابق', onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left)),
              Expanded(child: Center(child: Text(_monthLabel(arabic), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)))),
              IconButton(tooltip: 'الشهر التالي', onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right)),
            ]),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
            _legend('حضور', Colors.green), const SizedBox(width: 12), _legend('غياب', Colors.red), const SizedBox(width: 12), _legend('لا يوجد تسجيل', Colors.grey),
          ])),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
            const Text('لغة التقرير:'), const SizedBox(width: 8),
            DropdownButton<String>(value: exportLanguage, items: const [DropdownMenuItem(value: 'ar', child: Text('العربية')), DropdownMenuItem(value: 'en', child: Text('English'))], onChanged: exporting ? null : (v) { if (v != null) setState(() => exportLanguage = v); }),
            const Spacer(),
            IconButton(tooltip: 'معاينة وطباعة PDF', onPressed: exporting || records.isEmpty ? null : () => _previewPdf(sortedNames, statusByPersonDay, daysInMonth), icon: const Icon(Icons.preview_outlined)),
            IconButton(tooltip: 'تصدير PDF', onPressed: exporting || records.isEmpty ? null : () => _exportPdf(sortedNames, statusByPersonDay, daysInMonth), icon: const Icon(Icons.picture_as_pdf_outlined)),
          ])),
          const SizedBox(height: 8),
          Expanded(child: records.isEmpty
              ? const Center(child: AppText('لا توجد سجلات حضور فعلية لهذا الشهر في البيانات المتاحة.'))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStatePropertyAll(headerBg),
                      columnSpacing: 8,
                      horizontalMargin: 8,
                      columns: [
                        const DataColumn(label: SizedBox(width: 150, child: Text('العامل / المشرف'))),
                        for (var day = 1; day <= daysInMonth; day++)
                          DataColumn(label: SizedBox(width: 42, child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(_weekday(DateTime(month.year, month.month, day), arabic), style: const TextStyle(fontSize: 9)),
                            Text('$day', style: const TextStyle(fontWeight: FontWeight.w800)),
                          ]))),
                      ],
                      rows: [
                        for (final name in sortedNames)
                          DataRow(cells: [
                            DataCell(SizedBox(width: 150, child: Text(name, overflow: TextOverflow.ellipsis))),
                            for (var day = 1; day <= daysInMonth; day++)
                              DataCell(Container(
                                width: 32, height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _statusColor(statusByPersonDay['$name|$day']).withOpacity(.14),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(_statusMark(statusByPersonDay['$name|$day']), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _statusColor(statusByPersonDay['$name|$day']))),
                              )),
                          ]),
                      ],
                    ),
                  ),
                )),
          Padding(padding: const EdgeInsets.all(8), child: Text('عدد السجلات: ${records.length} — ${first.year}-${first.month.toString().padLeft(2, '0')}-${first.day.toString().padLeft(2, '0')}', style: Theme.of(context).textTheme.bodySmall)),
        ]),
      ),
    );
  }

  Future<Uint8List> _pdfBytes(List<String> names, Map<String, String> statuses, int daysInMonth) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'));
    final english = exportLanguage == 'en';
    final projectLabel = english ? 'Project / cycle' : 'المشروع / الدورة';
    final headers = <pw.Widget>[
      pw.Container(width: 90, padding: const pw.EdgeInsets.all(3), child: pw.Text(english ? 'Worker / Supervisor' : 'العامل / المشرف', style: pw.TextStyle(font: bold, fontSize: 6))),
      for (var d = 1; d <= daysInMonth; d++) pw.Container(width: 22, padding: const pw.EdgeInsets.all(1), child: pw.Column(children: [pw.Text(_weekday(DateTime(month.year, month.month, d), !english), style: pw.TextStyle(font: regular, fontSize: 5)), pw.Text('$d', style: pw.TextStyle(font: bold, fontSize: 6))])),
    ];
    final rows = <pw.TableRow>[pw.TableRow(children: headers), for (final name in names) pw.TableRow(children: [
      pw.Container(width: 90, padding: const pw.EdgeInsets.all(3), child: pw.Text(name, style: pw.TextStyle(font: regular, fontSize: 6))),
      for (var d = 1; d <= daysInMonth; d++) pw.Container(width: 22, padding: const pw.EdgeInsets.all(2), alignment: pw.Alignment.center, child: pw.Text(_pdfMark(statuses['$name|$d'], english), style: pw.TextStyle(font: bold, fontSize: 6, color: _pdfColor(statuses['$name|$d'])))),
    ])];
    final prefs = await SharedPreferences.getInstance();
    pw.ImageProvider? logo(String key) { final raw = prefs.getString(key); if (raw == null || raw.isEmpty) return null; try { return pw.MemoryImage(base64Decode(raw)); } catch (_) { return null; } }
    final municipalityLogo = logo('report_municipality_logo_base64');
    final councilLogo = logo('report_council_logo_base64');
    final unicefLogo = logo('report_unicef_logo_base64');
    final municipalityName = prefs.getString('report_municipality_name') ?? '';
    final councilName = prefs.getString('report_council_name') ?? '';
    final projectName = prefs.getString('report_project_name') ?? '';
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a3.landscape, margin: const pw.EdgeInsets.all(22), theme: pw.ThemeData.withFont(base: regular, bold: bold), build: (_) => [
      pw.Row(children: [if (municipalityLogo != null) pw.Container(width: 32,height:32,child:pw.Image(municipalityLogo)), if (councilLogo != null) pw.Padding(padding: const pw.EdgeInsets.only(left:3),child:pw.Container(width:32,height:32,child:pw.Image(councilLogo))), if (unicefLogo != null) pw.Padding(padding: const pw.EdgeInsets.only(left:3),child:pw.Container(width:32,height:32,child:pw.Image(unicefLogo))), pw.SizedBox(width:8), pw.Expanded(child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[if(municipalityName.isNotEmpty) pw.Text(municipalityName,style:pw.TextStyle(font:bold,fontSize:9)),if(councilName.isNotEmpty) pw.Text(councilName,style:pw.TextStyle(font:bold,fontSize:9)),if(projectName.isNotEmpty) pw.Text('$projectLabel: $projectName',style:pw.TextStyle(font:regular,fontSize:7)),pw.Text(english ? 'UNICEF' : 'اليونيسف (UNICEF)',style:pw.TextStyle(font:bold,fontSize:8))]))]),
      pw.SizedBox(height: 6),
      pw.Text(english ? 'Monthly Attendance Calendar' : 'التقرير الشهري التقويمي للحضور', style: pw.TextStyle(font: bold, fontSize: 14)),
      pw.SizedBox(height: 4),
      pw.Text(_monthLabel(!english), style: pw.TextStyle(font: regular, fontSize: 9)),
      pw.SizedBox(height: 10),
      pw.Directionality(textDirection: english ? pw.TextDirection.ltr : pw.TextDirection.rtl, child: pw.Table(border: pw.TableBorder.all(color: PdfColors.grey400, width: .35), columnWidths: {0: const pw.FixedColumnWidth(90), for (var d=1; d<=daysInMonth; d++) d: const pw.FixedColumnWidth(22)}, children: rows)),
      pw.SizedBox(height: 8), pw.Text(english ? 'Present: ✓   Absent: ×   Excused: E   Unexcused: U   No entry: —' : 'حضور: ✓   غياب: ×   بعذر: م   دون عذر: غ   لا يوجد تسجيل: —', style: pw.TextStyle(font: regular, fontSize: 7)),
    ]));
    return Uint8List.fromList(await doc.save());
  }
  Future<void> _previewPdf(List<String> names, Map<String, String> statuses, int days) async {
    setState(() => exporting = true);
    try { final bytes = await _pdfBytes(names, statuses, days); if (!mounted) return; await Printing.layoutPdf(onLayout: (_) async => bytes); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('تعذرت معاينة التقرير: $e'))); }
    finally { if (mounted) setState(() => exporting = false); }
  }
  Future<void> _exportPdf(List<String> names, Map<String, String> statuses, int days) async {
    setState(() => exporting = true);
    try { final bytes = await _pdfBytes(names, statuses, days); final path = await savePdfBytes(bytes, 'monthly_attendance_${month.year}_${month.month.toString().padLeft(2,'0')}_$exportLanguage.pdf'); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText(path == null ? 'تعذر حفظ PDF' : 'تم إنشاء PDF: $path'))); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('تعذر تصدير التقرير: $e'))); }
    finally { if (mounted) setState(() => exporting = false); }
  }
  String _displayName(String name, String role) => role == 'group_supervisor' ? '$name (مشرف)' : role == 'worker' ? '$name (عامل)' : name;
  String _monthLabel(bool arabic) {
    const ar = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    const en = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    return '${(arabic ? ar : en)[month.month - 1]} ${month.year}';
  }
  String _weekday(DateTime date, bool arabic) {
    const ar = ['الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'];
    const en = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return (arabic ? ar : en)[date.weekday - 1];
  }
  String _pdfMark(String? s, bool english) { if (s == 'present' || s == 'حضور') return '✓'; if (s == 'absent' || s == 'غياب') return '×'; if (s == 'excused_absence') return english ? 'E' : 'م'; if (s == 'unexcused_absence') return english ? 'U' : 'غ'; return '—'; }
  PdfColor _pdfColor(String? s) { if (s == 'present' || s == 'حضور') return PdfColors.green700; if (s == 'absent' || s == 'غياب' || s == 'excused_absence' || s == 'unexcused_absence') return PdfColors.red700; return PdfColors.grey600; }

  Widget _legend(String text, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 4), Text(text, style: const TextStyle(fontSize: 11))]);
  Color _statusColor(String? s) {
    if (s == 'present' || s == 'حضور') return Colors.green;
    if (s == 'absent' || s == 'غياب' || s == 'excused_absence' || s == 'unexcused_absence') return Colors.red;
    return Colors.grey;
  }
  String _statusMark(String? s) {
    if (s == 'present' || s == 'حضور') return '✓';
    if (s == 'absent' || s == 'غياب') return '×';
    if (s == 'excused_absence') return 'م';
    if (s == 'unexcused_absence') return 'غ';
    return '—';
  }
}
