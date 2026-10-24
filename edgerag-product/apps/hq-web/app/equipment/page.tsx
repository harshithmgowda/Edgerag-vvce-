'use client';

import React, { useEffect, useState } from 'react';
import { Sidebar } from '@/components/Sidebar';
import { Header } from '@/components/Header';
import { EmptyState } from '@/components/EmptyState';
import { api } from '@/lib/api-client';
import { Equipment } from '@/lib/types';
import { DeleteRecordButton } from '@/components/DeleteRecordButton';
import { Cpu, Plus, Search, Tag, Building2, Hash, X } from 'lucide-react';

export default function EquipmentPage() {
  const [equipmentList, setEquipmentList] = useState<Equipment[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [isModalOpen, setIsModalOpen] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);
  const [deleteMessage, setDeleteMessage] = useState('');

  // Form state
  const [name, setName] = useState('');
  const [modelNumber, setModelNumber] = useState('');
  const [manufacturer, setManufacturer] = useState('');
  const [serialNumber, setSerialNumber] = useState('');
  const [description, setDescription] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const fetchEquipment = async () => {
    try {
      setLoading(true);
      const data = await api.listEquipment();
      setEquipmentList(data);
    } catch (err: any) {
      setError(err.message || 'Failed to load equipment');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchEquipment();
  }, []);

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    setError(null);

    try {
      await api.createEquipment({
        name,
        model_number: modelNumber,
        manufacturer,
        serial_number: serialNumber,
        description,
      });

      setIsModalOpen(false);
      setName('');
      setModelNumber('');
      setManufacturer('');
      setSerialNumber('');
      setDescription('');
      await fetchEquipment();
    } catch (err: any) {
      setError(err.message || 'Failed to create equipment');
    } finally {
      setSubmitting(false);
    }
  };

  const filteredEquipment = equipmentList.filter(
    (eq) =>
      eq.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      eq.model_number.toLowerCase().includes(searchTerm.toLowerCase()) ||
      eq.manufacturer.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="flex min-h-screen">
      <Sidebar />

      <main className="flex-1 flex flex-col min-w-0">
        <Header
          title="Industrial Equipment Registry"
          subtitle="Manage machinery assets, model numbers, and technical documentation associations."
          action={
            <button
              onClick={() => setIsModalOpen(true)}
              className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-xl text-xs font-semibold bg-slate-900 text-white dark:bg-white dark:text-slate-900 shadow-sm hover:opacity-90 transition-opacity"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>Register Equipment</span>
            </button>
          }
        />

        <div className="p-8 space-y-6 flex-1 max-w-7xl mx-auto w-full">
          {deleteMessage && <p role="status" className="rounded-xl border border-slate-200 p-4 text-sm dark:border-slate-700">{deleteMessage}</p>}
          {error && !isModalOpen && <p role="alert" className="text-sm text-red-700 dark:text-red-300">{error}</p>}
          {/* Search bar */}
          <div className="flex items-center justify-between">
            <div className="relative w-80">
              <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-3" />
              <input
                type="text"
                placeholder="Search by name, model, manufacturer..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 rounded-xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 text-xs focus:outline-none focus:ring-2 focus:ring-slate-900 dark:focus:ring-white transition-all text-slate-900 dark:text-white"
              />
            </div>
            <span className="text-xs text-slate-400 font-medium">{filteredEquipment.length} Registered</span>
          </div>

          {/* Equipment Grid or Empty State */}
          {filteredEquipment.length === 0 && !loading ? (
            <EmptyState
              icon={Cpu}
              title="No Equipment Registered"
              description="Register your first industrial machinery asset to associate manuals and deploy knowledge packages to field engineers."
              actionText="Register Asset"
              onActionClick={() => setIsModalOpen(true)}
            />
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
              {filteredEquipment.map((eq) => (
                <div
                  key={eq.id}
                  className="bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl p-6 shadow-apple hover:shadow-apple-hover transition-all duration-200 flex flex-col justify-between"
                >
                  <div>
                    <div className="flex items-start justify-between mb-3">
                      <div className="w-10 h-10 rounded-2xl bg-slate-100 dark:bg-slate-800 flex items-center justify-center text-slate-800 dark:text-slate-200 font-bold">
                        <Cpu className="w-5 h-5" />
                      </div>
                      <span className="text-[11px] font-semibold px-2 py-0.5 rounded-full bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400">
                        {eq.manufacturer}
                      </span>
                    </div>

                    <h3 className="font-semibold text-slate-900 dark:text-white text-base tracking-tight">{eq.name}</h3>
                    {eq.description && (
                      <p className="mt-1 text-xs text-slate-500 dark:text-slate-400 line-clamp-2">{eq.description}</p>
                    )}

                    <div className="mt-4 pt-4 border-t border-slate-100 dark:border-slate-800/80 space-y-1.5 text-xs text-slate-500 dark:text-slate-400">
                      <div className="flex items-center gap-2">
                        <Tag className="w-3.5 h-3.5 text-slate-400" />
                        <span>Model: <strong className="text-slate-700 dark:text-slate-300">{eq.model_number}</strong></span>
                      </div>
                      <div className="flex items-center gap-2">
                        <Hash className="w-3.5 h-3.5 text-slate-400" />
                        <span>Serial: <strong className="text-slate-700 dark:text-slate-300">{eq.serial_number}</strong></span>
                      </div>
                    </div>
                  </div>

                  <div className="mt-6 pt-3 flex items-center justify-between text-[11px] text-slate-400">
                    <span>UUID: {eq.id.slice(0, 8)}...</span>
                    <span>{new Date(eq.created_at).toLocaleDateString()}</span>
                    <DeleteRecordButton kind="equipment" id={eq.id} name={eq.name}
                      onDeleted={() => setEquipmentList(items => items.filter(item => item.id !== eq.id))}
                      onMessage={setDeleteMessage} />
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </main>

      {/* Create Equipment Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-sm">
          <div className="w-full max-w-lg bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl p-6 shadow-2xl">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100 dark:border-slate-800">
              <h3 className="text-base font-semibold text-slate-900 dark:text-white">Register Industrial Equipment</h3>
              <button
                onClick={() => setIsModalOpen(false)}
                className="p-1 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-white"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {error && (
              <div className="mt-4 p-3 rounded-xl bg-rose-50 text-rose-700 dark:bg-rose-950/40 dark:text-rose-300 text-xs">
                {error}
              </div>
            )}

            <form onSubmit={handleCreate} className="mt-4 space-y-4">
              <div>
                <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1">
                  Equipment Asset Name *
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Siemens S7-1500 Modular PLC"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="w-full px-3.5 py-2 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-800 text-xs text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-slate-900"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1">
                    Model Number *
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. 6ES7516-3AN02"
                    value={modelNumber}
                    onChange={(e) => setModelNumber(e.target.value)}
                    className="w-full px-3.5 py-2 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-800 text-xs text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-slate-900"
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1">
                    Manufacturer *
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Siemens AG"
                    value={manufacturer}
                    onChange={(e) => setManufacturer(e.target.value)}
                    className="w-full px-3.5 py-2 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-800 text-xs text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-slate-900"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1">
                  Serial Number *
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. SN-2026-X9920"
                  value={serialNumber}
                  onChange={(e) => setSerialNumber(e.target.value)}
                  className="w-full px-3.5 py-2 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-800 text-xs text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-slate-900"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1">
                  Technical Description
                </label>
                <textarea
                  rows={3}
                  placeholder="Substation high-voltage power monitoring PLC controlling busbars 1 & 2."
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  className="w-full px-3.5 py-2 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-800 text-xs text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-slate-900"
                />
              </div>

              <div className="pt-3 flex items-center justify-end gap-3">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-4 py-2 rounded-xl text-xs font-medium text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-4 py-2 rounded-xl text-xs font-semibold bg-slate-900 text-white dark:bg-white dark:text-slate-900 shadow-sm hover:opacity-90 disabled:opacity-50"
                >
                  {submitting ? 'Registering...' : 'Save Equipment'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
