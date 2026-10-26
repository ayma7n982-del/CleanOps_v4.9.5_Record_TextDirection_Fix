import 'core/localization.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'presentation/screens/reports_center.dart';
import 'core/constants/app_constants.dart';
import 'core/models/core_models.dart';
import 'core/services/auth_service.dart';
import 'core/services/config_service.dart';
import 'core/services/data_service.dart';
import 'core/services/local_store.dart';
import 'core/services/operations_admin_service.dart';
import 'core/services/messaging_service.dart';
import 'core/services/gps_tracking_service.dart';
import 'core/services/container_service.dart';
import 'presentation/screens/operations_management.dart';
import 'presentation/screens/level1_supervisor.dart';
import 'presentation/screens/level2_municipality.dart';
import 'presentation/screens/level3_jsc.dart';
import 'presentation/screens/level4_unicef.dart';
import 'presentation/screens/enterprise_login.dart';
import 'presentation/screens/ai_bot_screen.dart';
import 'presentation/screens/ai_command_center.dart';
import 'presentation/screens/messages_center.dart';
import 'presentation/screens/live_operations_map.dart';
import 'presentation/screens/user_management_settings.dart';
import 'presentation/screens/enterprise_settings_pages.dart';
import 'presentation/screens/enterprise_operations_hub.dart';
import 'presentation/screens/container_management.dart';
import 'presentation/screens/equipment_search.dart';
import 'presentation/screens/global_search.dart';
import 'presentation/widgets/app_design.dart';
import 'presentation/widgets/creative_shortcuts.dart';
import 'presentation/widgets/smart_excel_import.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';

class AppIcon extends StatelessWidget {
  final double size;
  const AppIcon({super.key, this.size = 52});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * .28),
      boxShadow: [BoxShadow(color: aiCyan.withOpacity(.22), blurRadius: 16, spreadRadius: 1)],
    ),
    clipBehavior: Clip.antiAlias,
    child: Image.asset('assets/app_icon.png', width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: aiDark2, alignment: Alignment.center, child: Icon(Icons.eco_rounded, size: size * .66, color: aiCyan))),
  );
}

class FeatureIcon extends StatelessWidget {
  final String feature;
  final double size;
  const FeatureIcon(this.feature, {super.key, this.size = 30});
  @override
  Widget build(BuildContext context) => AiFeatureIcon(feature, size: size * .62);
}

class FeatureIconPainter extends CustomPainter {
  final String f;
  FeatureIconPainter(this.f);
  @override
  void paint(Canvas c, Size s) {
    final stroke = Paint()..style=PaintingStyle.stroke..strokeWidth=s.width*.09..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round..color=navy2;
    final fill = Paint()..color=gold;
    final x=s.width*.5,y=s.height*.5;
    if(f=='attendance'||f=='leave'){c.drawCircle(Offset(x,y*.72),s.width*.16,stroke);c.drawArc(Rect.fromCircle(center:Offset(x,y*.98),radius:s.width*.28),math.pi,math.pi,false,stroke); if(f=='attendance'){c.drawLine(Offset(x*.92,y*.72),Offset(x*1.03,y*.82),stroke);c.drawLine(Offset(x*1.03,y*.82),Offset(x*1.18,y*.62),stroke);}else{c.drawCircle(Offset(x*1.35,y*.52),s.width*.12,fill);}}
    else if(f=='trips'){final p=Path()..moveTo(s.width*.18,s.height*.56)..lineTo(s.width*.72,s.height*.56)..lineTo(s.width*.82,s.height*.38)..lineTo(s.width*.52,s.height*.38)..lineTo(s.width*.42,s.height*.24)..lineTo(s.width*.24,s.height*.24)..close();c.drawPath(p,stroke);c.drawCircle(Offset(s.width*.33,s.height*.72),s.width*.10,stroke);c.drawCircle(Offset(s.width*.72,s.height*.72),s.width*.10,stroke);}
    else if(f=='streets'){c.drawLine(Offset(s.width*.2,s.height*.8),Offset(s.width*.45,s.height*.2),stroke);c.drawLine(Offset(s.width*.8,s.height*.8),Offset(s.width*.55,s.height*.2),stroke);c.drawCircle(Offset(x,s.height*.48),s.width*.12,stroke);}
    else if(f=='emergency'){c.drawPath(Path()..moveTo(x,s.height*.15)..lineTo(s.width*.83,s.height*.8)..lineTo(s.width*.17,s.height*.8)..close(),stroke);c.drawLine(Offset(x,s.height*.36),Offset(x,s.height*.58),stroke);c.drawCircle(Offset(x,s.height*.69),s.width*.025,fill);}
    else if(f=='reports'||f=='dashboard'||f=='operations'){c.drawRect(Rect.fromLTWH(s.width*.2,s.height*.2,s.width*.6,s.height*.6),stroke);c.drawLine(Offset(s.width*.32,s.height*.66),Offset(s.width*.32,s.height*.52),stroke);c.drawLine(Offset(s.width*.5,s.height*.66),Offset(s.width*.5,s.height*.4),stroke);c.drawLine(Offset(s.width*.68,s.height*.66),Offset(s.width*.68,s.height*.3),stroke);}
    else if(f=='notifications'){c.drawArc(Rect.fromLTWH(s.width*.24,s.height*.18,s.width*.52,s.height*.58),math.pi,math.pi, false,stroke);c.drawLine(Offset(s.width*.2,s.height*.76),Offset(s.width*.8,s.height*.76),stroke);c.drawCircle(Offset(x,s.height*.84),s.width*.06,fill);}
    else if(f=='activity'){c.drawCircle(Offset(x,y),s.width*.3,stroke);c.drawLine(Offset(x,y),Offset(x,s.height*.3),stroke);c.drawLine(Offset(x,y),Offset(s.width*.68,s.height*.62),stroke);}
    else if(f=='workers'){c.drawCircle(Offset(s.width*.38,s.height*.38),s.width*.12,stroke);c.drawCircle(Offset(s.width*.68,s.height*.38),s.width*.12,stroke);c.drawArc(Rect.fromLTWH(s.width*.2,s.height*.5,s.width*.36,s.width*.3),math.pi,math.pi,false,stroke);c.drawArc(Rect.fromLTWH(s.width*.5,s.height*.5,s.width*.36,s.height*.3),math.pi,math.pi,false,stroke);}
    else if(f=='excel'){c.drawRect(Rect.fromLTWH(s.width*.2,s.height*.18,s.width*.6,s.height*.64),stroke);c.drawLine(Offset(s.width*.2,s.height*.4),Offset(s.width*.8,s.height*.4),stroke);c.drawLine(Offset(s.width*.5,s.height*.18),Offset(s.width*.5,s.height*.82),stroke);}
    else if(f=='permissions'){c.drawPath(Path()..moveTo(x,s.height*.15)..lineTo(s.width*.8,s.height*.3)..lineTo(s.width*.72,s.height*.7)..lineTo(x,s.height*.86)..lineTo(s.width*.28,s.height*.7)..lineTo(s.width*.2,s.height*.3)..close(),stroke);c.drawCircle(Offset(x,s.height*.48),s.width*.09,stroke);}
    else if(f=='critical_areas'){c.drawCircle(Offset(x,y),s.width*.28,stroke);c.drawLine(Offset(x,y*.72),Offset(x,y*1.15),stroke);c.drawCircle(Offset(x,y*.72),s.width*.08,fill);}
    else if(f=='settings'||f=='sync'){c.drawCircle(Offset(x,y),s.width*.2,stroke); for(var i=0;i<8;i++){final a=i*math.pi/4;c.drawLine(Offset(x+math.cos(a)*s.width*.3,y+math.sin(a)*s.height*.3),Offset(x+math.cos(a)*s.width*.42,y+math.sin(a)*s.height*.42),stroke);}}
    else {c.drawCircle(Offset(x,y),s.width*.3,stroke);}
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState()=>_SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState(){
    super.initState();
    controller=AnimationController(vsync:this,duration:const Duration(milliseconds:2200))..forward();
    Future.delayed(const Duration(milliseconds: 2450), () {
      if (!mounted) return;
      final auth = context.read<AuthService>();
      final user = auth.currentUser;
      final destination = user == null
          ? const EnterpriseLoginScreen()
          : (user.role == 'donor_manager' && !(context.read<SetupState>().complete)
              ? const SetupWizardPage()
              : const AppShell());
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => destination));
    });
  }

  @override
  void dispose(){controller.dispose();super.dispose();}

  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor: const Color(0xFF020B15),
    body: AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = Curves.easeOutCubic.transform(controller.value);
        final pulse = .5 + .5 * math.sin(controller.value * math.pi * 2.2);
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _CleanOpsSplashPainter(progress: t, pulse: pulse)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: .72 + .28 * t + .015 * pulse,
                    child: Opacity(
                      opacity: Curves.easeOut.transform(controller.value.clamp(0.0, 1.0)),
                      child: Container(
                        width: 250,
                        height: 250,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [aiCyan.withOpacity(.16), aiGreen.withOpacity(.06), Colors.transparent]),
                          boxShadow: [
                            BoxShadow(color: aiCyan.withOpacity(.16 + .12 * pulse), blurRadius: 46 + 18 * pulse, spreadRadius: 8),
                            BoxShadow(color: aiGreen.withOpacity(.10), blurRadius: 80, spreadRadius: 10),
                          ],
                        ),
                        child: Image.asset(
                          'assets/app_icon.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) => const Icon(Icons.eco_rounded, size: 130, color: aiCyan),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Opacity(
                    opacity: ((controller.value - .25) / .55).clamp(0.0, 1.0),
                    child: const AppText('CleanOps', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: .4)),
                  ),
                  const SizedBox(height: 5),
                  Opacity(
                    opacity: ((controller.value - .40) / .45).clamp(0.0, 1.0),
                    child: const AppText('Solid Waste Operations', style: TextStyle(color: aiCyan, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 150,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        value: controller.value,
                        backgroundColor: Colors.white.withOpacity(.06),
                        color: aiGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Opacity(opacity: ((controller.value - .55) / .35).clamp(0.0, 1.0), child: const AppText('معًا نحو بيئة أنظف', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700))),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _CleanOpsSplashPainter extends CustomPainter {
  final double progress;
  final double pulse;
  _CleanOpsSplashPainter({required this.progress, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 12);
    final maxR = math.max(size.width, size.height) * .68;
    final bg = Paint()..shader = RadialGradient(colors: [const Color(0xFF06314A), const Color(0xFF031525), const Color(0xFF020B15)], stops: const [.0, .48, 1.0]).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    for (var i = 0; i < 4; i++) {
      final phase = ((progress * 1.15) + i * .22) % 1.0;
      final radius = maxR * (.10 + phase * .90);
      final alpha = (1 - phase) * .22;
      final ring = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.3 + (1 - phase) * 1.5..color = (i.isEven ? aiCyan : aiGreen).withOpacity(alpha);
      canvas.drawCircle(center, radius, ring);
    }

    final glow = Paint()..shader = RadialGradient(colors: [aiCyan.withOpacity(.16 + .08 * pulse), aiGreen.withOpacity(.04), Colors.transparent]).createShader(Rect.fromCircle(center: center, radius: maxR * .46));
    canvas.drawCircle(center, maxR * .46, glow);

    for (var i = 0; i < 26; i++) {
      final a = (i * math.pi * 2 / 26) + progress * math.pi * 1.4;
      final r = maxR * (.20 + (i % 5) * .055);
      final p = center + Offset(math.cos(a) * r, math.sin(a) * r);
      final dot = Paint()..color = (i.isEven ? aiCyan : aiGreen).withOpacity(.18 + .55 * pulse);
      canvas.drawCircle(p, 1.2 + (i % 3) * .55, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _CleanOpsSplashPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.pulse != pulse;
}

class SetupWizardPage extends StatefulWidget {
  const SetupWizardPage({super.key});
  @override State<SetupWizardPage> createState()=>_SetupWizardState();
}

class _SetupWizardState extends State<SetupWizardPage>{
  int step=0;
  final titles=['بيانات المؤسسة','البلديات والمناطق','المجموعات','المستخدمون والصلاحيات','التشغيل والورديات','الصور والتخزين','الإشعارات','المناطق الحرجة','التقارير والتحليلات','المراجعة والتشغيل'];
  final icons=[Icons.business_rounded,Icons.map_rounded,Icons.groups_rounded,Icons.admin_panel_settings_rounded,Icons.schedule_rounded,Icons.photo_library_rounded,Icons.notifications_active_rounded,Icons.warning_amber_rounded,Icons.insights_rounded,Icons.rocket_launch_rounded];

  @override
  Widget build(BuildContext context){
    final width=MediaQuery.sizeOf(context).width;
    final progress=(step+1)/titles.length;
    return Scaffold(
      backgroundColor:cleanOpsBg,
      appBar:AppBar(title:const AppText('معالج إعداد المنظومة'),centerTitle:true),
      body:ListView(
        padding:EdgeInsets.fromLTRB(width<500?14:24,14,width<500?14:24,22),
        children:[
          Container(
            padding:const EdgeInsets.all(18),
            decoration:BoxDecoration(
              gradient:const LinearGradient(colors:[Color(0xFF041522),Color(0xFF0A3045),Color(0xFF063B3B)],begin:Alignment.topLeft,end:Alignment.bottomRight),
              borderRadius:BorderRadius.circular(26),
              border:Border.all(color:aiCyan.withOpacity(.16)),
              boxShadow:[BoxShadow(color:aiCyan.withOpacity(.08),blurRadius:30,offset:const Offset(0,12))],
            ),
            child:Row(children:[
              Container(width:62,height:62,decoration:BoxDecoration(shape:BoxShape.circle,gradient:const LinearGradient(colors:[aiBlue,aiGreen]),boxShadow:[BoxShadow(color:aiCyan.withOpacity(.28),blurRadius:22)]),child:Icon(icons[step],color:Colors.white,size:28)),
              const SizedBox(width:14),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const AppText('CLEANOPS SETUP',style:TextStyle(color:aiCyan,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:1.2)),
                const SizedBox(height:4),
                AppText(titles[step],style:const TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),
                const SizedBox(height:3),
                AppText('الخطوة ${step+1} من ${titles.length}',style:const TextStyle(color:Colors.white70,fontSize:10,fontWeight:FontWeight.w700)),
              ])),
              Text('${(progress*100).round()}%',style:const TextStyle(color:aiGreen,fontSize:18,fontWeight:FontWeight.w900)),
            ]),
          ),
          const SizedBox(height:12),
          ClipRRect(borderRadius:BorderRadius.circular(20),child:LinearProgressIndicator(minHeight:5,value:progress,backgroundColor:Colors.white.withOpacity(.06),color:aiGreen)),
          const SizedBox(height:14),
          AiSectionCard(
            title:'إعداد ${titles[step]}',
            subtitle:'تهيئة أساسية قبل تشغيل المنظومة',
            feature:'settings',
            child:Column(children:[
              Container(
                width:double.infinity,
                padding:const EdgeInsets.all(16),
                decoration:BoxDecoration(color:aiDark2.withOpacity(.55),borderRadius:BorderRadius.circular(18),border:Border.all(color:aiCyan.withOpacity(.10))),
                child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  const AiFeatureIcon('settings',size:18),
                  const SizedBox(width:11),
                  const Expanded(child:AppText('يمكن ضبط هذه الإعدادات الآن أو تعديلها لاحقًا من مركز إعدادات المنظومة. لا يتم إنشاء بيانات تشغيلية تجريبية في هذه الخطوة.',style:TextStyle(color:cleanOpsMuted,fontSize:12,height:1.55))),
                ]),
              ),
              const SizedBox(height:14),
              Wrap(spacing:7,runSpacing:7,children:List.generate(titles.length,(i)=>Container(width:9,height:9,decoration:BoxDecoration(shape:BoxShape.circle,color:i==step?aiGreen:i<step?aiCyan:Colors.white.withOpacity(.12))))),
            ]),
          ),
          const SizedBox(height:14),
          Row(children:[
            if(step>0)Expanded(child:OutlinedButton.icon(onPressed:()=>setState(()=>step--),icon:const Icon(Icons.arrow_back_rounded),label:const AppText('السابق'))),
            if(step>0)const SizedBox(width:10),
            Expanded(child:FilledButton.icon(
              onPressed:()async{
                if(step<titles.length-1){
                  setState(()=>step++);
                }else{
                  final p=await SharedPreferences.getInstance();
                  await p.setBool('setup_complete',true);
                  context.read<SetupState>().complete=true;
                  context.read<SetupState>().notifyListeners();
                  if(mounted)Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const AppShell()));
                }
              },
              icon:Icon(step==titles.length-1?Icons.rocket_launch_rounded:Icons.arrow_forward_rounded),
              label:AppText(step==titles.length-1?'تشغيل المنظومة':'التالي'),
            )),
          ]),
        ],
      ),
    );
  }
}

class AppShell extends StatefulWidget{
  const AppShell({super.key});
  @override State<AppShell> createState()=>_AppShellState();
}

class _AppShellState extends State<AppShell>{
  int index=0;
  String? _boundMessagingUserId;
  @override void initState(){
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final u=context.read<AuthService>().currentUser;
      if(u!=null) context.read<ConfigService>().attachRole(u.role);
      _syncMessagingBinding(u);
      unawaited(context.read<ContainerService>().attachUser(u));
    });
  }
  void _syncMessagingBinding(AppUser? user) {
    final id = user?.id;
    if (_boundMessagingUserId == id) return;
    _boundMessagingUserId = id;
    unawaited(context.read<MessagingService>().attachUser(user));
    unawaited(context.read<ContainerService>().attachUser(user));
  }

  List<Widget> _pages(AppUser u){
    return [const AICommandCenter(),const OperationsPage(),const AIBotScreen(),const ReportsPage(),const SettingsPage()];
  }
  @override Widget build(BuildContext context){
    final auth=context.watch<AuthService>();
    final data=context.watch<DataService>();
    final user=auth.currentUser;
    _syncMessagingBinding(user);
    if(user==null) return const EnterpriseLoginScreen();
    final pages=_pages(user);
    final titles=['مركز القيادة','العمليات','المساعد الذكي','التقارير','الإعدادات'];
    return Directionality(
      textDirection:context.watch<LocaleController>().isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child:Scaffold(
        backgroundColor:cleanOpsBg,
        appBar:AppBar(
          title:AppText(titles[index]),
          actions:[
            if(data.queue.isNotEmpty)
              Padding(
                padding:const EdgeInsets.symmetric(horizontal:8),
                child:Center(
                  child:Badge(
                    label:AppText('${data.queue.length}'),
                    child:IconButton(onPressed:data.syncing?null:data.sync,icon:Icon(data.syncing?Icons.sync:Icons.cloud_upload_outlined)),
                  ),
                ),
              ),
            IconButton(
              tooltip: tr('البحث الذكي'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalSearchPage())),
              icon: const Icon(Icons.search_rounded),
            ),
            Builder(builder: (context) {
              final messaging = context.watch<MessagingService>();
              return Badge(
                isLabelVisible: messaging.unreadCount > 0,
                label: Text('${messaging.unreadCount}'),
                child: IconButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const MessagesCenterScreen())), icon:const Icon(Icons.forum_outlined)),
              );
            }),
            IconButton(
              onPressed:()=>showNotifications(context),
              icon:Badge(isLabelVisible:data.notifications.any((n)=>!n.read),child:const Icon(Icons.notifications_none)),
            ),
          ],
        ),
        drawer:AppDrawer(user:user,onNavigate:(i){setState(()=>index=i);Navigator.pop(context);}),
        body:pages[index],
        bottomNavigationBar:NavigationBar(
          selectedIndex:index,
          onDestinationSelected:(i)=>setState(()=>index=i),
          destinations:[
            NavigationDestination(icon:const FeatureIcon('dashboard'),label: tr('مركز القيادة')),
            NavigationDestination(icon:const FeatureIcon('operations'),label: tr('العمليات')),
            NavigationDestination(icon:const Icon(Icons.auto_awesome_rounded),label: tr('المساعد الذكي')),
            NavigationDestination(icon:const FeatureIcon('reports'),label: tr('التقارير')),
            NavigationDestination(icon:const FeatureIcon('settings'),label: tr('الإعدادات')),
          ],
        ),
        floatingActionButton:user.can('attendance','create')
            ? FloatingActionButton.extended(onPressed:()=>quickAction(context),icon:const Icon(Icons.add),label:const AppText('إجراء سريع'))
            : null,
      ),
    );
  }
  void showNotifications(BuildContext context){Navigator.push(context,MaterialPageRoute(builder:(_)=>const NotificationsPage()));}
}

class AppDrawer extends StatelessWidget {
  final AppUser user;
  final void Function(int) onNavigate;
  const AppDrawer({super.key, required this.user, required this.onNavigate});
  @override
  Widget build(BuildContext context) {
    bool visible(String feature) => user.can(feature, 'view');
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              color: navy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const AppIcon(size: 50),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(user.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                          AppText(roleNames[user.role] ?? '', style: const TextStyle(color: gold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (visible('activity')) _item(context, 'activity', 'آخر النشاط', Icons.timeline, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityPage()))),
            if (visible('workers')) _item(context, 'workers', 'العمال والمجموعات', Icons.groups_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkersPage()))),
            if (visible('excel')) _item(context, 'excel', 'استيراد Excel', Icons.table_view_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExcelPage()))),
            if (visible('permissions')) _item(context, 'permissions', 'الصلاحيات الديناميكية', Icons.admin_panel_settings_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PermissionsPage()))),
            if (visible('audit')) _item(context, 'audit', 'سجل التدقيق', Icons.security_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuditPage()))),
            if (user.role == 'donor_manager' || user.role == 'municipality_coordinator') _item(context, 'users', 'إدارة المستخدمين', Icons.manage_accounts_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementSettingsPage()))),
            _item(context, 'operations', 'مركز الإدارة والتشغيل', Icons.hub_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EnterpriseOperationsHubPage()))),
            _item(context, 'messages', 'مركز الرسائل', Icons.forum_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesCenterScreen()))),
            if (user.role == 'donor_manager' || user.role == 'jsc_coordinator') _item(context, 'critical_areas', 'خريطة العمليات', Icons.map_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveOperationsMapScreen()))),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.dashboard_customize_outlined, color: Color(0xFF00B4DB)),
              title: const AppText('مساحة العمل'),
              subtitle: const AppText('واجهة العمل الخاصة بالدور الحالي'),
              onTap: () {
                Navigator.pop(context);
                final Widget page = switch (user.role) {
                  'group_supervisor' || 'worker' => const Level1SupervisorScreen(),
                  'municipality_coordinator' => const Level2MunicipalityScreen(),
                  'jsc_coordinator' => const Level3JscScreen(),
                  'donor_manager' => const Level4UnicefScreen(),
                  _ => const DashboardPage(),
                };
                Navigator.push(context, MaterialPageRoute(builder: (_) => page));
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: red),
              title: const AppText('تسجيل الخروج'),
              onTap: () => context.read<AuthService>().logout(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, String feature, String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: FeatureIcon(feature, size: 28),
      title: AppText(title),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onTap: onTap,
    );
  }
}

class DashboardPage extends StatelessWidget{
  const DashboardPage({super.key});
  @override Widget build(BuildContext context){
    final user=context.watch<AuthService>().currentUser!;
    final data=context.watch<DataService>();
    final config=context.watch<ConfigService>();
    return ListView(
      padding:const EdgeInsets.all(16),
      children:[
        HeaderCard(user:user,online:data.online,queue:data.queue.length),
        const SizedBox(height:14),
        FutureBuilder<Map<String,dynamic>>(
          future:context.read<OperationsAdminService>().liveOperationalSnapshot(user),
          builder:(context,snap){
            if(!snap.hasData)return const SizedBox(height:96,child:Center(child:CircularProgressIndicator()));
            final x=snap.data!;
            final cards=<Widget>[];
            void add(String f,String title,String value,String subtitle){if(user.can(f,'view'))cards.add(StatCard(icon:FeatureIcon(f,size:32),title:title,value:value,subtitle:subtitle));}
            add('workers','العاملون النشطون','${x['activeUsers']}','من بيانات المستخدمين');
            add('trips','الترحيلات','${x['trips']}','سجلات تشغيلية');
            add('workers','المجموعات','${x['groups']}','مجموعات مرتبطة');
            add('emergency','الطوارئ','${x['emergencies']}','سجلات حرجة');
            return Wrap(spacing:12,runSpacing:12,children:cards);
          },
        ),
        const SizedBox(height:16),
        if(user.can('operations','view'))
          CardSection(
            title:'مركز التشغيل',
            icon:const FeatureIcon('operations'),
            child:Column(
              children:[
                _line('حالة النظام',data.online?'متصل':'غير متصل',data.online?green:orange),
                _line('آخر مزامنة',data.lastSync,navy2),
                _line('صور الرفع', '${config.imageTargetKb >= 1024 ? '1 MB' : '${config.imageTargetKb} KB'}',navy2),
              ],
            ),
          ),
        if(user.can('notifications','view'))const SizedBox(height:14),
        if(user.can('notifications','view'))const NotificationsPreview(),
      ],
    );
  }
  Widget _line(String a,String b,Color c)=>Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Row(children:[Expanded(child:AppText(a)),AppText(b,style:TextStyle(fontWeight:FontWeight.bold,color:c))]));
}

class HeaderCard extends StatelessWidget{
  final AppUser user;
  final bool online;
  final int queue;
  const HeaderCard({super.key,required this.user,required this.online,required this.queue});
  @override Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.all(20),
    decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF061A2A),Color(0xFF0A2A43),Color(0xFF006A72)]),borderRadius:BorderRadius.circular(30),boxShadow:const [BoxShadow(color:Color(0x2200B4DB),blurRadius:26,offset:Offset(0,10))]),
    child:Row(
      children:[
        SizedBox(width:64,height:64,child:Image.asset('assets/app_icon.png',fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Icon(Icons.eco_rounded,size:42,color:aiCyan))),
        const SizedBox(width:14),
        Expanded(
          child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              const AppText('AI OPERATIONS',style:TextStyle(color:Color(0xFF18D7FF),fontSize:11,fontWeight:FontWeight.w900,letterSpacing:1.2)),
              AppText('مرحبًا، ${user.name}',style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:Colors.white),overflow:TextOverflow.ellipsis),
              AppText(roleNames[user.role]??'',style:const TextStyle(color:Color(0xFF00E676),fontWeight:FontWeight.w700,fontSize:12)),
              const SizedBox(height:8),
              Row(
                children:[
                  Icon(online?Icons.cloud_done:Icons.cloud_off,color:online?Colors.greenAccent:Colors.orangeAccent,size:17),
                  const SizedBox(width:6),
                  AppText(online?'متصل بالسحابة':'وضع Offline',style:const TextStyle(color:Colors.white70,fontSize:11)),
                  if(queue>0)...[const SizedBox(width:14),AppText('$queue بانتظار المزامنة',style:const TextStyle(color:Colors.white70,fontSize:11))],
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class StatCard extends StatelessWidget{
  final Widget icon;
  final String title,value,subtitle;
  const StatCard({super.key,required this.icon,required this.title,required this.value,required this.subtitle});
  @override Widget build(BuildContext context)=>SizedBox(
    width:MediaQuery.of(context).size.width>900?260:MediaQuery.of(context).size.width>600?230:(MediaQuery.of(context).size.width-44)/2,
    child:Card(
      child:Padding(
        padding:const EdgeInsets.all(16),
        child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            icon,
            const SizedBox(height:12),
            AppText(title,style:const TextStyle(color:cleanOpsMuted)),
            const SizedBox(height:4),
            AppText(value,style:const TextStyle(fontSize:28,fontWeight:FontWeight.w900,color:cleanOpsText)),
            AppText(subtitle,style:const TextStyle(fontSize:12,color:cleanOpsMuted)),
          ],
        ),
      ),
    ),
  );
}

class CardSection extends StatelessWidget{
  final String title;
  final Widget icon,child;
  const CardSection({super.key,required this.title,required this.icon,required this.child});
  @override Widget build(BuildContext context)=>Card(
    child:Padding(
      padding:const EdgeInsets.all(16),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          Row(children:[icon,const SizedBox(width:10),AppText(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:cleanOpsText))]),
          const Divider(height:24,color:cleanOpsBorder),
          child,
        ],
      ),
    ),
  );
}

class NotificationsPreview extends StatelessWidget {
  const NotificationsPreview({super.key});
  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final child = data.notifications.isEmpty
        ? const AppText('لا توجد إشعارات جديدة')
        : Column(
            children: data.notifications.take(4).map((n) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: StatusDot(level: n.level),
                title: AppText(n.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: AppText(n.body),
                trailing: AppText(DateFormat('HH:mm').format(DateTime.tryParse(n.createdAt) ?? DateTime.now())),
              );
            }).toList(),
          );
    return CardSection(title: 'آخر الإشعارات', icon: const FeatureIcon('notifications'), child: child);
  }
}

class StatusDot extends StatelessWidget{
  final String level;
  const StatusDot({super.key,required this.level});
  @override Widget build(BuildContext context)=>CircleAvatar(
    radius:17,
    backgroundColor:level=='critical'?red.withOpacity(.12):level=='warning'?orange.withOpacity(.12):green.withOpacity(.12),
    child:Icon(level=='critical'?Icons.priority_high:level=='warning'?Icons.notifications_active_outlined:Icons.check,color:level=='critical'?red:level=='warning'?orange:green,size:18),
  );
}

class OperationsPage extends StatefulWidget {
  const OperationsPage({super.key});
  @override State<OperationsPage> createState() => _OperationsState();
}

class _OperationsState extends State<OperationsPage> {
  String search = '';
  @override Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser!;
    final data = context.watch<DataService>();
    const features = ['attendance', 'leave', 'trips', 'streets', 'emergency'];
    final query = search.trim().toLowerCase();
    final cards = features.where((feature) {
      if (!user.can(feature, 'view')) return false;
      final title = I18n.tr(allFeatures[feature]!, context.read<LocaleController>().locale.languageCode);
      return title.toLowerCase().contains(query);
    }).map((feature) => ActionCard(feature: feature, title: allFeatures[feature]!, onTap: () => openFeature(context, feature))).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          onChanged: (value) => setState(() => search = value),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'بحث في العمليات', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 14),
        Wrap(spacing: 12, runSpacing: 12, children: cards),
        const SizedBox(height: 16),
        CardSection(
          title: 'حالة المزامنة',
          icon: const FeatureIcon('sync'),
          child: Column(
            children: [
              ListTile(
                leading: Icon(data.online ? Icons.cloud_done : Icons.cloud_off, color: data.online ? green : orange),
                title: AppText(data.online ? 'متصل' : 'Offline'),
                subtitle: AppText('آخر مزامنة: ${data.lastSync}'),
                trailing: FilledButton.tonalIcon(
                  onPressed: data.queue.isEmpty ? null : data.sync,
                  icon: const Icon(Icons.sync),
                  label: AppText('${data.queue.length}'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ActionCard extends StatelessWidget {
  final String feature;
  final String title;
  final VoidCallback onTap;
  const ActionCard({super.key, required this.feature, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width > 850 ? 250.0 : (MediaQuery.of(context).size.width - 44) / 2;
    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FeatureIcon(feature, size: 38),
                const SizedBox(height: 16),
                AppText(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: cleanOpsText)),
                const SizedBox(height: 6),
                const AppText('فتح الوحدة', style: TextStyle(color: cleanOpsMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void openFeature(BuildContext context, String feature) {
  final role = context.read<AuthService>().currentUser?.role;
  final Widget page = switch(role) {
    'group_supervisor' || 'worker' => const Level1SupervisorScreen(),
    'municipality_coordinator' => const Level2MunicipalityScreen(),
    'jsc_coordinator' => const Level3JscScreen(),
    'donor_manager' => const Level4UnicefScreen(),
    _ => const DashboardPage(),
  };
  Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});
  @override Widget build(BuildContext context) => const ReportsCenterScreen();
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});
  @override Widget build(BuildContext context) {
    final d = context.watch<DataService>();
    return Scaffold(
      appBar: AppBar(title: const AppText('مركز الإشعارات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CardSection(
            title: 'الإشعارات',
            icon: const FeatureIcon('notifications'),
            child: d.notifications.isEmpty
                ? const Padding(padding: EdgeInsets.all(20), child: AppText('لا توجد إشعارات'))
                : Column(
                    children: d.notifications.map((n) => ListTile(
                      onTap: () => d.markRead(n.id),
                      leading: StatusDot(level: n.level),
                      title: AppText(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.w900)),
                      subtitle: AppText(n.body),
                      trailing: AppText(DateFormat('HH:mm').format(DateTime.tryParse(n.createdAt) ?? DateTime.now())),
                    )).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});
  @override Widget build(BuildContext context) {
    final d = context.watch<DataService>();
    return Scaffold(
      appBar: AppBar(title: const AppText('آخر النشاط')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: d.activities.length,
        itemBuilder: (_, i) {
          final a = d.activities[i];
          return Card(
            child: ListTile(
              leading: StatusDot(level: a.level),
              title: AppText(a.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: AppText(a.detail),
              trailing: AppText(DateFormat('HH:mm').format(DateTime.tryParse(a.createdAt) ?? DateTime.now())),
            ),
          );
        },
      ),
    );
  }
}

class WorkersPage extends StatefulWidget {
  const WorkersPage({super.key});
  @override State<WorkersPage> createState() => _WorkersState();
}

class _WorkersState extends State<WorkersPage> {
  final name = TextEditingController();
  final number = TextEditingController();
  @override void dispose() { name.dispose(); number.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final u = context.watch<AuthService>().currentUser!;
    final canManage = u.role == 'municipality_coordinator' && u.can('workers', 'create');
    return Scaffold(
      appBar: AppBar(title: const AppText('العمال والمجموعات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CardSection(
            title: 'إدارة المجموعات',
            icon: const FeatureIcon('workers'),
            child: Column(
              children: [
                AppText(canManage ? 'منسق البلدية هو صاحب القرار الوحيد في إدارة المجموعات.' : 'عرض معلومات المجموعات وفق نطاق الصلاحية.', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                if (canManage) ...[
                  TextField(controller: name, decoration: InputDecoration(labelText: tr('اسم المجموعة'))),
                  const SizedBox(height: 10),
                  TextField(controller: number, decoration: InputDecoration(labelText: tr('رقم المجموعة'))),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonal(onPressed: () => _groupAction(context, 'create'), child: const AppText('إنشاء')),
                      FilledButton.tonal(onPressed: () => _groupAction(context, 'edit'), child: const AppText('تعديل')),
                      OutlinedButton(onPressed: () => _groupAction(context, 'delete'), child: const AppText('حذف منطقي')),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _groupAction(BuildContext context, String action) async {
    final d = context.read<DataService>();
    final u = context.read<AuthService>().currentUser!;
    if (u.role != 'municipality_coordinator' || !u.can('workers', action == 'delete' ? 'delete' : 'edit')) return;
    if (action != 'delete' && (name.text.trim().isEmpty || number.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('أدخل اسم المجموعة ورقمها.')));
      return;
    }
    await d.enqueue('group', action, {
      'id': const Uuid().v4(),
      'name': name.text.trim(),
      'number': number.text.trim(),
      'municipalityCoordinatorId': u.id,
      'createdAt': DateTime.now().toIso8601String(),
      'isDeleted': action == 'delete',
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('تمت إضافة العملية إلى قائمة المزامنة.')));
  }
}

class ExcelPage extends StatefulWidget {
  const ExcelPage({super.key});
  @override State<ExcelPage> createState() => _ExcelState();
}

class _ExcelState extends State<ExcelPage> {
  Future<void> _saveImportedRows(List<Map<String, String>> importedRows) async {
    final user = context.read<AuthService>().currentUser;
    final data = context.read<DataService>();
    if (user == null) return;
    for (final row in importedRows) {
      await data.enqueue('worker', 'upsert', {
        'id': row['id'],
        'name': row['name'],
        'job': row['job'],
        'phone': row['phone'],
        'municipality': row['municipality'],
        'group': row['group'],
        'groupNumber': row['group'],
        'municipalityCoordinatorId': row['municipalityCoordinatorId'] ?? '',
        'importedBy': user.id,
        'createdAt': DateTime.now().toIso8601String(),
        'isDeleted': false,
      });
    }
    if (importedRows.isNotEmpty) {
      await data.writeAudit(
        actorId: user.id,
        operation: 'IMPORT_WORKERS_SMART',
        targetId: DateTime.now().millisecondsSinceEpoch.toString(),
        after: {'count': importedRows.length, 'municipality': importedRows.first['municipality'], 'group': importedRows.first['group']},
      );
    }
  }

  @override Widget build(BuildContext context) => Directionality(
    textDirection: context.watch<LocaleController>().isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
    child: Scaffold(
      appBar: AppBar(title: const AppText('استيراد Excel الذكي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SmartExcelImportCard(onImport: _saveImportedRows),
        ],
      ),
    ),
  );
}

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});
  @override State<PermissionsPage> createState() => _PermissionsState();
}

class _PermissionsState extends State<PermissionsPage> {
  String selected = roles.first;
  @override Widget build(BuildContext context) {
    final config = context.watch<ConfigService>();
    return Directionality(
      textDirection: context.watch<LocaleController>().isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: const AppText('مصفوفة الصلاحيات الديناميكية')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: selected,
              items: roles.map((r) => DropdownMenuItem(value: r, child: AppText(roleNames[r]!))).toList(),
              onChanged: (v) { if (v != null) setState(() => selected = v); },
              decoration: InputDecoration(labelText: tr('الطبقة')),
            ),
            const SizedBox(height: 12),
            ...allFeatures.entries.map((entry) {
              final policy = config.policies[entry.key] ?? defaultPolicy(selected, entry.key);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [FeatureIcon(entry.key), const SizedBox(width: 10), Expanded(child: AppText(entry.value, style: const TextStyle(fontWeight: FontWeight.w800)))]),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          _permissionSwitch('عرض', policy.view, (v) => _set(entry.key, policy.copyWith(view: v))),
                          _permissionSwitch('إضافة', policy.create, (v) => _set(entry.key, policy.copyWith(create: v))),
                          _permissionSwitch('تعديل', policy.edit, (v) => _set(entry.key, policy.copyWith(edit: v))),
                          _permissionSwitch('اعتماد', policy.approve, (v) => _set(entry.key, policy.copyWith(approve: v))),
                          _permissionSwitch('حذف منطقي', policy.softDelete, (v) => _set(entry.key, policy.copyWith(softDelete: v))),
                          _permissionSwitch('استيراد', policy.importData, (v) => _set(entry.key, policy.copyWith(importData: v))),
                          _permissionSwitch('تصدير', policy.export, (v) => _set(entry.key, policy.copyWith(export: v))),
                          _permissionSwitch('إشعارات', policy.notifications, (v) => _set(entry.key, policy.copyWith(notifications: v))),
                          _permissionSwitch('Offline', policy.offlineAllowed, (v) => _set(entry.key, policy.copyWith(offlineAllowed: v))),
                          _permissionSwitch('إظهار', policy.visible, (v) => _set(entry.key, policy.copyWith(visible: v))),
                          _permissionSwitch('تفعيل', policy.enabled, (v) => _set(entry.key, policy.copyWith(enabled: v))),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _permissionSwitch(String label, bool value, ValueChanged<bool> onChanged) => SizedBox(
    width: 130,
    child: SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: AppText(label, style: const TextStyle(fontSize: 12)), value: value, onChanged: onChanged),
  );

  Future<void> _set(String feature, FeaturePolicy policy) async {
    try {
      await context.read<ConfigService>().setPolicy(selected, feature, policy);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText('تعذر حفظ الصلاحية: $e')));
    }
  }
}

class AuditPage extends StatelessWidget {
  const AuditPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AppText('سجل التدقيق')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('audit').orderBy('timestamp', descending: true).limit(150).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20), child: AppText('تعذر قراءة سجل التدقيق. تحقق من صلاحيات Firestore والاتصال.\n${snap.error}')));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: AppText('لا توجد أحداث تدقيق مسجلة حتى الآن.'));
        return ListView.separated(
          padding: const EdgeInsets.all(12), itemCount: docs.length, separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final x = docs[i].data();
            final operation = '${x['operation'] ?? 'عملية'}';
            final actor = '${x['actorId'] ?? 'غير محدد'}';
            final target = '${x['targetId'] ?? docs[i].id}';
            final time = '${x['createdAt'] ?? x['timestamp'] ?? '—'}';
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.history_rounded)),
              title: AppText(operation, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: AppText('المنفذ: $actor\nالعنصر: $target\nالتاريخ: $time', maxLines: 4),
              isThreeLine: true,
              trailing: IconButton(tooltip: 'تفاصيل الحدث', icon: const Icon(Icons.info_outline), onPressed: () => showDialog<void>(context: context, builder: (_) => AlertDialog(title: AppText(operation), content: SingleChildScrollView(child: SelectableText(x.entries.map((e) => '${e.key}: ${e.value}').join('\n'))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const AppText('إغلاق'))]))),
            );
          },
        );
      },
    ),
  );
}

class SettingsPage extends StatelessWidget{
  const SettingsPage({super.key});
  @override Widget build(BuildContext context){
    final config=context.watch<ConfigService>();
    final user=context.watch<AuthService>().currentUser!;
    final d=context.watch<DataService>();
    final locale=context.watch<LocaleController>();
    final choices=[300,400,500,600,1024];
    return ListView(
      padding:const EdgeInsets.all(16),
      children:[
        CardSection(
          title:'التخزين والصور',
          icon:const FeatureIcon('sync'),
          child:Column(
            children:[
              ListTile(
                title:const AppText('حجم الصورة عند الرفع'),
                subtitle:const AppText('يتم ضغط الصورة قبل الرفع ولا تُرفع النسخة الأصلية'),
                trailing:DropdownButton<int>(
                  value:choices.contains(config.imageTargetKb)?config.imageTargetKb:300,
                  items:choices.map((x)=>DropdownMenuItem(value:x,child:AppText(x==1024?'1 MB':'$x KB'))).toList(),
                  onChanged:user.role=='donor_manager'?(v){if(v!=null)config.updateImageTarget(v);}:null,
                ),
              ),
              ListTile(title:const AppText('مدة الاحتفاظ المحلي'),subtitle:AppText('${config.localImageRetentionDays} يومًا'),trailing:const Icon(Icons.lock_clock_outlined)),
              ListTile(title:const AppText('حالة الاتصال'),subtitle:AppText(d.online?'متصل':'Offline'),trailing:Icon(d.online?Icons.cloud_done:Icons.cloud_off,color:d.online?green:orange)),
            ],
          ),
        ),
        const SizedBox(height:14),
        CardSection(
          title:'التحكم الديناميكي Zero-Hardcoding',
          icon:const FeatureIcon('settings'),
          child:Column(
            children:[
              _switch(context,'التسجيل الصوتي',config.voiceEnabled,user.role=='donor_manager','voice'),
              _switch(context,'فحص PPE',config.ppeEnabled,user.role=='donor_manager','ppe'),
              _switch(context,'صور الشوارع',config.streetPhotosEnabled,user.role=='donor_manager','streetPhotos'),
              _switch(context,'الكارة البديلة',config.alternativeCartEnabled,user.role=='donor_manager','alternativeCart'),
              if(user.role=='donor_manager')
                ListTile(
                  title:const AppText('تجميد المرحلة',style:TextStyle(fontWeight:FontWeight.w800)),
                  subtitle:AppText(config.stageFrozen?'المرحلة مجمّدة — التعديلات التشغيلية مقفلة':'يمكن تجميد المرحلة بعد الاعتماد'),
                  trailing:FilledButton.tonalIcon(onPressed:config.stageFrozen?null:()=>config.freezeStage(),icon:const Icon(Icons.lock_outline),label:const AppText('تجميد')),
                ),
            ],
          ),
        ),
        if(user.role=='jsc_coordinator'||user.role=='donor_manager') ...[
          const SizedBox(height:14),
          CardSection(
            title:'تشغيل العمليات الحية',
            icon:const Icon(Icons.gps_fixed_outlined, color:Color(0xFF18D7FF)),
            child:Column(
              children:[
                _switch(context,'خريطة العمليات الحية',config.liveOperationsMapEnabled,true,'liveOperationsMap'),
                _switch(context,'تتبع مواقع العاملين',config.workerLocationTrackingEnabled,true,'workerLocationTracking'),
                const Padding(padding:EdgeInsets.only(top:4),child:AppText('هذه الإعدادات تظهر فقط للمستوى 4 والمستوى 3. لا يُطلب إذن الموقع ما لم يتم تفعيل تتبع مواقع العاملين.',style:TextStyle(color:cleanOpsMuted,fontSize:10))),
              ],
            ),
          ),
        ],
        CardSection(title:'مركز الإدارة والتشغيل',icon:const Icon(Icons.hub_rounded,color:aiCyan),child:ListTile(title:const AppText('لوحة الإدارة والتشغيل'),subtitle:const AppText('تنبيهات، مزامنة، صحة النظام، بحث، مجموعات وتقارير'),trailing:DirectionalChevron(),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const EnterpriseOperationsHubPage())))),
        if(user.role=='municipality_coordinator'||user.role=='jsc_coordinator'||user.role=='donor_manager')
          CardSection(
            title:'مركز إدارة العمليات',
            icon:const Icon(Icons.hub_outlined),
            child:ListTile(
              title:const AppText('دورات العمل والمكبات والموارد'),
              subtitle:const AppText('إدارة العمليات حسب مستوى الصلاحية'),
              trailing:DirectionalChevron(),
              onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const OperationsManagementScreen())),
            ),
          ),
        const SizedBox(height:14),
        if(user.role=='donor_manager'||user.role=='jsc_coordinator') ...[
          CardSection(title:'تكامل API',icon:const Icon(Icons.api_rounded,color:aiCyan),child:ListTile(title:const AppText('إعدادات API'),subtitle:AppText(config.apiEnabled?'مفعّل • ${config.apiVersion}':'غير مفعّل'),trailing:DirectionalChevron(),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const ApiSettingsPage())))),
          const SizedBox(height:12),
        ],
        CardSection(title:'الرسائل المحلية وOnline',icon:const Icon(Icons.forum_rounded,color:aiCyan),child:ListTile(title:const AppText('إعدادات الرسائل'),subtitle:AppText('${config.localMessagingEnabled?'Local':'Local off'} • ${config.onlineMessagingEnabled?'Online':'Online off'} • Sync ${config.autoMessageSync?'ON':'OFF'}'),trailing:DirectionalChevron(),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const MessagingSettingsPage())))),
        const SizedBox(height:14),
        if(user.role=='donor_manager'||user.role=='municipality_coordinator')
          CardSection(title:'المستخدمون',icon:const Icon(Icons.manage_accounts_rounded,color:aiGreen),child:ListTile(title:const AppText('إضافة مستخدم جديد'),subtitle:const AppText('الاسم، اسم المستخدم، كلمة المرور، الدور، الجوال والمعلومات التشغيلية'),trailing:DirectionalChevron(),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const UserManagementSettingsPage())))),
        const SizedBox(height:14),
        CardSection(
          title:'تغيير اللغة',
          icon:const Icon(Icons.language_outlined),
          child:ListTile(
            title:AppText(locale.isArabic?'العربية':'English'),
            subtitle:const AppText('تغيير اللغة'),
            trailing:Switch(
              value:locale.isArabic,
              onChanged:(v)async{
                locale.setLocale(v?LocaleController.arabic:LocaleController.english);
                final p=await SharedPreferences.getInstance();
                await p.setString('app_language',locale.locale.languageCode);
              },
            ),
          ),
        ),
        const SizedBox(height:14),
        CardSection(
          title:'عن التطبيق والمطور',
          icon:const Icon(Icons.info_outline),
          child:Column(
            children:const [
              ListTile(leading:Icon(Icons.person_outline),title:AppText('المطور'),subtitle:AppText('@Eman Al-Qahwaji')),
              ListTile(leading:Icon(Icons.email_outlined),title:AppText('البريد الإلكتروني'),subtitle:AppText('emanabd@gmail.com')),
              ListTile(leading:Icon(Icons.phone_in_talk_outlined),title:AppText('واتساب'),subtitle:AppText('00970567953487')),
            ],
          ),
        ),
      ],
    );
  }
  Widget _switch(BuildContext context,String title,bool value,bool enabled,String key)=>SwitchListTile(value:value,onChanged:enabled?(v)=>context.read<ConfigService>().setOperationalFeature(key,v):null,title:AppText(title));
}

Future<void> quickAction(BuildContext context) async {
  final user = context.read<AuthService>().currentUser!;
  final d = context.read<DataService>();
  final actions = <CreativeShortcut>[
    if (user.role == 'group_supervisor' || user.role == 'worker') ...[
      CreativeShortcut(title: 'الحضور والسلامة', subtitle: 'الحضور + معدات الوقاية', feature: 'attendance', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Level1SupervisorScreen()))),
      CreativeShortcut(title: 'تسجيل نقلة', subtitle: 'الترحيل والكمية والصور', feature: 'trips', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Level1SupervisorScreen()))),
      CreativeShortcut(title: 'إدخال حالة الحاويات', subtitle: 'تحديث حالة حاويات المجموعة', feature: 'containers', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Level1SupervisorScreen()))),
      CreativeShortcut(title: 'SOS والطوارئ', subtitle: 'بلاغ فوري مع GPS', feature: 'emergency', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Level1SupervisorScreen()))),
    ],
    if (user.role == 'municipality_coordinator') ...[
      CreativeShortcut(title: 'الحاويات', subtitle: 'الحالة والمشكلات', feature: 'containers', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Level2MunicipalityScreen()))),
      CreativeShortcut(title: 'المجموعات والعمال', subtitle: 'التوزيع والقوى العاملة', feature: 'workers', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Level2MunicipalityScreen()))),
      CreativeShortcut(title: 'المكبات', subtitle: 'السعة والامتلاء والحالة', feature: 'dumpsite', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OperationsManagementScreen(initialTab: 1)))),
      CreativeShortcut(title: 'التقارير', subtitle: 'الغياب والعمل والحاويات', feature: 'reports', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsCenterScreen()))),
    ],
    if (user.role == 'jsc_coordinator') ...[
      CreativeShortcut(title: 'الحاويات', subtitle: 'إدارة الحالات والمواقع', feature: 'containers', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContainerManagementScreen()))),
      CreativeShortcut(title: 'المكبات', subtitle: 'السعة والحالة', feature: 'dumpsite', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OperationsManagementScreen(initialTab: 0)))),
      CreativeShortcut(title: 'التقارير', subtitle: 'تقارير التشغيل والبلديات', feature: 'reports', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsCenterScreen()))),
      CreativeShortcut(title: 'البحث الذكي', subtitle: 'بحث مرن في بيانات المنظومة', feature: 'operations', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalSearchPage()))),
    ],
    if (user.role == 'donor_manager') ...[
      CreativeShortcut(title: 'مركز الإدارة', subtitle: 'الأصول والتنبيهات والبحث', feature: 'dashboard', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EnterpriseOperationsHubPage()))),
      CreativeShortcut(title: 'التقارير', subtitle: 'كل التقارير والتحليلات', feature: 'reports', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsCenterScreen()))),
      CreativeShortcut(title: 'إدارة المستخدمين', subtitle: 'الحسابات والصلاحيات', feature: 'users', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementSettingsPage()))),
      CreativeShortcut(title: 'البحث الذكي', subtitle: 'بحث مرن في كامل المنظومة', feature: 'operations', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalSearchPage()))),
    ],
  ];
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cleanOpsBg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 46, height: 5, decoration: BoxDecoration(color: cleanOpsMuted.withOpacity(.35), borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 12),
            const AppText('الإجراءات السريعة', textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const AppText('اختر الإجراء المطلوب — كل اختصار يعمل بنفس تصميم CleanOps', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: cleanOpsMuted)),
            const SizedBox(height: 14),
            CreativeShortcutGrid(items: actions),
          ]),
        ),
      ),
    ),
  );
  await d.addActivity('الإجراءات السريعة','تم فتح قائمة الإجراءات السريعة.');
}

class SetupState extends ChangeNotifier {
  bool complete;
  SetupState(this.complete);
}

class StartupDiagnostics {
  static bool firebaseReady = false;
  static String? firebaseError;

  static Future<void> initializeFirebase() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      if (Firebase.apps.isNotEmpty) {
        try {
          FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
        } catch (e) {
          debugPrint('Firestore persistence settings skipped: $e');
        }
      }
      firebaseReady = Firebase.apps.isNotEmpty;
      firebaseError = firebaseReady ? null : 'Firebase لم يتم تهيئته.';
    } on FirebaseException catch (e) {
      firebaseReady = false;
      firebaseError = 'Firebase: ${e.code}${e.message == null ? '' : ' — ${e.message}'}';
      debugPrint('Firebase initialization failed: $e');
    } catch (e, stack) {
      firebaseReady = false;
      firebaseError = 'تعذر تهيئة خدمات السحابة.';
      debugPrint('Firebase initialization failed: $e');
      debugPrintStack(stackTrace: stack);
    }
  }
}

class StartupFailureScreen extends StatelessWidget {
  final String message;
  const StartupFailureScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Scaffold(
          backgroundColor: cleanOpsBg,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                      const SizedBox(height: 16),
                      const AppText('تعذر بدء التطبيق', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      Text(message, textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => main(),
                        icon: const Icon(Icons.refresh),
                        label: const AppText('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> main() async {
  // Keep widget build failures visible instead of silently leaving a blank/white route.
  ErrorWidget.builder = (FlutterErrorDetails details) => Material(
    color: const Color(0xFF071A2B),
    child: Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 42),
              const SizedBox(height: 12),
              const Text('حدث خطأ في عرض هذه الشاشة', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(details.exceptionAsString(), style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center, maxLines: 5, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    ),
  );
  WidgetsFlutterBinding.ensureInitialized();
  await StartupDiagnostics.initializeFirebase();

  late final Box localBox;
  try {
    await Hive.initFlutter();
    try {
      localBox = await Hive.openBox('solid_waste_operations');
    } catch (e) {
      debugPrint('Hive box open failed; recreating local box: $e');
      try {
        await Hive.deleteBoxFromDisk('solid_waste_operations');
      } catch (_) {}
      localBox = await Hive.openBox('solid_waste_operations');
    }
  } catch (e, stack) {
    debugPrint('Local storage initialization failed: $e');
    debugPrintStack(stackTrace: stack);
    runApp(StartupFailureScreen(message: 'تعذر تهيئة التخزين المحلي للتطبيق.\n$e'));
    return;
  }

  try {
    final store = LocalStore(localBox);
    final auth = AuthService(store);
    final config = ConfigService(store);
    final data = DataService(store, config);
    final gpsTracking = GpsTrackingService();
    gpsTracking.bind(auth, config);

    try {
      await data.init();
    } catch (e, stack) {
      debugPrint('Data service initialization failed: $e');
      debugPrintStack(stackTrace: stack);
    }

    try {
      await config.loadLocal();
    } catch (e, stack) {
      debugPrint('Local config initialization failed: $e');
      debugPrintStack(stackTrace: stack);
    }

    try {
      await auth.loadRememberedState();
    } catch (e, stack) {
      debugPrint('Remember-me initialization failed: $e');
      debugPrintStack(stackTrace: stack);
    }

    try {
      await auth.restore();
    } catch (e, stack) {
      debugPrint('Session restore failed: $e');
      debugPrintStack(stackTrace: stack);
    }

    final messaging = MessagingService(store, config);
    final containers = ContainerService(store, data, messaging);
    try {
      await messaging.init(auth.currentUser);
    } catch (e, stack) {
      debugPrint('Messaging initialization failed: $e');
      debugPrintStack(stackTrace: stack);
    }

    if (auth.currentUser != null) {
      try {
        await data.refreshOperations();
        await data.sync();
      } catch (e, stack) {
        debugPrint('Post-auth synchronization failed: $e');
        debugPrintStack(stackTrace: stack);
      }
    }

    try {
      await config.loadRemote();
    } catch (e, stack) {
      debugPrint('Remote config initialization failed: $e');
      debugPrintStack(stackTrace: stack);
    }

    try {
      if (auth.currentUser != null && StartupDiagnostics.firebaseReady) {
        await config.attachRole(auth.currentUser!.role);
      }
    } catch (e, stack) {
      debugPrint('Role configuration initialization failed: $e');
      debugPrintStack(stackTrace: stack);
    }

    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e, stack) {
      debugPrint('SharedPreferences initialization failed: $e');
      debugPrintStack(stackTrace: stack);
      runApp(StartupFailureScreen(message: 'تعذر تهيئة إعدادات التطبيق المحلية.\n$e'));
      return;
    }

    final setupState = SetupState(prefs.getBool('setup_complete') ?? false);
    final locale = LocaleController();
    if (prefs.getString('app_language') == 'en') {
      locale.setLocale(LocaleController.english);
    }

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: config),
          ChangeNotifierProvider.value(value: data),
          ChangeNotifierProvider.value(value: messaging),
          ChangeNotifierProvider.value(value: containers),
          ChangeNotifierProvider.value(value: gpsTracking),
          Provider(create: (_) => OperationsAdminService()),
          ChangeNotifierProvider.value(value: setupState),
          ChangeNotifierProvider.value(value: locale),
        ],
        child: const EnterpriseApp(),
      ),
    );
  } catch (e, stack) {
    debugPrint('Unexpected startup failure: $e');
    debugPrintStack(stackTrace: stack);
    runApp(StartupFailureScreen(message: 'حدث خطأ غير متوقع أثناء بدء التطبيق.\n$e'));
  }
}

class EnterpriseApp extends StatelessWidget {
  const EnterpriseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>().locale;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: I18n.tr('منظومة عمليات جمع النفايات الصلبة', locale.languageCode),
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      builder: (context, child) => Directionality(
        textDirection: locale.languageCode == 'ar' ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        child: child ?? const SizedBox.shrink(),
      ),
      routes: {'/home': (_) => const AppShell()},
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: cleanOpsBg,
        fontFamily: GoogleFonts.cairo().fontFamily,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF087F6B),
          onPrimary: Colors.white,
          secondary: Color(0xFF35B9A2),
          surface: cleanOpsSurface,
          onSurface: cleanOpsText,
          error: Color(0xFFDC4545),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        splashFactory: InkSparkle.splashFactory,
        textTheme: GoogleFonts.cairoTextTheme(ThemeData.light().textTheme).apply(
          bodyColor: cleanOpsText,
          displayColor: cleanOpsText,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF3F8F5),
          foregroundColor: Color(0xFF173B35),
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cleanOpsSurface2,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: cleanOpsBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: cleanOpsBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF087F6B), width: 1.6)),
          labelStyle: const TextStyle(color: cleanOpsMuted),
          hintStyle: const TextStyle(color: cleanOpsMuted),
        ),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), textStyle: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800))),
        outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: const BorderSide(color: Color(0x33259E91)), textStyle: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800))),
        textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), textStyle: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800))),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: cleanOpsSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: cleanOpsBorder)),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: Color(0x2235B9A2),
          labelTextStyle: WidgetStatePropertyAll(TextStyle(color: Color(0xFF173B35), fontWeight: FontWeight.w700)),
          iconTheme: WidgetStatePropertyAll(IconThemeData(color: Color(0xFF087F6B))),
          elevation: 8,
          shadowColor: Color(0x14073C35),
        ),
        drawerTheme: const DrawerThemeData(backgroundColor: Color(0xFFF7FBF8), scrimColor: Color(0x66073C35), elevation: 18),
      ),
      home: const SplashScreen(),
    );
  }
}
