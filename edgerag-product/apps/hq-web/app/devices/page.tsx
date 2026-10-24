'use client';

import React, { useEffect, useState } from 'react';
import { Sidebar } from '@/components/Sidebar';
import { Header } from '@/components/Header';
import { EmptyState } from '@/components/EmptyState';
import { StatusBadge } from '@/components/StatusBadge';
import { api } from '@/lib/api-client';
import { Device } from '@/lib/types';
import { Smartphone, ShieldAlert, Wifi, Clock, CheckCircle2 } from 'lucide-react';

export default function DevicesPage() {
  const [devices, setDevices] = useState<Device[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchDevices = async () => {
    try {
      setLoading(true);
      const data = await api.listDevices();
      setDevices(data);
    } catch {
      // Empty state
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchDevices();
  }, []);

  const handleRevoke = async (deviceId: string) => {
    if (!confirm('Are you sure you want to revoke this field device? It will be blocked from syncing knowledge.')) {
      return;
    }
    try {
      await api.revokeDevice(deviceId);
      await fetchDevices();
    } catch (err: any) {
      alert(err.message || 'Failed to revoke device');
    }
  };

  return (
    <div className="flex min-h-screen">
      <Sidebar />

      <main className="flex-1 flex flex-col min-w-0">
        <Header
          title="Field Devices & Security Pairing"
          subtitle="Authorize and monitor Android devices operating in air-gapped industrial facilities."
        />

        <div className="p-8 space-y-6 flex-1 max-w-7xl mx-auto w-full">
          {devices.length === 0 && !loading ? (
            <EmptyState
              icon={Smartphone}
              title="No Registered Field Devices"
              description="Field engineers register their Android devices over the headquarters Wi-Fi / Hotspot LAN. Paired devices and their sync status will be monitored here."
            />
          ) : (
            <div className="bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl overflow-hidden shadow-apple">
              <div className="overflow-x-auto">
                <table className="w-full text-left text-xs">
                  <thead className="bg-slate-50/75 dark:bg-slate-800/50 border-b border-slate-100 dark:border-slate-800 text-slate-400 font-semibold uppercase tracking-wider">
                    <tr>
                      <th className="py-3.5 px-6">Device Name & Model</th>
                      <th className="py-3.5 px-6">Identifier</th>
                      <th className="py-3.5 px-6">OS Version</th>
                      <th className="py-3.5 px-6">Status</th>
                      <th className="py-3.5 px-6">Last Heartbeat</th>
                      <th className="py-3.5 px-6">Last Knowledge Sync</th>
                      <th className="py-3.5 px-6 text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100 dark:divide-slate-800/60">
                    {devices.map((dev) => (
                      <tr key={dev.id} className="hover:bg-slate-50/50 dark:hover:bg-slate-800/30 transition-colors">
                        <td className="py-4 px-6">
                          <div className="flex items-center gap-3">
                            <div className="w-8 h-8 rounded-xl bg-slate-100 dark:bg-slate-800 flex items-center justify-center text-slate-600 dark:text-slate-300">
                              <Smartphone className="w-4 h-4" />
                            </div>
                            <div>
                              <p className="font-semibold text-slate-900 dark:text-white">{dev.device_name}</p>
                              <p className="text-[11px] text-slate-400">{dev.model}</p>
                            </div>
                          </div>
                        </td>
                        <td className="py-4 px-6 font-mono text-[11px] text-slate-500">
                          {dev.device_identifier.slice(0, 12)}...
                        </td>
                        <td className="py-4 px-6 text-slate-600 dark:text-slate-400">
                          {dev.os_version}
                        </td>
                        <td className="py-4 px-6">
                          <StatusBadge status={dev.status} />
                        </td>
                        <td className="py-4 px-6 text-slate-500">
                          {new Date(dev.last_heartbeat).toLocaleTimeString()}
                        </td>
                        <td className="py-4 px-6 text-slate-500">
                          {dev.last_sync ? new Date(dev.last_sync).toLocaleDateString() : 'Never'}
                        </td>
                        <td className="py-4 px-6 text-right">
                          {dev.status === 'ACTIVE' && (
                            <button
                              onClick={() => handleRevoke(dev.id)}
                              className="px-2.5 py-1 rounded-lg text-[11px] font-semibold text-rose-600 dark:text-rose-400 hover:bg-rose-50 dark:hover:bg-rose-950/40 transition-colors"
                            >
                              Revoke
                            </button>
                          )}
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
