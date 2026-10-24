'use client';

import React, { useState, useEffect, useRef } from 'react';
import Link from 'next/link';
import { api } from '@/lib/api-client';
import { ProcessingJob, KnowledgePackage } from '@/lib/types';
import {
  ShieldCheck,
  BookOpen,
  Boxes,
  Cpu,
  Database,
  PackageCheck,
  CheckCircle2,
  AlertCircle,
  RefreshCw,
  Clock,
  Terminal,
  Download,
  ArrowRight,
  ExternalLink,
  Wifi,
  Sparkles,
  FileText,
  Copy,
  Check,
} from 'lucide-react';

interface RagFlowInspectorProps {
  jobId: string;
  equipmentName?: string;
  manualTitle?: string;
  onUploadAnother?: () => void;
}

interface PipelineStep {
  id: string;
  stageKey: string;
  title: string;
  techBadge: string;
  description: string;
  icon: React.ElementType;
}

const PIPELINE_STEPS: PipelineStep[] = [
  {
    id: 'vault',
    stageKey: 'INIT',
    title: '1. Vault Storage & Verification',
    techBadge: 'MinIO / Local Vault',
    description: 'Encrypted document vault storage, SHA-256 checksum verification, asset association.',
    icon: ShieldCheck,
  },
  {
    id: 'extract',
    stageKey: 'EXTRACTING_PAGES',
    title: '2. Text & Page Extraction',
    techBadge: 'PyMuPDF (fitz)',
    description: 'Structural PDF layout analysis, clean page extraction, font & boundary coordinates.',
    icon: BookOpen,
  },
  {
    id: 'chunk',
    stageKey: 'CHUNKING',
    title: '3. Semantic Chunking',
    techBadge: 'Sliding Window Tokenizer',
    description: '224 tokens per chunk, 32-token overlap, page-level cross-referencing and metadata.',
    icon: Boxes,
  },
  {
    id: 'embed',
    stageKey: 'EMBEDDING',
    title: '4. Dense Vector Embeddings',
    techBadge: 'all-MiniLM-L6-v2',
    description: '384-dimensional dense semantic vectors, cosine similarity normalization, float32 encoding.',
    icon: Cpu,
  },
  {
    id: 'sqlite',
    stageKey: 'GENERATING_SQLITE',
    title: '5. Knowledge SQLite Compilation',
    techBadge: 'knowledge.sqlite',
    description: 'Compiling offline SQLite relational schema: manuals, chunks, and embedding BLOB tables.',
    icon: Database,
  },
  {
    id: 'package',
    stageKey: 'PACKAGING',
    title: '6. Edge Package Assembly',
    techBadge: 'ZIP + manifest.json',
    description: 'Generating signed manifest, SHA-256 seal, atomic package ZIP for edge Hotspot/Wi-Fi distribution.',
    icon: PackageCheck,
  },
];

const STAGE_ORDER_MAP: Record<string, number> = {
  INIT: 1,
  EXTRACTING_PAGES: 2,
  CHUNKING: 3,
  EMBEDDING: 4,
  GENERATING_SQLITE: 5,
  PACKAGING: 6,
  COMPLETED: 7,
};

export function RagFlowInspector({
  jobId,
  equipmentName,
  manualTitle,
  onUploadAnother,
}: RagFlowInspectorProps) {
  const [job, setJob] = useState<ProcessingJob | null>(null);
  const [loading, setLoading] = useState(true);
  const [pollError, setPollError] = useState<string | null>(null);
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const [logLines, setLogLines] = useState<string[]>([]);
  const [packageRecord, setPackageRecord] = useState<KnowledgePackage | null>(null);
  const [copiedHash, setCopiedHash] = useState(false);

  const logsEndRef = useRef<HTMLDivElement>(null);
  const timerRef = useRef<NodeJS.Timeout | null>(null);
  const processedStagesRef = useRef<Set<string>>(new Set());

  // Auto-scroll logs
  useEffect(() => {
    logsEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [logLines]);

  // Elapsed timer
  useEffect(() => {
    timerRef.current = setInterval(() => {
      setElapsedSeconds((prev) => prev + 1);
    }, 1000);

    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, []);

  // Format log timestamp
  const getLogTimestamp = () => {
    const now = new Date();
    return now.toTimeString().split(' ')[0] + '.' + String(now.getMilliseconds()).padStart(3, '0');
  };

  const addLog = (message: string) => {
    setLogLines((prev) => [...prev, `[${getLogTimestamp()}] ${message}`]);
  };

  // Poll Job Status
  useEffect(() => {
    let isMounted = true;
    let intervalId: NodeJS.Timeout | null = null;

    addLog(`Initiating RAG pipeline tracker for Job ID: ${jobId}`);

    const poll = async () => {
      try {
        const currentJob = await api.getJob(jobId);
        if (!isMounted) return;

        setJob(currentJob);
        setLoading(false);

        // Stage logging
        const stage = currentJob.stage;
        if (stage && !processedStagesRef.current.has(stage)) {
          processedStagesRef.current.add(stage);

          switch (stage) {
            case 'INIT':
              addLog(`[INGEST] Document stored in secure vault. Verifying binary integrity...`);
              break;
            case 'EXTRACTING_PAGES':
              addLog(`[EXTRACT] PyMuPDF active. Parsing page boundaries, text streams & fonts...`);
              break;
            case 'CHUNKING':
              if (currentJob.total_pages) {
                addLog(`[EXTRACT] Extracted ${currentJob.total_pages} total pages successfully.`);
              }
              addLog(`[CHUNKER] Splitting text into 224-token semantic chunks with 32-token overlap...`);
              break;
            case 'EMBEDDING':
              if (currentJob.total_chunks) {
                addLog(`[CHUNKER] Generated ${currentJob.total_chunks} semantic chunks.`);
              }
              addLog(`[EMBED] Loading dense embedding model (all-MiniLM-L6-v2, 384-d)...`);
              addLog(`[EMBED] Computing L2-normalized dense embeddings for all chunk tokens...`);
              break;
            case 'GENERATING_SQLITE':
              addLog(`[SQLITE] Compiling offline knowledge database at knowledge.sqlite...`);
              addLog(`[SQLITE] Creating B-tree relational tables: manuals, chunks, embeddings BLOBs...`);
              break;
            case 'PACKAGING':
              addLog(`[PACKAGE] Building atomic package bundle: manifest.json + knowledge.sqlite...`);
              addLog(`[PACKAGE] Calculating SHA-256 seal for tamper-proof mobile distribution.`);
              break;
            case 'COMPLETED':
              addLog(`[COMPLETE] 🎉 Pipeline finished successfully! Package published.`);
              break;
          }
        }

        // Check if finished
        if (currentJob.status === 'SUCCEEDED') {
          if (timerRef.current) clearInterval(timerRef.current);
          if (intervalId) clearInterval(intervalId);

          // Fetch package
          try {
            const pkgs = await api.listPackages(currentJob.equipment_id);
            if (pkgs.length > 0) {
              setPackageRecord(pkgs[0]);
              addLog(`[PACKAGE] Package artifact ready: ${pkgs[0].package_file_name} (${(pkgs[0].file_size_bytes / 1024).toFixed(1)} KB)`);
            }
          } catch {
            // Optional
          }
        } else if (currentJob.status === 'FAILED') {
          if (timerRef.current) clearInterval(timerRef.current);
          if (intervalId) clearInterval(intervalId);
          addLog(`[ERROR] Pipeline failed: ${currentJob.error_message || 'Unknown error occurred'}`);
        }
      } catch (err: any) {
        if (!isMounted) return;
        setPollError(err.message || 'Error tracking processing job');
      }
    };

    poll();
    intervalId = setInterval(poll, 800);

    return () => {
      isMounted = false;
      if (intervalId) clearInterval(intervalId);
    };
  }, [jobId]);

  // Determine stage status
  const currentStageLevel = job?.status === 'SUCCEEDED' ? 7 : STAGE_ORDER_MAP[job?.stage || 'INIT'] || 1;

  const getStepState = (stepIndex: number) => {
    const stepLevel = stepIndex + 1; // 1 to 6
    if (job?.status === 'FAILED' && currentStageLevel === stepLevel) {
      return 'failed';
    }
    if (currentStageLevel > stepLevel) {
      return 'completed';
    }
    if (currentStageLevel === stepLevel) {
      return 'active';
    }
    return 'pending';
  };

  const copyHash = (hash: string) => {
    navigator.clipboard.writeText(hash);
    setCopiedHash(true);
    setTimeout(() => setCopiedHash(false), 2000);
  };

  return (
    <div className="space-y-8 animate-fadeIn">
      {/* Top Telemetry Header Card */}
      <div className="bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl p-6 shadow-apple">
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 pb-6 border-b border-slate-100 dark:border-slate-800">
          <div>
            <div className="flex items-center gap-2.5">
              <span className="w-2.5 h-2.5 rounded-full bg-emerald-500 animate-ping" />
              <h2 className="text-base font-bold text-slate-900 dark:text-white tracking-tight">
                Live RAG Ingestion Pipeline
              </h2>
              <span className="text-[11px] font-mono px-2 py-0.5 rounded-md bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 font-semibold">
                Job: {jobId.slice(0, 8)}...
              </span>
            </div>
            <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">
              {manualTitle || 'Technical Manual'} • Equipment: <span className="font-semibold text-slate-800 dark:text-slate-200">{equipmentName || 'Industrial Asset'}</span>
            </p>
          </div>

          <div className="flex items-center gap-3">
            {/* Status Badge */}
            <div
              className={`px-3 py-1.5 rounded-xl text-xs font-semibold flex items-center gap-2 ${
                job?.status === 'SUCCEEDED'
                  ? 'bg-emerald-50 text-emerald-700 dark:bg-emerald-950/50 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-800/40'
                  : job?.status === 'FAILED'
                  ? 'bg-rose-50 text-rose-700 dark:bg-rose-950/50 dark:text-rose-400 border border-rose-200 dark:border-rose-800/40'
                  : 'bg-indigo-50 text-indigo-700 dark:bg-indigo-950/50 dark:text-indigo-400 border border-indigo-200 dark:border-indigo-800/40 animate-pulse'
              }`}
            >
              {job?.status === 'SUCCEEDED' ? (
                <>
                  <CheckCircle2 className="w-3.5 h-3.5" />
                  <span>Pipeline Completed</span>
                </>
              ) : job?.status === 'FAILED' ? (
                <>
                  <AlertCircle className="w-3.5 h-3.5" />
                  <span>Ingestion Failed</span>
                </>
              ) : (
                <>
                  <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                  <span>Processing Stage ({job?.progress_percentage ?? 15}%)</span>
                </>
              )}
            </div>

            {/* Elapsed Timer */}
            <div className="px-3 py-1.5 rounded-xl bg-slate-100 dark:bg-slate-800/80 text-xs font-mono text-slate-600 dark:text-slate-400 flex items-center gap-1.5">
              <Clock className="w-3.5 h-3.5 text-slate-400" />
              <span>{elapsedSeconds}s</span>
            </div>
          </div>
        </div>

        {/* Dynamic Progress Bar */}
        <div className="mt-6 space-y-2">
          <div className="flex justify-between text-xs">
            <span className="font-semibold text-slate-700 dark:text-slate-300">
              Active Stage:{' '}
              <span className="text-indigo-600 dark:text-indigo-400 font-mono">
                {job?.stage || 'INIT'}
              </span>
            </span>
            <span className="font-mono font-bold text-slate-900 dark:text-white">
              {job?.progress_percentage ?? 15}%
            </span>
          </div>
          <div className="w-full h-2.5 rounded-full bg-slate-100 dark:bg-slate-800 overflow-hidden relative">
            <div
              className={`h-full transition-all duration-500 rounded-full ${
                job?.status === 'SUCCEEDED'
                  ? 'bg-gradient-to-r from-emerald-500 to-teal-500'
                  : job?.status === 'FAILED'
                  ? 'bg-rose-500'
                  : 'bg-gradient-to-r from-indigo-500 via-blue-500 to-emerald-400'
              }`}
              style={{ width: `${job?.progress_percentage ?? 15}%` }}
            />
          </div>
        </div>
      </div>

      {/* 6-Stage Visual Interactive Pipeline Flow */}
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <h3 className="text-xs font-bold uppercase tracking-wider text-slate-400 dark:text-slate-500">
            RAG Pipeline Architecture Stages
          </h3>
          <span className="text-[11px] text-slate-400">
            Deterministic Local Extraction & Compilation
          </span>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {PIPELINE_STEPS.map((step, idx) => {
            const state = getStepState(idx);
            const Icon = step.icon;

            return (
              <div
                key={step.id}
                className={`relative rounded-3xl p-5 border transition-all duration-300 ${
                  state === 'completed'
                    ? 'bg-emerald-50/40 dark:bg-emerald-950/10 border-emerald-300/80 dark:border-emerald-800/50 shadow-sm'
                    : state === 'active'
                    ? 'bg-white dark:bg-slate-900 border-indigo-500 dark:border-indigo-400 ring-2 ring-indigo-500/20 shadow-lg shadow-indigo-500/5'
                    : state === 'failed'
                    ? 'bg-rose-50/50 dark:bg-rose-950/20 border-rose-300 dark:border-rose-800'
                    : 'bg-slate-50/60 dark:bg-slate-900/40 border-slate-200/60 dark:border-slate-800/60 opacity-60'
                }`}
              >
                <div className="flex items-start justify-between">
                  <div
                    className={`w-10 h-10 rounded-2xl flex items-center justify-center ${
                      state === 'completed'
                        ? 'bg-emerald-500 text-white shadow-sm'
                        : state === 'active'
                        ? 'bg-indigo-600 text-white shadow-md shadow-indigo-500/20 animate-pulse'
                        : state === 'failed'
                        ? 'bg-rose-500 text-white'
                        : 'bg-slate-200 dark:bg-slate-800 text-slate-400'
                    }`}
                  >
                    {state === 'completed' ? (
                      <CheckCircle2 className="w-5 h-5" />
                    ) : state === 'active' ? (
                      <Icon className="w-5 h-5 animate-bounce" />
                    ) : (
                      <Icon className="w-5 h-5" />
                    )}
                  </div>

                  {/* Status Indicator */}
                  <div>
                    {state === 'completed' && (
                      <span className="inline-flex items-center gap-1 text-[10px] font-bold uppercase tracking-wider text-emerald-600 dark:text-emerald-400 bg-emerald-100/70 dark:bg-emerald-950/60 px-2.5 py-0.5 rounded-full">
                        Done
                      </span>
                    )}
                    {state === 'active' && (
                      <span className="inline-flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-wider text-indigo-600 dark:text-indigo-400 bg-indigo-100/80 dark:bg-indigo-950/80 px-2.5 py-0.5 rounded-full">
                        <RefreshCw className="w-3 h-3 animate-spin" />
                        In Progress
                      </span>
                    )}
                    {state === 'pending' && (
                      <span className="text-[10px] font-semibold text-slate-400 px-2 py-0.5">
                        Queued
                      </span>
                    )}
                    {state === 'failed' && (
                      <span className="text-[10px] font-bold uppercase tracking-wider text-rose-600 dark:text-rose-400 bg-rose-100 dark:bg-rose-950 px-2 py-0.5 rounded-full">
                        Failed
                      </span>
                    )}
                  </div>
                </div>

                <div className="mt-4">
                  <h4 className="text-xs font-bold text-slate-900 dark:text-white">
                    {step.title}
                  </h4>
                  <div className="mt-1 flex items-center gap-2">
                    <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 font-semibold">
                      {step.techBadge}
                    </span>
                  </div>
                  <p className="mt-2 text-[11px] text-slate-500 dark:text-slate-400 leading-relaxed">
                    {step.description}
                  </p>
                </div>

                {/* Dynamic live metrics attached to stages */}
                <div className="mt-3 pt-3 border-t border-slate-100 dark:border-slate-800/80 text-[11px]">
                  {step.id === 'extract' && (
                    <div className="flex items-center justify-between text-slate-600 dark:text-slate-300 font-semibold">
                      <span>Total Pages:</span>
                      <span className="font-mono text-emerald-600 dark:text-emerald-400 font-bold">
                        {job?.total_pages ? `${job.total_pages} pages extracted` : state === 'active' ? 'Extracting...' : '--'}
                      </span>
                    </div>
                  )}

                  {step.id === 'chunk' && (
                    <div className="flex items-center justify-between text-slate-600 dark:text-slate-300 font-semibold">
                      <span>Semantic Chunks:</span>
                      <span className="font-mono text-emerald-600 dark:text-emerald-400 font-bold">
                        {job?.total_chunks ? `${job.total_chunks} chunks produced` : state === 'active' ? 'Tokenizing...' : '--'}
                      </span>
                    </div>
                  )}

                  {step.id === 'embed' && (
                    <div className="flex items-center justify-between text-slate-600 dark:text-slate-300 font-semibold">
                      <span>Vector Dimensionality:</span>
                      <span className="font-mono text-indigo-600 dark:text-indigo-400 font-bold">
                        384-d normalized
                      </span>
                    </div>
                  )}

                  {step.id === 'sqlite' && (
                    <div className="flex items-center justify-between text-slate-600 dark:text-slate-300 font-semibold">
                      <span>Edge Database:</span>
                      <span className="font-mono text-slate-800 dark:text-slate-200">
                        knowledge.sqlite
                      </span>
                    </div>
                  )}

                  {step.id === 'vault' && (
                    <div className="flex items-center justify-between text-slate-600 dark:text-slate-300 font-semibold">
                      <span>Storage Status:</span>
                      <span className="font-mono text-emerald-600 dark:text-emerald-400">
                        Integrity Verified
                      </span>
                    </div>
                  )}

                  {step.id === 'package' && (
                    <div className="flex items-center justify-between text-slate-600 dark:text-slate-300 font-semibold">
                      <span>Distribution Format:</span>
                      <span className="font-mono text-emerald-600 dark:text-emerald-400 font-bold">
                        Atomic ZIP Archive
                      </span>
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Real-time Telemetry Event Log Terminal */}
      <div className="bg-slate-950 border border-slate-800 rounded-3xl p-5 shadow-2xl overflow-hidden text-slate-300 font-mono text-xs">
        <div className="flex items-center justify-between pb-3 mb-3 border-b border-slate-800">
          <div className="flex items-center gap-2">
            <Terminal className="w-4 h-4 text-emerald-400" />
            <span className="font-bold text-slate-200">LIVE RAG PIPELINE TELEMETRY</span>
          </div>
          <div className="flex items-center gap-2 text-[10px] text-slate-500">
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-ping" />
            <span>STREAMING REALTIME</span>
          </div>
        </div>

        <div className="h-44 overflow-y-auto space-y-1.5 pr-2 font-mono text-[11px] scrollbar-thin scrollbar-thumb-slate-800">
          {logLines.map((line, idx) => (
            <div key={idx} className="leading-relaxed">
              {line.includes('[SUCCESS]') || line.includes('[COMPLETE]') ? (
                <span className="text-emerald-400 font-bold">{line}</span>
              ) : line.includes('[ERROR]') ? (
                <span className="text-rose-400 font-bold">{line}</span>
              ) : line.includes('[EXTRACT]') ? (
                <span className="text-amber-300">{line}</span>
              ) : line.includes('[CHUNKER]') ? (
                <span className="text-sky-300">{line}</span>
              ) : line.includes('[EMBED]') ? (
                <span className="text-purple-300">{line}</span>
              ) : line.includes('[SQLITE]') ? (
                <span className="text-indigo-300">{line}</span>
              ) : line.includes('[PACKAGE]') ? (
                <span className="text-teal-300">{line}</span>
              ) : (
                <span className="text-slate-400">{line}</span>
              )}
            </div>
          ))}
          <div ref={logsEndRef} />
        </div>
      </div>

      {/* Completion Banner & Next Actions */}
      {job?.status === 'SUCCEEDED' && (
        <div className="bg-gradient-to-br from-emerald-500/10 via-teal-500/10 to-indigo-500/10 border-2 border-emerald-500/30 rounded-3xl p-8 shadow-apple space-y-6">
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 rounded-2xl bg-emerald-500 text-white flex items-center justify-center shadow-lg shadow-emerald-500/20">
                <CheckCircle2 className="w-7 h-7" />
              </div>
              <div>
                <h3 className="text-base font-bold text-slate-900 dark:text-white">
                  RAG Knowledge Package Generated & Signed!
                </h3>
                <p className="text-xs text-slate-600 dark:text-slate-300 mt-0.5">
                  Extracted <span className="font-semibold text-emerald-600 dark:text-emerald-400">{job.total_pages} pages</span> into{' '}
                  <span className="font-semibold text-emerald-600 dark:text-emerald-400">{job.total_chunks} semantic chunks</span> with 384-dimensional dense vectors.
                </p>
              </div>
            </div>

            {packageRecord && (
              <a
                href={api.getPackageDownloadUrl(packageRecord.id)}
                download
                className="px-4 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-semibold flex items-center gap-2 shadow-sm transition-all"
              >
                <Download className="w-4 h-4" />
                <span>Download Package (.zip)</span>
              </a>
            )}
          </div>

          {/* Quick Stats Ribbon */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 pt-4 border-t border-emerald-500/20">
            <div className="p-3 rounded-2xl bg-white/60 dark:bg-slate-900/60 border border-slate-200/50 dark:border-slate-800/50">
              <span className="text-[10px] text-slate-400 uppercase font-semibold">Extracted Pages</span>
              <p className="text-sm font-bold text-slate-900 dark:text-white font-mono mt-0.5">{job.total_pages}</p>
            </div>
            <div className="p-3 rounded-2xl bg-white/60 dark:bg-slate-900/60 border border-slate-200/50 dark:border-slate-800/50">
              <span className="text-[10px] text-slate-400 uppercase font-semibold">Semantic Chunks</span>
              <p className="text-sm font-bold text-slate-900 dark:text-white font-mono mt-0.5">{job.total_chunks}</p>
            </div>
            <div className="p-3 rounded-2xl bg-white/60 dark:bg-slate-900/60 border border-slate-200/50 dark:border-slate-800/50">
              <span className="text-[10px] text-slate-400 uppercase font-semibold">Vector Embedding</span>
              <p className="text-sm font-bold text-slate-900 dark:text-white font-mono mt-0.5">384-d MiniLM</p>
            </div>
            <div className="p-3 rounded-2xl bg-white/60 dark:bg-slate-900/60 border border-slate-200/50 dark:border-slate-800/50">
              <span className="text-[10px] text-slate-400 uppercase font-semibold">Mobile Edge Sync</span>
              <p className="text-sm font-bold text-emerald-600 dark:text-emerald-400 font-mono mt-0.5">Ready</p>
            </div>
          </div>

          {packageRecord && (
            <div className="p-4 rounded-2xl bg-white/80 dark:bg-slate-900/80 border border-slate-200/80 dark:border-slate-800 text-xs space-y-2">
              <div className="flex items-center justify-between">
                <span className="font-semibold text-slate-700 dark:text-slate-300">Package Artifact:</span>
                <span className="font-mono text-slate-900 dark:text-white font-bold">{packageRecord.package_file_name}</span>
              </div>
              <div className="flex items-center justify-between text-slate-500">
                <span>SHA-256 Checksum:</span>
                <div className="flex items-center gap-1.5 font-mono text-[10px]">
                  <span>{packageRecord.sha256_hash.slice(0, 24)}...</span>
                  <button
                    onClick={() => copyHash(packageRecord.sha256_hash)}
                    className="p-1 hover:text-slate-900 dark:hover:text-white transition-colors"
                  >
                    {copiedHash ? <Check className="w-3.5 h-3.5 text-emerald-500" /> : <Copy className="w-3.5 h-3.5" />}
                  </button>
                </div>
              </div>
            </div>
          )}

          {/* Action Buttons */}
          <div className="flex flex-wrap items-center justify-between gap-3 pt-2">
            <div className="flex items-center gap-2">
              <Link
                href="/packages"
                className="px-4 py-2 rounded-xl bg-slate-900 text-white dark:bg-white dark:text-slate-900 font-semibold text-xs flex items-center gap-1.5 hover:opacity-90 transition-opacity"
              >
                <span>View Knowledge Packages</span>
                <ArrowRight className="w-3.5 h-3.5" />
              </Link>
              <Link
                href="/jobs"
                className="px-4 py-2 rounded-xl border border-slate-200 dark:border-slate-800 font-semibold text-xs text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
              >
                <span>Jobs Ledger</span>
              </Link>
            </div>

            {onUploadAnother && (
              <button
                onClick={onUploadAnother}
                className="px-4 py-2 rounded-xl bg-indigo-50 dark:bg-indigo-950/40 text-indigo-700 dark:text-indigo-300 font-semibold text-xs hover:bg-indigo-100 transition-colors"
              >
                + Ingest Another Manual
              </button>
            )}
          </div>
        </div>
      )}

      {/* Failure Box */}
      {job?.status === 'FAILED' && (
        <div className="p-6 rounded-3xl bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-800/40 text-rose-800 dark:text-rose-300 space-y-4">
          <div className="flex items-center gap-3">
            <AlertCircle className="w-6 h-6 flex-shrink-0 text-rose-600" />
            <div>
              <h4 className="font-bold text-sm">Processing Pipeline Aborted</h4>
              <p className="text-xs text-rose-600 dark:text-rose-400 mt-0.5">
                {job.error_message || 'An error occurred during text extraction or vector embedding compilation.'}
              </p>
            </div>
          </div>
          {onUploadAnother && (
            <button
              onClick={onUploadAnother}
              className="px-4 py-2 rounded-xl bg-rose-600 text-white font-semibold text-xs hover:bg-rose-700 transition-colors"
            >
              Try Uploading Again
            </button>
          )}
        </div>
      )}
    </div>
  );
}
