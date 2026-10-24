'use client';

import React, { useId, useRef, useState } from 'react';
import { Trash2 } from 'lucide-react';
import { api, ApiError } from '@/lib/api-client';

export function DeleteRecordButton({ kind, id, name, onDeleted, onMessage }: {
  kind: 'equipment' | 'manual';
  id: string;
  name: string;
  onDeleted: () => void;
  onMessage: (message: string) => void;
}) {
  const [busy, setBusy] = useState(false);
  const [needsLogin, setNeedsLogin] = useState(false);
  const [username, setUsername] = useState('admin');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const pending = useRef(false);
  const dialog = useRef<HTMLDialogElement>(null);
  const titleId = useId();
  const impact = kind === 'equipment'
    ? 'This permanently deletes its HQ manuals, knowledge packages, and incidents as well.'
    : 'This permanently deletes the HQ PDF and invalidates all published knowledge packages for its equipment. Publish a fresh package for remaining manuals.';

  function open() {
    setError('');
    setPassword('');
    setNeedsLogin(!localStorage.getItem('edgerag_token'));
    dialog.current?.showModal();
  }

  async function signIn(event: React.FormEvent) {
    event.preventDefault();
    if (pending.current) return;
    pending.current = true;
    setBusy(true);
    setError('');
    try {
      const result = await api.login(username.trim(), password);
      if (result.user.role !== 'ADMIN') throw new Error('Use a Headquarters administrator account to delete records.');
      localStorage.setItem('edgerag_token', result.access_token);
      localStorage.setItem('edgerag_user', JSON.stringify(result.user));
      setPassword('');
      setNeedsLogin(false);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Sign-in failed.');
    } finally {
      pending.current = false;
      setBusy(false);
    }
  }

  async function remove() {
    if (pending.current || needsLogin) return;
    pending.current = true;
    setBusy(true);
    setError('');
    onMessage('');
    try {
      const result = kind === 'equipment' ? await api.deleteEquipment(id) : await api.deleteManual(id);
      if (!result.deleted) throw new Error('Deletion was not confirmed. Refresh and try again.');
      dialog.current?.close();
      onDeleted();
      onMessage(result.cleanup_pending > 0
        ? 'Deleted "' + name + '". Server file cleanup needs administrator attention.'
        : 'Deleted "' + name + '".');
    } catch (err) {
      if (err instanceof ApiError && (err.status === 401 || err.status === 403)) {
        setNeedsLogin(true);
        setError('Sign in with a Headquarters administrator account to continue.');
      } else {
        setError(err instanceof Error ? err.message : 'Deletion failed. Please try again.');
      }
    } finally {
      pending.current = false;
      setBusy(false);
    }
  }

  return <>
    <button type="button" disabled={busy} onClick={open}
      aria-label={'Delete ' + kind + ': ' + name}
      className="inline-flex items-center gap-2 rounded-full px-3 py-2 text-xs font-medium text-red-700 dark:text-red-300 hover:bg-red-50 dark:hover:bg-red-950 disabled:opacity-50">
      <Trash2 size={15} />Delete
    </button>
    <dialog ref={dialog} aria-labelledby={titleId}
      onCancel={event => { if (pending.current) event.preventDefault(); }}
      onClose={() => setPassword('')}
      className="m-auto w-[calc(100%-2rem)] max-w-lg rounded-3xl border border-slate-200 bg-white p-6 text-left text-slate-900 shadow-xl backdrop:bg-slate-900/40 dark:border-slate-700 dark:bg-slate-900 dark:text-white">
      <h2 id={titleId} className="text-xl font-medium">Delete “{name}”?</h2>
      <p className="mt-4 text-sm leading-relaxed">{impact}</p>
      <p className="mt-3 text-sm text-slate-500 dark:text-slate-400">Offline devices retain existing downloads until removed locally. This cannot be undone.</p>
      {error && <p role="alert" className="mt-4 rounded-xl bg-red-50 p-3 text-sm text-red-800 dark:bg-red-950 dark:text-red-200">{error}</p>}
      {needsLogin ? <form onSubmit={signIn} className="mt-5 space-y-4">
        <p className="text-sm">Sign in as an administrator, then confirm deletion.</p>
        <label className="block text-sm">Username
          <input required autoComplete="username" value={username} onChange={event => setUsername(event.target.value)}
            className="mt-1 w-full rounded-xl border border-slate-300 bg-transparent px-3 py-2" />
        </label>
        <label className="block text-sm">Password
          <input required type="password" autoComplete="current-password" value={password} onChange={event => setPassword(event.target.value)}
            className="mt-1 w-full rounded-xl border border-slate-300 bg-transparent px-3 py-2" />
        </label>
        <div className="flex justify-end gap-3">
          <button type="button" disabled={busy} onClick={() => dialog.current?.close()} className="rounded-full px-4 py-2">Cancel</button>
          <button type="submit" disabled={busy} className="rounded-full bg-blue-700 px-4 py-2 text-white disabled:opacity-50">{busy ? 'Signing in…' : 'Sign in'}</button>
        </div>
      </form> : <div className="mt-6 flex justify-end gap-3">
        <button type="button" disabled={busy} onClick={() => dialog.current?.close()} className="rounded-full px-4 py-2">Cancel</button>
        <button type="button" disabled={busy} onClick={remove} className="rounded-full bg-red-700 px-4 py-2 text-white disabled:opacity-50">{busy ? 'Deleting…' : 'Delete permanently'}</button>
      </div>}
    </dialog>
  </>;
}
