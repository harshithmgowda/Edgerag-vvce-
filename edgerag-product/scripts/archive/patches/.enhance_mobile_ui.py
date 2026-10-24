from pathlib import Path
p=Path('apps/mobile/lib/screens/ai_chat_screen.dart')
p.write_text('''import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/agent_controller.dart';
import 'citation_viewer_screen.dart';

class AiChatScreen extends StatefulWidget {
  final EquipmentModel equipment;
  final AiMode aiMode;
  const AiChatScreen({super.key, required this.equipment, required this.aiMode});
  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}
class _AiChatScreenState extends State<AiChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _agent = AgentController();
  final _conversation = const Uuid().v4();
  final List<ChatMessageModel> _messages = [];
  bool _busy = false;
  String _draft = '', _status = '', _error = '';
  List<String> _trace = [];
  int _request = 0;
  static const ink = Color(0xFF173D2B), green = Color(0xFF16845B);
  String get _mode => widget.aiMode == AiMode.offlineOnly ? 'On-device AI' : widget.aiMode == AiMode.onlineAi ? 'Online AI' : 'Smart auto';

  @override
  void dispose() { _request++; _agent.cancel(); _input.dispose(); _scroll.dispose(); super.dispose(); }
  void _bottom() { WidgetsBinding.instance.addPostFrameCallback((_){if(mounted&&_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent,duration:const Duration(milliseconds:180),curve:Curves.easeOut);}); }
  Future<void> _send() async {
    final question=_input.text.trim();if(question.isEmpty||_busy)return;
    final history=_messages.skip(_messages.length>6?_messages.length-6:0).map((m)=>{'role':m.isUser?'user':'assistant','content':m.content.length>4000?m.content.substring(0,4000):m.content}).toList();
    final request=++_request;
    setState((){_messages.add(ChatMessageModel(id:const Uuid().v4(),conversationId:_conversation,isUser:true,content:question,timestamp:DateTime.now()));_busy=true;_draft='';_error='';_status='Searching your documents…';});
    _input.clear();_bottom();
    try {
      final result=await _agent.executeQuery(question:question,equipmentId:widget.equipment.id,aiMode:widget.aiMode,history:history,
        onStatus:(value){if(mounted&&request==_request)setState(()=>_status=value);},
        onReset:(){if(mounted&&request==_request)setState(()=>_draft='');},
        onTokenStream:(token){if(mounted&&request==_request){setState(()=>_draft+=token);_bottom();}});
      if(!mounted||request!=_request)return;
      setState((){_messages.add(ChatMessageModel(id:const Uuid().v4(),conversationId:_conversation,isUser:false,content:result.answer,timestamp:DateTime.now(),citations:result.citations,providerUsed:result.providerUsed));_trace=result.executionTrace;_draft='';});
    }catch(e){if(mounted&&request==_request)setState(()=>_error='Could not complete the answer. $e');}
    finally {if(mounted&&request==_request){setState(()=>_busy=false);_bottom();}}
  }
  Future<void> _stop() async {
    ++_request;
    setState((){if(_draft.isNotEmpty)_messages.add(ChatMessageModel(id:const Uuid().v4(),conversationId:_conversation,isUser:false,content:_draft,timestamp:DateTime.now(),providerUsed:'Stopped · incomplete'));_draft='';_busy=false;});
    await _agent.cancel();
  }
  void _showTrace(){showModalBottomSheet(context:context,showDragHandle:true,builder:(_)=>Padding(padding:const EdgeInsets.all(24),child:ListView(children:[const Text('Answer activity',style:TextStyle(fontWeight:FontWeight.w700,fontSize:20)),const SizedBox(height:16),..._trace.map((line)=>Padding(padding:const EdgeInsets.only(bottom:12),child:Text(line,style:const TextStyle(fontFamily:'OpenSans',fontSize:12))))])));}
  String _readable(ChatMessageModel message){var text=message.content;for(var i=0;i<message.citations.length;i++){text=text.replaceAll('[Source ${message.citations[i].id}]','[${i+1}](source:${message.citations[i].id})');}return text;}
  Widget _markdown(String text,{List<ChunkModel> sources=const []})=>MarkdownBody(data:text,selectable:true,styleSheet:MarkdownStyleSheet(
    p:const TextStyle(fontFamily:'OpenSans',fontSize:14,height:1.85,color:ink),
    h1:const TextStyle(fontFamily:'Metropolis',fontSize:23,fontWeight:FontWeight.w700,color:ink),
    h2:const TextStyle(fontFamily:'Metropolis',fontSize:19,fontWeight:FontWeight.w700,color:ink),
    h3:const TextStyle(fontFamily:'Metropolis',fontSize:16,fontWeight:FontWeight.w600,color:ink),
    code:const TextStyle(fontFamily:'monospace',fontSize:12,color:ink),
    codeblockDecoration:BoxDecoration(color:const Color(0xFFEDF2E8),borderRadius:BorderRadius.circular(12)),
    blockSpacing:14,tableBorder:TableBorder.all(color:const Color(0xFFD8E2D4)),a:const TextStyle(color:green,fontWeight:FontWeight.w700)),
    onTapLink:(text,href,title){final found=sources.where((c)=>href=='source:${c.id}');if(found.isNotEmpty)Navigator.push(context,MaterialPageRoute(builder:(_)=>CitationViewerScreen(chunk:found.first)));});

  @override
  Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFFF8FAF5),
    appBar:AppBar(title:const Text('Ask Edge.',style:TextStyle(fontWeight:FontWeight.w700,fontSize:23,letterSpacing:-1)),actions:[IconButton(tooltip:'Answer activity',icon:const Icon(Icons.tune_rounded,size:21),onPressed:_showTrace),IconButton(tooltip:'New chat',icon:const Icon(Icons.add_rounded),onPressed:_busy?null:()=>setState((){_messages.clear();_error='';_trace=[];}))]),
    body:Column(children:[
      Container(padding:const EdgeInsets.symmetric(horizontal:22,vertical:12),decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:Color(0xFFE1E7DB)))),child:Row(children:[const Icon(Icons.menu_book_outlined,size:16,color:green),const SizedBox(width:8),Expanded(child:Text(widget.equipment.name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600))),Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:const Color(0xFFE5F1E4),borderRadius:BorderRadius.circular(20)),child:Text(_mode,style:const TextStyle(fontSize:9,color:green,fontWeight:FontWeight.w600)))])),
      Expanded(child:_messages.isEmpty?_welcome():ListView(controller:_scroll,padding:const EdgeInsets.fromLTRB(20,24,20,12),children:[..._messages.map(_message),if(_busy)_answer(_draft,provider:'EdgeRAG',loading:true)])),
      if(_error.isNotEmpty)Container(margin:const EdgeInsets.symmetric(horizontal:18,vertical:8),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFFFFEFE7),borderRadius:BorderRadius.circular(12)),child:Text(_error,style:const TextStyle(fontSize:12,color:Color(0xFF9B4925)))),
      _composer(),
    ]));
  Widget _welcome()=>SingleChildScrollView(padding:const EdgeInsets.fromLTRB(26,42,26,20),child:Column(children:[Container(width:64,height:64,decoration:BoxDecoration(color:const Color(0xFFE4F2E2),borderRadius:BorderRadius.circular(21),border:Border.all(color:const Color(0xFFC8DEC5))),child:const Icon(Icons.auto_awesome_rounded,size:29,color:green)),const SizedBox(height:26),const Text('YOUR KNOWLEDGE, CONNECTED',style:TextStyle(fontSize:9,letterSpacing:1.5,color:Color(0xFF81927F),fontWeight:FontWeight.w700)),const SizedBox(height:15),const Text('Big questions.\nClear answers.',textAlign:TextAlign.center,style:TextStyle(fontSize:35,height:1.16,letterSpacing:-1.6,fontWeight:FontWeight.w600,color:ink)),const SizedBox(height:16),const Text('Explore your documents and work through a problem, one clear answer at a time.',textAlign:TextAlign.center,style:TextStyle(fontFamily:'OpenSans',fontSize:13,height:1.7,color:Color(0xFF7D8B79))),const SizedBox(height:28),_suggestion('💡','Understand a concept','Explain '),_suggestion('📖','Explore this document','Summarize the main topics in this document.'),_suggestion('⌘','Walk through an example','Give me a step-by-step example of ')]));
  Widget _suggestion(String emoji,String title,String prompt)=>Padding(padding:const EdgeInsets.only(bottom:10),child:OutlinedButton(onPressed:(){_input.text=prompt;},style:OutlinedButton.styleFrom(backgroundColor:Colors.white,padding:const EdgeInsets.all(17),side:const BorderSide(color:Color(0xFFDDE6D7)),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),child:Row(children:[Text(emoji,style:const TextStyle(fontSize:19)),const SizedBox(width:14),Expanded(child:Text(title,style:const TextStyle(fontSize:12,color:ink))),const Icon(Icons.north_east,size:16,color:green)])));
  Widget _message(ChatMessageModel message){if(message.isUser)return Align(alignment:Alignment.centerRight,child:Container(margin:const EdgeInsets.only(left:40,bottom:26),padding:const EdgeInsets.symmetric(horizontal:18,vertical:15),decoration:const BoxDecoration(color:Color(0xFFEAF0E5),borderRadius:BorderRadius.only(topLeft:Radius.circular(18),topRight:Radius.circular(18),bottomLeft:Radius.circular(18),bottomRight:Radius.circular(4))),child:SelectableText(message.content,style:const TextStyle(fontFamily:'OpenSans',fontSize:14,height:1.6,color:ink))));return _answer(_readable(message),provider:message.providerUsed,sources:message.citations,raw:message.content);}
  Widget _answer(String text,{required String provider,List<ChunkModel> sources=const [],bool loading=false,String? raw})=>Padding(padding:const EdgeInsets.only(bottom:28),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const Icon(Icons.auto_awesome,size:17,color:green),const SizedBox(width:8),const Text('EdgeRAG',style:TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:green)),const SizedBox(width:10),Expanded(child:Text(provider,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:9,color:Color(0xFF869480))))]),const SizedBox(height:16),if(text.isNotEmpty)_markdown(text,sources:sources),if(loading)Padding(padding:const EdgeInsets.only(top:12),child:Row(children:[const SizedBox(width:13,height:13,child:CircularProgressIndicator(strokeWidth:1.8,color:green)),const SizedBox(width:10),Expanded(child:Text(_status,style:const TextStyle(fontSize:11,color:Color(0xFF7B8B77))))])),if(sources.isNotEmpty)...[const SizedBox(height:20),const Text('SOURCES',style:TextStyle(fontSize:9,letterSpacing:1.5,fontWeight:FontWeight.w700,color:Color(0xFF81927F))),const SizedBox(height:8),...sources.asMap().entries.map((entry)=>Padding(padding:const EdgeInsets.only(bottom:6),child:InkWell(borderRadius:BorderRadius.circular(10),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CitationViewerScreen(chunk:entry.value))),child:Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10),border:Border.all(color:const Color(0xFFDCE6D6))),child:Row(children:[Text('${entry.key+1}',style:const TextStyle(fontSize:10,color:green,fontWeight:FontWeight.w700)),const SizedBox(width:10),Expanded(child:Text(entry.value.manualTitle,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11))),Text('p. ${entry.value.pageNumber}',style:const TextStyle(fontSize:10,color:green)),const SizedBox(width:5),const Icon(Icons.north_east,size:12,color:green)])))))],if(!loading&&text.isNotEmpty)TextButton.icon(onPressed:(){Clipboard.setData(ClipboardData(text:raw??text));ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Answer copied')));},icon:const Icon(Icons.copy_outlined,size:13),label:const Text('Copy answer',style:TextStyle(fontSize:10)),style:TextButton.styleFrom(foregroundColor:const Color(0xFF7B8B77)))]));
  Widget _composer()=>SafeArea(top:false,child:Padding(padding:const EdgeInsets.fromLTRB(16,8,16,10),child:Column(children:[Container(padding:const EdgeInsets.fromLTRB(16,5,8,6),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(19),border:Border.all(color:const Color(0xFFD4E0CE)),boxShadow:const [BoxShadow(color:Color(0x08173525),blurRadius:20,offset:Offset(0,4))]),child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[Expanded(child:TextField(controller:_input,minLines:1,maxLines:5,maxLength:4000,textCapitalization:TextCapitalization.sentences,style:const TextStyle(fontFamily:'OpenSans',fontSize:13),decoration:const InputDecoration(hintText:'Ask about your documents…',counterText:'',filled:false,border:InputBorder.none,enabledBorder:InputBorder.none,focusedBorder:InputBorder.none,hintStyle:TextStyle(color:Color(0xFF9CA695),fontSize:12)))),IconButton.filled(tooltip:_busy?'Stop generating':'Send message',onPressed:_busy?_stop:_send,style:IconButton.styleFrom(backgroundColor:ink,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),icon:Icon(_busy?Icons.stop_rounded:Icons.arrow_upward_rounded,size:21))])),const SizedBox(height:8),const Text('AI can make mistakes. Check the sources.',style:TextStyle(fontFamily:'OpenSans',fontSize:9,color:Color(0xFF95A08C)))])));
}
''',encoding='utf-8')
