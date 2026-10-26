import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/excel_service.dart';
import '../../core/models/core_models.dart';
import 'app_design.dart';
import '../../core/localization.dart';
import '../../core/constants/app_constants.dart';

class SmartExcelImportCard extends StatefulWidget {
  final Future<void> Function(List<Map<String, String>> rows) onImport;
  final String title;
  const SmartExcelImportCard({super.key, required this.onImport, this.title = 'استيراد العمال الذكي'});

  @override
  State<SmartExcelImportCard> createState() => _SmartExcelImportCardState();
}

class _SmartExcelImportCardState extends State<SmartExcelImportCard> {
  final service = ExcelService();
  List<ExcelCoordinatorOption> coordinators = const [];
  List<ExcelGroupOption> groups = const [];
  ExcelCoordinatorOption? selectedCoordinator;
  ExcelGroupOption? selectedGroup;
  Uint8List? bytes;
  String fileName = '';
  ExcelImportResult? result;
  String message = '';
  bool loading = false;
  bool loadingGroups = false;
  bool importing = false;

  @override
  void initState() {
    super.initState();
    _loadCoordinators();
  }

  Future<void> _loadCoordinators() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;
    try {
      final list = await service.loadMunicipalityCoordinators(actorId: user.id, actorRole: user.role);
      if (!mounted) return;
      setState(() {
        coordinators = list;
        selectedCoordinator = list.length == 1 ? list.first : null;
      });
      if (selectedCoordinator != null) await _loadGroups(selectedCoordinator!.id);
    } catch (e) {
      if (mounted) setState(() => message = 'تعذر تحميل منسقي البلديات: $e');
    }
  }

  Future<void> _loadGroups(String coordinatorId) async {
    if (coordinatorId.trim().isEmpty) return;
    setState(() {
      loadingGroups = true;
      groups = const [];
      selectedGroup = null;
    });
    try {
      final list = await service.loadGroupsForCoordinator(coordinatorId);
      if (!mounted) return;
      setState(() {
        groups = list;
        selectedGroup = list.length == 1 ? list.first : null;
      });
    } catch (e) {
      if (mounted) setState(() => message = 'تعذر تحميل مجموعات المنسق: $e');
    } finally {
      if (mounted) setState(() => loadingGroups = false);
    }
  }

  String _errorText(Object error) {
    final raw = error.toString();
    // Keep technical serialization details out of the main Arabic error message;
    // the original error is still logged for diagnosis.
    if (raw.contains('encodable object failed') || raw.contains("Instance of 'Timestamp'")) {
      return 'تعذر تجهيز بعض قيم التاريخ أو الوقت للاستيراد. تمت إضافة معالجة للتواريخ، حدّث النسخة وأعد المحاولة. إذا استمر الخطأ فأرسل تقرير الاستيراد للمراجعة.';
    }
    if (raw.startsWith('Exception: ')) return raw.substring('Exception: '.length);
    if (raw.startsWith('FormatException: ')) return raw.substring('FormatException: '.length);
    return raw;
  }

  void _showImportError(Object error, {String? fileName}) {
    debugPrint('Smart Excel import failed: $error');
    final details = _errorText(error);
    final prefix = fileName == null || fileName.trim().isEmpty ? 'فشل استيراد الملف' : 'فشل استيراد «$fileName»';
    final text = '$prefix: $details';
    if (!mounted) return;
    setState(() => message = text);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text, textDirection: Directionality.of(context)),
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(label: 'إغلاق', onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar()),
        ),
      );
  }

  Future<void> _pickFile() async {
    setState(() {
      loading = true;
      message = '';
      result = null;
    });
    try {
      final file = await service.pickWorkersFile();
      if (file == null) return;
      if (!mounted) return;
      setState(() {
        bytes = file.bytes;
        fileName = file.name;
        message = 'تم اختيار الملف. راجع المنسق والمجموعة ثم اضغط «فحص واستيراد».';
      });
    } catch (e) {
      _showImportError(e, fileName: fileName.isEmpty ? null : fileName);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _parseAndImport() async {
    final data = bytes;
    final coordinator = selectedCoordinator;
    final group = selectedGroup;
    if (data == null) {
      setState(() => message = 'اختر ملف Excel أو CSV أولًا.');
      return;
    }
    if (coordinator == null) {
      setState(() => message = 'اختر منسق البلدية أولًا.');
      return;
    }
    if (coordinator.municipality.trim().isEmpty) {
      setState(() => message = 'هذا المنسق لا يحتوي على اسم بلدية مرتبط به. يجب تعريف «اسم البلدية» في حساب المنسق مرة واحدة.');
      return;
    }
    if (group == null) {
      setState(() => message = 'اختر رقم المجموعة. المجموعات المعروضة تخص منسق البلدية المختار فقط.');
      return;
    }

    setState(() {
      importing = true;
      message = 'جارٍ اكتشاف الأعمدة والصفوف وفحص البيانات...';
    });
    try {
      final parsed = await service.parseWorkersBytes(
        data,
        municipality: coordinator.municipality,
        group: group.number.isNotEmpty ? group.number : group.id,
        coordinatorId: coordinator.id,
        fileName: fileName,
      );
      if (!mounted) return;
      setState(() {
        result = parsed;
        message = 'تم اكتشاف صف العناوين ${parsed.detectedHeaderRow} تلقائيًا، والتقطيع حسب أسماء الأعمدة وليس ترتيبها. البلدية: ${coordinator.municipality} • المجموعة: ${group.label}.';
      });
      if (parsed.validRows.isNotEmpty) {
        await widget.onImport(parsed.validRows);
        if (mounted) setState(() => message = '${message}\nتم إرسال ${parsed.validRows.length} سجل صالح إلى طابور المزامنة.');
      }
    } catch (e) {
      _showImportError(e, fileName: fileName);
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final canSelectCoordinator = user?.role != 'municipality_coordinator';
    final r = result;
    return AiSectionCard(
      title: widget.title,
      subtitle: 'استيراد Excel/CSV ذكي: ترتيب الأعمدة والصفوف لا يهم، والبلدية والمجموعة تُحددان من منسق البلدية.',
      feature: 'excel',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: loading || importing ? null : _pickFile,
            icon: const Icon(Icons.upload_file_rounded),
            label: AppText(loading ? 'جارٍ اختيار الملف...' : (fileName.isEmpty ? 'اختيار ملف Excel أو CSV' : 'تغيير ملف Excel أو CSV')),
          ),
          if (fileName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: aiCyan.withOpacity(.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: cleanOpsBorder)),
              child: Row(children: [const Icon(Icons.description_outlined, color: aiCyan), const SizedBox(width: 8), Expanded(child: AppText(fileName, maxLines: 1, overflow: TextOverflow.ellipsis))]),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedCoordinator?.id,
            items: coordinators.map((c) => DropdownMenuItem(value: c.id, child: AppText('${c.name}${c.municipality.isNotEmpty ? ' • ${c.municipality}' : ''}'))).toList(),
            onChanged: !canSelectCoordinator || importing ? null : (v) async {
              final matches = coordinators.where((x) => x.id == v).toList();
      final c = matches.isEmpty ? null : matches.first;
              if (c == null) return;
              setState(() => selectedCoordinator = c);
              await _loadGroups(c.id);
            },
            decoration: InputDecoration(labelText: tr('منسق البلدية')),
          ),
          const SizedBox(height: 10),
          InputDecorator(
            decoration: InputDecoration(labelText: tr('البلدية المرتبطة تلقائيًا')),
            child: Row(children: [const Icon(Icons.location_city_outlined, color: aiGreen), const SizedBox(width: 8), Expanded(child: AppText(selectedCoordinator?.municipality.isNotEmpty == true ? selectedCoordinator!.municipality : 'غير معرفة'))]),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedGroup?.id,
            items: groups.map((g) => DropdownMenuItem(value: g.id, child: AppText(g.label))).toList(),
            onChanged: importing || loadingGroups ? null : (v) => setState(() { final matches = groups.where((x) => x.id == v).toList(); selectedGroup = matches.isEmpty ? null : matches.first; }),
            decoration: InputDecoration(labelText: loadingGroups ? tr('جارٍ تحميل مجموعات المنسق...') : tr('رقم المجموعة — باسم المنسق المختار')),
          ),
          const SizedBox(height: 10),
          const AppText('لن نأخذ اسم البلدية أو رقم المجموعة من Excel؛ سيتم وضعهما تلقائيًا من الحساب والمجموعة المختارة، حتى لو كانت هذه الأعمدة موجودة في الملف.', style: TextStyle(fontSize: 11, color: cleanOpsMuted)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: importing || bytes == null ? null : _parseAndImport,
            icon: importing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded),
            label: AppText(importing ? 'جارٍ الفحص والاستيراد...' : 'فحص ذكي واستيراد'),
          ),
          if (message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: AppText(message)),
          if (r != null) ...[
            const SizedBox(height: 10),
            AppText('الأعمدة المكتشفة: ${r.detectedColumns.values.join(' • ')}', style: const TextStyle(fontSize: 11, color: cleanOpsMuted)),
            AppText('السجلات الصالحة: ${r.validRows.length} • الأخطاء: ${r.errors.length} • التكرارات: ${r.duplicateCount}', style: const TextStyle(fontWeight: FontWeight.w800)),
            if (r.errors.isNotEmpty)
              ...r.errors.take(20).map((e) => AppText(e, style: const TextStyle(color: red, fontSize: 12))),
            ...r.validRows.take(20).map((row) => ListTile(
              dense: true,
              leading: const Icon(Icons.person_outline, color: aiGreen),
              title: AppText(row['name'] ?? ''),
              subtitle: AppText('${row['job']} • ${row['id']} • ${row['phone']} • ${row['municipality']} • مجموعة ${row['group']}'),
            )),
          ],
        ],
      ),
    );
  }
}
