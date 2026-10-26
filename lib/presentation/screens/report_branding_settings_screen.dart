import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/data_service.dart';
import '../widgets/app_design.dart';
import '../../core/localization.dart';

/// Local report identity settings and selected logo images for offline PDF exports.
class ReportBrandingSettingsScreen extends StatefulWidget {
  const ReportBrandingSettingsScreen({super.key});
  @override
  State<ReportBrandingSettingsScreen> createState() => _ReportBrandingSettingsScreenState();
}

class _ReportBrandingSettingsScreenState extends State<ReportBrandingSettingsScreen> {
  final _municipality = TextEditingController();
  final _council = TextEditingController();
  final _project = TextEditingController();
  bool _hasMunicipalityLogo = false, _hasCouncilLogo = false, _hasUnicefLogo = false;
  bool _busy = true;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _municipality.text = p.getString('report_municipality_name') ?? '';
    _council.text = p.getString('report_council_name') ?? '';
    _project.text = p.getString('report_project_name') ?? '';
    _hasMunicipalityLogo = (p.getString('report_municipality_logo_base64') ?? '').isNotEmpty;
    _hasCouncilLogo = (p.getString('report_council_logo_base64') ?? '').isNotEmpty;
    _hasUnicefLogo = (p.getString('report_unicef_logo_base64') ?? '').isNotEmpty;
    if (mounted) setState(() => _busy = false);
  }
  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('report_municipality_name', _municipality.text.trim());
    await p.setString('report_council_name', _council.text.trim());
    await p.setString('report_project_name', _project.text.trim());
    final user = context.read<AuthService>().currentUser;
    if (user != null) {
      await context.read<DataService>().writeAudit(actorId: user.id, operation: 'REPORT_BRANDING_UPDATED', targetId: 'report_branding_settings', after: {'municipalityName': _municipality.text.trim(), 'councilName': _council.text.trim(), 'projectName': _project.text.trim(), 'logosConfigured': {'municipality': _hasMunicipalityLogo, 'council': _hasCouncilLogo, 'unicef': _hasUnicefLogo}});
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('تم حفظ إعدادات ترويسة التقارير على هذا الجهاز.')));
  }
  Future<void> _pickLogo(String key) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.single.bytes;
    if (bytes == null || bytes.isEmpty) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('تعذر قراءة ملف الصورة. جرّب اختيار صورة أخرى.'))); return; }
    final p = await SharedPreferences.getInstance();
    await p.setString(key, base64Encode(bytes));
    if (!mounted) return;
    setState(() { if (key == 'report_municipality_logo_base64') _hasMunicipalityLogo = true; if (key == 'report_council_logo_base64') _hasCouncilLogo = true; if (key == 'report_unicef_logo_base64') _hasUnicefLogo = true; });
  }
  @override
  void dispose() { _municipality.dispose(); _council.dispose(); _project.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AppText('هوية التقارير والدورة')),
    body: _busy ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
      const AppText('تظهر هذه البيانات في ترويسة التقرير. اسم المشروع مرتبط بالدورة المختارة عند التصدير، وهذه القيمة هي الاسم الافتراضي.', style: TextStyle(height: 1.5)),
      const SizedBox(height: 12),
      _field(_municipality, 'اسم البلدية'), _field(_council, 'اسم المجلس'), _field(_project, 'اسم المشروع / الدورة'),
      const Divider(height: 28),
      _logoPicker('شعار البلدية', _hasMunicipalityLogo, () => _pickLogo('report_municipality_logo_base64')),
      _logoPicker('شعار المجلس', _hasCouncilLogo, () => _pickLogo('report_council_logo_base64')),
      _logoPicker('شعار اليونيسيف', _hasUnicefLogo, () => _pickLogo('report_unicef_logo_base64')),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const AppText('حفظ الإعدادات')),
      const SizedBox(height: 8),
      const AppText('تُحفظ الشعارات المختارة محليًا على الجهاز وتُضمّن في PDF عند توفرها. عند عدم اختيار شعار، لن يتم اختراع صورة بديلة.', style: TextStyle(fontSize: 12, height: 1.4)),
    ]),
  );
  Widget _logoPicker(String label, bool selected, VoidCallback onTap) => Padding(padding: const EdgeInsets.only(bottom: 10), child: OutlinedButton.icon(onPressed: onTap, icon: Icon(selected ? Icons.check_circle_outline : Icons.add_photo_alternate_outlined), label: Text('$label — ${selected ? 'تم الاختيار' : 'اختيار صورة'}')));
  Widget _field(TextEditingController c, String label) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: c, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())));
}
