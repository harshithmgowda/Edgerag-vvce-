"use client";
import { cleanAnswerText } from '@/lib/answer-text';
import React, { useEffect, useRef, useState } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { ArrowUp, BookOpen, Check, Copy, Plus, Sparkles, Square, ArrowUpRight, ChevronDown } from 'lucide-react';
import { Sidebar } from '@/components/Sidebar';
import { SourcePreview } from '@/components/SourcePreview';
import { api } from '@/lib/api-client';
import { Equipment } from '@/lib/types';

type Source = { manual_id:string; manual_revision?:string; package_version?:string; chunk_id:string; manual_title:string; page_number:number; snippet:string };
type Message = { role:'user'|'assistant'; content:string; citations?:Source[]; provider?:string; evidence?:string };
const base = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:8000/api/v1';
const suggestions = [ ['💡', 'Understand a concept', 'Explain the key concept in my document with a simple example.'], ['↗', 'Walk through a procedure', 'Explain the main procedure step by step.'], ['⌘', 'Explain code or a formula', 'Explain the algorithm or formula in my document.'], ['📖', 'Find a specific answer', 'What are the main topics covered in this document?'] ];
export default function ChatPage() {
 const [equipment,setEquipment]=useState<Equipment[]>([]), [selected,setSelected]=useState('');
 const [messages,setMessages]=useState<Message[]>([]), [input,setInput]=useState('');
 const [busy,setBusy]=useState(false), [stage,setStage]=useState(''), [error,setError]=useState('');
 const [copied,setCopied]=useState<number|null>(null);
 const abort=useRef<AbortController|null>(null), bottom=useRef<HTMLDivElement>(null);
 useEffect(()=>{api.listEquipment().then(items=>{setEquipment(items);setSelected(items[0]?.id||'');}).catch(e=>setError(e.message));return ()=>abort.current?.abort();},[]);
 useEffect(()=>{bottom.current?.scrollIntoView({behavior:'smooth',block:'end'});},[messages,stage]);
 const updateAnswer=(update:Partial<Message>,append=false)=>setMessages(old=>old.map((m,i)=>i===old.length-1?{...m,...update,content:append?m.content+(update.content||''):(update.content??m.content)}:m));
 async function send(value=input) {
  const question=value.trim();if(!question||busy||!selected)return;
  const history=messages.filter(m=>m.content).slice(-6).map(({role,content})=>({role,content:content.slice(0,4000)}));
  setMessages(old=>[...old,{role:'user',content:question},{role:'assistant',content:''}]);setInput('');setError('');setBusy(true);setStage('Connecting to your knowledge…');
  const controller=new AbortController();abort.current=controller;
  try {
   const token=localStorage.getItem('edgerag_token');
   const response=await fetch(`${base}/ai/chat/stream`,{method:'POST',signal:controller.signal,headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},body:JSON.stringify({question,equipment_id:selected,ai_mode:'ONLINE_AI',history})});
   if(!response.ok||!response.body)throw new Error(`Chat unavailable (${response.status}). Check the backend connection.`);
   const reader=response.body.getReader(),decoder=new TextDecoder();let buffer='',completed=false;
   while(true){const {value,done}=await reader.read();if(done)break;buffer+=decoder.decode(value,{stream:true});
    const frames=buffer.split('\n\n');buffer=frames.pop()||'';
    for(const frame of frames){const kind=frame.match(/^event: (.+)$/m)?.[1];const data=frame.match(/^data: (.+)$/m)?.[1];if(!data)continue;const payload=JSON.parse(data);
     if(kind==='status')setStage(payload.message);
     if(kind==='reset')updateAnswer({content:''});
     if(kind==='delta')updateAnswer({content:payload.text},true);
     if(kind==='result'){completed=true;updateAnswer({content:payload.answer,citations:payload.citations,provider:payload.provider_used,evidence:payload.evidence_status});if(payload.status==='ERROR')setError(payload.answer);}
     if(kind==='error')throw new Error(payload.message);
    }
   }
   if(!completed)throw new Error('Connection ended before the answer was complete. Please retry.');
  }catch(e:any){if(e.name==='AbortError'){setStage('Stopped');}else setError(e.message||'Unable to generate an answer.');}
  finally{setBusy(false);abort.current=null;}
 }
 function readable(m:Message){return m.role === 'assistant' ? cleanAnswerText(m.content) : m.content;}
 return <div className="flex h-screen overflow-hidden"><Sidebar/><main className="chat-workspace">
  <header className="chat-topbar"><div><span className="eyebrow">YOUR KNOWLEDGE, CONNECTED</span><h1>Ask Edge<span className="text-emerald-600">.</span></h1></div><button className="quiet-button" onClick={()=>{abort.current?.abort();setMessages([]);setError('');}} disabled={busy}><Plus size={16}/> New chat</button></header>
  <div className="chat-toolbar"><div className="flex items-center gap-2"><BookOpen size={15}/><label htmlFor="knowledge" className="sr-only">Knowledge collection</label><select id="knowledge" value={selected} disabled={busy} onChange={e=>{setSelected(e.target.value);setMessages([]);}}>{equipment.length?equipment.map(e=><option key={e.id} value={e.id}>{e.name}</option>):<option value="">No equipment registered</option>}</select></div><span className="context-pill"><span/> Grounded in your documents</span></div>
  <section className="chat-scroll" aria-label="Conversation">
   {!messages.length?<div className="chat-welcome"><div className="assistant-symbol"><Sparkles size={30}/></div><span className="eyebrow">A LITTLE CLARITY GOES A LONG WAY</span><h2>Big questions.<br/><span>Clear answers.</span></h2><p>Explore your manuals, untangle a concept, or work through a problem. Your documents are the starting point.</p><div className="suggestion-grid">{suggestions.map(([icon,title,prompt])=><button key={title} onClick={()=>setInput(prompt)} disabled={!selected}><span className="suggestion-icon">{icon}</span><strong>{title}</strong><ArrowUpRight size={16}/></button>)}</div></div>:<div className="conversation">{messages.map((m,i)=><article key={i} className={`chat-message ${m.role}`}><div className="message-label">{m.role==='assistant'?<><Sparkles size={15}/> EdgeRAG</>:'You'}{m.provider&&<span>{m.provider}</span>}{m.evidence&&<span>{m.evidence==='SUPPORTED'?'Supporting sources found':m.evidence==='INSUFFICIENT'?'More evidence needed':'Review answer against sources'}</span>}</div>{m.content?<div className="answer-markdown"><ReactMarkdown remarkPlugins={[remarkGfm]}>{readable(m)}</ReactMarkdown></div>:busy&&i===messages.length-1?<div className="thinking"><span/><span/><span/><small>{stage}</small></div>:<p className="text-slate-500 text-sm">No answer generated.</p>}{!!m.citations?.length&&<div className="sources"><p className="eyebrow">SOURCES · {m.citations.length}</p>{m.citations.map((s,n)=><details key={s.chunk_id} id={`source-${s.chunk_id}`}><summary><span>{n+1}</span><BookOpen size={14}/>{s.manual_title}<small>p. {s.page_number}</small><ChevronDown size={13}/></summary><p><mark>{s.snippet}</mark></p><p className="text-xs">Revision {s.manual_revision || "unknown"} · Package {s.package_version || "unknown"}</p>{s.manual_id&&<SourcePreview manualId={s.manual_id} page={s.page_number} excerpt={s.snippet}/>}</details>)}</div>}{m.role==='assistant'&&m.content&&<button className="copy-answer" aria-label="Copy answer" onClick={async()=>{try{await navigator.clipboard.writeText(readable(m));setCopied(i);setTimeout(()=>setCopied(null),1800);}catch{setError('Clipboard unavailable. Select and copy the answer.');}}}>{copied===i?<Check size={14}/>:<Copy size={14}/>} {copied===i?'Copied':'Copy answer'}</button>}</article>)}<div ref={bottom}/></div>}
  </section>
  <footer className="composer-area">{error&&<div className="chat-error" role="alert">{error} <a href="/settings/ai">Provider settings ↗</a></div>}{busy&&messages.at(-1)?.content&&<div className="generation-status" role="status"><span className="status-dot"/>{stage}</div>}<form className="chat-composer" onSubmit={e=>{e.preventDefault();send();}}><textarea aria-label="Message EdgeRAG" value={input} onChange={e=>setInput(e.target.value)} placeholder="Ask anything about your documents…" rows={2} maxLength={4000} onKeyDown={e=>{if(e.key==='Enter'&&!e.shiftKey&&!e.nativeEvent.isComposing){e.preventDefault();send();}}}/><div><span><BookOpen size={13}/> {equipment.find(e=>e.id===selected)?.name||'Choose a knowledge collection'}</span>{busy?<button type="button" aria-label="Stop generating" onClick={()=>abort.current?.abort()}><Square size={16}/></button>:<button type="submit" aria-label="Send message" disabled={!selected||!input.trim()}><ArrowUp size={20}/></button>}</div></form><p className="composer-note">AI can make mistakes. Open the sources to check important details.</p></footer>
 </main></div>;
}

