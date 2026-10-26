import 'dart:ui' show TextDirection;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization.dart';
import '../../core/services/data_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/pdf_file_saver.dart';
import '../widgets/app_design.dart';
import 'monthly_attendance_report_screen.dart';

class AttendanceReportsHomeScreen extends StatefulWidget {
  const AttendanceReportsHomeScreen({super.key});
  @override
  State<AttendanceReportsHomeScreen> createState() => _AttendanceReportsHomeScreenState();
}

class _AttendanceReportsHomeScreenState extends State<AttendanceReportsHomeScreen> {
  DateTime selectedDate = DateTime.now();
  String exportLanguage = 'ar';
  bool showGroups = false;
  bool busy = false;
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
    } catch (_) { /* Keep offline attendance records usable if roster access is unavailable. */ }
  }

  @override
  Widget build(BuildContext context) {
    final arabic = context.watch<LocaleController>().isArabic;
    final operations = context.watch<DataService>().operations;
    final records = operations.where((e) {
      if (e['_entity'] != 'attendance' || e['isDeleted'] == true) return false;
      final raw = e['createdAt'] ?? e['date'] ?? e['timestamp'];
      final date = raw is DateTime ? raw : DateTime.tryParse('$raw');
      return date != null && date.year == selectedDate.year && date.month == selectedDate.month && date.day == selectedDate.day;
    }).toList();
    final recordedIds = records.map((e) => '${e['workerId'] ?? ''}').where((id) => id.isNotEmpty).toSet();
    for (final person in roster) {
      final id = '${person['id'] ?? ''}';
      if (id.isEmpty || recordedIds.contains(id)) continue;
      records.add({'workerId': id, 'workerName': person['name'] ?? person['username'] ?? id, 'workerRole': person['workerRole'] ?? person['role'] ?? 'worker', 'groupId': person['groupId'] ?? '', 'groupName': person['groupName'] ?? person['groupId'] ?? '', 'status': 'no_entry', 'ppeComplete': false, 'createdAt': selectedDate.toIso8601String(), 'isRosterOnly': true});
    }
    records.sort((a,b) => '${a['workerName'] ?? ''}'.compareTo('${b['workerName'] ?? ''}'));
    final present = records.where((e) => e['status'] == 'present' || e['status'] == 'حضور').length;
    final absent = records.where((e) => ['absent','غياب','excused_absence','unexcused_absence'].contains(e['status'])).length;
    return Directionality(textDirection: arabic ? TextDirection.rtl : TextDirection.ltr, child: Scaffold(
      appBar: AppBar(title: const AppText('تقارير الحضور'), actions: [IconButton(tooltip: 'التقرير الشهري التقويمي', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MonthlyAttendanceReportScreen())), icon: const Icon(Icons.calendar_month))]),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AppText('التقرير اليومي للبلدية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Row(children: [Expanded(child: Text(DateFormat('yyyy-MM-dd').format(selectedDate))), TextButton.icon(onPressed: () async { final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (d != null && mounted) setState(() => selectedDate = d); }, icon: const Icon(Icons.calendar_today), label: const AppText('اختيار التاريخ'))]),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const AppText('إظهار أسماء المجموعات'), value: showGroups, onChanged: (v) => setState(() => showGroups = v)),
          Row(children: [const Text('لغة التصدير:'), const SizedBox(width: 8), DropdownButton<String>(value: exportLanguage, items: const [DropdownMenuItem(value: 'ar', child: Text('العربية')), DropdownMenuItem(value: 'en', child: Text('English'))], onChanged: (v) { if (v != null) setState(() => exportLanguage = v); }), const Spacer(), IconButton(tooltip: 'معاينة وطباعة', onPressed: busy || records.isEmpty ? null : () => _preview(records), icon: const Icon(Icons.preview_outlined)), IconButton(tooltip: 'تصدير PDF', onPressed: busy || records.isEmpty ? null : () => _export(records), icon: const Icon(Icons.picture_as_pdf_outlined))]),
        ]))),
        Wrap(spacing: 8, runSpacing: 8, children: [_kpi('السجلات', records.length), _kpi('الحضور', present), _kpi('الغياب', absent)]),
        const SizedBox(height: 12),
        if (records.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(18), child: AppText('لا توجد سجلات حضور فعلية لهذا التاريخ في البيانات المتاحة. لا يتم إنشاء أسماء أو حالات افتراضية.')))
        else Card(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: [if (showGroups) const DataColumn(label: Text('المجموعة')), const DataColumn(label: Text('العامل / المشرف')), const DataColumn(label: Text('الصفة')), const DataColumn(label: Text('الحالة')), const DataColumn(label: Text('معدات الوقاية'))], rows: [for (final r in records) DataRow(cells: [if (showGroups) DataCell(Text('${r['groupName'] ?? r['groupId'] ?? '—'}')), DataCell(Text('${r['workerName'] ?? r['workerId'] ?? 'غير محدد'}')), DataCell(Text(_role('${r['workerRole'] ?? 'worker'}'))), DataCell(Text(_status('${r['status'] ?? ''}'))), DataCell(Text(r['ppeComplete'] == true ? 'مكتملة' : '—'))])]))),
      ]),
    ));
  }

  Future<Uint8List> _pdfBytes(List<Map<String, dynamic>> records) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'));
    final en = exportLanguage == 'en';
    final projectLabel = en ? 'Project / cycle' : 'المشروع / الدورة';
    final rows = <pw.TableRow>[
      pw.TableRow(children: [if (showGroups) _cell(en ? 'Group' : 'المجموعة', bold), _cell(en ? 'Worker / Supervisor' : 'العامل / المشرف', bold), _cell(en ? 'Role' : 'الصفة', bold), _cell(en ? 'Status' : 'الحالة', bold), _cell(en ? 'PPE' : 'معدات الوقاية', bold)]),
      for (final r in records) pw.TableRow(children: [if (showGroups) _cell('${r['groupName'] ?? r['groupId'] ?? '—'}', regular), _cell('${r['workerName'] ?? r['workerId'] ?? '—'}', regular), _cell(_role('${r['workerRole'] ?? 'worker'}', en: en), regular), _cell(_status('${r['status'] ?? ''}', en: en), regular), _cell(r['ppeComplete'] == true ? (en ? 'Complete' : 'مكتملة') : '—', regular)]),
    ];
    final prefs = await SharedPreferences.getInstance();
    pw.ImageProvider? logo(String key) { final raw = prefs.getString(key); if (raw == null || raw.isEmpty) return null; try { return pw.MemoryImage(base64Decode(raw)); } catch (_) { return null; } }
    final municipalityLogo = logo('report_municipality_logo_base64');
    final councilLogo = logo('report_council_logo_base64');
    final unicefLogo = logo('report_unicef_logo_base64');
    final municipalityName = prefs.getString('report_municipality_name') ?? '';
    final councilName = prefs.getString('report_council_name') ?? '';
    final projectName = prefs.getString('report_project_name') ?? '';
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4.landscape, margin: const pw.EdgeInsets.all(28), theme: pw.ThemeData.withFont(base: regular, bold: bold), build: (_) => [
      pw.Row(children: [if (municipalityLogo != null) pw.Container(width: 36,height:36,child:pw.Image(municipalityLogo)), if (councilLogo != null) pw.Padding(padding: const pw.EdgeInsets.only(left:4),child:pw.Container(width:36,height:36,child:pw.Image(councilLogo))), if (unicefLogo != null) pw.Padding(padding: const pw.EdgeInsets.only(left:4),child:pw.Container(width:36,height:36,child:pw.Image(unicefLogo))), pw.SizedBox(width:8), pw.Expanded(child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[if(municipalityName.isNotEmpty) pw.Text(municipalityName,style:pw.TextStyle(font:bold,fontSize:10)),if(councilName.isNotEmpty) pw.Text(councilName,style:pw.TextStyle(font:bold,fontSize:10)),if(projectName.isNotEmpty) pw.Text('$projectLabel: $projectName',style:pw.TextStyle(font:regular,fontSize:8)),pw.Text(en ? 'UNICEF' : 'اليونيسف (UNICEF)',style:pw.TextStyle(font:bold,fontSize:9))]))]),
      pw.SizedBox(height: 8),
      pw.Text(en ? 'Municipality Daily Attendance Report' : 'تقرير الحضور اليومي للبلدية', style: pw.TextStyle(font: bold, fontSize: 16)),
      pw.SizedBox(height: 5), pw.Text('${en ? 'Date' : 'التاريخ'}: ${DateFormat('yyyy-MM-dd').format(selectedDate)}', style: pw.TextStyle(font: regular, fontSize: 9)),
      pw.SizedBox(height: 12),
      pw.Directionality(textDirection: en ? pw.TextDirection.ltr : pw.TextDirection.rtl, child: pw.Table(border: pw.TableBorder.all(color: PdfColors.grey400, width: .5), columnWidths: {for (var i = 0; i < (showGroups ? 5 : 4); i++) i: const pw.FlexColumnWidth()}, children: rows)),
      pw.SizedBox(height: 8), pw.Text('${en ? 'Records' : 'عدد السجلات'}: ${records.length} • ${en ? 'Present' : 'حضور'}: ${records.where((e) => e['status'] == 'present' || e['status'] == 'حضور').length} • ${en ? 'Absent' : 'غياب'}: ${records.where((e) => ['absent','غياب','excused_absence','unexcused_absence'].contains(e['status'])).length}', style: pw.TextStyle(font: regular, fontSize: 8)),
    ]));
    return Uint8List.fromList(await doc.save());
  }
  pw.Widget _cell(String text, pw.Font font) => pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 8)));
  Future<void> _preview(List<Map<String, dynamic>> rows) async { setState(() => busy = true); try { final bytes = await _pdfBytes(rows); if (mounted) await Printing.layoutPdf(onLayout: (_) async => bytes); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('تعذرت المعاينة: $e'))); } finally { if (mounted) setState(() => busy = false); } }
  Future<void> _export(List<Map<String, dynamic>> rows) async { setState(() => busy = true); try { final bytes = await _pdfBytes(rows); final path = await savePdfBytes(bytes, 'daily_attendance_${DateFormat('yyyyMMdd').format(selectedDate)}_$exportLanguage.pdf'); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText(path == null ? 'تعذر حفظ PDF' : 'تم إنشاء PDF: $path'))); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('تعذر التصدير: $e'))); } finally { if (mounted) setState(() => busy = false); } }
  Widget _kpi(String label, int value) => SizedBox(width: 105, child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [Text(label), Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))]))));
  String _role(String value, {bool en = false}) => switch (value) {'group_supervisor' => en ? 'Supervisor' : 'مشرف', 'worker_with_cart' => en ? 'Worker with cart' : 'عامل بكارة', 'worker' => en ? 'Worker' : 'عامل', _ => value};
  String _status(String value, {bool en = false}) {
    if (value == 'no_entry') return en ? 'No entry' : 'لم يسجل';
    if (value == 'present' || value == 'حضور') return en ? 'Present' : 'حضور';
    if (value == 'absent' || value == 'غياب') return en ? 'Absent' : 'غياب';
    if (value == 'excused_absence') return en ? 'Excused' : 'غياب بعذر';
    if (value == 'unexcused_absence') return en ? 'Unexcused' : 'غياب دون عذر';
    if (value.isEmpty) return en ? 'No entry' : 'لا يوجد تسجيل';
    return value;
  }
}
