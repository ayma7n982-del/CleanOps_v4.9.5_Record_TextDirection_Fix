import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/localization.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/core_models.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/container_service.dart';
import '../widgets/app_design.dart';
import '../widgets/location_picker.dart';

class ContainerManagementScreen extends StatelessWidget {
  const ContainerManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) return const Scaffold(body: Center(child: AppText('لا توجد جلسة مستخدم.')));
    return Directionality(
      textDirection: context.watch<LocaleController>().isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: const AppText('إدارة الحاويات'),
          actions: [
            if (user.role == 'jsc_coordinator') IconButton(onPressed: () => _openEditor(context), icon: const Icon(Icons.add_box_rounded)),
          ],
        ),
        body: const _ContainerBody(),
        floatingActionButton: user.role == 'jsc_coordinator'
            ? FloatingActionButton.extended(onPressed: () => _openEditor(context), icon: const Icon(Icons.add_rounded), label: const AppText('إضافة حاوية'))
            : null,
      ),
    );
  }

  static Future<void> _openEditor(BuildContext context, [ContainerItem? item]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cleanOpsSurface,
      builder: (_) => _ContainerEditor(item: item),
    );
  }
}

class _ContainerBody extends StatelessWidget {
  const _ContainerBody();
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser!;
    final service = context.watch<ContainerService>();
    final list = service.containers;
    return RefreshIndicator(
      onRefresh: () async => service.attachUser(user),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
        children: [
          AiSectionCard(
            title: 'حالة الحاويات',
            subtitle: user.role == 'group_supervisor' || user.role == 'worker' ? 'اختر حاوية مجموعتك وحدّث حالتها اليومية.' : 'المتابعة حسب البلدية والمجموعة مع دورة المشكلة كاملة.',
            feature: 'containers',
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              _CountChip('فارغة', list.where((x) => x.status == 'empty').length, green),
              _CountChip('نصف ممتلئة', list.where((x) => x.status == 'partial').length, orange),
              _CountChip('ممتلئة', list.where((x) => x.status == 'full').length, red),
              _CountChip('مشكلات', list.where((x) => x.issueStatus == 'reported' || x.issueStatus == 'resolving').length, orange),
            ]),
          ),
          const SizedBox(height: 12),
          if (service.loading) const LinearProgressIndicator(minHeight: 2),
          if (service.error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: AppText('تعذر تحميل الحاويات: ${service.error}', style: const TextStyle(color: red))),
          if (list.isEmpty)
            const AiSectionCard(title: 'لا توجد حاويات', subtitle: 'سيظهر هنا نطاق الحاويات المتاح للدور الحالي.', feature: 'containers', child: Center(child: Padding(padding: EdgeInsets.all(20), child: AppText('لا توجد حاويات مسجلة ضمن النطاق الحالي.'))))
          else
            ...list.map((item) => _ContainerTile(item: item, user: user)),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label; final int count; final Color color;
  const _CountChip(this.label, this.count, this.color);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withOpacity(.30))),
    child: AppText('$label  $count', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
  );
}

class _ContainerTile extends StatelessWidget {
  final ContainerItem item; final AppUser user;
  const _ContainerTile({required this.item, required this.user});

  Color get statusColor => item.status == 'full' ? red : item.status == 'partial' ? orange : green;
  String get statusLabel => item.status == 'full' ? 'ممتلئة' : item.status == 'partial' ? 'نصف ممتلئة' : 'فارغة';
  String get issueLabel => switch (item.issueStatus) {
    'reported' => 'مشكلة مسجلة',
    'resolving' => 'إجراء تصحيحي - قيد المعالجة',
    'verified_resolved' => 'توكيد حل المشكلة',
    _ => 'لا توجد مشكلة',
  };
  Color get issueColor => switch (item.issueStatus) { 'reported' => red, 'resolving' => orange, 'verified_resolved' => green, _ => cleanOpsMuted };

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openActions(context),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor.withOpacity(.12)), child: Icon(Icons.delete_sweep_rounded, color: statusColor)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AppText(item.locationName.isEmpty ? 'حاوية بدون اسم موقع' : item.locationName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              AppText('GPS: ${item.latitude.toStringAsFixed(5)}, ${item.longitude.toStringAsFixed(5)} • المجموعة ${item.groupId.isEmpty ? '—' : item.groupId}', style: const TextStyle(color: cleanOpsMuted, fontSize: 10)),
            ])),
            _StatusPill(statusLabel, statusColor),
          ]),
          const SizedBox(height: 10),
          Row(children: [Icon(Icons.feedback_outlined, size: 15, color: issueColor), const SizedBox(width: 6), Expanded(child: AppText(issueLabel, style: TextStyle(color: issueColor, fontSize: 11, fontWeight: FontWeight.w800))), if (item.feedbackNotes.isNotEmpty) const Icon(Icons.notes_outlined, size: 15, color: cleanOpsMuted)]),
          if (item.feedbackNotes.isNotEmpty) ...[const SizedBox(height: 5), AppText(item.feedbackNotes, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: cleanOpsMuted, fontSize: 10))],
        ]),
      ),
    ),
  );

  Future<void> _openActions(BuildContext context) async {
    final service = context.read<ContainerService>();
    if (user.role == 'jsc_coordinator') {
      await showModalBottomSheet<void>(context: context, backgroundColor: cleanOpsSurface, builder: (_) => _ContainerEditor(item: item));
      return;
    }
    if (user.role == 'municipality_coordinator') {
      await showModalBottomSheet<void>(context: context, backgroundColor: cleanOpsSurface, builder: (_) => _MunicipalityContainerActions(item: item));
      return;
    }
    await showModalBottomSheet<void>(context: context, backgroundColor: cleanOpsSurface, builder: (_) => _SupervisorContainerActions(item: item));
    if (service.containers.isEmpty) return;
  }
}

class _StatusPill extends StatelessWidget {
  final String text; final Color color;
  const _StatusPill(this.text, this.color);
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(.25))), child: AppText(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)));
}

class _SupervisorContainerActions extends StatefulWidget {
  final ContainerItem item;
  const _SupervisorContainerActions({required this.item});
  @override State<_SupervisorContainerActions> createState() => _SupervisorContainerActionsState();
}
class _SupervisorContainerActionsState extends State<_SupervisorContainerActions> {
  late String status = widget.item.status;
  final notes = TextEditingController();
  bool busy = false;
  @override void dispose(){notes.dispose();super.dispose();}
  Future<void> _save() async {
    setState(() => busy = true);
    try {
      final service = context.read<ContainerService>();
      await service.updateDailyStatus(widget.item, status);
      if (notes.text.trim().isNotEmpty) await service.reportIssue(service.byId(widget.item.id) ?? widget.item, notes.text);
      if (mounted) Navigator.pop(context);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('$e'))); } finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppText(widget.item.locationName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: status, items: const [DropdownMenuItem(value: 'empty', child: AppText('فارغة')), DropdownMenuItem(value: 'partial', child: AppText('نصف ممتلئة')), DropdownMenuItem(value: 'full', child: AppText('ممتلئة'))], onChanged: busy ? null : (v) => setState(() => status = v ?? status), decoration: InputDecoration(labelText: tr('الحالة اليومية'))),
      const SizedBox(height: 10),
      TextField(controller: notes, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: tr('ملاحظة مشكلة / عطل / عدم إمكانية الوصول'), hintText: tr('اتركه فارغًا إذا لا توجد مشكلة'))),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: busy ? null : _save, icon: const Icon(Icons.save_rounded), label: AppText(busy ? 'جارٍ الحفظ...' : 'حفظ الحالة')),
      if (widget.item.issueStatus == 'resolving') ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: busy ? null : () async { try { await context.read<ContainerService>().confirmResolved(widget.item, notes.text); if (context.mounted) Navigator.pop(context); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('$e'))); } }, icon: const Icon(Icons.verified_rounded, color: green), label: const AppText('توكيد حل المشكلة')),
      ],
    ]),
  );
}

class _MunicipalityContainerActions extends StatefulWidget {
  final ContainerItem item;
  const _MunicipalityContainerActions({required this.item});
  @override State<_MunicipalityContainerActions> createState() => _MunicipalityContainerActionsState();
}
class _MunicipalityContainerActionsState extends State<_MunicipalityContainerActions> {
  final notes = TextEditingController(); bool busy = false;
  @override void dispose(){notes.dispose();super.dispose();}
  Future<void> _run(String mode) async {
    setState(() => busy = true);
    try {
      final s = context.read<ContainerService>();
      if (mode == 'resolve') await s.confirmResolved(widget.item, notes.text);
      else await s.startCorrectiveAction(widget.item, notes.text);
      if (mounted) Navigator.pop(context);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('$e'))); } finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppText(widget.item.locationName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8), AppText('الحالة الحالية: ${widget.item.issueStatus}'),
      const SizedBox(height: 10), TextField(controller: notes, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: tr('تفاصيل الإجراء التصحيحي'))),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: busy ? null : () => _run('start'), icon: const Icon(Icons.build_circle_outlined), label: const AppText('بدء إجراء تصحيحي')),
      const SizedBox(height: 8), OutlinedButton.icon(onPressed: busy ? null : () => _run('resolve'), icon: const Icon(Icons.verified_rounded, color: green), label: const AppText('توكيد حل المشكلة')),
    ]),
  );
}

class _ContainerEditor extends StatefulWidget {
  final ContainerItem? item;
  const _ContainerEditor({this.item});
  @override State<_ContainerEditor> createState() => _ContainerEditorState();
}
class _ContainerEditorState extends State<_ContainerEditor> {
  late final TextEditingController location = TextEditingController(text: widget.item?.locationName ?? '');
  late final TextEditingController municipality = TextEditingController(text: widget.item?.municipalityId ?? '');
  late final TextEditingController group = TextEditingController(text: widget.item?.groupId ?? '');
  LatLng? point; bool busy = false; double? accuracy;
  @override void initState(){super.initState(); point=widget.item == null ? null : LatLng(widget.item!.latitude, widget.item!.longitude); if(widget.item==null) _loadCurrent();}
  @override void dispose(){location.dispose();municipality.dispose();group.dispose();super.dispose();}
  Future<void> _loadCurrent() async { try { if(!await Geolocator.isLocationServiceEnabled()) return; var p=await Geolocator.checkPermission(); if(p==LocationPermission.denied)p=await Geolocator.requestPermission(); if(p==LocationPermission.denied||p==LocationPermission.deniedForever)return; Position? x; try{x=await Geolocator.getCurrentPosition(locationSettings:const LocationSettings(accuracy:LocationAccuracy.high,timeLimit:Duration(seconds:8)));}catch(_){x=await Geolocator.getLastKnownPosition();} if(x!=null&&mounted)setState(() { point=LatLng(x!.latitude,x.longitude); accuracy=x.accuracy; }); } catch(_){} }
  Future<void> _save() async {
    final p=point; if(location.text.trim().isEmpty||p==null){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:AppText('أدخل اسم الموقع واختر موقع GPS من الخريطة.')));return;}
    setState(()=>busy=true); try { final s=context.read<ContainerService>(); if(widget.item==null) await s.createContainer(locationName:location.text,latitude:p.latitude,longitude:p.longitude,municipalityId:municipality.text,groupId:group.text); else await s.updateContainer(widget.item!,locationName:location.text,latitude:p.latitude,longitude:p.longitude,groupId:group.text); if(mounted)Navigator.pop(context); } catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:AppText('$e')));}finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Padding(padding:EdgeInsets.fromLTRB(18,18,18,MediaQuery.viewInsetsOf(context).bottom+18),child:SingleChildScrollView(padding: const EdgeInsets.only(bottom: 120), child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    AppText(widget.item==null?'إضافة حاوية جديدة':'تعديل الحاوية',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:12),
    TextField(controller:location,decoration:InputDecoration(labelText:tr('اسم الموقع'))),const SizedBox(height:9),
    LocationField(value:point,onChanged:(v)=>setState(()=>point=v)),
    if(accuracy!=null)Padding(padding:const EdgeInsets.only(top:4),child:Text('دقة GPS: ${accuracy!.round()} م${accuracy!>50?' — يفضّل تحسين الدقة':''}',style:TextStyle(fontSize:11,color:accuracy!>50?Colors.orange:Colors.green))),
    const SizedBox(height:5),OutlinedButton.icon(onPressed:_loadCurrent,icon:const Icon(Icons.my_location),label:const AppText('تحديث موقعي الآن')),
    const SizedBox(height:9),TextField(controller:municipality,decoration:InputDecoration(labelText:tr('معرّف البلدية / منسق البلدية'))),const SizedBox(height:9),TextField(controller:group,decoration:InputDecoration(labelText:tr('معرّف المجموعة (اختياري)'))),const SizedBox(height:14),FilledButton.icon(onPressed:busy?null:_save,icon:const Icon(Icons.save_rounded),label:AppText(busy?'جارٍ الحفظ...':'حفظ الحاوية'))
  ])));
}
