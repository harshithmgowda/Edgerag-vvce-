'use client';

import React, { useEffect, useState } from 'react';
import { Sidebar } from '@/components/Sidebar';
import { Header } from '@/components/Header';
import { EmptyState } from '@/components/EmptyState';
import { StatusBadge } from '@/components/StatusBadge';
import { api } from '@/lib/api-client';
import { Incident } from '@/lib/types';
import { AlertTriangle, CheckCircle2, MessageSquare, Clock, Filter, X } from 'lucide-react';

export default function IncidentsPage() {
  const [incidents, setIncidents] = useState<Incident[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState('');
  const [selectedIncident, setSelectedIncident] = useState<Incident | null>(null);
  const [reviewStatus, setReviewStatus] = useState<'OPEN' | 'IN_REVIEW' | 'RESOLVED' | 'DISMISSED'>('IN_REVIEW');
  const [reviewNotes, setReviewNotes] = useState('');
  const [submittingReview, setSubmittingReview] = useState(false);

  const fetchIncidents = async () => {
    try {
      setLoading(true);
      const data = await api.listIncidents(statusFilter || undefined);
      setIncidents(data);
    } catch {
      // Empty state
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchIncidents();
  }, [statusFilter]);

  const handleOpenReview = (inc: Incident) => {
    setSelectedIncident(inc);
    setReviewStatus(inc.status as any);
    setReviewNotes(inc.review_notes || '');
  };

  const handleSubmitReview = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedIncident) return;

    setSubmittingReview(true);
    try {
      await api.reviewIncident(selectedIncident.id, reviewStatus, reviewNotes);
      setSelectedIncident(null);
      await fetchIncidents();
    } catch (err: any) {
      alert(err.message || 'Failed to submit review');
    } finally {
      setSubmittingReview(false);
    }
  };

  return (
    <div className="flex min-h-screen">
      <Sidebar />

      <main className="flex-1 flex flex-col min-w-0">
        <Header
          title="Field Incidents & Anomaly Review"
          subtitle="Triage safety alerts and equipment defects recorded offline by field engineers."
        />

        <div className="p-8 space-y-6 flex-1 max-w-7xl mx-auto w-full">
          {/* Filter Bar */}
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <Filter className="w-4 h-4 text-slate-400" />
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="px-3 py-1.5 rounded-xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 text-xs text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-slate-900"
              >
                <option value="">All Statuses</option>
                <option value="OPEN">Open (Pending)</option>
                <option value="IN_REVIEW">Under Review</option>
                <option value="RESOLVED">Resolved</option>
                <option value="DISMISSED">Dismissed</option>
              </select>
            </div>
            <span className="text-xs text-slate-400 font-medium">{incidents.length} Incidents</span>
          </div>

          {/* Incidents List or Empty State */}
          {incidents.length === 0 && !loading ? (
            <EmptyState
              icon={AlertTriangle}
              title="No Incidents Reported"
              description="Field technicians record incidents offline on their mobile devices. When they reconnect to the headquarters Wi-Fi / Hotspot LAN, incidents will sync here automatically."
            />
          ) : (
            <div className="space-y-4">
              {incidents.map((inc) => (
                <div
                  key={inc.id}
                  className="bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl p-6 shadow-apple hover:shadow-apple-hover transition-all duration-200 flex flex-col justify-between"
                >
                  <div className="flex items-start justify-between">
                    <div>
                      <div className="flex items-center gap-3">
                        <StatusBadge status={inc.severity} />
                        <h3 className="font-semibold text-slate-900 dark:text-white text-sm tracking-tight">
                          {inc.title}
                        </h3>
                        <StatusBadge status={inc.status} />
                      </div>
                      <p className="mt-2 text-xs text-slate-600 dark:text-slate-300 leading-relaxed max-w-4xl">
                        {inc.description}
                      </p>
                    </div>

                    <button
                      onClick={() => handleOpenReview(inc)}
                      className="px-3 py-1.5 rounded-xl text-xs font-semibold bg-slate-100 dark:bg-slate-800 text-slate-900 dark:text-white hover:bg-slate-200 dark:hover:bg-slate-700 transition-colors"
                    >
                      Review Ticket
                    </button>
                  </div>

                  {inc.review_notes && (
                    <div className="mt-4 p-3 rounded-2xl bg-slate-50 dark:bg-slate-800/50 border border-slate-100 dark:border-slate-800 text-xs">
                      <span className="font-semibold text-slate-500">Administrator Review: </span>
                      <span className="text-slate-700 dark:text-slate-300">{inc.review_notes}</span>
                    </div>
                  )}

                  <div className="mt-4 pt-3 border-t border-slate-100 dark:border-slate-800/80 flex items-center justify-between text-[11px] text-slate-400">
                    <span>UUID: {inc.id.slice(0, 8)}...</span>
                    <span>Recorded Offline: {new Date(inc.recorded_offline_at).toLocaleString()}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </main>

      {/* Incident Review Modal Drawer */}
      {selectedIncident && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-sm">
          <div className="w-full max-w-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl p-6 shadow-2xl">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100 dark:border-slate-800">
              <div>
                <h3 className="text-base font-semibold text-slate-900 dark:text-white">Review Field Incident</h3>
                <p className="text-xs text-slate-400">Ticket ID: {selectedIncident.id}</p>
              </div>
              <button
                onClick={() => setSelectedIncident(null)}
                className="p-1 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-white"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="mt-4 p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/50 space-y-1.5 text-xs">
              <p className="font-semibold text-slate-900 dark:text-white">{selectedIncident.title}</p>
              <p className="text-slate-600 dark:text-slate-300">{selectedIncident.description}</p>
              <div className="pt-2 flex items-center gap-2">
                <StatusBadge status={selectedIncident.severity} />
                <span className="text-slate-400">Recorded: {new Date(selectedIncident.recorded_offline_at).toLocaleDateString()}</span>
              </div>
            </div>

            <form onSubmit={handleSubmitReview} className="mt-4 space-y-4">
              <div>
                <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5">
                  Update Resolution Status *
                </label>
                <select
                  value={reviewStatus}
                  onChange={(e: any) => setReviewStatus(e.target.value)}
                  className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-800 text-xs text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-slate-900"
                >
                  <option value="IN_REVIEW">IN_REVIEW (Under Engineering Investigation)</option>
                  <option value="RESOLVED">RESOLVED (Corrective Action Taken)</option>
                  <option value="DISMISSED">DISMISSED (Not a Defect / False Alarm)</option>
                  <option value="OPEN">OPEN (Pending Triage)</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5">
                  Administrator Review Notes / Corrective Actions *
                </label>
                <textarea
                  rows={4}
                  required
                  placeholder="e.g. Dispatched replacement thermal sensor. Verified electrical schematic page 42."
                  value={reviewNotes}
                  onChange={(e) => setReviewNotes(e.target.value)}
                  className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-800 text-xs text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-slate-900"
                />
              </div>

              <div className="pt-3 flex items-center justify-end gap-3">
                <button
                  type="button"
                  onClick={() => setSelectedIncident(null)}
                  className="px-4 py-2 rounded-xl text-xs font-medium text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={submittingReview}
                  className="px-5 py-2 rounded-xl text-xs font-semibold bg-slate-900 text-white dark:bg-white dark:text-slate-900 shadow-sm hover:opacity-90 disabled:opacity-50"
                >
                  {submittingReview ? 'Submitting...' : 'Save Incident Review'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
