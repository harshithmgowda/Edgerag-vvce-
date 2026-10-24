'use client';

import React, { useState, useEffect, Suspense } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { Sidebar } from '@/components/Sidebar';
import { Header } from '@/components/Header';
import { RagFlowInspector } from '@/components/RagFlowInspector';
import { api } from '@/lib/api-client';
import { Equipment } from '@/lib/types';
import {
  UploadCloud,
  FileText,
  AlertCircle,
  ArrowLeft,
  Sparkles,
  BookOpen,
  Boxes,
  Cpu,
  Database,
  PackageCheck,
  CheckCircle2,
  Layers,
} from 'lucide-react';
import Link from 'next/link';

function UploadManualContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const initialJobId = searchParams.get('job_id');

  const [equipmentList, setEquipmentList] = useState<Equipment[]>([]);
  const [equipmentId, setEquipmentId] = useState('');
  const [title, setTitle] = useState('');
  const [revision, setRevision] = useState('v1.0.0');
  const [file, setFile] = useState<File | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [uploadStatusText, setUploadStatusText] = useState('Preparing upload...');
  const [error, setError] = useState<string | null>(null);

  // Active Job State for live RAG Flow
  const [activeJobId, setActiveJobId] = useState<string | null>(initialJobId);

  useEffect(() => {
    api
      .listEquipment()
      .then((data) => {
        setEquipmentList(data);
        if (data.length > 0 && !equipmentId) setEquipmentId(data[0].id);
      })
      .catch(() => setError('Could not load equipment list.'));
  }, []);

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      const selected = e.target.files[0];
      validateAndSetFile(selected);
    }
  };

  const validateAndSetFile = (selected: File) => {
    if (!selected.name.toLowerCase().endsWith('.pdf')) {
      setError('Only valid PDF files are authorized for manual ingestion.');
      return;
    }
    if (selected.size > 50 * 1024 * 1024) {
      setError('File exceeds maximum allowable size of 50 Megabytes.');
      return;
    }
    setError(null);
    setFile(selected);
    if (!title) {
      setTitle(selected.name.replace(/\.[^/.]+$/, '').replace(/[-_]/g, ' '));
    }
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      validateAndSetFile(e.dataTransfer.files[0]);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!file || !equipmentId) {
      setError('Please select an equipment asset and attach a PDF manual.');
      return;
    }

    setUploading(true);
    setError(null);
    setUploadProgress(15);
    setUploadStatusText('Verifying PDF file integrity and metadata...');

    // Progress animation interval
    let currentPct = 15;
    const progressTimer = setInterval(() => {
      currentPct += Math.floor(Math.random() * 12) + 5;
      if (currentPct > 90) currentPct = 90;
      setUploadProgress(currentPct);
      if (currentPct > 45) {
        setUploadStatusText('Encrypting & transferring binary payload to Document Vault...');
      }
      if (currentPct > 75) {
        setUploadStatusText('Registering manual and queuing background processing job...');
      }
    }, 200);

    try {
      const formData = new FormData();
      formData.append('file', file);
      formData.append('equipment_id', equipmentId);
      formData.append('title', title);
      formData.append('revision', revision);

      const res = await api.uploadManual(formData);

      clearInterval(progressTimer);
      setUploadProgress(100);
      setUploadStatusText('Document Vault accepted. Launching Live RAG Pipeline...');

      // Transition smoothly to the Live RAG Flow Inspector
      setTimeout(() => {
        setUploading(false);
        setActiveJobId(res.job_id);
      }, 400);
    } catch (err: any) {
      clearInterval(progressTimer);
      setError(err.message || 'Upload failed');
      setUploading(false);
      setUploadProgress(0);
    }
  };

  const selectedEquipment = equipmentList.find((e) => e.id === equipmentId);

  return (
    <div className="flex min-h-screen bg-slate-50/50 dark:bg-slate-950">
      <Sidebar />

      <main className="flex-1 flex flex-col min-w-0">
        <Header
          title={activeJobId ? 'RAG Ingestion Pipeline Inspector' : 'Ingest Technical Manual'}
          subtitle={
            activeJobId
              ? 'Real-time observation of document extraction, semantic chunking, and SQLite vector compilation.'
              : 'Ingest PDF documents for PyMuPDF extraction, token chunking, and 384-d embedding compilation.'
          }
        />

        <div className="p-8 max-w-5xl mx-auto w-full">
          {/* Back button */}
          <div className="flex items-center justify-between mb-6">
            <Link
              href="/manuals"
              className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-500 hover:text-slate-900 dark:hover:text-white transition-colors"
            >
              <ArrowLeft className="w-3.5 h-3.5" />
              <span>Back to Manuals</span>
            </Link>

            {activeJobId && (
              <button
                onClick={() => {
                  setActiveJobId(null);
                  setFile(null);
                  setTitle('');
                }}
                className="inline-flex items-center gap-1 text-xs font-semibold text-indigo-600 dark:text-indigo-400 hover:underline"
              >
                + Ingest Another Manual
              </button>
            )}
          </div>

          {/* ACTIVE LIVE RAG FLOW INSPECTOR */}
          {activeJobId ? (
            <RagFlowInspector
              jobId={activeJobId}
              equipmentName={selectedEquipment?.name}
              manualTitle={title || 'Technical Manual'}
              onUploadAnother={() => {
                setActiveJobId(null);
                setFile(null);
                setTitle('');
              }}
            />
          ) : (
            /* UPLOAD FORM VIEW */
            <div className="space-y-6">
              {/* Architecture Blueprint Card */}
              <div className="bg-gradient-to-r from-slate-900 via-indigo-950 to-slate-900 text-white rounded-3xl p-6 shadow-xl border border-indigo-900/40">
                <div className="flex items-center gap-2 mb-3">
                  <Sparkles className="w-4 h-4 text-indigo-400" />
                  <span className="text-xs font-bold uppercase tracking-wider text-indigo-300">
                    Autonomous Local RAG Ingestion Flow
                  </span>
                </div>
                <p className="text-xs text-slate-300 leading-relaxed mb-4">
                  When you upload a technical manual, the pipeline deterministically executes offline extraction, tokenization, dense vector embedding, and package bundling ready for Field Engineer mobile sync:
                </p>

                <div className="grid grid-cols-2 sm:grid-cols-5 gap-2 text-center text-[11px]">
                  <div className="p-2.5 rounded-2xl bg-white/5 border border-white/10">
                    <BookOpen className="w-4 h-4 text-emerald-400 mx-auto mb-1" />
                    <span className="font-semibold text-white block">1. PyMuPDF</span>
                    <span className="text-[10px] text-slate-400">Page text extraction</span>
                  </div>
                  <div className="p-2.5 rounded-2xl bg-white/5 border border-white/10">
                    <Boxes className="w-4 h-4 text-sky-400 mx-auto mb-1" />
                    <span className="font-semibold text-white block">2. Chunking</span>
                    <span className="text-[10px] text-slate-400">224-token sliding window</span>
                  </div>
                  <div className="p-2.5 rounded-2xl bg-white/5 border border-white/10">
                    <Cpu className="w-4 h-4 text-purple-400 mx-auto mb-1" />
                    <span className="font-semibold text-white block">3. 384-d Vectors</span>
                    <span className="text-[10px] text-slate-400">all-MiniLM-L6-v2</span>
                  </div>
                  <div className="p-2.5 rounded-2xl bg-white/5 border border-white/10">
                    <Database className="w-4 h-4 text-indigo-400 mx-auto mb-1" />
                    <span className="font-semibold text-white block">4. SQLite DB</span>
                    <span className="text-[10px] text-slate-400">knowledge.sqlite compiled</span>
                  </div>
                  <div className="p-2.5 rounded-2xl bg-white/5 border border-white/10 col-span-2 sm:col-span-1">
                    <PackageCheck className="w-4 h-4 text-teal-400 mx-auto mb-1" />
                    <span className="font-semibold text-white block">5. ZIP Package</span>
                    <span className="text-[10px] text-slate-400">Signed manifest seal</span>
                  </div>
                </div>
              </div>

              {/* Main Upload Card */}
              <div className="bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl p-8 shadow-apple">
                {error && (
                  <div className="mb-6 p-4 rounded-2xl bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-800/40 text-rose-700 dark:text-rose-300 text-xs flex items-center gap-3">
                    <AlertCircle className="w-5 h-5 flex-shrink-0" />
                    <span>{error}</span>
                  </div>
                )}

                <form onSubmit={handleSubmit} className="space-y-6">
                  {/* Target Equipment Selector */}
                  <div>
                    <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5">
                      Target Equipment Asset *
                    </label>
                    {equipmentList.length === 0 ? (
                      <div className="p-3 rounded-xl bg-amber-50 dark:bg-amber-950/40 border border-amber-200 text-amber-800 text-xs">
                        No equipment registered yet.{' '}
                        <Link href="/equipment" className="underline font-semibold">
                          Register an asset first &rarr;
                        </Link>
                      </div>
                    ) : (
                      <select
                        value={equipmentId}
                        onChange={(e) => setEquipmentId(e.target.value)}
                        className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-800/50 text-xs text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-slate-900 dark:focus:ring-white"
                      >
                        {equipmentList.map((eq) => (
                          <option key={eq.id} value={eq.id}>
                            {eq.name} — {eq.model_number} ({eq.manufacturer})
                          </option>
                        ))}
                      </select>
                    )}
                  </div>

                  {/* Title & Revision */}
                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                    <div className="sm:col-span-2">
                      <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5">
                        Manual Title *
                      </label>
                      <input
                        type="text"
                        required
                        placeholder="e.g. S7-1500 Diagnostics and Fault Recovery Manual"
                        value={title}
                        onChange={(e) => setTitle(e.target.value)}
                        className="w-full px-3.5 py-2 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-800/50 text-xs text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-slate-900 dark:focus:ring-white"
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5">
                        Revision / Version *
                      </label>
                      <input
                        type="text"
                        required
                        placeholder="e.g. Rev 3.2"
                        value={revision}
                        onChange={(e) => setRevision(e.target.value)}
                        className="w-full px-3.5 py-2 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-800/50 text-xs text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-slate-900 dark:focus:ring-white"
                      />
                    </div>
                  </div>

                  {/* Drag and Drop Zone */}
                  <div>
                    <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5">
                      PDF Manual File *
                    </label>
                    <div
                      onDragOver={(e) => {
                        e.preventDefault();
                        setIsDragging(true);
                      }}
                      onDragLeave={() => setIsDragging(false)}
                      onDrop={handleDrop}
                      className={`border-2 border-dashed rounded-3xl p-8 text-center transition-all cursor-pointer ${
                        isDragging
                          ? 'border-indigo-500 bg-indigo-50/40 dark:bg-indigo-950/20'
                          : 'border-slate-200 dark:border-slate-800 hover:border-slate-400 bg-slate-50/30 dark:bg-slate-800/20'
                      }`}
                      onClick={() => document.getElementById('manual-file-input')?.click()}
                    >
                      <input
                        id="manual-file-input"
                        type="file"
                        accept=".pdf,application/pdf"
                        onChange={handleFileChange}
                        className="hidden"
                      />

                      {file ? (
                        <div className="flex items-center justify-center gap-3 text-xs text-slate-900 dark:text-white font-medium">
                          <div className="w-10 h-10 rounded-2xl bg-emerald-500/10 text-emerald-500 flex items-center justify-center">
                            <FileText className="w-5 h-5" />
                          </div>
                          <div className="text-left">
                            <p className="font-semibold text-slate-900 dark:text-white">{file.name}</p>
                            <p className="text-slate-400 text-[11px]">
                              {(file.size / (1024 * 1024)).toFixed(2)} MB • Ready for RAG Ingestion
                            </p>
                          </div>
                        </div>
                      ) : (
                        <div>
                          <div className="w-12 h-12 rounded-2xl bg-slate-100 dark:bg-slate-800 flex items-center justify-center text-slate-400 mx-auto mb-3">
                            <UploadCloud className="w-6 h-6" />
                          </div>
                          <p className="text-xs font-semibold text-slate-700 dark:text-slate-300">
                            Drop equipment PDF manual here or click to browse
                          </p>
                          <p className="text-[11px] text-slate-400 mt-1">
                            PDF format up to 50MB. Text, diagrams & page references will be extracted.
                          </p>
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Smooth Animated Upload Progress */}
                  {uploading && (
                    <div className="p-5 rounded-2xl bg-indigo-50/60 dark:bg-indigo-950/30 border border-indigo-200 dark:border-indigo-800/40 space-y-2">
                      <div className="flex justify-between text-xs font-semibold">
                        <span className="text-indigo-900 dark:text-indigo-300">{uploadStatusText}</span>
                        <span className="font-mono text-indigo-600 dark:text-indigo-400">{uploadProgress}%</span>
                      </div>
                      <div className="w-full h-2 rounded-full bg-indigo-100 dark:bg-indigo-900/40 overflow-hidden">
                        <div
                          className="h-full bg-indigo-600 dark:bg-indigo-400 transition-all duration-300 rounded-full"
                          style={{ width: `${uploadProgress}%` }}
                        />
                      </div>
                    </div>
                  )}

                  {/* Submit Button */}
                  <div className="pt-4 flex items-center justify-between">
                    <p className="text-[11px] text-slate-400">
                      Pipeline compiles local SQLite Knowledge Packages with 384-d vector embeddings.
                    </p>

                    <button
                      type="submit"
                      disabled={uploading || !file || equipmentList.length === 0}
                      className="px-6 py-2.5 rounded-xl bg-slate-900 text-white dark:bg-white dark:text-slate-900 font-semibold text-xs tracking-wide shadow-sm hover:opacity-90 disabled:opacity-50 transition-all flex items-center gap-2"
                    >
                      {uploading ? (
                        <>
                          <span className="w-3.5 h-3.5 rounded-full border-2 border-white/30 border-t-white animate-spin" />
                          <span>Uploading & Initializing...</span>
                        </>
                      ) : (
                        <>
                          <span>Start RAG Ingestion</span>
                          <Sparkles className="w-3.5 h-3.5" />
                        </>
                      )}
                    </button>
                  </div>
                </form>
              </div>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}

export default function UploadManualPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen flex items-center justify-center bg-slate-50 dark:bg-slate-950">
          <div className="text-xs text-slate-400 flex items-center gap-2">
            <span className="w-4 h-4 rounded-full border-2 border-slate-300 border-t-slate-800 animate-spin" />
            <span>Loading Ingestion Console...</span>
          </div>
        </div>
      }
    >
      <UploadManualContent />
    </Suspense>
  );
}
