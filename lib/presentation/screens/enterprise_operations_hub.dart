import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization.dart';
import '../../core/models/core_models.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/config_service.dart';
import '../../core/services/data_service.dart';
import '../../core/services/messaging_service.dart';
import '../../core/services/operations_admin_service.dart';
import '../../core/services/excel_file_saver.dart';
import '../widgets/app_design.dart';
import '../widgets/creative_shortcuts.dart';
import 'container_management.dart';
import 'operations_management.dart';
import 'equipment_search.dart';
import 'global_search.dart';
import 'ai_bot_screen.dart';
import '../widgets/operations_overview.dart';
import 'reports_center.dart';
import 'user_management_settings.dart';
import '../../core/constants/app_constants.dart';

class EnterpriseOperationsHubPage extends StatelessWidget {
  const EnterpriseOperationsHubPage({super.key});
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser!;
    final tiles = <CreativeShortcut>[
      CreativeShortcut(title: 'الحاويات', subtitle: 'الحالة والامتلاء والمشكلات', feature: 'containers', onTap: () => _push(context, const ContainerManagementScreen())),
      CreativeShortcut(title: 'المكبات', subtitle: 'السعة والامتلاء والحالة', feature: 'dumpsite', onTap: () => _push(context, user.role == 'donor_manager' ? const DumpsitesOverviewScreen() : OperationsManagementScreen(initialTab: user.role == 'municipality_coordinator' ? 1 : 0))),
      CreativeShortcut(title: 'بحث المعدات', subtitle: 'بحث سريع بالاسم والنوع والموقع', feature: 'operations', onTap: () => _push(context, const EquipmentSearchScreen())),
      CreativeShortcut(title: 'البحث الشامل', subtitle: 'بحث ذكي يفهم الاختلافات والأخطاء', feature: 'reports', onTap: () => _push(context, const GlobalSearchPage())),
      CreativeShortcut(title: 'التنبيهات والبلاغات', subtitle: 'البلاغات والحالات الحرجة', feature: 'emergency', onTap: () => _push(context, const AlertsCenterPage())),
      if (user.can('workers', 'view')) CreativeShortcut(title: 'المجموعات والعمال', subtitle: 'الحالة والتوزيع والأفراد', feature: 'workers', onTap: () => _push(context, const GroupsCommandCenterPage())),
      if (user.can('trips', 'view')) CreativeShortcut(title: 'سجل الترحيلات', subtitle: 'جميع النقلات الموثقة', feature: 'trips', onTap: () => _push(context, const TripsLogPage())),
      if (user.can('reports', 'view')) CreativeShortcut(title: 'التقارير', subtitle: 'الغياب والحاويات والعمل والدورات', feature: 'reports', onTap: () => _push(context, const ReportsCenterScreen())),
      CreativeShortcut(title: 'المزامنة', subtitle: 'Online / Offline والطوابير', feature: 'sync', onTap: () => _push(context, const SyncCenterPage())),
      CreativeShortcut(title: 'الأمان', subtitle: 'الحساب والجلسة والصلاحيات', feature: 'permissions', onTap: () => _push(context, const SecurityCenterPage())),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const AppText('مركز الإدارة والتشغيل'),
        actions: [IconButton(tooltip: tr('البحث الذكي'), onPressed: () => _push(context, const GlobalSearchPage()), icon: const Icon(Icons.search_rounded))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
        AiHero(user: user, eyebrow: 'CLEANOPS OPERATIONS HUB', title: 'مركز الإدارة والتشغيل', subtitle: 'مركز بسيط للوصول إلى أهم الأصول والبحث والتنبيهات.'),
        const SizedBox(height: 14),
        FutureBuilder<Map<String, dynamic>>(
          future: context.read<OperationsAdminService>().liveOperationalSnapshot(user),
          builder: (context, snap) {
            if (!snap.hasData) return const _LoadingCard();
            final x = snap.data!;
            return AiSectionCard(title: 'لقطة تشغيلية حقيقية', subtitle: 'تُقرأ من Firestore ولا تستخدم أرقامًا تجريبية', feature: 'dashboard', trailing: AppText(_time(x['checkedAt']), style: const TextStyle(color: cleanOpsMuted, fontSize: 10)), child: Wrap(spacing: 10, runSpacing: 10, children: [
              _HubMetric('العمال النشطون', '${x['workers']}', 'workers'), _HubMetric('المجموعات', '${x['groups']}', 'operations'), _HubMetric('الطوارئ', '${x['emergencies']}', 'emergency'), _HubMetric('مكبات حرجة', '${x['criticalDumpsites']}', 'dumpsite'),
            ]));
          },
        ),
        const SizedBox(height: 14),
        CreativeShortcutGrid(items: tiles, emphasize: true, maxColumns: 2),
      ],
      ),
    );
  }
  static String _time(dynamic v) => v is DateTime ? '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}' : '--:--';
  static void _push(BuildContext c, Widget page) => Navigator.push(c, MaterialPageRoute(builder: (_) => page));
}

class _HubMetric extends StatelessWidget { final String title,value,feature; const _HubMetric(this.title,this.value,this.feature); @override Widget build(BuildContext c)=>Container(width: MediaQuery.sizeOf(c).width < 500 ? 105 : 130,padding: const EdgeInsets.all(10),decoration: BoxDecoration(color: aiDark2.withOpacity(.65),borderRadius: BorderRadius.circular(14),border: Border.all(color: aiCyan.withOpacity(.16))),child: Row(children:[AiFeatureIcon(feature,size:13),const SizedBox(width:7),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[AppText(value,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),AppText(title,style:const TextStyle(fontSize:9,color:cleanOpsMuted),overflow:TextOverflow.ellipsis)]))])); }
class _LoadingCard extends StatelessWidget { const _LoadingCard(); @override Widget build(BuildContext c)=>const AiSectionCard(title:'جاري قراءة البيانات',subtitle:'من Firestore',feature:'sync',child:Center(child:Padding(padding:EdgeInsets.all(16),child:CircularProgressIndicator()))); }

class AlertsCenterPage extends StatelessWidget {
  const AlertsCenterPage({super.key});
  @override Widget build(BuildContext context) => _OpsStreamPage(title:'مركز التنبيهات',feature:'emergency',query:FirebaseFirestore.instance.collection('operations').where('_entity',whereIn:['emergency','notification']).limit(200),empty:'لا توجد تنبيهات أو بلاغات مسجلة.',builder:(docs)=>Column(children:docs.map((d)=>_OperationTile(d, critical: '${d.data()['level'] ?? ''}' == 'critical' || '${d.data()['_entity']}' == 'emergency')).toList()));
}

class TripsLogPage extends StatelessWidget {
  const TripsLogPage({super.key});
  @override Widget build(BuildContext context) => _OpsStreamPage(title:'سجل الترحيلات',feature:'trips',query:FirebaseFirestore.instance.collection('operations').where('_entity',isEqualTo:'trip').limit(300),empty:'لا توجد ترحيلات مسجلة.',builder:(docs)=>Column(children:docs.map((d)=>_OperationTile(d)).toList()));
}

class _OpsStreamPage extends StatelessWidget {
  final String title,feature,empty; final Query<Map<String,dynamic>> query; final Widget Function(List<QueryDocumentSnapshot<Map<String,dynamic>>>) builder;
  const _OpsStreamPage({required this.title,required this.feature,required this.query,required this.empty,required this.builder});
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:AppText(title)),body:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:query.snapshots(),builder:(c,s){if(s.hasError)return Center(child:Padding(padding:const EdgeInsets.all(20),child:AppText('تعذر تحميل البيانات: ${s.error}')));if(!s.hasData)return const Center(child:CircularProgressIndicator());final docs=s.data!.docs.toList()..sort((a,b)=>'${b.data()['createdAt']??b.data()['timestamp']??''}'.compareTo('${a.data()['createdAt']??a.data()['timestamp']??''}'));if(docs.isEmpty)return Center(child:AppText(empty));return ListView(padding:const EdgeInsets.fromLTRB(16,16,16,120),children:[AiSectionCard(title:title,feature:feature,subtitle:'بيانات حقيقية من العمليات',child:builder(docs))]);}));
}
class _OperationTile extends StatelessWidget { final QueryDocumentSnapshot<Map<String,dynamic>> doc; final bool critical; const _OperationTile(this.doc,{this.critical=false}); @override Widget build(BuildContext c){final d=doc.data();final entity='${d['_entity']??''}';final title='${d['title']??d['name']??d['operation']??entity}';final detail='${d['detail']??d['description']??d['status']??''}';return ListTile(contentPadding:const EdgeInsets.symmetric(vertical:4),leading:AiFeatureIcon(critical?'emergency':entity=='trip'?'trips':'notifications',size:15),title:AppText(title,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800)),subtitle:AppText(detail,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10,color:cleanOpsMuted)),trailing:Text(doc.id.substring(0,doc.id.length < 8 ? doc.id.length : 8),style:const TextStyle(fontSize:9,color:cleanOpsMuted)));}}

class SyncCenterPage extends StatelessWidget {
  const SyncCenterPage({super.key});
  @override Widget build(BuildContext context){final d=context.watch<DataService>();final m=context.watch<MessagingService>();final c=context.watch<ConfigService>();return Scaffold(appBar:AppBar(title:const AppText('مركز المزامنة')),body:ListView(padding:const EdgeInsets.fromLTRB(16,16,16,120),children:[AiSectionCard(title:'حالة الاتصال',feature:'sync',child:ListTile(leading:Icon(d.online?Icons.cloud_done_rounded:Icons.cloud_off_rounded,color:d.online?aiGreen:Colors.orange),title:AppText(d.online?'Online':'Offline'),subtitle:AppText('آخر مزامنة: ${d.lastSync}'),trailing:FilledButton.tonalIcon(onPressed:d.syncing?null:()=>d.sync(),icon:const Icon(Icons.sync_rounded),label:const AppText('مزامنة الآن')))),const SizedBox(height:12),AiSectionCard(title:'طابور البيانات المحلي',feature:'sync',child:Column(children:[_kv('عمليات بانتظار المزامنة','${d.queue.length}'),_kv('مزامنة تلقائية',c.autoMessageSync?'مفعّلة':'متوقفة'),_kv('الرسائل غير المقروءة','${m.unreadCount}'),_kv('الرسائل المحلية',c.localMessagingEnabled?'مفعّلة':'متوقفة'),_kv('الرسائل Online',c.onlineMessagingEnabled?'مفعّلة':'متوقفة')])),const SizedBox(height:12),AiSectionCard(title:'سلوك Offline',feature:'messages',child:const AppText('البيانات التي تسمح بها الصلاحيات تُحفظ محليًا وتنتظر المزامنة عند عودة الاتصال. لا يتم استخدام FCM.'))]));}
}

class SystemHealthPage extends StatefulWidget { const SystemHealthPage({super.key}); @override State<SystemHealthPage> createState()=>_SystemHealthPageState(); }
class _SystemHealthPageState extends State<SystemHealthPage>{Map<String,String> state={};bool busy=false;Future<void> check()async{setState(()=>busy=true);final next=<String,String>{};next['Firebase']=Firebase.apps.isNotEmpty?'جاهز':'غير مهيأ';next['Authentication']=FirebaseAuth.instance.currentUser != null?'جلسة نشطة':'لا توجد جلسة';try{await FirebaseFirestore.instance.collection('config').doc('global').get(const GetOptions(source:Source.server)).timeout(const Duration(seconds:5));next['Firestore']='متصل';}catch(e){next['Firestore']='غير متاح';}final c=context.read<ConfigService>();next['API']=c.apiEnabled?(c.apiBaseUrl.isEmpty?'مفعّل بلا عنوان':'مفعّل'):'غير مفعّل';next['Local Store']='جاهز';setState(()=>state=next..['Checked At']=DateTime.now().toIso8601String());setState(()=>busy=false);} @override void initState(){super.initState();unawaited(check());} @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const AppText('صحة النظام')),body:ListView(padding:const EdgeInsets.fromLTRB(16,16,16,120),children:[AiSectionCard(title:'System Health',subtitle:'فحص فعلي للخدمات المتاحة',feature:'operations',trailing:IconButton(onPressed:busy?null:check,icon:const Icon(Icons.refresh_rounded)),child:Column(children:state.entries.map((e)=>ListTile(dense:true,leading:Icon(e.key=='Checked At'?Icons.schedule_rounded:Icons.circle,color:e.key=='Checked At'?cleanOpsMuted:(e.value.contains('غير')||e.value.contains('لا ')?Colors.orange:aiGreen),size:15),title:AppText(e.key,style:const TextStyle(fontSize:11)),trailing:AppText(e.value,style:const TextStyle(fontSize:10,color:cleanOpsText)))).toList()))]));}

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});
  @override State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final controller = TextEditingController();
  bool busy = false;
  Timer? _searchDebounce;
  int _searchRequest = 0;
  List<_SearchResult> results = [];
  final Map<String, List<Map<String, dynamic>>> _searchCache = {};
  final Map<String, DateTime> _searchCacheAt = {};

  @override void dispose() { _searchDebounce?.cancel(); controller.dispose(); super.dispose(); }

  void _onQueryChanged(String value) {
    _searchDebounce?.cancel();
    final request = ++_searchRequest;
    if (value.trim().isEmpty) { setState(() { results = []; busy = false; }); return; }
    setState(() => busy = true);
    _searchDebounce = Timer(const Duration(milliseconds: 500), () { if (mounted && request == _searchRequest) search(); });
  }

  Future<void> search() async {
    final q = _normalize(controller.text);
    final request = _searchRequest;
    if (q.isEmpty) { if (mounted) setState(() { results = []; busy = false; }); return; }
    if (mounted) setState(() => busy = true);
    final db = FirebaseFirestore.instance;
    final actor = context.read<AuthService>().currentUser!;
    final out = <_SearchResult>[];

    Future<void> scan(String collection, String label) async {
      try {
        Query<Map<String, dynamic>> query = db.collection(collection).limit(150);
        if (collection == 'users') {
          if (actor.role == 'municipality_coordinator') {
            query = db.collection(collection).where('municipalityCoordinatorId', isEqualTo: actor.id).limit(150);
          } else if (actor.role != 'donor_manager' && actor.role != 'jsc_coordinator') {
            return;
          }
        }
        final cacheKey = '$collection|${actor.role}|${actor.id}';
        final cachedAt = _searchCacheAt[cacheKey];
        List<Map<String, dynamic>> docs;
        if (cachedAt != null && DateTime.now().difference(cachedAt) < const Duration(seconds: 45) && _searchCache.containsKey(cacheKey)) {
          docs = _searchCache[cacheKey]!;
        } else {
          final snap = await query.get();
          docs = [for (final d in snap.docs) {'id': d.id, ...d.data()}];
          _searchCache[cacheKey] = docs;
          _searchCacheAt[cacheKey] = DateTime.now();
        }
        for (final d in docs) {
          final raw = _normalize(d.values.map((v) => '$v').join(' '));
          if (_partialMatch(raw, q)) {
            var resultLabel = label;
            if (collection == 'operations') {
              resultLabel = switch ('${d['_entity'] ?? ''}') {
                'group' => 'مجموعة',
                'trip' => 'نقلة',
                'cycle' => 'دورة',
                'municipality' => 'بلدية',
                'emergency' => 'طوارئ',
                _ => 'عملية',
              };
            }
            out.add(_SearchResult(resultLabel, '${d['id'] ?? ''}', d));
          }
        }
      } catch (_) {}
    }

    await Future.wait([
      scan('users', 'مستخدم'),
      scan('operations', 'عملية'),
      scan('containers', 'حاوية'),
      scan('equipment', 'معدة'),
      scan('dumpsites', 'مكب'),
      scan('work_cycles', 'دورة'),
      scan('municipalities', 'بلدية'),
    ]);
    if (!mounted || request != _searchRequest) return;
    setState(() { results = out.take(80).toList(); busy = false; });
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[ًٌٍَُِّْـ]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  int _distance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 0; i < a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0);
      cur[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        cur[j + 1] = [cur[j] + 1, prev[j + 1] + 1, prev[j] + cost].reduce((x, y) => x < y ? x : y);
      }
      prev = cur;
    }
    return prev.last;
  }

  bool _partialMatch(String haystack, String query) {
    final text = _normalize(haystack);
    final original = _normalize(query).split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    if (original.isEmpty) return false;
    final compactText = text.replaceAll(' ', '');
    final compactQuery = original.join();
    if (compactText.contains(compactQuery)) return true;
    final words = text.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    const aliases = <String, List<String>>{
      'مكب': ['مكب', 'مطمر', 'مطامر', 'مكبات'],
      'مطمر': ['مطمر', 'مكب', 'مكبات'],
      'حاويه': ['حاويه', 'حاويات', 'سله', 'سلال', 'كونتينر', 'كونتينرات'],
      'حاويات': ['حاويات', 'حاويه', 'سلال', 'كونتينر', 'كونتينرات'],
      'نقله': ['نقله', 'نقل', 'ترحيل', 'ترحيلات', 'رحله', 'رحلات', 'شحن'],
      'ترحيل': ['ترحيل', 'ترحيلات', 'نقله', 'نقل', 'رحلات'],
      'غياب': ['غياب', 'غيابات', 'عدم', 'حضور'],
      'عمال': ['عمال', 'عاملين', 'موظفين', 'قوى', 'موارد'],
      'مجموعه': ['مجموعه', 'مجموعات', 'فريق', 'فرق'],
      'تقرير': ['تقرير', 'تقارير', 'تحليل', 'احصائيات', 'كشف', 'ملخص'],
      'معده': ['معده', 'معدات', 'آليه', 'آليات', 'سياره', 'مركبه'],
      'امن': ['امن', 'سلامه', 'وقايه', 'ppe'],
      'بحث': ['بحث', 'استعلام', 'تفتيش', 'عثور'],
      'اداره': ['اداره', 'إدارة', 'مركز', 'تحكم', 'تشغيل', 'اداره', 'مدير', 'اداري'],
      'اشراف': ['اشراف', 'مشرف', 'مشرفين', 'مراقب', 'مراقبين'],
      'بلديه': ['بلديه', 'بلديات', 'بلدية', 'مجلس', 'محلي', 'مدينة'],
      'دوره': ['دوره', 'دورات', 'دورة', 'مرحله', 'مراحل', 'تشغيل'],
    };
    bool matchesTerm(String term) {
      final options = <String>{term, ...(aliases[term] ?? const [])};
      for (final candidate in options) {
        final normalized = _normalize(candidate);
        if (normalized.isEmpty || text.contains(normalized)) return true;
        for (final word in words) {
          if (word.length < 3 || normalized.length < 3) continue;
          final limit = normalized.length >= 7 ? 2 : 1;
          if (_distance(word, normalized) <= limit) return true;
        }
      }
      return false;
    }
    return original.every(matchesTerm);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('البحث الشامل')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onChanged: _onQueryChanged,
          onSubmitted: (_) { _searchDebounce?.cancel(); search(); },
            decoration: InputDecoration(
              hintText: tr('ابحث في المستخدمين والعمليات والمكبات والدورات'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(onPressed: busy ? null : search, icon: const Icon(Icons.arrow_forward_rounded)),
            ),
          ),
          const SizedBox(height: 12),
          if (busy) const LinearProgressIndicator(),
          if (!busy && results.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Column(children: [const AppText('لا توجد نتائج مطابقة ضمن نطاق صلاحياتك.'), const SizedBox(height: 10), OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIBotScreen())), icon: const Icon(Icons.auto_awesome), label: const AppText('اسأل المساعد الذكي'))])),
          for (final r in results)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AiGlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: ListTile(
                  onTap: () => _openResult(r),
                  leading: AiFeatureIcon(r.label == 'مستخدم' ? 'users' : r.label == 'حاوية' ? 'containers' : r.label == 'معدة' ? 'operations' : r.label == 'مكب' || r.label == 'بلدية' ? 'dumpsite' : r.label == 'دورة' ? 'cycle' : 'operations', size: 20),
                  title: AppText(r.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  subtitle: AppText('${r.label} • ${r.id}', style: const TextStyle(fontSize: 11, color: cleanOpsMuted)),
                  trailing: const Icon(Icons.open_in_new_rounded, color: aiCyan),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openResult(_SearchResult r) {
    final actor = context.read<AuthService>().currentUser!;
    Widget? page;
    switch (r.label) {
      case 'مستخدم':
        if (actor.role == 'donor_manager' || actor.role == 'municipality_coordinator') page = const UserManagementSettingsPage();
        break;
      case 'مكب':
        page = actor.role == 'donor_manager' ? const DumpsitesOverviewScreen() : OperationsManagementScreen(initialTab: actor.role == 'municipality_coordinator' ? 1 : 0);
        break;
      case 'بلدية':
        page = const EnterpriseOperationsHubPage();
        break;
      case 'حاوية':
        page = const ContainerManagementScreen();
        break;
      case 'معدة':
        page = const EquipmentSearchScreen();
        break;
      case 'دورة':
        page = actor.role == 'donor_manager' ? const OperationsManagementScreen(initialTab: 0) : const ReportsCenterScreen();
        break;
      case 'مجموعة':
        page = const GroupsCommandCenterPage();
        break;
      case 'نقلة':
        page = const TripsLogPage();
        break;
      case 'طوارئ':
        page = const AlertsCenterPage();
        break;
      case 'عملية':
        final entity = '${r.data['_entity'] ?? ''}';
        page = entity == 'trip' ? const TripsLogPage() : const EnterpriseOperationsHubPage();
        break;
    }
    if (page != null) Navigator.push(context, MaterialPageRoute(builder: (_) => page!));
  }
}

class _SearchResult {
  final String label, id;
  final Map<String, dynamic> data;
  _SearchResult(this.label, this.id, this.data);
  String get title => '${data['name'] ?? data['nameAr'] ?? data['locationName'] ?? data['containerName'] ?? data['equipmentName'] ?? data['title'] ?? data['username'] ?? data['displayName'] ?? data['fullName'] ?? id}';
}

class GroupsCommandCenterPage extends StatelessWidget {
  const GroupsCommandCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final u = context.watch<AuthService>().currentUser;
    if (u == null) return const Scaffold(body: Center(child: AppText('يرجى تسجيل الدخول مجددًا.')));
    final canManage = u.can('workers', 'edit');
    final groupQuery = FirebaseFirestore.instance.collection('operations').limit(1500);
    final userQuery = FirebaseFirestore.instance.collection('users').limit(1500);

    return Scaffold(
      appBar: AppBar(
        title: const AppText('مركز المجموعات'),
        actions: [
          if (canManage) IconButton(tooltip: 'استيراد مجموعات', icon: const Icon(Icons.file_upload_outlined), onPressed: () => _importGroups(context, u.id, u.role, u.scope)),
          if (canManage) IconButton(tooltip: 'تصدير Excel', icon: const Icon(Icons.file_download_outlined), onPressed: () => _exportGroups(context, actorId: u.id, actorRole: u.role, scope: u.scope, csv: false)),
          if (canManage) PopupMenuButton<String>(
            tooltip: 'خيارات التصدير',
            onSelected: (v) => _exportGroups(context, actorId: u.id, actorRole: u.role, scope: u.scope, csv: v == 'csv'),
            itemBuilder: (_) => const [PopupMenuItem(value: 'csv', child: AppText('تصدير CSV'))],
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(onPressed: () => _createGroup(context, u.id, u.scope), icon: const Icon(Icons.group_add_rounded), label: const AppText('إضافة مجموعة'))
          : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: groupQuery.snapshots(),
        builder: (context, groupsSnap) {
          if (groupsSnap.hasError) return Center(child: AppText('تعذر تحميل المجموعات: ${groupsSnap.error}'));
          if (!groupsSnap.hasData) return const Center(child: CircularProgressIndicator());
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: userQuery.snapshots(),
            builder: (context, usersSnap) {
              if (usersSnap.hasError) return Center(child: AppText('تعذر تحميل بيانات العمال: ${usersSnap.error}'));
              if (!usersSnap.hasData) return const Center(child: CircularProgressIndicator());
              final users = usersSnap.data!.docs;
              final counts = <String, int>{};
              final seenMembers = <String>{};
              final legacyGroups = <String, Map<String, dynamic>>{};
              for (final d in users) {
                final x = d.data();
                if (x['isDeleted'] == true) continue;
                final rawGroup = '${x['groupId'] ?? x['groupNumber'] ?? x['group'] ?? ''}'.trim();
                if (rawGroup.isEmpty) continue;
                final active = x['isActive'] != false;
                if (active) {
                  final memberKey = '$rawGroup|${d.id}';
                  if (seenMembers.add(memberKey)) counts[rawGroup] = (counts[rawGroup] ?? 0) + 1;
                  final key = rawGroup.toLowerCase();
                  legacyGroups.putIfAbsent(key, () => {
                    'id': 'legacy:$rawGroup', '_docId': '', '_isSynthetic': true,
                    'name': '${x['groupName'] ?? x['groupLabel'] ?? rawGroup}',
                    'groupName': '${x['groupName'] ?? x['groupLabel'] ?? rawGroup}',
                    'number': rawGroup, 'groupNumber': rawGroup, 'groupId': rawGroup,
                    'municipalityCoordinatorId': '${x['municipalityCoordinatorId'] ?? x['coordinatorId'] ?? ''}',
                    'municipalityName': '${x['municipalityName'] ?? x['municipality'] ?? x['scope'] ?? ''}',
                    'status': 'active',
                  });
                }
              }
              // Imported workers are stored as operations documents, not necessarily in
              // the users collection. Recover group names/numbers from those records too.
              for (final d in groupsSnap.data!.docs) {
                final x = d.data();
                if ('${x['_entity'] ?? ''}' != 'worker' || x['isDeleted'] == true) continue;
                final rawGroup = '${x['groupId'] ?? x['groupNumber'] ?? x['group'] ?? ''}'.trim();
                if (rawGroup.isEmpty) continue;
                final active = x['isActive'] != false;
                final personKey = '$rawGroup|${x['id'] ?? d.id}';
                if (active && seenMembers.add(personKey)) counts[rawGroup] = (counts[rawGroup] ?? 0) + 1;
                final key = rawGroup.toLowerCase();
                legacyGroups.putIfAbsent(key, () => {
                  'id': 'legacy:$rawGroup', '_docId': '', '_isSynthetic': true,
                  'name': '${x['groupName'] ?? x['groupLabel'] ?? rawGroup}',
                  'groupName': '${x['groupName'] ?? x['groupLabel'] ?? rawGroup}',
                  'number': rawGroup, 'groupNumber': rawGroup, 'groupId': rawGroup,
                  'municipalityCoordinatorId': '${x['municipalityCoordinatorId'] ?? x['coordinatorId'] ?? ''}',
                  'municipalityName': '${x['municipalityName'] ?? x['municipality'] ?? x['scope'] ?? ''}',
                  'status': 'active',
                });
              }

              final visible = <Map<String, dynamic>>[];
              final knownKeys = <String>{};
              for (final d in groupsSnap.data!.docs) {
                final x = d.data();
                if ('${x['_entity'] ?? ''}' != 'group') continue;
                if (x['isDeleted'] == true || '${x['status'] ?? ''}'.toLowerCase() == 'deleted') continue;
                if (u.role == 'municipality_coordinator' && !_belongsToCoordinator(x, u.id, u.scope)) continue;
                final number = '${x['number'] ?? x['groupNumber'] ?? x['groupId'] ?? ''}'.trim();
                final name = '${x['name'] ?? x['groupName'] ?? number}'.trim();
                visible.add({...x, 'id': d.id, '_docId': d.id, '_isSynthetic': false, 'name': name, 'number': number});
                knownKeys.add(number.toLowerCase());
                knownKeys.add(name.toLowerCase());
                knownKeys.add(d.id.toLowerCase());
              }
              // Show groups that exist in worker records but were never written to the
              // operations group registry; this is the main legacy/missing-group case.
              for (final entry in legacyGroups.entries) {
                final g = entry.value;
                if (knownKeys.contains(entry.key)) continue;
                if (u.role == 'municipality_coordinator' && !_belongsToCoordinator(g, u.id, u.scope)) continue;
                visible.add(g);
              }
              visible.sort((a, b) => '${a['number'] ?? a['name'] ?? ''}'.compareTo('${b['number'] ?? b['name'] ?? ''}'));

              if (visible.isEmpty) {
                return ListView(padding: const EdgeInsets.all(18), children: [
                  const SizedBox(height: 80),
                  const Icon(Icons.groups_2_outlined, size: 56, color: aiCyan),
                  const SizedBox(height: 12),
                  const Center(child: AppText('لا توجد مجموعات مسجلة لهذا النطاق.')),
                  const SizedBox(height: 8),
                  const Center(child: AppText('يمكنك إنشاء مجموعة أو استيرادها من Excel/CSV.', style: TextStyle(color: cleanOpsMuted))),
                  if (canManage) ...[
                    const SizedBox(height: 18),
                    FilledButton.icon(onPressed: () => _createGroup(context, u.id, u.scope), icon: const Icon(Icons.add), label: const AppText('إنشاء مجموعة')),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(onPressed: () => _importGroups(context, u.id, u.role, u.scope), icon: const Icon(Icons.file_upload), label: const AppText('استيراد مجموعات')),
                  ],
                ]);
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  AiSectionCard(
                    title: 'المجموعات (${visible.length})',
                    feature: 'workers',
                    subtitle: 'تظهر المجموعات المسجلة وكذلك المجموعات القديمة المستنتجة من سجلات العمال.',
                    child: Column(children: visible.map((x) {
                      final id = '${x['_docId'] ?? ''}';
                      final number = '${x['number'] ?? x['groupNumber'] ?? x['groupId'] ?? ''}'.trim();
                      final name = '${x['name'] ?? x['groupName'] ?? number}'.trim();
                      final count = <String>{id, number, name}.where((e) => e.isNotEmpty).fold<int>(0, (sum, key) => sum + (counts[key] ?? 0));
                      final synthetic = x['_isSynthetic'] == true;
                      return ListTile(
                        leading: Icon(synthetic ? Icons.group_work_outlined : Icons.groups_rounded, color: synthetic ? Colors.amber : aiCyan),
                        title: AppText(name.isEmpty ? 'مجموعة ${number.isEmpty ? 'بدون رقم' : number}' : name),
                        subtitle: AppText('رقم المجموعة: ${number.isEmpty ? '—' : number} • العمال النشطون: $count • ${synthetic ? 'مجموعة قديمة تحتاج تسجيلًا' : (x['status'] ?? 'نشطة')}', style: const TextStyle(fontSize: 11, color: cleanOpsMuted)),
                        trailing: canManage ? PopupMenuButton<String>(
                          tooltip: 'إدارة المجموعة',
                          onSelected: (v) {
                            if (v == 'edit') _editGroup(context, id, x, u.id, u.scope);
                            if (v == 'delete') _confirmDeleteGroup(context, id, number, name, count, synthetic);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'edit', child: AppText(synthetic ? 'تسجيل / تعديل المجموعة' : 'تعديل المجموعة')),
                            if (!synthetic) const PopupMenuItem(value: 'delete', child: AppText('حذف المجموعة')),
                          ],
                        ) : null,
                      );
                    }).toList()),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static String _normalizeScope(String value) => value
      .replaceAll('\uFEFF', '')
      .replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا')
      .replaceAll('ة', 'ه').replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'^(بلديه|بلدية)\s*'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim().toLowerCase();

  static bool _belongsToCoordinator(Map<String, dynamic> x, String coordinatorId, String scope) {
    final owners = [x['municipalityCoordinatorId'], x['coordinatorId'], x['createdBy'], x['createdByUserId']]
        .map((v) => '${v ?? ''}'.trim()).where((v) => v.isNotEmpty);
    if (owners.contains(coordinatorId.trim())) return true;
    final expected = _normalizeScope(scope);
    final municipality = _normalizeScope('${x['municipalityName'] ?? x['municipality'] ?? x['municipalityScope'] ?? x['scope'] ?? ''}');
    return expected.isNotEmpty && municipality.isNotEmpty && expected == municipality;
  }

  Future<void> _createGroup(BuildContext context, String coordinatorId, String municipalityName) async {
    final number = TextEditingController();
    final name = TextEditingController();
    try {
      final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: const AppText('إضافة مجموعة جديدة'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: number, keyboardType: TextInputType.text, decoration: const InputDecoration(labelText: 'رقم المجموعة', hintText: 'مثال: 01')),
          const SizedBox(height: 10),
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'اسم المجموعة', hintText: 'مثال: المجموعة الأولى')),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const AppText('إلغاء')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const AppText('إضافة'))],
      ));
      if (ok != true || !context.mounted) return;
      final groupName = name.text.trim();
      final groupNumber = number.text.trim().isEmpty ? groupName : number.text.trim();
      if (groupName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('يرجى إدخال اسم المجموعة.')));
        return;
      }
      final ref = FirebaseFirestore.instance.collection('operations').doc();
      await ref.set({
        'id': ref.id, 'groupId': groupNumber, 'number': groupNumber, 'groupNumber': groupNumber,
        '_entity': 'group', 'name': groupName, 'groupName': groupName, 'title': groupName,
        'status': 'active', 'isActive': true, 'isDeleted': false,
        'municipalityCoordinatorId': coordinatorId, 'coordinatorId': coordinatorId,
        'municipalityName': municipalityName, 'municipality': municipalityName,
        'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(), 'createdBy': coordinatorId,
      });
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('تمت إضافة المجموعة وربطها بمنسق البلدية.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('تعذرت إضافة المجموعة: $e')));
    } finally { number.dispose(); name.dispose(); }
  }

  Future<void> _editGroup(BuildContext context, String id, Map<String, dynamic> data, String actorId, String municipalityName) async {
    final number = TextEditingController(text: '${data['number'] ?? data['groupNumber'] ?? data['groupId'] ?? ''}');
    final name = TextEditingController(text: '${data['name'] ?? data['groupName'] ?? ''}');
    final status = ValueNotifier<String>('${data['status'] ?? 'active'}' == 'inactive' ? 'inactive' : 'active');
    final synthetic = data['_isSynthetic'] == true || id.isEmpty;
    try {
      final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: AppText(synthetic ? 'تسجيل مجموعة قديمة' : 'تعديل المجموعة'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: number, decoration: const InputDecoration(labelText: 'رقم المجموعة')),
          const SizedBox(height: 10), TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المجموعة')),
          const SizedBox(height: 10), ValueListenableBuilder<String>(valueListenable: status, builder: (_, value, __) => DropdownButtonFormField<String>(value: value, items: const [DropdownMenuItem(value: 'active', child: AppText('نشطة')), DropdownMenuItem(value: 'inactive', child: AppText('غير نشطة'))], onChanged: (v) => status.value = v ?? value, decoration: const InputDecoration(labelText: 'الحالة'))),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const AppText('إلغاء')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const AppText('حفظ'))],
      ));
      if (ok != true || !context.mounted) return;
      if (name.text.trim().isEmpty || number.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('اسم المجموعة ورقمها مطلوبان.'))); return;
      }
      final ref = synthetic ? FirebaseFirestore.instance.collection('operations').doc() : FirebaseFirestore.instance.collection('operations').doc(id);
      await ref.set({
        'id': ref.id, '_entity': 'group', 'name': name.text.trim(), 'groupName': name.text.trim(), 'title': name.text.trim(),
        'number': number.text.trim(), 'groupNumber': number.text.trim(), 'groupId': number.text.trim(),
        'status': status.value, 'isActive': status.value == 'active', 'isDeleted': false,
        'municipalityCoordinatorId': actorId, 'coordinatorId': actorId,
        'municipalityName': '${data['municipalityName'] ?? data['municipality'] ?? municipalityName}',
        'createdBy': '${data['createdBy'] ?? actorId}', 'updatedBy': actorId,
        if (synthetic) 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('تم حفظ المجموعة وتوحيد حقولها بنجاح.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('تعذر حفظ المجموعة: $e')));
    } finally { number.dispose(); name.dispose(); status.dispose(); }
  }

  Future<void> _confirmDeleteGroup(BuildContext context, String id, String number, String name, int count, bool synthetic) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const AppText('تأكيد حذف المجموعة'),
      content: AppText('سيتم حذف سجل المجموعة «${name.isEmpty ? number : name}». عدد العمال النشطين المرتبطين بها: $count. لن تُحذف سجلات العمال تلقائيًا. هل تريد المتابعة؟'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const AppText('إلغاء')), TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const AppText('حذف', style: TextStyle(color: Colors.red)))],
    ));
    if (confirmed != true || !context.mounted) return;
    try {
      await FirebaseFirestore.instance.collection('operations').doc(id).delete();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('تم حذف سجل المجموعة. لم يتم حذف العمال المرتبطين بها.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('تعذر حذف المجموعة: $e')));
    }
  }

  Future<void> _exportGroups(BuildContext context, {required String actorId, required String actorRole, required String scope, required bool csv}) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('operations').limit(1500).get();
      final groupsByKey = <String, List<String>>{};
      for (final d in snap.docs) {
        final x = d.data();
        final entity = '${x['_entity'] ?? ''}';
        if (x['isDeleted'] == true || (actorRole == 'municipality_coordinator' && !_belongsToCoordinator(x, actorId, scope))) continue;
        if (entity == 'group') {
          final number = '${x['number'] ?? x['groupNumber'] ?? x['groupId'] ?? ''}'.trim();
          final name = '${x['name'] ?? x['groupName'] ?? number}'.trim();
          final key = (number.isNotEmpty ? number : name).toLowerCase();
          if (key.isEmpty) continue;
          groupsByKey[key] = [d.id, number, name, '${x['municipalityName'] ?? x['municipality'] ?? ''}', '${x['municipalityCoordinatorId'] ?? x['coordinatorId'] ?? ''}', '${x['status'] ?? 'active'}'];
        }
      }
      // Include legacy groups found in imported worker records even if the group
      // registry document was never created.
      for (final d in snap.docs) {
        final x = d.data();
        if ('${x['_entity'] ?? ''}' != 'worker' || x['isDeleted'] == true) continue;
        if (actorRole == 'municipality_coordinator' && !_belongsToCoordinator(x, actorId, scope)) continue;
        final number = '${x['groupId'] ?? x['groupNumber'] ?? x['group'] ?? ''}'.trim();
        if (number.isEmpty) continue;
        groupsByKey.putIfAbsent(number.toLowerCase(), () => ['', number, '${x['groupName'] ?? x['groupLabel'] ?? number}', '${x['municipalityName'] ?? x['municipality'] ?? ''}', '${x['municipalityCoordinatorId'] ?? x['coordinatorId'] ?? ''}', 'legacy']);
      }
      final rows = groupsByKey.values.toList();
      const headers = ['معرّف المجموعة', 'رقم المجموعة', 'اسم المجموعة', 'البلدية', 'معرّف المنسق', 'الحالة'];
      String? path;
      final stamp = DateTime.now().millisecondsSinceEpoch;
      if (csv) {
        String quote(String s) { final q = String.fromCharCode(34); return '$q${s.replaceAll(q, q + q)}$q'; }
        final content = '\uFEFF${[headers, ...rows].map((r) => r.map(quote).join(',')).join('\r\n')}';
        path = await saveExcelBytes(Uint8List.fromList(utf8.encode(content)), 'cleanops_groups_$stamp.csv');
      } else {
        final book = excel.Excel.createExcel();
        final sheet = book['Groups'];
        sheet.appendRow(headers.map(excel.TextCellValue.new).toList());
        for (final row in rows) { sheet.appendRow(row.map(excel.TextCellValue.new).toList()); }
        final bytes = book.encode();
        if (bytes != null && bytes.isNotEmpty) path = await saveExcelBytes(Uint8List.fromList(bytes), 'cleanops_groups_$stamp.xlsx');
      }
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText(path == null ? 'تعذر حفظ ملف التصدير على هذا الجهاز.' : 'تم تصدير ${rows.length} مجموعة إلى: $path')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('فشل تصدير المجموعات: $e')));
    }
  }

  Future<void> _importGroups(BuildContext context, String actorId, String actorRole, String municipalityName) async {
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'csv'], withData: true);
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) throw Exception('الملف فارغ أو تعذر قراءته.');
      List<List<String>> rows;
      if (file.name.toLowerCase().endsWith('.csv')) {
        final decoded = utf8.decode(bytes, allowMalformed: true).replaceFirst('\uFEFF', '');
        rows = decoded.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).map((l) => l.split(RegExp(r'[,;\t]')).map((v) => v.trim().replaceAll(RegExp(r'^"|"$'), '')).toList()).toList();
      } else {
        final book = excel.Excel.decodeBytes(bytes);
        if (book.tables.isEmpty) throw Exception('لا توجد ورقة عمل قابلة للقراءة.');
        rows = book.tables.values.first.rows.map((r) => r.map((c) => c?.value == null ? '' : '${c!.value}'.trim()).toList()).toList();
      }
      if (rows.isEmpty) throw Exception('الملف لا يحتوي على بيانات.');
      String norm(String s) => s.replaceAll('\uFEFF', '').replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('ة', 'ه').trim().toLowerCase();
      final header = rows.take(30).toList().asMap().entries.firstWhere((entry) => entry.value.any((v) => ['رقم المجموعة','المجموعة','group number','group no','number','اسم المجموعة','group name','name'].contains(norm(v))), orElse: () => const MapEntry<int, List<String>>(-1, <String>[]));
      if (header.key < 0) throw Exception('لم يتم العثور على صف العناوين. استخدم عمود «رقم المجموعة» و/أو «اسم المجموعة».');
      final h = <String, int>{};
      for (var i = 0; i < header.value.length; i++) {
        final v = norm(header.value[i]);
        if (['رقم المجموعة','المجموعة','group number','group no','number','group'].contains(v)) h.putIfAbsent('number', () => i);
        if (['اسم المجموعة','group name','name'].contains(v)) h.putIfAbsent('name', () => i);
        if (['البلدية','اسم البلدية','municipality','municipality name'].contains(v)) h.putIfAbsent('municipality', () => i);
      }
      if (!h.containsKey('number') && !h.containsKey('name')) throw Exception('أضف عمود رقم المجموعة أو اسم المجموعة.');
      final existing = await FirebaseFirestore.instance.collection('operations').where('_entity', isEqualTo: 'group').limit(1500).get();
      final existingKeys = existing.docs.map((d) => '${d.data()['number'] ?? d.data()['groupNumber'] ?? d.data()['groupId'] ?? ''}'.trim().toLowerCase()).where((v) => v.isNotEmpty).toSet();
      var created = 0; var skipped = 0;
      final batch = FirebaseFirestore.instance.batch();
      for (var i = header.key + 1; i < rows.length; i++) {
        final row = rows[i];
        String value(String key) { final index = h[key]; return index == null || index >= row.length ? '' : row[index].trim(); }
        final number = value('number');
        final name = value('name').isNotEmpty ? value('name') : number;
        final groupNumber = number.isNotEmpty ? number : name;
        if (groupNumber.isEmpty || name.isEmpty) { skipped++; continue; }
        if (existingKeys.contains(groupNumber.toLowerCase())) { skipped++; continue; }
        final municipality = value('municipality').isNotEmpty ? value('municipality') : municipalityName;
        final ref = FirebaseFirestore.instance.collection('operations').doc();
        batch.set(ref, {'id': ref.id, '_entity': 'group', 'name': name, 'groupName': name, 'title': name, 'number': groupNumber, 'groupNumber': groupNumber, 'groupId': groupNumber, 'municipalityCoordinatorId': actorId, 'coordinatorId': actorId, 'municipalityName': municipality, 'municipality': municipality, 'status': 'active', 'isActive': true, 'isDeleted': false, 'createdBy': actorId, 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
        existingKeys.add(groupNumber.toLowerCase()); created++;
      }
      if (created > 0) await batch.commit();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('اكتمل استيراد المجموعات: أضيف $created، وتُجاوز $skipped (فارغة أو مكررة).')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('فشل استيراد المجموعات: $e'), duration: const Duration(seconds: 8)));
    }
  }
}

class ExecutiveReportPage extends StatelessWidget {
  const ExecutiveReportPage({super.key});
  @override
  Widget build(BuildContext context) {
    final u = context.watch<AuthService>().currentUser!;
    return Scaffold(
      appBar: AppBar(title: const AppText('التقرير التنفيذي')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: context.read<OperationsAdminService>().liveOperationalSnapshot(u),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final x = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              AiHero(user: u, eyebrow: 'EXECUTIVE REPORT', title: 'ملخص تنفيذي', subtitle: 'الأرقام الحالية مأخوذة من Firestore وقت إنشاء التقرير.'),
              const SizedBox(height: 12),
              AiSectionCard(
                title: 'المؤشرات التشغيلية', feature: 'reports',
                child: Wrap(spacing: 10, runSpacing: 10, children: [
                  _HubMetric('المستخدمون النشطون', '${x['activeUsers']}', 'users'),
                  _HubMetric('العمال', '${x['workers']}', 'workers'),
                  _HubMetric('المشرفون', '${x['supervisors']}', 'workers'),
                  _HubMetric('المجموعات', '${x['groups']}', 'operations'),
                  _HubMetric('الترحيلات', '${x['trips']}', 'trips'),
                  _HubMetric('الطوارئ', '${x['emergencies']}', 'emergency'),
                  _HubMetric('التقارير', '${x['reports']}', 'reports'),
                  _HubMetric('المكبات الحرجة', '${x['criticalDumpsites']}', 'dumpsite'),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SecurityCenterPage extends StatelessWidget {
  const SecurityCenterPage({super.key});
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser!;
    final auth = context.read<AuthService>();
    return Scaffold(
      appBar: AppBar(title: const AppText('مركز الأمان')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), children: [
        AiSectionCard(title: 'الحساب الحالي', feature: 'permissions', child: Column(children: [
          _kv('اسم المستخدم', user.username),
          _kv('الدور', roleNames[user.role] ?? user.role),
          _kv('الحالة', user.isActive ? 'نشط' : 'غير نشط'),
          _kv('كلمة المرور', 'لا تُحفظ داخل Firestore أو LocalStore'),
        ])),
        const SizedBox(height: 12),
        AiSectionCard(title: 'إعادة كلمة المرور', feature: 'users', subtitle: 'يُرسل رابط إعادة التعيين إلى البريد المرتبط بالحساب', child: FilledButton.icon(
          onPressed: () async {
            final ok = await auth.requestPasswordReset(user.username);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText(ok ? 'تم إرسال رابط إعادة التعيين.' : (auth.error ?? 'تعذر إرسال الرابط.'))));
          },
          icon: const Icon(Icons.lock_reset_rounded),
          label: const AppText('إرسال رابط إعادة التعيين'),
        )),
        const SizedBox(height: 12),
        const AiSectionCard(title: 'سياسة الأمان', feature: 'permissions', child: Column(children: [
          ListTile(leading: Icon(Icons.password_rounded, color: aiGreen), title: AppText('كلمات المرور'), subtitle: AppText('تُدار عبر Firebase Authentication ولا تُكتب في Firestore.')),
          ListTile(leading: Icon(Icons.cloud_off_rounded, color: aiCyan), title: AppText('Offline'), subtitle: AppText('لا يتم تخزين كلمة المرور في التخزين المحلي.')),
          ListTile(leading: Icon(Icons.notifications_off_rounded, color: aiCyan), title: AppText('FCM'), subtitle: AppText('غير مستخدم في منظومة الرسائل الحالية.')),
        ])),
      ]),
    );
  }
}

class FilesCenterPage extends StatefulWidget {
  const FilesCenterPage({super.key});
  @override State<FilesCenterPage> createState() => _FilesCenterPageState();
}

class _FilesCenterPageState extends State<FilesCenterPage> {
  bool busy = true;
  String? error;
  final files = <Reference>[];
  Future<void> load() async {
    setState(() { busy = true; error = null; files.clear(); });
    try {
      final storage = FirebaseStorage.instance;
      Future<void> collect(Reference ref, int depth) async {
        if (files.length >= 100 || depth > 3) return;
        final result = await ref.listAll();
        files.addAll(result.items.take(100 - files.length));
        for (final prefix in result.prefixes) {
          if (files.length >= 100) break;
          await collect(prefix, depth + 1);
        }
      }
      for (final root in ['photos', 'audio']) {
        if (files.length >= 100) break;
        await collect(storage.ref(root), 0);
      }
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => busy = false);
  }
  @override void initState() { super.initState(); unawaited(load()); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AppText('مركز الملفات'), actions: [IconButton(onPressed: busy ? null : load, icon: const Icon(Icons.refresh_rounded))]),
    body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), children: [
      AiSectionCard(title: 'الملفات المرفوعة', subtitle: 'تُقرأ من Firebase Storage • الصور والتسجيلات الميدانية', feature: 'reports', child: busy
        ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        : error != null
          ? AppText('تعذر تحميل الملفات: $error')
          : files.isEmpty
            ? const AppText('لا توجد ملفات مرفوعة بعد.')
            : Column(children: files.map((r) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AiFeatureIcon(r.fullPath.startsWith('audio/') ? 'messages' : 'reports', size: 14),
                title: AppText(r.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                subtitle: AppText(r.fullPath, style: const TextStyle(fontSize: 9, color: cleanOpsMuted), overflow: TextOverflow.ellipsis),
                onTap: () async { final url = await r.getDownloadURL(); if (!context.mounted) return; await showDialog(context: context, builder: (_) => AlertDialog(title: const AppText('رابط الملف'), content: SelectableText(url), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const AppText('إغلاق'))])); },
              )).toList()),
      ),
    ]),
  );
}

class AuditLogPage extends StatelessWidget {
  const AuditLogPage({super.key});
  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance.collection('audit').orderBy('timestamp', descending: true).limit(200).snapshots();
    return Scaffold(
      appBar: AppBar(title: const AppText('سجل التدقيق')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20), child: AppText('تعذر تحميل سجل التدقيق: ${snap.error}')));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: AppText('لا توجد عمليات مسجلة بعد.'));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              AiSectionCard(
                title: 'سجل التدقيق', subtitle: 'قراءة فقط • Level 4', feature: 'permissions',
                child: Column(children: docs.map((d) {
                  final x = d.data();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const AiFeatureIcon('permissions', size: 14),
                    title: AppText('${x['operation'] ?? 'عملية'}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    subtitle: AppText('المنفذ: ${x['actorId'] ?? '-'} • الهدف: ${x['targetId'] ?? '-'}', style: const TextStyle(fontSize: 9, color: cleanOpsMuted)),
                  );
                }).toList()),
              ),
            ],
          );
        },
      ),
    );
  }
}

Widget _kv(String a,String b)=>ListTile(contentPadding:EdgeInsets.zero,title:AppText(a,style:const TextStyle(fontSize:11)),trailing:AppText(b,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800,color:aiCyan)));
