import 'package:flutter/material.dart';

const navy = Color(0xFF063C35);
const navy2 = Color(0xFF0B6657);
const gold = Color(0xFF22B8A7);
const bg = Color(0xFFF2F8F5);

const cleanOpsBg = Color(0xFFF3F8F5);
const cleanOpsSurface = Color(0xFFFFFFFF);
const cleanOpsSurface2 = Color(0xFFEAF4EF);
const cleanOpsBorder = Color(0xFFD8E8E0);
const cleanOpsText = Color(0xFF173B35);
const cleanOpsMuted = Color(0xFF6B8580);

const green = Color(0xFF159A70);
const orange = Color(0xFFF59E0B);
const red = Color(0xFFEF4444);

const roles = [
  'donor_manager',
  'jsc_coordinator',
  'municipality_coordinator',
  'group_supervisor',
  'worker'
];

const roleNames = {
  'donor_manager': 'مدير المنظومة',
  'jsc_coordinator': 'منسق مجلس الخدمات',
  'municipality_coordinator': 'منسق البلدية',
  'group_supervisor': 'مشرف المجموعة',
  'worker': 'عامل ميداني'
};

const allFeatures = {
  'attendance': 'الحضور والغياب',
  'leave': 'الإجازات والأذونات',
  'trips': 'النقلات والكارو',
  'streets': 'توثيق الشوارع',
  'emergency': 'الطوارئ',
  'notifications': 'الإشعارات',
  'activity': 'آخر النشاط',
  'reports': 'التقارير والتحليل',
  'workers': 'العمال والمجموعات',
  'excel': 'استيراد/تصدير Excel',
  'operations': 'مركز العمليات',
  'permissions': 'الصلاحيات الديناميكية',
  'settings': 'الإعدادات',
  'sync': 'المزامنة والتخزين',
  'critical_areas': 'المناطق الحرجة',
  'cycle': 'دورات العمل',
  'dumpsite': 'إدارة المكبات',
  'users': 'إدارة المستخدمين',
  'dashboard': 'مركز القيادة',
  'messages': 'مركز الرسائل',
  'containers': 'إدارة الحاويات',
};
