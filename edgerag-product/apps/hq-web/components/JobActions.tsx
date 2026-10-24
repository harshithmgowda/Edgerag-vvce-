'use client';
import { useState } from 'react';
import { api } from '@/lib/api-client';

export function JobActions({id, failed, onRetry}: {id: string; failed: boolean; onRetry: () => void}) {
  const [busy, setBusy] = useState(false), [message, setMessage] = useState('');
  const [reports, setReports] = useState<{title: string; total_pages?: number; extractable_pages?: number; indexed_pages?: number[]; skipped_pages?: number[]; warnings: string[]}[] | null>(null);
  async function act(retry: boolean) {
    setBusy(true); setMessage('');
    try {
      if (retry) { await api.retryJob(id); setReports(null); onRetry(); }
      else { const result = await api.extractionReport(id); setReports(result.manuals); }
    } catch (e) { setMessage((e instanceof Error ? e.message : 'Request failed') + '. Sign in as an administrator if your session has expired.'); }
    finally { setBusy(false); }
  }
  return <div className="mt-4 space-y-3 text-sm">
    <div className="flex gap-3"><button className="quiet-button" disabled={busy} onClick={()=>act(false)}>Page extraction report</button>
    {failed && <button className="quiet-button" disabled={busy} onClick={()=>act(true)}>Retry processing</button>}</div>
    {message && <p role="alert" className="text-red-600 text-xs">{message}</p>}
    {reports && (reports.length ? reports.map((report, i)=><div key={i} className="rounded-xl bg-slate-50 dark:bg-slate-800/50 p-4 border border-slate-200 dark:border-slate-700 space-y-2">
      <div className="flex items-center justify-between">
        <strong className="text-slate-900 dark:text-slate-100">{report.title}</strong>
        <span className="text-xs px-2 py-0.5 rounded-full bg-blue-100 text-blue-800 dark:bg-blue-900/40 dark:text-blue-300 font-medium">
          {report.extractable_pages ?? report.indexed_pages?.length ?? 0} of {report.total_pages ?? '?'} pages indexed
        </span>
      </div>
      {report.indexed_pages && report.indexed_pages.length > 0 && (
        <p className="text-xs text-emerald-700 dark:text-emerald-400">
          ✓ Indexed pages: {report.indexed_pages.slice(0, 15).join(', ')}{report.indexed_pages.length > 15 ? `... (+${report.indexed_pages.length - 15} more)` : ''}
        </p>
      )}
      {report.skipped_pages && report.skipped_pages.length > 0 && (
        <p className="text-xs text-amber-700 dark:text-amber-400">
          ⊘ Skipped empty/lined pages: {report.skipped_pages.join(', ')}
        </p>
      )}
      {report.warnings?.length ? (
        <div className="mt-2 text-xs text-slate-600 dark:text-slate-400">
          <span className="font-semibold text-slate-700 dark:text-slate-300">Audited notices:</span>
          <ul className="list-disc pl-5 mt-1 space-y-0.5">{report.warnings.map((w,j)=><li key={j}>{w}</li>)}</ul>
        </div>
      ) : <p className="text-xs text-slate-500">All pages passed extraction validation without warnings.</p>}
    </div>) : <p className="text-xs text-slate-500">No extraction report is available yet.</p>)}
  </div>;
}
