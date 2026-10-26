import 'dart:typed_data';
import '../../core/localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../widgets/app_design.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/core_models.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/data_service.dart';
import '../../core/services/report_service.dart';
import 'monthly_attendance_report_screen.dart';
import 'attendance_reports_home_screen.dart';
import 'work_reports_dashboard.dart';
import 'report_branding_settings_screen.dart';
import 'report_approval_screen.dart';

class ReportsCenterScreen extends StatefulWidget {
  const ReportsCenterScreen({super.key});
  @override State<ReportsCenterScreen> createState() => _ReportsCenterState();
}

class _ReportsCenterState extends State<ReportsCenterScreen> {
  late Future<ReportSnapshot> future;
  int days = 30;
  DateTime startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime endDate = DateTime.now();
  String reportType = 'all';
  String exportLanguage = 'ar';
  String? municipality, group, cycle;

  @override void initState() { super.initState(); _reload(); }
  void _reload() {
    final data = context.read<DataService>(); final user = context.read<AuthService>().currentUser;
    future = ReportService(data).load(days: days, startDate: startDate, endDate: endDate, user: user, municipality: municipality, group: group, cycle: cycle, reportType: reportType);
  }
  void _refresh() => _reload();

  @override Widget build(BuildContext context) {
    final rtl = context.watch<LocaleController>().isArabic;
    return Directionality(textDirection: rtl ? TextDirection.rtl : TextDirection.ltr, child: Scaffold(
      appBar: AppBar(title: const AppText('مركز التقارير والتحليلات')), 
      body: FutureBuilder<ReportSnapshot>(future: future, builder: (context, snap) {
        if (snap.hasError) return Center(child: AppText('تعذر تحميل التقارير: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return _body(snap.data!);
      }),
    ));
  }

  Widget _body(ReportSnapshot s) {
    final u = context.read<AuthService>().currentUser!;
    return RefreshIndicator(onRefresh: () async { _refresh(); await future; }, child: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 120), children: [
      _hero(s), const SizedBox(height: 12), _specializedReports(), const SizedBox(height: 12), _filters(s), const SizedBox(height: 12),
      _typeCards(), const SizedBox(height: 12), _kpis(s), const SizedBox(height: 12),
      _selectedReport(s), const SizedBox(height: 12), _charts(s), const SizedBox(height: 12), _actions(s, u),
    ]));
  }

  Widget _hero(ReportSnapshot s) => Card(color: navy, child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
    const Icon(Icons.analytics_rounded, color: gold, size: 42), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const AppText('مركز التقارير والتحليلات', style: TextStyle(color: cleanOpsSurface, fontSize: 24, fontWeight: FontWeight.w900)),
      AppText('بيانات فعلية من العمليات والحاويات والدورات', style: const TextStyle(color: cleanOpsMuted)),
      const SizedBox(height: 5), AppText(s.periodLabel, style: const TextStyle(color: gold)),
    ])),
    IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh, color: cleanOpsSurface)),
  ])));

  Widget _specializedReports() => Wrap(spacing: 8, runSpacing: 8, children: [
    OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceReportsHomeScreen())), icon: const Icon(Icons.fact_check_outlined), label: const AppText('تقارير الحضور')),
    OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MonthlyAttendanceReportScreen())), icon: const Icon(Icons.calendar_month), label: const AppText('التقرير الشهري التقويمي')),
    OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkReportsDashboard())), icon: const Icon(Icons.assignment_turned_in_outlined), label: const AppText('لوحة تقارير العمل')),
    OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportBrandingSettingsScreen())), icon: const Icon(Icons.branding_watermark_outlined), label: const AppText('شعارات وهوية التقرير')),
    OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportApprovalScreen())), icon: const Icon(Icons.fact_check_outlined), label: const AppText('اعتماد التقارير')),
  ]);

  Widget _filters(ReportSnapshot s) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const AppText('فلاتر التقرير', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)), const SizedBox(height: 8),
    Wrap(spacing: 8, runSpacing: 8, children: [
      _dateField('من تاريخ', startDate, (v) { if (v != null) { setState(() { startDate = v; if (endDate.isBefore(startDate)) endDate = startDate; }); _refresh(); } }),
      _dateField('إلى تاريخ', endDate, (v) { if (v != null) { setState(() { endDate = v.isBefore(startDate) ? startDate : v; }); _refresh(); } }),
      _drop<String>('لغة التصدير', exportLanguage, const {'ar':'العربية','en':'English'}, (v){if(v!=null)setState(()=>exportLanguage=v);}),
      _drop<String>('البلدية', municipality, <String?,String>{null:'كل البلديات', ...{for(final x in s.municipalityNames) x:x}}, (v){setState(() { municipality=v; group=null; }); _refresh();}),
      _drop<String>('المجموعة', group, <String?,String>{null:'كل المجموعات', ...{for(final x in _availableGroups()) x:x}}, (v){setState(()=>group=v); _refresh();}),
      _drop<String>('الدورة', cycle, <String?,String>{null:'كل الدورات', ...{for(final x in s.cycles) x:x}}, (v){setState(()=>cycle=v); _refresh();}),
    ]),
  ])));

  List<String> _availableGroups() {
    final ops = context.read<DataService>().operations;
    final values = <String>{};
    for (final e in ops) {
      if (e['isDeleted'] == true) continue;
      if (e['_entity'] != 'group' && e['_entity'] != 'trip' && e['_entity'] != 'attendance' && e['_entity'] != 'work_report') continue;
      final groupName = '${e['groupName'] ?? e['name'] ?? e['groupId'] ?? ''}'.trim();
      if (groupName.isEmpty) continue;
      if (municipality != null && municipality!.isNotEmpty) {
        final municipalityName = '${e['municipalityName'] ?? e['municipality'] ?? ''}'.trim();
        final municipalityId = '${e['municipalityId'] ?? ''}'.trim();
        if (municipalityName != municipality && municipalityId != municipality) continue;
      }
      values.add(groupName);
    }
    return values.toList()..sort();
  }

  Widget _dateField(String label, DateTime value, ValueChanged<DateTime?> onPicked) => SizedBox(width: 190, child: OutlinedButton.icon(
    onPressed: () async { final picked = await showDatePicker(context: context, initialDate: value, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (picked != null) onPicked(picked); },
    icon: const Icon(Icons.calendar_month), label: Text('$label: ${value.year}-${value.month.toString().padLeft(2,'0')}-${value.day.toString().padLeft(2,'0')}', overflow: TextOverflow.ellipsis),
  ));

  Widget _drop<T>(String label, T? value, Map<T?,String> items, ValueChanged<T?> onChanged) => SizedBox(width: 190, child: DropdownButtonFormField<T>(value: value, decoration: InputDecoration(labelText: label, isDense: true), items: items.entries.map((e)=>DropdownMenuItem<T>(value:e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(), onChanged: onChanged));

  Widget _typeCards() {
    final types = <(String, String, IconData)>[
      ('all', 'كل التقارير', Icons.dashboard_customize_rounded),
      ('absence', 'الحضور والغياب', Icons.fact_check_rounded),
      ('containers', 'تقارير الحاويات', Icons.delete_sweep_rounded),
      ('work', 'تقارير العمل', Icons.local_shipping_rounded),
      ('cycles', 'دورات العمل', Icons.event_repeat_rounded),
      ('municipalities', 'تقارير البلديات', Icons.location_city_rounded),
      ('groups', 'تقارير المجموعات', Icons.groups_rounded),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: types.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.65,
      ),
      itemBuilder: (context, index) {
        final item = types[index];
        final selected = reportType == item.$1;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: selected
                  ? [const Color(0xFF09293A), const Color(0xFF103E4B)]
                  : [const Color(0xFF071D30), const Color(0xFF0A2A3B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: selected ? red.withOpacity(.75) : Colors.white10, width: selected ? 1.6 : 1),
            boxShadow: selected ? [BoxShadow(color: red.withOpacity(.16), blurRadius: 18, spreadRadius: 1)] : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                if (item.$1 == 'absence') { Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceReportsHomeScreen())); return; }
                if (item.$1 == 'work') { Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkReportsDashboard())); return; }
                setState(() => reportType = item.$1); _refresh();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(item.$3, size: 26, color: selected ? red : cleanOpsMuted),
                  const SizedBox(height: 7),
                  AppText(item.$2, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: selected ? red : cleanOpsText, fontWeight: FontWeight.w900, fontSize: 13)),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _kpis(ReportSnapshot s) => Wrap(spacing:8, runSpacing:8, children: [
    _k('الترحيلات', '${s.trips}', navy, Icons.local_shipping_outlined), _k('الحضور', '${(s.attendanceRate*100).toStringAsFixed(0)}%', green, Icons.how_to_reg), _k('الغياب','${s.absence}',red,Icons.person_off),
    _k('الحاويات','${s.containersTotal}',navy,Icons.delete_outline), _k('ممتلئة','${s.containersFull}',red,Icons.warning_amber), _k('مشكلات الحاويات','${s.containerIssues}',orange,Icons.build_circle_outlined),
    _k('المجموعات','${s.groups}',green,Icons.groups), _k('المشرفون','${s.supervisors}',aiCyan,Icons.supervisor_account), _k('العمال','${s.workers}',aiGreen,Icons.people_alt), _k('البلديات','${s.municipalities}',gold,Icons.location_city), _k('المكبات','${s.dumpsites}',orange,Icons.delete_sweep),
  ]);
  Widget _k(String a,String b,Color c,IconData icon)=>SizedBox(width:145,child:Card(child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[Icon(icon,color:c),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[AppText(a,style:const TextStyle(fontSize:13)),AppText(b,style:TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:c))]))]))));

  Widget _selectedReport(ReportSnapshot s) {
    switch(reportType){
      case 'absence': return _section('تقرير الغياب والحضور', Column(children:[_donut(s),_rank(s.absenceByGroup,'أعلى مجموعات الغياب',red)]));
      case 'containers': return _section('تقرير الحاويات', Column(children:[_containerStatus(s),_rank(s.containersByMunicipality,'توزيع الحاويات حسب البلدية',navy),_rank(s.containersByGroup,'توزيع الحاويات حسب المجموعة',green)]));
      case 'work': return _section('تقرير العمل والتشغيل', Column(children:[_lineTrips(s),_rank(s.tripsByGroup,'الترحيلات حسب المجموعة',green),_rank(s.tripsByMunicipality,'الترحيلات حسب البلدية',navy)]));
      case 'cycles': return _section('تقرير دورات العمل', Column(children:[_cycleSummary(s),_lineTrips(s)]));
      case 'municipalities': return _section('تقرير البلديات', _rank(s.tripsByMunicipality,'الأداء حسب البلدية',gold));
      case 'groups': return _section('تقرير المجموعات', Column(children:[_rank(s.tripsByGroup,'الترحيلات حسب المجموعة',green),_rank(s.absenceByGroup,'الغياب حسب المجموعة',red)]));
      default: return _section('نظرة تنفيذية شاملة', Column(children:[_lineTrips(s),_donut(s),_containerStatus(s)]));
    }
  }
  Widget _section(String title,Widget child)=>AiSectionCard(title:title,feature:'reports',child:child);

  Widget _charts(ReportSnapshot s)=>Column(children:[if(reportType=='all'||reportType=='municipalities'||reportType=='groups') _section('مقارنة الأداء',_bar(s)), if(reportType=='all') ...[_section('الحاويات',_containerStatus(s))]]);

  Widget _bar(ReportSnapshot s){final labels=s.tripsByGroup.keys.toList(); final vals=s.tripsByGroup.values.toList(); final data=vals.isEmpty?[0]:vals; final max=data.reduce((a,b)=>a>b?a:b); return SizedBox(height:220,child:BarChart(BarChartData(maxY:(max+2).toDouble(),barGroups:[for(var i=0;i<data.length;i++)BarChartGroupData(x:i,barRods:[BarChartRodData(toY:data[i].toDouble(),width:22,borderRadius:BorderRadius.circular(5))])],titlesData:FlTitlesData(bottomTitles:AxisTitles(sideTitles:SideTitles(showTitles:true,getTitlesWidget:(v,m)=>AppText(v.toInt()<labels.length?labels[v.toInt()]:'',style:const TextStyle(fontSize:9))))))));}
  Widget _lineTrips(ReportSnapshot s){final p=s.tripsByDay.entries.toList(); final spots=p.isEmpty?[const FlSpot(0,0)]:[for(var i=0;i<p.length;i++)FlSpot(i.toDouble(),p[i].value.toDouble())]; return SizedBox(height:210,child:LineChart(LineChartData(minY:0,lineBarsData:[LineChartBarData(spots:spots,isCurved:true,barWidth:3,dotData:const FlDotData(show:true))],titlesData:const FlTitlesData(bottomTitles:AxisTitles(sideTitles:SideTitles(showTitles:false)),rightTitles:AxisTitles(sideTitles:SideTitles(showTitles:false)),topTitles:AxisTitles(sideTitles:SideTitles(showTitles:false))))));}
  Widget _donut(ReportSnapshot s)=>SizedBox(height:220,child:PieChart(PieChartData(centerSpaceRadius:45,sections:[PieChartSectionData(value:s.attendance.toDouble().clamp(0.1,double.infinity).toDouble(),title:'حضور',radius:62),PieChartSectionData(value:s.absence.toDouble().clamp(0.1,double.infinity).toDouble(),title:'غياب',radius:62),PieChartSectionData(value:s.ppeCompliant.toDouble().clamp(0.1,double.infinity).toDouble(),title:'PPE',radius:62)])));
  Widget _containerStatus(ReportSnapshot s)=>Wrap(spacing:8,runSpacing:8,children:[_mini('فارغة',s.containersEmpty,green),_mini('جزئية',s.containersPartial,orange),_mini('ممتلئة',s.containersFull,red),_mini('مشكلات',s.containerIssues,red)]);
  Widget _mini(String t,int v,Color c)=>Container(width:125,padding:const EdgeInsets.all(12),decoration:BoxDecoration(borderRadius:BorderRadius.circular(14),border:Border.all(color:c.withOpacity(.3))),child:Column(children:[AppText(t),AppText('$v',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900,color:c))]));
  Widget _rank(Map<String,int> map,String title,Color color){ final entries=map.entries.toList()..sort((a,b)=>b.value.compareTo(a.value)); return Padding(padding:const EdgeInsets.only(top:10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[AppText(title,style:const TextStyle(fontWeight:FontWeight.w900)),...entries.take(7).map((e)=>ListTile(dense:true,leading:Icon(Icons.circle,size:10,color:color),title:AppText(e.key),trailing:AppText('${e.value}',style:TextStyle(fontWeight:FontWeight.w900,color:color))))])); }
  Widget _cycleSummary(ReportSnapshot s)=>ListTile(leading:const Icon(Icons.event_repeat),title:AppText('الدورات المتاحة: ${s.cycleCount}'),subtitle:AppText(s.cycles.isEmpty?'لا توجد بيانات دورات متاحة':'آخر دورة: ${s.cycles.first}'));

  Widget _actions(ReportSnapshot s, AppUser u)=>_section('التصدير والاعتماد',Wrap(spacing:8,runSpacing:8,children:[OutlinedButton.icon(onPressed:()async{final bytes=await ReportService(context.read<DataService>()).buildOperationalPdfBytes(snapshot:s,user:u,title:'${_title()} — CleanOps', languageCode: exportLanguage);if(!mounted)return;Navigator.push(context,MaterialPageRoute(builder:(_)=>Scaffold(appBar:AppBar(title:const AppText('معاينة التقرير')),body:PdfPreview(build:(_)=>Uint8List.fromList(bytes)))));},icon:const Icon(Icons.preview_outlined),label:const AppText('معاينة / طباعة')),FilledButton.icon(onPressed:()async{try{final path=await ReportService(context.read<DataService>()).exportOperationalPdf(snapshot:s,user:u,title:'${_title()} — CleanOps', languageCode: exportLanguage);if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:AppText(path==null?'تعذر إنشاء PDF':'تم إنشاء PDF: $path')));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:AppText('فشل إنشاء PDF: $e')));}},icon:const Icon(Icons.picture_as_pdf),label:const AppText('تصدير PDF')),OutlinedButton.icon(onPressed:u.role == 'municipality_coordinator' ? ()async{final now=DateTime.now().toIso8601String();await context.read<DataService>().enqueue('report_approval','create',{'id':s.reportId,'title':_title(),'reportType':reportType,'period':s.periodLabel,'municipality':municipality,'group':group,'cycle':cycle,'requestedBy':u.id,'createdAt':now,'status':'submitted','isDeleted':false});await context.read<DataService>().writeAudit(actorId:u.id,operation:'REQUEST_REPORT_APPROVAL',targetId:s.reportId,after:{'reportType':reportType,'period':s.periodLabel,'status':'submitted','municipality':municipality,'group':group,'cycle':cycle});if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:AppText('تم إرسال التقرير إلى دورة المراجعة.')));Navigator.push(context,MaterialPageRoute(builder:(_)=>const ReportApprovalScreen()));}} : null,icon:const Icon(Icons.verified_outlined),label:const AppText('إرسال التقرير للمراجعة'))]));
  String _title()=>switch(reportType){'absence'=>'تقرير الغياب والحضور','containers'=>'تقرير الحاويات','work'=>'تقرير العمل والتشغيل','cycles'=>'تقرير الدورات','municipalities'=>'تقرير البلديات','groups'=>'تقرير المجموعات',_=>'التقرير التنفيذي الشامل'};
}
