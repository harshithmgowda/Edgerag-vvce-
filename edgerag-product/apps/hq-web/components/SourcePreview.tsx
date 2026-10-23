'use client';
import { useEffect, useState } from 'react';
import { api } from '@/lib/api-client';

export function SourcePreview({manualId, page, excerpt}: {manualId: string; page: number; excerpt: string}) {
  const [url, setUrl] = useState(''), [error, setError] = useState(''), [busy, setBusy] = useState(false);
  useEffect(() => () => { if (url) URL.revokeObjectURL(url); }, [url]);
  async function open() {
    setBusy(true); setError('');
    try { setUrl(URL.createObjectURL(await api.manualPage(manualId, page, excerpt))); }
    catch (e) { setError(e instanceof Error ? e.message : 'Unable to open original page'); }
    finally { setBusy(false); }
  }
  return <div className="p-4 space-y-3">
    <button className="quiet-button" onClick={open} disabled={busy}>{busy ? 'Opening…' : 'Open original page'}</button>
    {error && <p role="alert">{error} <a href="/login">Sign in</a></p>}
    {url && <><p className="text-xs text-slate-500">Exact text matches are highlighted when available.</p><img src={url} alt={`Original manual page ${page}`} className="w-full rounded-xl border" /></>}
  </div>;
}
