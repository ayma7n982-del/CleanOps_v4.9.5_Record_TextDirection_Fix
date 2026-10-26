import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../models/core_models.dart';
import 'report_service.dart';

class ReportPdfTemplate {
  final pw.Font regular;
  final pw.Font bold;
  final AppUser? user;
  final String title;
  final ReportSnapshot snapshot;
  final pw.ImageProvider? logo;
  final pw.ImageProvider? municipalityLogo, councilLogo, unicefLogo;
  final String languageCode;
  final String municipalityName, councilName, projectName;
  bool get english => languageCode == 'en';
  String t(String ar, String en) => english ? en : ar;
  ReportPdfTemplate({required this.regular, required this.bold, required this.user, required this.title, required this.snapshot, this.logo, this.municipalityLogo, this.councilLogo, this.unicefLogo, this.languageCode = 'ar', this.municipalityName = '', this.councilName = '', this.projectName = ''});

  pw.Widget _kpi(String label, String value) => pw.Container(padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(6)), child: pw.Column(children:[pw.Text(label,style:pw.TextStyle(font:regular,fontSize:8)),pw.SizedBox(height:3),pw.Text(value,style:pw.TextStyle(font:bold,fontSize:15))]));
  pw.Widget _bars(Map<String,int> values) { if(values.isEmpty)return pw.Text(t('لا توجد بيانات كافية للرسم.','Not enough data to chart.'),style:pw.TextStyle(font:regular,fontSize:8)); final max=values.values.fold<int>(1,(a,b)=>a>b?a:b); return pw.Column(children:values.entries.take(12).map((e)=>pw.Padding(padding:const pw.EdgeInsets.symmetric(vertical:2),child:pw.Row(children:[pw.SizedBox(width:65,child:pw.Text(e.key,style:pw.TextStyle(font:regular,fontSize:7))),pw.Expanded(child:pw.Container(height:11,color:PdfColors.grey200,child:pw.Align(alignment:pw.Alignment.centerLeft,child:pw.Container(width:120*e.value/max,height:11,color:PdfColors.blueGrey700)))),pw.SizedBox(width:28,child:pw.Text('${e.value}',style:pw.TextStyle(font:bold,fontSize:7)))]))).toList()); }
  pw.Widget _section(String heading,List<pw.Widget> children)=>pw.Container(margin:const pw.EdgeInsets.only(top:12),padding:const pw.EdgeInsets.all(10),decoration:pw.BoxDecoration(border:pw.Border.all(color:PdfColors.grey300),borderRadius:pw.BorderRadius.circular(7)),child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[pw.Text(heading,style:pw.TextStyle(font:bold,fontSize:12)),pw.SizedBox(height:7),...children]));

  List<pw.Widget> build() {
    final role=user?.role ?? 'donor_manager'; final roleTitle=english ? ({'donor_manager':'System Manager','jsc_coordinator':'JSC Coordinator','municipality_coordinator':'Municipality Coordinator','group_supervisor':'Group Supervisor','worker':'Worker'}[role] ?? 'Operational Report') : (roleNames[role] ?? 'التقرير التشغيلي');
    final summary=english ? '${snapshot.trips} trips recorded. Attendance rate ${(snapshot.attendanceRate*100).toStringAsFixed(1)}%, PPE compliance ${(snapshot.ppeRate*100).toStringAsFixed(1)}%, emergencies ${snapshot.emergencies}.' : 'تم تسجيل ${snapshot.trips} نقلة. معدل الحضور ${(snapshot.attendanceRate*100).toStringAsFixed(1)}%، والتزام معدات الوقاية ${(snapshot.ppeRate*100).toStringAsFixed(1)}%، والطوارئ ${snapshot.emergencies}.';
    return [
      pw.Container(padding:const pw.EdgeInsets.all(14),decoration:pw.BoxDecoration(color:PdfColors.blueGrey900,borderRadius:pw.BorderRadius.circular(10)),child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
        pw.Row(crossAxisAlignment:pw.CrossAxisAlignment.center,children:[
          if(municipalityLogo!=null) pw.Container(width:38,height:38,child:pw.Image(municipalityLogo!)),
          if(councilLogo!=null) pw.Padding(padding:const pw.EdgeInsets.only(left:4),child:pw.Container(width:38,height:38,child:pw.Image(councilLogo!))),
          if(unicefLogo!=null) pw.Padding(padding:const pw.EdgeInsets.only(left:4),child:pw.Container(width:38,height:38,child:pw.Image(unicefLogo!))),
          if(logo!=null && municipalityLogo==null && councilLogo==null && unicefLogo==null) pw.Container(width:38,height:38,child:pw.Image(logo!)),
          pw.SizedBox(width:8),
          pw.Expanded(child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[if(municipalityName.isNotEmpty) pw.Text(municipalityName,style:pw.TextStyle(font:bold,fontSize:10,color:PdfColors.white)),if(councilName.isNotEmpty) pw.Text(councilName,style:pw.TextStyle(font:bold,fontSize:10,color:PdfColors.white)),if(projectName.isNotEmpty) pw.Text('${t('المشروع / الدورة: ','Project / cycle: ')}$projectName',style:pw.TextStyle(font:regular,fontSize:8,color:PdfColors.white)),pw.Text(title,style:pw.TextStyle(font:bold,fontSize:17,color:PdfColors.white))])),
          pw.Container(padding:const pw.EdgeInsets.symmetric(horizontal:8,vertical:6),decoration:pw.BoxDecoration(color:PdfColors.cyan,borderRadius:pw.BorderRadius.circular(5)),child:pw.Text('UNICEF',style:pw.TextStyle(font:bold,fontSize:10,color:PdfColors.white))),
        ]),
        pw.SizedBox(height:7),
        pw.Text(t('الجهة الداعمة: اليونيسف (UNICEF)','Supported by UNICEF'),style:pw.TextStyle(font:bold,fontSize:9,color:PdfColors.cyan)),
        pw.Text('${t('البلديات: ','Municipalities: ')}${snapshot.municipalityNames.isEmpty ? (snapshot.selectedMunicipality ?? t('غير محددة','Unspecified')) : snapshot.municipalityNames.take(10).join(' • ')}',style:pw.TextStyle(font:bold,fontSize:8,color:PdfColors.white)),
        pw.Text(roleTitle,style:pw.TextStyle(font:bold,fontSize:9,color:PdfColors.amber)),
        pw.Text('${t('الفترة: ','Period: ')}${snapshot.periodLabel}',style:pw.TextStyle(font:regular,fontSize:8,color:PdfColors.white)),
        pw.Text('${t('تاريخ الإصدار: ','Generated: ')}${DateFormat('yyyy-MM-dd HH:mm').format(snapshot.generatedAt)}',style:pw.TextStyle(font:regular,fontSize:8,color:PdfColors.white)),
      ])),
      pw.SizedBox(height:12),pw.Table(border:pw.TableBorder.all(color:PdfColors.grey300,width:.5),children:[pw.TableRow(children:[_kpi(t('الرحلات','Trips'),'${snapshot.trips}'),_kpi(t('الحضور','Attendance'),'${(snapshot.attendanceRate*100).toStringAsFixed(0)}%'),_kpi('PPE','${(snapshot.ppeRate*100).toStringAsFixed(0)}%'),_kpi(t('الطوارئ المفتوحة','Open emergencies'),'${snapshot.emergencyOpen}')])]),
      _section(role=='municipality_coordinator'?t('مقارنة المجموعات','Group comparison'):role=='group_supervisor'?t('ملخص المجموعة','Group summary'):t('الملخص التشغيلي','Operational summary'),[if(role=='municipality_coordinator') ...[_comparisonTable()],_bars(snapshot.tripsByDay),pw.Text(summary,style:pw.TextStyle(font:regular,fontSize:9))]),
      if(snapshot.containerByStatus.isNotEmpty)_section(t('حالة الحاويات','Container status'),[pw.Text(snapshot.containerByStatus.entries.map((e)=>'${_statusLabel(e.key)}: ${e.value}').join(' • '),style:pw.TextStyle(font:regular,fontSize:9))]),
      _section(t('ملاحظات وتوصيات','Notes and recommendations'),[pw.Text(snapshot.emergencies>0?t('متابعة البلاغات المفتوحة وإغلاقها وفق إجراءات السلامة.','Follow up and close open incidents according to safety procedures.'):t('لا توجد طوارئ مفتوحة ضمن البيانات المتاحة.','No open emergencies in the available data.'),style:pw.TextStyle(font:regular,fontSize:9)),pw.Text(snapshot.ppeRate<.95?t('مراجعة الالتزام بمعدات الوقاية الشخصية.','Review personal protective equipment compliance.'):t('الالتزام بـ PPE ضمن المستوى الجيد.','PPE compliance is at a good level.'),style:pw.TextStyle(font:regular,fontSize:9))]),
      _section(t('الاعتماد والتوقيع','Review and signatures'),[pw.Text('${t('معدّ التقرير: ','Prepared by: ')}${user?.name ?? t('النظام','System')}',style:pw.TextStyle(font:regular,fontSize:9)),pw.Text(t('المراجع: ____________________','Reviewer: ____________________'),style:pw.TextStyle(font:regular,fontSize:9)),pw.Text(t('المعتمد: ____________________    التاريخ: __________','Approved by: ____________________    Date: __________'),style:pw.TextStyle(font:regular,fontSize:9))]),
    ];
  }
  String _statusLabel(String value) => english ? ({'full':'Full','partial':'Partial','empty':'Empty','unknown':'Unknown','ممتلئة':'Full','جزئية':'Partial','فارغة':'Empty'}[value] ?? value) : ({'full':'ممتلئة','partial':'جزئية','empty':'فارغة','unknown':'غير محددة'}[value] ?? value);
  pw.Widget _comparisonTable(){final rows=snapshot.tripsByGroup.entries.toList()..sort((a,b)=>b.value.compareTo(a.value)); return pw.Table(border:pw.TableBorder.all(color:PdfColors.grey300),children:[pw.TableRow(children:['#',t('المجموعة','Group'),t('الرحلات','Trips')].map((x)=>pw.Padding(padding:const pw.EdgeInsets.all(4),child:pw.Text(x,style:pw.TextStyle(font:bold,fontSize:8)))).toList()),...rows.asMap().entries.map((e)=>pw.TableRow(children:[pw.Text('${e.key+1}',style:pw.TextStyle(font:regular,fontSize:8)),pw.Text(e.value.key,style:pw.TextStyle(font:regular,fontSize:8)),pw.Text('${e.value.value}',style:pw.TextStyle(font:bold,fontSize:8))]))]);}
  pw.Widget header(pw.Context context){
    final municipalities = snapshot.municipalityNames.isEmpty ? (snapshot.selectedMunicipality ?? 'كل البلديات') : snapshot.municipalityNames.take(5).join(' • ');
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 7),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        if (municipalityLogo != null) pw.Container(width: 24, height: 24, child: pw.Image(municipalityLogo!)),
        if (councilLogo != null) pw.Padding(padding: const pw.EdgeInsets.only(left: 3), child: pw.Container(width: 24, height: 24, child: pw.Image(councilLogo!))),
        if (unicefLogo != null) pw.Padding(padding: const pw.EdgeInsets.only(left: 3), child: pw.Container(width: 24, height: 24, child: pw.Image(unicefLogo!))),
        if (logo != null && municipalityLogo == null && councilLogo == null && unicefLogo == null) pw.Container(width: 24, height: 24, child: pw.Image(logo!)),
        pw.SizedBox(width: 6),
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          if(municipalityName.isNotEmpty) pw.Text(municipalityName, style: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.cyan800)),
          if(councilName.isNotEmpty) pw.Text(councilName, style: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.cyan800)),
          if(projectName.isNotEmpty) pw.Text('${t('المشروع / الدورة: ','Project / cycle: ')}$projectName', style: pw.TextStyle(font: regular, fontSize: 6.5)),
          pw.Text(t('اليونيسف • UNICEF','UNICEF'), style: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.blue800)),
          pw.Text('${t('البلديات: ','Municipalities: ')}$municipalities', maxLines: 1, style: pw.TextStyle(font: regular, fontSize: 6.5)),
          pw.Text(title, maxLines: 1, style: pw.TextStyle(font: bold, fontSize: 8.5)),
        ])),
        pw.Text('${t('رقم التقرير: ','Report ID: ')}${snapshot.reportId}', style: pw.TextStyle(font: regular, fontSize: 7)),
      ]),
    );
  }
  pw.Widget footer(pw.Context context)=>pw.Container(padding:const pw.EdgeInsets.only(top:5),decoration:const pw.BoxDecoration(border:pw.Border(top:pw.BorderSide(color:PdfColors.grey300))),child:pw.Row(children:[pw.Expanded(child:pw.Text('${t('صادر عن: ','Issued by: ')}${user?.name ?? t('النظام','System')}',style:pw.TextStyle(font:regular,fontSize:7))),pw.Text(t('صفحة ${context.pageNumber} من ${context.pagesCount}','Page ${context.pageNumber} of ${context.pagesCount}'),style:pw.TextStyle(font:bold,fontSize:7))]));
  pw.MultiPage page()=>pw.MultiPage(pageFormat:PdfPageFormat.a4,margin:const pw.EdgeInsets.fromLTRB(28,32,28,32),header:header,footer:footer,theme:pw.ThemeData.withFont(base:regular,bold:bold),build:(_)=>[pw.Directionality(textDirection:english ? pw.TextDirection.ltr : pw.TextDirection.rtl,child:pw.Column(children:build()))]);
}
