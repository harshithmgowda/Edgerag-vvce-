'use client';

import React, { useEffect, useState } from 'react';
import { Sidebar } from '@/components/Sidebar';
import { Header } from '@/components/Header';
import { api } from '@/lib/api-client';
import { HealthStatus } from '@/lib/types';
import { Settings, Wifi, Database, Server, HardDrive, ShieldCheck, CheckCircle2 } from 'lucide-react';

export default function SettingsPage() {
  const [health, setHealth] = useState<HealthStatus | null>(null);

  useEffect(() => {
    api
      .getHealth()
      .then(setHealth)
      .catch(() => setHealth(null));
  }, []);

  return (
    <div className="flex min-h-screen">
      <Sidebar />

      <main className="flex-1 flex flex-col min-w-0">
        <Header
          title="System Settings & Infrastructure"
          subtitle="Local network interfaces, database connectors, and offline hotspot configuration."
        />

        <div className="p-8 space-y-8 flex-1 max-w-5xl mx-auto w-full">
          {/* Network & Hotspot Card */}
          <div className="bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl p-6 shadow-apple">
            <div className="flex items-center gap-3 mb-4">
              <div className="w-9 h-9 rounded-xl bg-slate-100 dark:bg-slate-800 flex items-center justify-center text-slate-800 dark:text-slate-200">
                <Wifi className="w-5 h-5" />
              </div>
              <div>
                <h3 className="font-semibold text-sm text-slate-900 dark:text-white">Hotspot LAN Connectivity</h3>
                <p className="text-xs text-slate-400">Settings for Android field synchronization over local Wi-Fi</p>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mt-4 text-xs">
              <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/50 border border-slate-100 dark:border-slate-800">
                <span className="text-slate-400">Default Hotspot Gateway</span>
                <p className="text-sm font-mono font-semibold text-slate-900 dark:text-white mt-1">192.168.137.1</p>
                <p className="text-[11px] text-slate-400 mt-1">Windows Mobile Hotspot standard IP</p>
              </div>

              <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/50 border border-slate-100 dark:border-slate-800">
                <span className="text-slate-400">FastAPI Listener Port</span>
                <p className="text-sm font-mono font-semibold text-slate-900 dark:text-white mt-1">8000</p>
                <p className="text-[11px] text-slate-400 mt-1">Bound to 0.0.0.0 (all interfaces)</p>
              </div>

              <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/50 border border-slate-100 dark:border-slate-800">
                <span className="text-slate-400">Public Internet Requirement</span>
                <p className="text-sm font-semibold text-emerald-600 dark:text-emerald-400 mt-1">None (Air-Gapped)</p>
                <p className="text-[11px] text-slate-400 mt-1">Local LAN synchronization ready</p>
              </div>
            </div>
          </div>

          {/* Infrastructure Health Status Card */}
          <div className="bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl p-6 shadow-apple">
            <div className="flex items-center gap-3 mb-4">
              <div className="w-9 h-9 rounded-xl bg-slate-100 dark:bg-slate-800 flex items-center justify-center text-slate-800 dark:text-slate-200">
                <Server className="w-5 h-5" />
              </div>
              <div>
                <h3 className="font-semibold text-sm text-slate-900 dark:text-white">Service Health Diagnostics</h3>
                <p className="text-xs text-slate-400">Native Windows / WSL2 services (No Docker)</p>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mt-4 text-xs">
              <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/50 border border-slate-100 dark:border-slate-800 flex items-center justify-between">
                <div>
                  <span className="text-slate-400">MySQL Database</span>
                  <p className="font-semibold text-slate-900 dark:text-white mt-0.5">
                    {health?.database || 'Checking...'}
                  </p>
                </div>
                <Database className="w-5 h-5 text-slate-400" />
              </div>

              <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/50 border border-slate-100 dark:border-slate-800 flex items-center justify-between">
                <div>
                  <span className="text-slate-400">Redis Broker</span>
                  <p className="font-semibold text-slate-900 dark:text-white mt-0.5">
                    {health?.redis || 'Checking...'}
                  </p>
                </div>
                <Server className="w-5 h-5 text-slate-400" />
              </div>

              <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/50 border border-slate-100 dark:border-slate-800 flex items-center justify-between">
                <div>
                  <span className="text-slate-400">MinIO / S3 Storage</span>
                  <p className="font-semibold text-slate-900 dark:text-white mt-0.5">
                    {health?.storage || 'Checking...'}
                  </p>
                </div>
                <HardDrive className="w-5 h-5 text-slate-400" />
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
