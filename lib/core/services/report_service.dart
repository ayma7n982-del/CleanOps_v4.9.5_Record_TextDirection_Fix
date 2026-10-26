import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../constants/app_constants.dart';
import '../models/core_models.dart';
import 'data_service.dart';
import 'pdf_file_saver.dart';
import 'report_pdf_template.dart';

class ReportSnapshot {
  final int trips, alternativeTrips, attendance, absence, ppeCompliant, emergencies, emergencyOpen, emergencySecured;
  final int containersTotal, containersFull, containersPartial, containersEmpty, containerIssues;
  final int workers, supervisors, groups, municipalities, dumpsites, cycleCount;
  final List<String> municipalityNames;
  final Map<String, int> tripsByMunicipality;
  final Map<String, int> attendanceByMunicipality;
  final Map<String, int> absenceByGroup;
  final Map<String, int> containersByMunicipality;
  final Map<String, int> containersByGroup;
  final List<String> cycles;
  final String? selectedMunicipality, selectedGroup, selectedCycle, reportType;
  final double landfillCapacity, heavyMachineryHours;
  final Map<String, int> tripsByGroup;
  final Map<String, int> tripsByDay;
  final Map<String, int> attendanceByGroup;
  final Map<String, int> ppeByGroup;
  final Map<String, int> emergenciesByGroup;
  final Map<String, int> containerByStatus;
  final String reportId;
  final String periodLabel;
  final DateTime generatedAt;

  const ReportSnapshot({
    required this.trips,
    required this.alternativeTrips,
    required this.attendance,
    required this.absence,
    required this.ppeCompliant,
    required this.emergencies,
    required this.emergencyOpen,
    required this.emergencySecured,
    required this.landfillCapacity,
    required this.heavyMachineryHours,
    required this.tripsByGroup,
    required this.tripsByDay,
    required this.attendanceByGroup,
    required this.ppeByGroup,
    required this.emergenciesByGroup,
    required this.containerByStatus,
    required this.containersTotal, required this.containersFull, required this.containersPartial, required this.containersEmpty, required this.containerIssues,
    required this.workers, required this.supervisors, required this.groups, required this.municipalities, required this.dumpsites, required this.cycleCount, required this.municipalityNames,
    required this.tripsByMunicipality, required this.attendanceByMunicipality, required this.absenceByGroup, required this.containersByMunicipality, required this.containersByGroup, required this.cycles,
    this.selectedMunicipality, this.selectedGroup, this.selectedCycle, this.reportType,
    required this.reportId,
    required this.periodLabel,
    required this.generatedAt,
  });

  double get ppeRate => attendance == 0 ? 0 : (ppeCompliant / attendance).clamp(0.0, 1.0).toDouble();
  double get attendanceRate => attendance + absence == 0 ? 0 : (attendance / (attendance + absence)).clamp(0.0, 1.0).toDouble();
}

class ReportService {
  final DataService data;
  ReportService(this.data);

  Future<ReportSnapshot> load({
    int days = 7,
    DateTime? startDate,
    DateTime? endDate,
    AppUser? user,
    String? municipality,
    String? group,
    String? cycle,
    String? reportType,
  }) async {
    final now = DateTime.now();
    final end = DateTime(endDate?.year ?? now.year, endDate?.month ?? now.month, endDate?.day ?? now.day, 23, 59, 59);
    final start = DateTime(startDate?.year ?? now.subtract(Duration(days: math.max(1, days) - 1)).year, startDate?.month ?? now.subtract(Duration(days: math.max(1, days) - 1)).month, startDate?.day ?? now.subtract(Duration(days: math.max(1, days) - 1)).day);
    int trips = 0, alternativeTrips = 0, attendance = 0, absence = 0, ppe = 0, emergencies = 0, emergencyOpen = 0, emergencySecured = 0;
    int containersTotal = 0, containersFull = 0, containersPartial = 0, containersEmpty = 0, containerIssues = 0, dumpsites = 0;
    double landfill = 0, heavyMachineryHours = 0;
    final byGroup = <String, int>{}, byDay = <String, int>{}, attendanceByGroup = <String,int>{}, ppeByGroup = <String,int>{}, emergenciesByGroup = <String,int>{}, containerByStatus = <String,int>{};
    final tripsByMunicipality = <String,int>{}, attendanceByMunicipality = <String,int>{}, absenceByGroup = <String,int>{}, containersByMunicipality = <String,int>{}, containersByGroup = <String,int>{};
    final groups = <String>{}, municipalities = <String>{}, workers = <String>{}, supervisors = <String>{};

    if (Firebase.apps.isNotEmpty) {
      try {
        Query<Map<String, dynamic>> usersQuery = FirebaseFirestore.instance.collection('users').limit(1000);
        if (user?.role == 'municipality_coordinator') {
          usersQuery = FirebaseFirestore.instance.collection('users').where('municipalityCoordinatorId', isEqualTo: user!.id).limit(1000);
        }
        final userSnap = await usersQuery.get();
        for (final d in userSnap.docs) {
          final m = d.data();
          if (m['isActive'] == false) continue;
          final mun = '${m['municipalityName'] ?? m['municipality'] ?? m['scope'] ?? 'غير محددة'}';
          final grp = '${m['groupName'] ?? m['groupId'] ?? 'غير محددة'}';
          if (!_matchesFilters(m, municipality: municipality, group: group, cycle: cycle)) continue;
          if (mun != 'غير محددة') municipalities.add(mun);
          if (grp != 'غير محددة' && grp.isNotEmpty) groups.add(grp);
          final role = '${m['role'] ?? ''}';
          if (role == 'worker') workers.add(d.id);
          if (role == 'group_supervisor') supervisors.add(d.id);
        }
      } catch (_) {}
    }

    final cached = await data.refreshOperations();
    for (final m in cached) {
      if (m['isDeleted'] == true || !_inDateRange(m, start, end) || !_inScope(m, user)) continue;
      if (!_matchesFilters(m, municipality: municipality, group: group, cycle: cycle)) continue;
      final entity = '${m['_entity'] ?? ''}';
      final mun = '${m['municipalityName'] ?? m['municipality'] ?? m['municipalityId'] ?? 'غير محددة'}';
      final grp = '${m['groupName'] ?? m['groupId'] ?? 'غير محددة'}';
      if (grp != 'غير محددة') groups.add(grp);
      if (mun != 'غير محددة') municipalities.add(mun);
      final workerId = '${m['workerId'] ?? m['userId'] ?? m['reportedBy'] ?? ''}';
      if (workerId.isNotEmpty) workers.add(workerId);
      if (entity == 'trip' || entity == 'trips') {
        trips++; if (m['alternative'] == true || m['cartType'] == 'alternative') alternativeTrips++;
        byGroup[grp]=(byGroup[grp]??0)+1; tripsByMunicipality[mun]=(tripsByMunicipality[mun]??0)+1;
        final created = DateTime.tryParse('${m['createdAt']}') ?? now; final day=DateFormat('MM/dd').format(created); byDay[day]=(byDay[day]??0)+1;
      } else if (entity == 'attendance') {
        final status='${m['status']??''}';
        if (status == 'present' || status == 'حضور') { attendance++; attendanceByGroup[grp]=(attendanceByGroup[grp]??0)+1; attendanceByMunicipality[mun]=(attendanceByMunicipality[mun]??0)+1; if(m['ppeComplete']==true){ppe++; ppeByGroup[grp]=(ppeByGroup[grp]??0)+1;} }
        if (status == 'absent' || status == 'غياب' || status == 'excused_absence' || status == 'unexcused_absence') { absence++; absenceByGroup[grp]=(absenceByGroup[grp]??0)+1; }
      } else if (entity == 'emergency') {
        emergencies++; emergenciesByGroup[grp]=(emergenciesByGroup[grp]??0)+1; final status='${m['status']??'urgent'}'; if(status=='secured'||status=='مؤمنة') emergencySecured++; else emergencyOpen++;
      } else if (entity == 'heavy_machinery') { heavyMachineryHours += (m['hours'] as num?)?.toDouble() ?? 0; }
      else if (entity == 'landfill_status') { final c=(m['capacity'] as num?)?.toDouble(); if(c!=null) landfill=math.max(landfill,c.clamp(0.0,1.0).toDouble()); }
    }

    if (Firebase.apps.isNotEmpty) {
      try {
        final snap = await FirebaseFirestore.instance.collection('containers').get();
        for (final d in snap.docs) {
          final m={'id':d.id,...d.data()};
          final mun='${m['municipalityName'] ?? m['municipalityId'] ?? 'غير محددة'}'; final grp='${m['groupName'] ?? m['groupId'] ?? 'غير محددة'}';
          if (municipality != null && municipality.isNotEmpty && mun != municipality && '${m['municipalityId']}' != municipality) continue;
          if (group != null && group.isNotEmpty && grp != group && '${m['groupId']}' != group) continue;
          if (user != null && user.scope != 'all' && user.scope.isNotEmpty && user.scope != 'assigned_only' && mun != user.scope && '${m['municipalityId']}' != user.id) continue;
          containersTotal++; containersByMunicipality[mun]=(containersByMunicipality[mun]??0)+1; containersByGroup[grp]=(containersByGroup[grp]??0)+1;
          final status='${m['status']??'unknown'}'; containerByStatus[status]=(containerByStatus[status]??0)+1;
          if(status=='full') containersFull++; else if(status=='partial') containersPartial++; else if(status=='empty') containersEmpty++;
          if('${m['issueStatus']??'none'}' != 'none' && '${m['issueStatus']}' != 'verified_resolved') containerIssues++;
        }
      } catch (_) {}
    }

    if (Firebase.apps.isNotEmpty) {
      try {
        final dumpSnap = await FirebaseFirestore.instance.collection('dumpsites').where('isActive', isEqualTo: true).limit(500).get();
        for (final d in dumpSnap.docs) {
          final m = d.data();
          final mun = '${m['municipalityName'] ?? m['municipality'] ?? m['municipalityId'] ?? 'غير محددة'}';
          if (municipality != null && municipality.isNotEmpty && mun != municipality && '${m['municipalityId']}' != municipality) continue;
          dumpsites++;
          if (mun != 'غير محددة') municipalities.add(mun);
        }
      } catch (_) {}
    }

    List<String> cycles=[]; int cycleCount=0;
    if (Firebase.apps.isNotEmpty) { try { final snap=await FirebaseFirestore.instance.collection('work_cycles').orderBy('startDate', descending:true).limit(50).get(); cycles=[for(final d in snap.docs) '${d.data()['name'] ?? d.id}']; cycleCount=snap.docs.length; } catch (_) {} }
    final municipalityNames = municipalities.toList()..sort();
    if (municipality != null && municipality.isNotEmpty && !municipalityNames.contains(municipality)) municipalityNames.insert(0, municipality);
    return ReportSnapshot(trips: trips, alternativeTrips: alternativeTrips, attendance: attendance, absence: absence, ppeCompliant: ppe, emergencies: emergencies, emergencyOpen: emergencyOpen, emergencySecured: emergencySecured, landfillCapacity: landfill, heavyMachineryHours: heavyMachineryHours, tripsByGroup: byGroup, tripsByDay: byDay, attendanceByGroup: attendanceByGroup, ppeByGroup: ppeByGroup, emergenciesByGroup: emergenciesByGroup, containerByStatus: containerByStatus, containersTotal: containersTotal, containersFull: containersFull, containersPartial: containersPartial, containersEmpty: containersEmpty, containerIssues: containerIssues, workers: workers.length, supervisors: supervisors.length, groups: groups.length, municipalities: municipalities.length, dumpsites: dumpsites, cycleCount: cycleCount, municipalityNames: municipalityNames, tripsByMunicipality: tripsByMunicipality, attendanceByMunicipality: attendanceByMunicipality, absenceByGroup: absenceByGroup, containersByMunicipality: containersByMunicipality, containersByGroup: containersByGroup, cycles: cycles, selectedMunicipality: municipality, selectedGroup: group, selectedCycle: cycle, reportType: reportType, reportId: 'CO-${now.millisecondsSinceEpoch}', periodLabel: '${DateFormat('yyyy-MM-dd').format(start)} → ${DateFormat('yyyy-MM-dd').format(end)}', generatedAt: now);
  }

  bool _matchesFilters(Map<String,dynamic> m, {String? municipality, String? group, String? cycle}) {
    final mun='${m['municipalityName'] ?? m['municipality'] ?? m['municipalityId'] ?? ''}'; final grp='${m['groupName'] ?? m['groupId'] ?? ''}'; final cyc='${m['cycleName'] ?? m['cycleId'] ?? ''}';
    if(municipality != null && municipality.isNotEmpty && mun != municipality && '${m['municipalityId']}' != municipality) return false;
    if(group != null && group.isNotEmpty && grp != group && '${m['groupId']}' != group) return false;
    if(cycle != null && cycle.isNotEmpty && cyc != cycle && '${m['cycleId']}' != cycle) return false;
    return true;
  }

  bool _inDateRange(Map<String, dynamic> data, DateTime start, DateTime end) {
    final raw = data['createdAt'] ?? data['date'] ?? data['timestamp'];
    final value = raw is DateTime ? raw : DateTime.tryParse('$raw');
    // Keep undated legacy records visible; date-stamped records obey both bounds.
    return value == null || (!value.isBefore(start) && !value.isAfter(end));
  }

  bool _inScope(Map<String, dynamic> data, AppUser? user) {
    if (user == null || user.scope == 'all') return true;
    final scope = user.scope.trim();
    if (scope.isEmpty || scope == 'assigned_only') {
      final owner = '${data['reportedBy'] ?? data['requestedBy'] ?? data['supervisorId'] ?? data['generatedBy'] ?? ''}';
      return owner.isEmpty || owner == user.id;
    }
    final municipality = '${data['municipality'] ?? data['municipalityName'] ?? ''}'.trim();
    return municipality.isEmpty || municipality == scope;
  }

  Future<String> createSmartReport({
    required AppUser user,
    required ReportSnapshot snapshot,
    String? municipality,
    String? group,
  }) async {
    final attendanceText = snapshot.attendanceRate >= .95 ? 'التزام حضور مرتفع' : 'تحتاج الحضور إلى متابعة';
    final ppeText = snapshot.ppeRate >= .95 ? 'التزام PPE جيد' : 'يوجد احتياج لمراجعة PPE';
    final emergencyText = snapshot.emergencies == 0
        ? 'لا توجد بلاغات طوارئ ضمن البيانات المتاحة'
        : 'توجد بلاغات طوارئ تحتاج متابعة';
    final objective = municipality == null
        ? 'تنفيذ وتوثيق أعمال جمع النفايات ومراقبة السلامة والنقلات.'
        : 'متابعة أداء البلدية وتوثيق الإنجاز الميداني ضمن النطاق المحدد.';
    final summary = 'تم تسجيل ${snapshot.trips} نقلة، مع ${snapshot.alternativeTrips} نقلة بكارة بديلة. $attendanceText، $ppeText. $emergencyText.';
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await data.enqueue('report', 'create', {
      'id': id,
      'type': 'smart_operational',
      'scope': user.scope,
      'municipality': municipality,
      'group': group,
      'generatedBy': user.id,
      'createdAt': DateTime.now().toIso8601String(),
      'objectives': objective,
      'results': summary,
      'shiftSummary': 'موجز الوردية: $summary',
      'status': 'draft',
    });
    await data.writeAudit(actorId: user.id, operation: 'CREATE_SMART_REPORT', targetId: id, after: {'type': 'smart_operational'});
    return summary;
  }

  String autoCaption({required String phase, required String streetName}) =>
      phase == 'before'
          ? 'توثيق حالة الشارع قبل التنفيذ${streetName.isEmpty ? '' : ' — $streetName'}'
          : 'توثيق حالة الشارع بعد التنفيذ${streetName.isEmpty ? '' : ' — $streetName'}';

  Future<List<int>> buildOperationalPdfBytes({ReportSnapshot? snapshot, AppUser? user, String title = 'التقرير التشغيلي لمنظومة جمع النفايات', String languageCode = 'ar'}) async {
    final s = snapshot ?? await load(user: user);
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'));
    final prefs = await SharedPreferences.getInstance();
    pw.ImageProvider? readLogo(String key) {
      final encoded = prefs.getString(key);
      if (encoded == null || encoded.isEmpty) return null;
      try { return pw.MemoryImage(base64Decode(encoded)); } catch (_) { return null; }
    }
    final municipalityLogo = readLogo('report_municipality_logo_base64');
    final councilLogo = readLogo('report_council_logo_base64');
    final unicefLogo = readLogo('report_unicef_logo_base64');
    final configuredMunicipality = prefs.getString('report_municipality_name') ?? '';
    final municipalityName = configuredMunicipality.isNotEmpty ? configuredMunicipality : (s.selectedMunicipality ?? (s.municipalityNames.length == 1 ? s.municipalityNames.first : ''));
    final councilName = prefs.getString('report_council_name') ?? '';
    final projectName = (s.selectedCycle != null && s.selectedCycle!.isNotEmpty) ? s.selectedCycle! : (prefs.getString('report_project_name') ?? '');
    final exportTitle = languageCode == 'en' ? _englishReportTitle(title) : title;
    final doc = pw.Document();
    doc.addPage(ReportPdfTemplate(regular: regular, bold: bold, user: user, title: exportTitle, snapshot: s, languageCode: languageCode, municipalityName: municipalityName, councilName: councilName, projectName: projectName, municipalityLogo: municipalityLogo, councilLogo: councilLogo, unicefLogo: unicefLogo).page());
    return doc.save();
  }

  Future<String?> exportOperationalPdf({ReportSnapshot? snapshot, AppUser? user, String title = 'التقرير التشغيلي لمنظومة جمع النفايات', String languageCode = 'ar'}) async {
    try {
      final s = snapshot ?? await load(user: user);
      final bytes = await buildOperationalPdfBytes(snapshot: s, user: user, title: title, languageCode: languageCode);
      final file = await savePdfBytes(bytes, 'operational_report_${user?.role ?? 'report'}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      if (user != null) await data.writeAudit(actorId: user.id, operation: 'EXPORT_OPERATIONAL_PDF', targetId: s.reportId, after: {'role': user.role, 'period': s.periodLabel, 'languageCode': languageCode});
      return file;
    } catch (e) {
      throw Exception('فشل إنشاء التقرير PDF: $e');
    }
  }

  String _englishReportTitle(String title) {
    const map = <String, String>{
      'تقرير الغياب والحضور — CleanOps': 'Attendance & Absence Report — CleanOps',
      'تقرير الحاويات — CleanOps': 'Container Report — CleanOps',
      'تقرير العمل والتشغيل — CleanOps': 'Work & Operations Report — CleanOps',
      'تقرير الدورات — CleanOps': 'Work Cycles Report — CleanOps',
      'تقرير البلديات — CleanOps': 'Municipality Report — CleanOps',
      'تقرير المجموعات — CleanOps': 'Groups Report — CleanOps',
      'التقرير التنفيذي الشامل — CleanOps': 'Executive Summary Report — CleanOps',
    };
    return map[title] ?? title.replaceAll('التقرير التشغيلي لمنظومة جمع النفايات', 'Solid Waste Operations Report');
  }

}
