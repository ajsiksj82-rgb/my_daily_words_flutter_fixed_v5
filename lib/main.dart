import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const primary = Color(0xFF5B5FEF);
const primaryDark = Color(0xFF4347C4);
const bg = Color(0xFFFFF8EC);
const ink = Color(0xFF3A3458);
const inkSoft = Color(0xFF7B7393);
const gold = Color(0xFFFFB627);
const success = Color(0xFF3DDC84);
const danger = Color(0xFFFF6B6B);

class Word {
  String id, en, ar, status;
  DateTime createdAt;
  int correctStreak, reviewCount, wrongCount;
  Word({required this.id, required this.en, required this.ar, this.status='new', DateTime? createdAt,
    this.correctStreak=0, this.reviewCount=0, this.wrongCount=0}) : createdAt=createdAt ?? DateTime.now();
  Map<String,dynamic> toJson()=>{'id':id,'en':en,'ar':ar,'status':status,'createdAt':createdAt.toIso8601String(),'correctStreak':correctStreak,'reviewCount':reviewCount,'wrongCount':wrongCount};
  factory Word.fromJson(Map<String,dynamic> j)=>Word(id:j['id'],en:j['en'],ar:j['ar'],status:j['status']??'new',createdAt:DateTime.tryParse(j['createdAt']??'')??DateTime.now(),correctStreak:j['correctStreak']??0,reviewCount:j['reviewCount']??0,wrongCount:j['wrongCount']??0);
}

class Game {
  int xp, streak, best, correct, answered, sessions, perfect;
  String lastDay;
  Map<String,int> days;
  Game({this.xp=0,this.streak=0,this.best=0,this.correct=0,this.answered=0,this.sessions=0,this.perfect=0,this.lastDay='',Map<String,int>? days}):days=days??{};
  int level(){int l=1; while(xp>=50*l*l) l++; return l;}
  Map<String,dynamic> toJson()=>{'xp':xp,'streak':streak,'best':best,'correct':correct,'answered':answered,'sessions':sessions,'perfect':perfect,'lastDay':lastDay,'days':days};
  factory Game.fromJson(Map<String,dynamic> j)=>Game(xp:j['xp']??0,streak:j['streak']??0,best:j['best']??0,correct:j['correct']??0,answered:j['answered']??0,sessions:j['sessions']??0,perfect:j['perfect']??0,lastDay:j['lastDay']??'',days:Map<String,int>.from(j['days']??{}));
}

void main()=>runApp(const MyDailyWordsApp());

class MyDailyWordsApp extends StatelessWidget {
  const MyDailyWordsApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false, title:'كلماتي اليومية', locale:const Locale('ar'), supportedLocales:const [Locale('ar'),Locale('en')], localizationsDelegates:const [GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,GlobalCupertinoLocalizations.delegate], theme:ThemeData(useMaterial3:true,scaffoldBackgroundColor:bg,colorScheme:ColorScheme.fromSeed(seedColor:primary),fontFamily:'Arial'), home:const HomePage());
}

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState()=>_HomePageState(); }
class _HomePageState extends State<HomePage> {
  late SharedPreferences prefs; final tts=FlutterTts(); List<Word> words=[]; Game game=Game(); String name=''; bool ready=false; int tab=0; String query='';
  @override void initState(){super.initState(); _load();}
  Future<void> _load() async {prefs=await SharedPreferences.getInstance(); name=prefs.getString('name')??''; final ws=prefs.getStringList('words')??[]; words=ws.map((e)=>Word.fromJson(Map<String,dynamic>.from(Uri.decodeFull(e).isEmpty?{}:jsonDecode(Uri.decodeFull(e))))).toList(); final gs=prefs.getString('game'); if(gs!=null) game=Game.fromJson(jsonDecode(gs)); if(name.isEmpty && mounted) await _askName(); setState(()=>ready=true);}
  Future<void> _askName() async {final c=TextEditingController(); await showDialog(context:context,barrierDismissible:false,builder:(_)=>AlertDialog(title:const Text('أهلًا بك 👋'),content:TextField(controller:c,decoration:const InputDecoration(labelText:'اسمك')),actions:[TextButton(onPressed:(){if(c.text.trim().isNotEmpty){name=c.text.trim();prefs.setString('name',name);Navigator.pop(context);}},child:const Text('ابدأ'))]));}
  Future<void> save() async {prefs.setStringList('words',words.map((w)=>Uri.encodeFull(jsonEncode(w.toJson()))).toList()); prefs.setString('game',jsonEncode(game.toJson()));}
  void speak(String s) async {await tts.setLanguage('en-US');await tts.setSpeechRate(.45);await tts.speak(s);}
  String dayKey(DateTime d)=>'${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  int liveStreak(){final t=dayKey(DateTime.now()), y=dayKey(DateTime.now().subtract(const Duration(days:1)));return (game.lastDay==t||game.lastDay==y)?game.streak:0;}
  void answer(Word w,bool ok){final today=dayKey(DateTime.now()); if(game.lastDay!=today){final y=dayKey(DateTime.now().subtract(const Duration(days:1)));game.streak=game.lastDay==y?game.streak+1:1;game.lastDay=today;if(game.streak>game.best)game.best=game.streak;} game.xp+=ok?10:2;game.answered++;if(ok){game.correct++;w.correctStreak++;}else{w.correctStreak=0;w.wrongCount++;}w.reviewCount++;game.days[today]=(game.days[today]??0)+1;save();setState((){});}
  @override Widget build(BuildContext context){if(!ready)return const Scaffold(body:Center(child:CircularProgressIndicator())); final filtered=words.where((w)=>query.isEmpty||w.en.toLowerCase().contains(query.toLowerCase())||w.ar.contains(query)).toList();return Directionality(textDirection:TextDirection.rtl,child:Scaffold(body:SafeArea(child:Stack(children:[Positioned.fill(child:CustomPaint(painter:DecorPainter())),Column(children:[_top(),_tabs(),Expanded(child:tab==2?_stats():_list(filtered,tab==0))])]),),floatingActionButton:FloatingActionButton.extended(backgroundColor:primary,onPressed:()=>_edit(),icon:const Icon(Icons.add,color:Colors.white),label:const Text('إضافة كلمة',style:TextStyle(color:Colors.white))),bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const [NavigationDestination(icon:Icon(Icons.fiber_new),label:'الجديدة'),NavigationDestination(icon:Icon(Icons.menu_book),label:'كل كلماتي'),NavigationDestination(icon:Icon(Icons.bar_chart),label:'إحصائيات')])));}
  Widget _top()=>Padding(padding:const EdgeInsets.fromLTRB(18,14,18,10),child:Row(children:[CircleAvatar(backgroundColor:const Color(0xFFE8E8FE),child:const Text('📚')),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('كلماتي اليومية',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:primaryDark)),Text('أهلًا $name 👋',style:const TextStyle(fontSize:12,color:inkSoft))])),_chip('🔥 ${liveStreak()}'),const SizedBox(width:5),_chip('⭐ ${game.level()}') ]));
  Widget _chip(String s)=>Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20)),child:Text(s,style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold)));
  Widget _tabs()=>Padding(padding:const EdgeInsets.symmetric(horizontal:18,vertical:2),child:Row(children:[Expanded(child:_tab('كلماتي الجديدة',0,words.where((w)=>w.status=='new').length)),const SizedBox(width:8),Expanded(child:_tab('جميع كلماتي',1,words.length))]));
  Widget _tab(String s,int i,int count)=>GestureDetector(onTap:()=>setState(()=>tab=i),child:Container(padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:tab==i?primary:Colors.transparent,borderRadius:BorderRadius.circular(14)),child:Center(child:Text('$s  $count',style:TextStyle(color:tab==i?Colors.white:inkSoft,fontWeight:FontWeight.bold)))));
  Widget _list(List<Word> list,bool onlyNew){final arr=onlyNew?list.where((w)=>w.status=='new').toList():list;return ListView(padding:const EdgeInsets.fromLTRB(18,8,18,90),children:[if(!onlyNew&&words.isNotEmpty)_trainButton(),Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16)),padding:const EdgeInsets.symmetric(horizontal:12),child:TextField(onChanged:(v)=>setState(()=>query=v),decoration:const InputDecoration(border:InputBorder.none,prefixIcon:Icon(Icons.search),hintText:'ابحث عن كلمة...'))),const SizedBox(height:12),...arr.map(_wordCard)]);}
  Widget _trainButton()=>Padding(padding:const EdgeInsets.only(bottom:12),child:ElevatedButton.icon(style:ElevatedButton.styleFrom(backgroundColor:primary,foregroundColor:Colors.white,padding:const EdgeInsets.all(16),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),onPressed:()=>_training(words.where((w)=>w.status=='all'||w.status=='new').toList()),icon:const Text('🎯',style:TextStyle(fontSize:28)),label:const Expanded(child:Text('ابدأ التدريب\nاختبر كلماتك وتعلم بطريقة ممتعة'))));
  Widget _wordCard(Word w)=>Card(margin:const EdgeInsets.only(bottom:10),elevation:1,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),child:ListTile(onTap:()=>_edit(w),leading:CircleAvatar(backgroundColor:const Color(0xFFE8E8FE),child:IconButton(icon:const Icon(Icons.volume_up,color:primary),onPressed:()=>speak(w.en))),title:Text(w.en,textDirection:TextDirection.ltr,style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)),subtitle:Text(w.ar),trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')_edit(w);else {_delete(w);}},itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('تعديل')),PopupMenuItem(value:'delete',child:Text('حذف'))])));
  Future<void> _edit([Word? old]) async {final en=TextEditingController(text:old?.en), ar=TextEditingController(text:old?.ar); final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:Text(old==null?'إضافة كلمة':'تعديل الكلمة'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:en,textDirection:TextDirection.ltr,decoration:const InputDecoration(labelText:'English')),TextField(controller:ar,decoration:const InputDecoration(labelText:'المعنى بالعربية'))]),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),FilledButton(onPressed:(){if(en.text.trim().isEmpty||ar.text.trim().isEmpty)return;if(old==null)words.insert(0,Word(id:DateTime.now().microsecondsSinceEpoch.toString(),en:en.text.trim(),ar:ar.text.trim()));else{old.en=en.text.trim();old.ar=ar.text.trim();}save();Navigator.pop(context,true);},child:const Text('حفظ'))]));if(ok==true)setState((){});}
  void _delete(Word w){showDialog(context:context,builder:(_)=>AlertDialog(title:const Text('حذف الكلمة؟'),content:Text('سيتم حذف «${w.en}»'),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('إلغاء')),FilledButton(onPressed:(){words.remove(w);save();setState((){});Navigator.pop(context);},child:const Text('حذف'))]));}
  Widget _stats(){final mastered=words.where((w)=>w.correctStreak>=3).length;final acc=game.answered==0?0:(game.correct*100~/game.answered);return ListView(padding:const EdgeInsets.all(18),children:[_statCard('⭐ المستوى ${game.level()}','${game.xp} نقطة'),_statCard('🎯 هدف اليوم','${min(game.days[dayKey(DateTime.now())]??0,20)} / 20 إجابة'),Row(children:[Expanded(child:_smallStat('🔥 ${liveStreak()}','أيام متتالية')),const SizedBox(width:8),Expanded(child:_smallStat('${game.best}','أفضل سلسلة')),const SizedBox(width:8),Expanded(child:_smallStat('$acc%','نسبة الدقة'))]),const SizedBox(height:10),_statCard('📚 الكلمات المتقنة','$mastered / ${words.length}'),_hardWords()]);}
  Widget _statCard(String a,String b)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(a,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),Text(b,style:const TextStyle(color:inkSoft))])));
  Widget _smallStat(String a,String b)=>Card(child:Padding(padding:const EdgeInsets.symmetric(vertical:18,horizontal:8),child:Column(children:[Text(a,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18)),Text(b,style:const TextStyle(fontSize:10,color:inkSoft),textAlign:TextAlign.center)])));
  Widget _hardWords(){final hard=[...words]..sort((a,b)=>b.wrongCount.compareTo(a.wrongCount));final h=hard.where((w)=>w.wrongCount>0).take(5).toList();return Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('😅 كلمات تحتاج مراجعة',style:TextStyle(fontWeight:FontWeight.bold)),...h.map((w)=>ListTile(dense:true,title:Text(w.en),subtitle:Text(w.ar),trailing:Text('✖ ${w.wrongCount}',style:const TextStyle(color:danger)))),if(h.isNotEmpty)FilledButton(onPressed:()=>_training(h),child:const Text('🎯 درّب كلماتي الصعبة'))])));}
  Future<void> _training(List<Word> pool) async {if(pool.isEmpty)return; await Navigator.push(context,MaterialPageRoute(builder:(_)=>TrainingPage(pool:pool,onAnswer:(w,ok){answer(w,ok);})));setState((){});}
}

class TrainingPage extends StatefulWidget {final List<Word> pool; final void Function(Word,bool) onAnswer; const TrainingPage({super.key,required this.pool,required this.onAnswer});@override State<TrainingPage> createState()=>_TrainingPageState();}
class _TrainingPageState extends State<TrainingPage>{final tts=FlutterTts();int i=0,correct=0;late Word current;late List<Word> opts;final input=TextEditingController();String feedback='';bool locked=false;final rnd=Random();@override void initState(){super.initState();_next();}void _next(){current=widget.pool[rnd.nextInt(widget.pool.length)];opts=[current,...widget.pool.where((w)=>w.id!=current.id).toList()..shuffle()].take(min(4,widget.pool.length)).toList()..shuffle();input.clear();feedback='';locked=false;setState((){});}void speak()async{await tts.setLanguage('en-US');await tts.speak(current.en);}void check(bool ok){if(locked)return;locked=true;if(ok)correct++;widget.onAnswer(current,ok);setState(()=>feedback=ok?'🎉 إجابة صحيحة':'❌ حاول مرة أخرى');i++;Future.delayed(const Duration(milliseconds:800),(){if(mounted)_next();});}
@override Widget build(BuildContext context){return Directionality(textDirection:TextDirection.rtl,child:Scaffold(backgroundColor:bg,appBar:AppBar(title:Text('تدريب  ${i+1}'),backgroundColor:bg),body:Padding(padding:const EdgeInsets.all(20),child:Column(children:[LinearProgressIndicator(value:(i%10)/10,color:primary),const Spacer(),Text(current.en,textDirection:TextDirection.ltr,style:const TextStyle(fontSize:34,fontWeight:FontWeight.w800,color:ink)),IconButton(onPressed:speak,icon:const Icon(Icons.volume_up,color:primary,size:32)),const SizedBox(height:20),Text('اختر المعنى الصحيح',style:const TextStyle(color:inkSoft)),const SizedBox(height:12),...opts.map((w)=>Padding(padding:const EdgeInsets.only(bottom:10),child:OutlinedButton(onPressed:()=>check(w.id==current.id),style:OutlinedButton.styleFrom(minimumSize:const Size(double.infinity,52),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),child:Text(w.ar,style:const TextStyle(fontSize:16))))),if(feedback.isNotEmpty)Text(feedback,style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:feedback.startsWith('🎉')?success:danger)),const Spacer(),Text('إجابات صحيحة: $correct',style:const TextStyle(color:inkSoft))]))));}}

class DecorPainter extends CustomPainter{ @override void paint(Canvas c,Size s){final p=Paint();p.color=gold.withOpacity(.16);c.drawCircle(Offset(s.width+20,-10),80,p);p.color=primary.withOpacity(.08);c.drawCircle(Offset(-20,s.height*.55),60,p);p.color=success.withOpacity(.08);c.drawCircle(Offset(s.width*.15,s.height*.2),30,p);} @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;}