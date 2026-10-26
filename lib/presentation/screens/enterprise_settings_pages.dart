import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization.dart';
import '../../core/services/config_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/messaging_service.dart';
import '../widgets/app_design.dart';
import '../../core/constants/app_constants.dart';

class ApiSettingsPage extends StatefulWidget {
  const ApiSettingsPage({super.key});
  @override State<ApiSettingsPage> createState() => _ApiSettingsPageState();
}
class _ApiSettingsPageState extends State<ApiSettingsPage> {
  late TextEditingController base, version, timeout, key, aiKey, aiModel;
  @override void initState() { super.initState(); final c=context.read<ConfigService>(); base=TextEditingController(text:c.apiBaseUrl); version=TextEditingController(text:c.apiVersion); timeout=TextEditingController(text:'${c.apiTimeoutSeconds}'); key=TextEditingController(); aiKey=TextEditingController(); aiModel=TextEditingController(text:c.aiModel); }
  @override void dispose(){base.dispose();version.dispose();timeout.dispose();key.dispose();aiKey.dispose();aiModel.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    final c=context.watch<ConfigService>();
    return Scaffold(appBar:AppBar(title:const AppText('إعدادات API'),actions:const [Padding(padding:EdgeInsetsDirectional.only(end:14),child:AiFeatureIcon('sync',size:16))]),body:ListView(padding:const EdgeInsets.fromLTRB(16,16,16,120),children:[
      const AiSectionCard(title:'اتصال الـ API',subtitle:'إعدادات التكامل الخارجي محفوظة محليًا، والمفتاح في Secure Storage.',feature:'sync',child:_ApiStatus()),
      const SizedBox(height:12),
      AiSectionCard(title:'النقطة الأساسية',feature:'settings',child:Column(children:[
        SwitchListTile(value:c.apiEnabled,onChanged:(v)=>setState(()=>c.apiEnabled=v),title:const AppText('تفعيل تكامل API')),
        const SizedBox(height:8),TextField(controller:base,textDirection:TextDirection.ltr,decoration:InputDecoration(labelText:'API Base URL',hintText:'https://api.example.com')),
        const SizedBox(height:8),TextField(controller:version,textDirection:TextDirection.ltr,decoration:InputDecoration(labelText:'API Version')),
        const SizedBox(height:8),TextField(controller:timeout,textDirection:TextDirection.ltr,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:'Timeout (seconds)')),
        const SizedBox(height:8),TextField(controller:key,textDirection:TextDirection.ltr,obscureText:true,decoration:InputDecoration(labelText:'API Key',hintText:c.maskedApiKey.isEmpty?'أدخل المفتاح':'اتركه فارغًا للإبقاء على المفتاح الحالي')),
        const SizedBox(height:14),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()async{await c.updateApiSettings(enabled:c.apiEnabled,baseUrl:base.text,version:version.text,timeoutSeconds:int.tryParse(timeout.text)??30,apiKey:key.text);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:AppText('تم حفظ إعدادات API بأمان.')));},icon:const Icon(Icons.save_rounded),label:const AppText('حفظ الإعدادات')))
      ])),
      const SizedBox(height:12),
      AiSectionCard(title:'CleanOps AI — OpenAI',subtitle:'الخدمة اختيارية. لا تعمل إلا بعد تفعيلها وإضافة مفتاح API من الإعدادات.',feature:'ai',child:Column(children:[
        SwitchListTile(contentPadding:EdgeInsets.zero,value:c.aiEnabled,onChanged:(v)=>setState(()=>c.aiEnabled=v),title:const AppText('تفعيل المساعد الذكي'),subtitle:const AppText('للمستوى 3 والمستوى 4 فقط.'),secondary:const AiFeatureIcon('ai',size:17)),
        const SizedBox(height:8),
        TextField(controller:aiKey,textDirection:TextDirection.ltr,obscureText:true,decoration:InputDecoration(labelText:'OpenAI API Key',hintText:c.maskedAiApiKey.isEmpty?'اختياري — أدخل المفتاح هنا':'اتركه فارغًا للإبقاء على المفتاح الحالي')),
        const SizedBox(height:8),
        TextField(controller:aiModel,textDirection:TextDirection.ltr,decoration:InputDecoration(labelText:'OpenAI Model',hintText:'gpt-5.6-luna')),
        const SizedBox(height:12),
        SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()async{await c.updateAISettings(enabled:c.aiEnabled,apiKey:aiKey.text,model:aiModel.text);aiKey.clear();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:AppText('تم حفظ إعدادات CleanOps AI بأمان.')));},icon:const Icon(Icons.auto_awesome_rounded),label:const AppText('حفظ إعدادات الذكاء الاصطناعي'))),
        const SizedBox(height:8),
        ListTile(contentPadding:EdgeInsets.zero,title:const AppText('الحالة'),trailing:AppText(!c.aiEnabled?'متوقف':(c.aiApiKey.isEmpty?'مفعّل بدون مفتاح':'جاهز'),style:TextStyle(color:aiGreen,fontWeight:FontWeight.w800))),
      ])),
      const SizedBox(height:12),
      AiSectionCard(title:'حالة الاتصال',feature:'operations',child:Column(children:[_row('الحالة',c.apiEnabled?'مفعّل':'غير مفعّل'),_row('Base URL',c.apiBaseUrl.isEmpty?'غير محدد':c.apiBaseUrl),_row('الإصدار',c.apiVersion),_row('Timeout','${c.apiTimeoutSeconds} ثانية'),_row('المفتاح',c.maskedApiKey.isEmpty?'غير مضبوط':c.maskedApiKey)])),
    ]));
  }
  Widget _row(String a,String b)=>ListTile(contentPadding:EdgeInsets.zero,title:AppText(a),trailing:ConstrainedBox(constraints:const BoxConstraints(maxWidth:220),child:AppText(b,style:const TextStyle(color:aiCyan,fontWeight:FontWeight.w800),overflow:TextOverflow.ellipsis,textAlign:TextAlign.end)));
}
class _ApiStatus extends StatelessWidget { const _ApiStatus(); @override Widget build(BuildContext context){final c=context.watch<ConfigService>();return Row(children:[Icon(c.apiEnabled?Icons.cloud_done_rounded:Icons.cloud_off_rounded,color:c.apiEnabled?aiGreen:cleanOpsMuted),const SizedBox(width:10),Expanded(child:AppText(c.apiEnabled?'التكامل مفعّل — جاهز لاختبار الاتصال من طبقة الخدمات.':'التكامل غير مفعّل حاليًا.'))]);}}

class MessagingSettingsPage extends StatelessWidget {
  const MessagingSettingsPage({super.key});
  @override Widget build(BuildContext context){
    final c=context.watch<ConfigService>();
    return Scaffold(appBar:AppBar(title:const AppText('إعدادات الرسائل'),actions:const [Padding(padding:EdgeInsetsDirectional.only(end:14),child:AiFeatureIcon('messages',size:16))]),body:ListView(padding:const EdgeInsets.fromLTRB(16,16,16,120),children:[
      AiSectionCard(title:'وضع الرسائل',subtitle:'محلي + Online مع مزامنة تلقائية عند توفر الشبكة',feature:'messages',child:Column(children:[
        SwitchListTile(value:c.localMessagingEnabled,onChanged:(v)=>_save(context,c,local:v),title:const AppText('الرسائل المحلية'),subtitle:const AppText('حفظ Inbox وOutbox وDrafts محليًا للعمل دون إنترنت.')),
        SwitchListTile(value:c.onlineMessagingEnabled,onChanged:(v)=>_save(context,c,online:v),title:const AppText('الرسائل Online'),subtitle:const AppText('مزامنة Firestore عند توفر الاتصال.')),
        SwitchListTile(value:c.autoMessageSync,onChanged:(v)=>_save(context,c,auto:v),title:const AppText('المزامنة التلقائية')),
        SwitchListTile(value:c.readReceiptsEnabled,onChanged:(v)=>_save(context,c,read:v),title:const AppText('إيصالات القراءة')),
        SwitchListTile(value:c.saveSentMessagesLocally,onChanged:(v)=>_save(context,c,save:v),title:const AppText('حفظ الرسائل المرسلة محليًا')),
        ListTile(title:const AppText('مدة الاحتفاظ المحلي'),subtitle:AppText('${c.messageRetentionDays} يومًا'),trailing:DropdownButton<int>(value:c.messageRetentionDays,items:const [7,30,90,365].map((x)=>DropdownMenuItem(value:x,child:Text('$x يوم'))).toList(),onChanged:(v)=>v==null?null:_save(context,c,retention:v))),
      ])),
      const SizedBox(height:12),
      const AiSectionCard(title:'التشغيل Offline / Online',feature:'sync',child:Column(children:[ListTile(leading:Icon(Icons.offline_bolt_rounded,color:aiGreen),title:AppText('Offline'),subtitle:AppText('يمكن قراءة الرسائل المحفوظة وإنشاء رسالة جديدة حسب الصلاحيات.')),
      ListTile(leading:Icon(Icons.cloud_sync_rounded,color:aiCyan),title:AppText('Online'),subtitle:AppText('Firestore يستقبل الرسائل ويعيد مزامنة الطابور بعد عودة الاتصال.'))])),
    ]));
  }
  Future<void> _save(BuildContext context,ConfigService c,{bool? local,bool? online,bool? auto,bool? read,bool? save,int? retention}) async {await c.updateMessagingSettings(localEnabled:local??c.localMessagingEnabled,onlineEnabled:online??c.onlineMessagingEnabled,autoSync:auto??c.autoMessageSync,readReceipts:read??c.readReceiptsEnabled,saveSentLocally:save??c.saveSentMessagesLocally,retentionDays:retention??c.messageRetentionDays);final u=context.read<AuthService>().currentUser;await context.read<MessagingService>().attachUser(u);}
}
