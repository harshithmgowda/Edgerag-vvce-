'use client';

import React, { useEffect, useState } from 'react';
import Link from 'next/link';
import { Sidebar } from '@/components/Sidebar';
import { Header } from '@/components/Header';
import { MetricCard } from '@/components/MetricCard';
import { StatusBadge } from '@/components/StatusBadge';
import { EmptyState } from '@/components/EmptyState';
import { api } from '@/lib/api-client';
import { Equipment, Manual, KnowledgePackage, Device, Incident, ProcessingJob } from '@/lib/types';
import {
  Cpu,
  BookOpen,
  Package,
  Smartphone,
  AlertTriangle,
  UploadCloud,
  CheckCircle2,
  Clock,
  ExternalLink,
} from 'lucide-react';
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  Cell,
} from 'recharts';

export default function DashboardPage() {
  const [equipment, setEquipment] = useState<Equipment[]>([]);
  const [manuals, setManuals] = useState<Manual[]>([]);
  const [packages, setPackages] = useState<KnowledgePackage[]>([]);
  const [devices, setDevices] = useState<Device[]>([]);
  const [incidents, setIncidents] = useState<Incident[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function loadDashboardData() {
      try {
        setLoading(true);
        const [eqData, manData, pkgData, devData, incData] = await Promise.all([
          api.listEquipment().catch(() => []),
          api.listManuals().catch(() => []),
          api.listPackages().catch(() => []),
          api.listDevices().catch(() => []),
          api.listIncidents().catch(() => []),
        ]);

        setEquipment(eqData);
        setManuals(manData);
        setPackages(pkgData);
        setDevices(devData);
        setIncidents(incData);
      } catch (err: any) {
        setError(err.message || 'Failed to load dashboard data');
      } finally {
        setLoading(false);
      }
    }

    loadDashboardData();
  }, []);

  // Compute real stats from actual database records
  const pendingIncidentsCount = incidents.filter((i) => i.status === 'OPEN' || i.status === 'IN_REVIEW').length;
  const activeDevicesCount = devices.filter((d) => d.status === 'ACTIVE').length;

  // Prepare chart data only if incidents exist
  const incidentSeverityData = [
    { severity: 'CRITICAL', count: incidents.filter((i) => i.severity === 'CRITICAL').length, color: '#f43f5e' },
    { severity: 'HIGH', count: incidents.filter((i) => i.severity === 'HIGH').length, color: '#fb923c' },
    { severity: 'MEDIUM', count: incidents.filter((i) => i.severity === 'MEDIUM').length, color: '#fbbf24' },
    { severity: 'LOW', count: incidents.filter((i) => i.severity === 'LOW').length, color: '#94a3b8' },
  ].filter((item) => item.count > 0);

  const hasAnyData = equipment.length > 0 || manuals.length > 0 || packages.length > 0 || devices.length > 0;

  return (
    <div className="flex min-h-screen">
      <Sidebar />

      <main className="flex-1 flex flex-col min-w-0">
        <Header
          title="Headquarters Command Center"
          subtitle="Real-time knowledge ingestion, synchronization status, and incident triage."
          action={
            <Link
              href="/manuals/upload"
              className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-xl text-xs font-semibold bg-slate-900 text-white dark:bg-white dark:text-slate-900 shadow-sm hover:opacity-90 transition-opacity"
            >
              <UploadCloud className="w-3.5 h-3.5" />
              <span>Upload Manual</span>
            </Link>
          }
        />

        <div className="p-8 space-y-8 flex-1 max-w-7xl mx-auto w-full">
          {/* Top Metrics Row */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
            <MetricCard
              title="Equipment"
              value={equipment.length}
              subtitle="Industrial machines registered"
              icon={Cpu}
            />
            <MetricCard
              title="Manuals"
              value={manuals.length}
              subtitle="PDF revisions ingested"
              icon={BookOpen}
            />
            <MetricCard
              title="Knowledge Packages"
              value={packages.length}
              subtitle="Verified vector bundles"
              icon={Package}
            />
            <MetricCard
              title="Active Devices"
              value={activeDevicesCount}
              subtitle="Paired Android field phones"
              icon={Smartphone}
            />
            <MetricCard
              title="Open Incidents"
              value={pendingIncidentsCount}
              subtitle="Pending review tickets"
              icon={AlertTriangle}
              badge={
                pendingIncidentsCount > 0
                  ? { text: 'Needs Review', variant: 'warning' }
                  : { text: 'Clear', variant: 'success' }
              }
            />
          </div>

          {/* Conditional Display: Empty State vs. Live Dashboard */}
          {!hasAnyData && !loading ? (
            <EmptyState
              icon={BookOpen}
              title="No Equipment or Manuals Registered Yet"
              description="Get started by registering your first industrial equipment asset and uploading its technical PDF manual for vector processing."
              actionText="Register First Equipment"
              actionHref="/equipment"
            />
          ) : (
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
              {/* Left Column: Recent Incidents / Distribution */}
              <div className="lg:col-span-2 bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl p-6 shadow-apple">
                <div className="flex items-center justify-between mb-4">
                  <div>
                    <h3 className="text-sm font-semibold text-slate-900 dark:text-white">Field Incidents Triage</h3>
                    <p className="text-xs text-slate-500 dark:text-slate-400">
                      Synchronized from offline field engineers over LAN/Hotspot
                    </p>
                  </div>
                  <Link
                    href="/incidents"
                    className="text-xs font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white flex items-center gap-1"
                  >
                    <span>View all</span>
                    <ExternalLink className="w-3 h-3" />
                  </Link>
                </div>

                {incidents.length === 0 ? (
                  <div className="py-12 text-center text-xs text-slate-400">
                    <CheckCircle2 className="w-8 h-8 text-emerald-500 mx-auto mb-2 opacity-80" />
                    <span>No incidents recorded in the system yet.</span>
                  </div>
                ) : (
                  <div className="space-y-3 mt-4">
                    {/* Severity distribution bar if records exist */}
                    {incidentSeverityData.length > 0 && (
                      <div className="h-44 w-full mb-6">
                        <ResponsiveContainer width="100%" height="100%">
                          <BarChart data={incidentSeverityData} layout="vertical" margin={{ left: 10, right: 20 }}>
                            <XAxis type="number" allowDecimals={false} stroke="#94a3b8" fontSize={11} />
                            <YAxis type="category" dataKey="severity" stroke="#94a3b8" fontSize={11} width={80} />
                            <Tooltip />
                            <Bar dataKey="count" radius={[0, 6, 6, 0]}>
                              {incidentSeverityData.map((entry, index) => (
                                <Cell key={`cell-${index}`} fill={entry.color} />
                              ))}
                            </Bar>
                          </BarChart>
                        </ResponsiveContainer>
                      </div>
                    )}

                    {/* Recent Incident Rows */}
                    <div className="divide-y divide-slate-100 dark:divide-slate-800">
                      {incidents.slice(0, 4).map((inc) => (
                        <div key={inc.id} className="py-3 flex items-center justify-between text-xs">
                          <div className="min-w-0 pr-4">
                            <p className="font-semibold text-slate-900 dark:text-white truncate">{inc.title}</p>
                            <p className="text-slate-400 truncate">{inc.description}</p>
                          </div>
                          <div className="flex items-center gap-2 flex-shrink-0">
                            <StatusBadge status={inc.severity} />
                            <StatusBadge status={inc.status} />
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>

              {/* Right Column: Published Packages & Network Status */}
              <div className="bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl p-6 shadow-apple flex flex-col justify-between">
                <div>
                  <h3 className="text-sm font-semibold text-slate-900 dark:text-white mb-1">Knowledge Packages</h3>
                  <p className="text-xs text-slate-500 dark:text-slate-400 mb-4">
                    Ready for phone synchronization over local hotspot
                  </p>

                  {packages.length === 0 ? (
                    <div className="py-10 text-center text-xs text-slate-400">
                      <Clock className="w-6 h-6 text-slate-300 dark:text-slate-600 mx-auto mb-2" />
                      <span>No knowledge packages published yet.</span>
                    </div>
                  ) : (
                    <div className="space-y-3">
                      {packages.slice(0, 4).map((pkg) => (
                        <div
                          key={pkg.id}
                          className="p-3 rounded-2xl bg-slate-50 dark:bg-slate-800/50 border border-slate-100 dark:border-slate-800 text-xs"
                        >
                          <div className="flex items-center justify-between font-semibold text-slate-900 dark:text-white">
                            <span>{pkg.package_file_name}</span>
                            <span className="text-[11px] px-2 py-0.5 rounded-full bg-slate-200 dark:bg-slate-700">
                              {pkg.version}
                            </span>
                          </div>
                          <div className="mt-1 flex items-center justify-between text-slate-400 text-[11px]">
                            <span>{pkg.chunk_count} chunks</span>
                            <span>{(pkg.file_size_bytes / (1024 * 1024)).toFixed(1)} MB</span>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                <div className="mt-6 pt-4 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between text-xs text-slate-500">
                  <span>Hotspot Binding: 0.0.0.0:8000</span>
                  <Link href="/packages" className="font-semibold text-slate-900 dark:text-white hover:underline">
                    Manage packages &rarr;
                  </Link>
                </div>
              </div>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}
