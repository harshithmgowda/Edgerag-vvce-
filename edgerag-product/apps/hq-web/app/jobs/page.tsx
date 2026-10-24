'use client';

import React, { useEffect, useState } from 'react';
import Link from 'next/link';
import { Sidebar } from '@/components/Sidebar';
import { Header } from '@/components/Header';
import { EmptyState } from '@/components/EmptyState';
import { StatusBadge } from '@/components/StatusBadge';
import { ProcessingJob } from '@/lib/types';
import { JobActions } from '@/components/JobActions';
import {
  Layers,
  RefreshCw,
  CheckCircle2,
  AlertCircle,
  Clock,
  ArrowRight,
  ShieldCheck,
  BookOpen,
  Boxes,
  Cpu,
  Database,
  PackageCheck,
  ExternalLink,
} from 'lucide-react';

const STAGES = [
  { key: 'INIT', label: 'Vault', icon: ShieldCheck },
  { key: 'EXTRACTING_PAGES', label: 'Extract', icon: BookOpen },
  { key: 'CHUNKING', label: 'Chunk', icon: Boxes },
  { key: 'EMBEDDING', label: 'Embed', icon: Cpu },
  { key: 'GENERATING_SQLITE', label: 'SQLite', icon: Database },
  { key: 'PACKAGING', label: 'Package', icon: PackageCheck },
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

export default function ProcessingJobsPage() {
  const [jobs, setJobs] = useState<ProcessingJob[]>([]);
  const [loading, setLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);

  const fetchJobs = async () => {
    try {
      setIsRefreshing(true);
      const res = await fetch(`${process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:8000/api/v1'}/jobs`);
      if (res.ok) {
        const data = await res.json();
        setJobs(data);
      }
    } catch {
      // Empty if no jobs yet
    } finally {
      setLoading(false);
      setIsRefreshing(false);
    }
  };

  useEffect(() => {
    fetchJobs();
    const interval = setInterval(fetchJobs, 4000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="flex min-h-screen bg-slate-50/50 dark:bg-slate-950">
      <Sidebar />

      <main className="flex-1 flex flex-col min-w-0">
        <Header
          title="RAG Knowledge Processing Jobs"
          subtitle="Real-time worker pipeline for PDF extraction, chunking, and 384-dimensional vector embedding."
          action={
            <div className="flex items-center gap-3">
              <Link
                href="/manuals/upload"
                className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-slate-900 text-white dark:bg-white dark:text-slate-900 text-xs font-semibold hover:opacity-90 transition-opacity"
              >
                <span>+ Upload Manual</span>
              </Link>
              <button
                onClick={fetchJobs}
                disabled={isRefreshing}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl border border-slate-200 dark:border-slate-800 text-xs font-semibold text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
              >
                <RefreshCw className={`w-3.5 h-3.5 ${isRefreshing ? 'animate-spin' : ''}`} />
                <span>Refresh</span>
              </button>
            </div>
          }
        />

        <div className="p-8 space-y-6 flex-1 max-w-7xl mx-auto w-full">
          {jobs.length === 0 && !loading ? (
            <EmptyState
              icon={Layers}
              title="No Processing Jobs"
              description="When manuals are uploaded, local extraction, token chunking, and dense vector embeddings will execute and record telemetry here."
              actionText="Upload a Manual"
              actionHref="/manuals/upload"
            />
          ) : (
            <div className="space-y-4">
              {jobs.map((job) => {
                const currentStageLevel =
                  job.status === 'SUCCEEDED' ? 7 : STAGE_ORDER_MAP[job.stage] || 1;

                return (
                  <div
                    key={job.id}
                    className="bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl p-6 shadow-apple hover:shadow-md transition-shadow"
                  >
                    <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
                      <div>
                        <div className="flex items-center gap-3">
                          <h3 className="font-semibold text-slate-900 dark:text-white text-sm">
                            Job: {job.id.slice(0, 8)}...
                          </h3>
                          <StatusBadge status={job.status} />
                          <span className="text-[11px] font-mono px-2 py-0.5 rounded-md bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 font-semibold">
                            {job.stage}
                          </span>
                        </div>
                        <p className="mt-1 text-xs text-slate-400">
                          Manual ID: <span className="font-mono text-slate-600 dark:text-slate-300">{job.manual_id.slice(0, 8)}...</span> • Equipment:{' '}
                          <span className="font-mono text-slate-600 dark:text-slate-300">{job.equipment_id.slice(0, 8)}...</span>
                        </p>
                      </div>

                      <div className="flex items-center gap-4">
                        <div className="text-right text-xs text-slate-400">
                          <p>{new Date(job.created_at).toLocaleTimeString()}</p>
                          {job.completed_at && (
                            <p className="text-[10px] text-emerald-500 font-semibold">
                              Duration:{' '}
                              {Math.round(
                                (new Date(job.completed_at).getTime() - new Date(job.created_at).getTime()) /
                                  1000
                              )}
                              s
                            </p>
                          )}
                        </div>

                        {/* Direct link to Inspect Flow */}
                        <Link
                          href={`/manuals/upload?job_id=${job.id}`}
                          className="px-3 py-1.5 rounded-xl bg-indigo-50 dark:bg-indigo-950/40 text-indigo-700 dark:text-indigo-300 border border-indigo-200 dark:border-indigo-800/40 text-xs font-semibold flex items-center gap-1.5 hover:bg-indigo-100 dark:hover:bg-indigo-900/50 transition-colors"
                        >
                          <span>Inspect Flow</span>
                          <ArrowRight className="w-3.5 h-3.5" />
                        </Link>
                      </div>
                    </div>

                    {/* Visual 6-Stage Pipeline Stepper */}
                    <div className="mt-5 pt-4 border-t border-slate-100 dark:border-slate-800/80">
                      <div className="grid grid-cols-2 sm:grid-cols-6 gap-2">
                        {STAGES.map((stg, idx) => {
                          const stepLevel = idx + 1;
                          const isDone = currentStageLevel > stepLevel;
                          const isActive = currentStageLevel === stepLevel && job.status !== 'FAILED';
                          const isFailed = currentStageLevel === stepLevel && job.status === 'FAILED';
                          const Icon = stg.icon;

                          return (
                            <div
                              key={stg.key}
                              className={`p-2 rounded-2xl border text-center transition-all ${
                                isDone
                                  ? 'bg-emerald-50/50 dark:bg-emerald-950/20 border-emerald-300/70 dark:border-emerald-800/40 text-emerald-700 dark:text-emerald-400'
                                  : isActive
                                  ? 'bg-indigo-50/70 dark:bg-indigo-950/40 border-indigo-500 ring-1 ring-indigo-500 text-indigo-700 dark:text-indigo-300 animate-pulse'
                                  : isFailed
                                  ? 'bg-rose-50 dark:bg-rose-950/30 border-rose-300 text-rose-700'
                                  : 'bg-slate-50/50 dark:bg-slate-800/30 border-slate-200/50 dark:border-slate-800/50 text-slate-400 opacity-60'
                              }`}
                            >
                              <div className="flex items-center justify-center gap-1.5 text-xs font-semibold">
                                {isDone ? (
                                  <CheckCircle2 className="w-3.5 h-3.5 text-emerald-500 flex-shrink-0" />
                                ) : (
                                  <Icon className="w-3.5 h-3.5 flex-shrink-0" />
                                )}
                                <span className="text-[11px]">{stg.label}</span>
                              </div>
                            </div>
                          );
                        })}
                      </div>
                    </div>

                    {/* Progress Bar */}
                    <div className="mt-4 space-y-1.5">
                      <div className="flex justify-between text-xs text-slate-500 font-medium">
                        <span>Pipeline Progress</span>
                        <span className="font-mono font-bold text-slate-900 dark:text-white">
                          {job.progress_percentage}%
                        </span>
                      </div>
                      <div className="w-full h-2 rounded-full bg-slate-100 dark:bg-slate-800 overflow-hidden">
                        <div
                          className={`h-full transition-all duration-300 ${
                            job.status === 'FAILED'
                              ? 'bg-rose-500'
                              : job.status === 'SUCCEEDED'
                              ? 'bg-emerald-500'
                              : 'bg-gradient-to-r from-indigo-500 to-emerald-400'
                          }`}
                          style={{ width: `${job.progress_percentage}%` }}
                        />
                      </div>
                    </div>

                    <JobActions id={job.id} failed={job.status === 'FAILED'} onRetry={fetchJobs}/>
                    {/* Stage Metrics */}
                    <div className="mt-4 pt-4 border-t border-slate-100 dark:border-slate-800/80 grid grid-cols-2 md:grid-cols-4 gap-4 text-xs">
                      <div>
                        <span className="text-slate-400">Extracted Pages</span>
                        <p className="font-semibold text-slate-900 dark:text-white font-mono">
                          {job.total_pages ?? '--'}
                        </p>
                      </div>
                      <div>
                        <span className="text-slate-400">Generated Chunks</span>
                        <p className="font-semibold text-slate-900 dark:text-white font-mono">
                          {job.total_chunks ?? '--'}
                        </p>
                      </div>
                      <div>
                        <span className="text-slate-400">Embedding Model</span>
                        <p className="font-semibold text-slate-900 dark:text-white">all-MiniLM-L6-v2</p>
                      </div>
                      <div>
                        <span className="text-slate-400">Vector Dimensions</span>
                        <p className="font-semibold text-slate-900 dark:text-white font-mono">384-d normalized</p>
                      </div>
                    </div>

                    {job.error_message && (
                      <div className="mt-4 p-3 rounded-xl bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-800/40 text-rose-700 dark:text-rose-300 text-xs flex items-center gap-2">
                        <AlertCircle className="w-4 h-4 flex-shrink-0" />
                        <span>{job.error_message}</span>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </main>
    </div>
  );
}
