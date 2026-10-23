'use client';

import React, { useEffect, useState } from 'react';
import Link from 'next/link';
import { Sidebar } from '@/components/Sidebar';
import { Header } from '@/components/Header';
import { EmptyState } from '@/components/EmptyState';
import { StatusBadge } from '@/components/StatusBadge';
import { api } from '@/lib/api-client';
import { Manual, Equipment } from '@/lib/types';
import { DeleteRecordButton } from '@/components/DeleteRecordButton';
import { BookOpen, UploadCloud, FileText, CheckCircle, Clock } from 'lucide-react';

export default function ManualsPage() {
  const [manuals, setManuals] = useState<Manual[]>([]);
  const [equipmentList, setEquipmentList] = useState<Equipment[]>([]);
  const [selectedEquipment, setSelectedEquipment] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);
  const [deleteMessage, setDeleteMessage] = useState('');

  useEffect(() => {
    async function loadData() {
      try {
        setLoading(true);
        const [manData, eqData] = await Promise.all([
          api.listManuals(selectedEquipment || undefined),
          api.listEquipment(),
        ]);
        setManuals(manData);
        setEquipmentList(eqData);
      } catch (err: any) {
        setError(err.message || 'Failed to load manuals');
      } finally {
        setLoading(false);
      }
    }

    loadData();
  }, [selectedEquipment]);

  const getEquipmentName = (id: string) => {
    const eq = equipmentList.find((e) => e.id === id);
    return eq ? eq.name : 'Unknown Equipment';
  };

  return (
    <div className="flex min-h-screen">
      <Sidebar />

      <main className="flex-1 flex flex-col min-w-0">
        <Header
          title="Technical Equipment Manuals"
          subtitle="Original PDF engineering documentation ingested for RAG vectorization."
          action={
            <Link
              href="/manuals/upload"
              className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-xl text-xs font-semibold bg-slate-900 text-white dark:bg-white dark:text-slate-900 shadow-sm hover:opacity-90 transition-opacity"
            >
              <UploadCloud className="w-3.5 h-3.5" />
              <span>Upload PDF Manual</span>
            </Link>
          }
        />

        <div className="p-8 space-y-6 flex-1 max-w-7xl mx-auto w-full">
          {deleteMessage && <p role="status" className="rounded-xl border border-slate-200 p-4 text-sm dark:border-slate-700">{deleteMessage}</p>}
          {error && <p role="alert" className="text-sm text-red-700 dark:text-red-300">{error}</p>}
          {/* Filter Bar */}
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <label className="text-xs font-semibold text-slate-500">Filter by Equipment:</label>
              <select
                value={selectedEquipment}
                onChange={(e) => setSelectedEquipment(e.target.value)}
                className="px-3 py-1.5 rounded-xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 text-xs text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-slate-900"
              >
                <option value="">All Equipment Assets</option>
                {equipmentList.map((eq) => (
                  <option key={eq.id} value={eq.id}>
                    {eq.name} ({eq.model_number})
                  </option>
                ))}
              </select>
            </div>
            <span className="text-xs text-slate-400 font-medium">{manuals.length} Manuals Ingested</span>
          </div>

          {/* Manuals Table or Empty State */}
          {manuals.length === 0 && !loading ? (
            <EmptyState
              icon={BookOpen}
              title="No Manuals Ingested Yet"
              description="Upload your equipment PDF manuals to extract text, create vector embeddings, and generate offline knowledge packages."
              actionText="Upload First PDF"
              actionHref="/manuals/upload"
            />
          ) : (
            <div className="bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl overflow-hidden shadow-apple">
              <div className="overflow-x-auto">
                <table className="w-full text-left text-xs">
                  <thead className="bg-slate-50/75 dark:bg-slate-800/50 border-b border-slate-100 dark:border-slate-800 text-slate-400 font-semibold uppercase tracking-wider">
                    <tr>
                      <th className="py-3.5 px-6">Manual Title</th>
                      <th className="py-3.5 px-6">Associated Equipment</th>
                      <th className="py-3.5 px-6">Revision</th>
                      <th className="py-3.5 px-6">Pages / Size</th>
                      <th className="py-3.5 px-6">Processing Status</th>
                      <th className="py-3.5 px-6 text-right">Uploaded</th>
                      <th className="py-3.5 px-6 text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100 dark:divide-slate-800/60">
                    {manuals.map((man) => (
                      <tr key={man.id} className="hover:bg-slate-50/50 dark:hover:bg-slate-800/30 transition-colors">
                        <td className="py-4 px-6">
                          <div className="flex items-center gap-3">
                            <div className="w-8 h-8 rounded-xl bg-slate-100 dark:bg-slate-800 flex items-center justify-center text-slate-600 dark:text-slate-300">
                              <FileText className="w-4 h-4" />
                            </div>
                            <div>
                              <p className="font-semibold text-slate-900 dark:text-white">{man.title}</p>
                              <p className="text-[11px] text-slate-400">{man.file_name}</p>
                            </div>
                          </div>
                        </td>
                        <td className="py-4 px-6 font-medium text-slate-700 dark:text-slate-300">
                          {getEquipmentName(man.equipment_id)}
                        </td>
                        <td className="py-4 px-6">
                          <span className="px-2 py-0.5 rounded-full bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 font-semibold text-[11px]">
                            {man.revision}
                          </span>
                        </td>
                        <td className="py-4 px-6 text-slate-500">
                          {man.page_count} pages • {(man.file_size_bytes / (1024 * 1024)).toFixed(1)} MB
                        </td>
                        <td className="py-4 px-6">
                          <StatusBadge status={man.status} />
                        </td>
                        <td className="py-4 px-6 text-right text-slate-400">
                          {new Date(man.created_at).toLocaleDateString()}
                        </td>
                        <td className="py-4 px-6 text-right">
                          <DeleteRecordButton kind="manual" id={man.id} name={man.title}
                            onDeleted={() => setManuals(items => items.filter(item => item.id !== man.id))}
                            onMessage={setDeleteMessage} />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}
