'use client';

import React, { useEffect, useState } from 'react';
import { Sidebar } from '@/components/Sidebar';
import { Header } from '@/components/Header';
import { EmptyState } from '@/components/EmptyState';
import { api } from '@/lib/api-client';
import { KnowledgePackage, Equipment } from '@/lib/types';
import { Package, Download, ShieldCheck, Hash, Layers, HardDrive } from 'lucide-react';

export default function KnowledgePackagesPage() {
  const [packages, setPackages] = useState<KnowledgePackage[]>([]);
  const [equipmentList, setEquipmentList] = useState<Equipment[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadData() {
      try {
        setLoading(true);
        const [pkgData, eqData] = await Promise.all([
          api.listPackages(),
          api.listEquipment(),
        ]);
        setPackages(pkgData);
        setEquipmentList(eqData);
      } catch {
        // Fallback
      } finally {
        setLoading(false);
      }
    }

    loadData();
  }, []);

  const getEquipmentName = (id: string) => {
    const eq = equipmentList.find((e) => e.id === id);
    return eq ? eq.name : 'Unknown Equipment';
  };

  return (
    <div className="flex min-h-screen">
      <Sidebar />

      <main className="flex-1 flex flex-col min-w-0">
        <Header
          title="Published Knowledge Packages"
          subtitle="Cryptographically verified SQLite vector bundles distributed to Android devices over Hotspot LAN."
        />

        <div className="p-8 space-y-6 flex-1 max-w-7xl mx-auto w-full">
          {packages.length === 0 && !loading ? (
            <EmptyState
              icon={Package}
              title="No Knowledge Packages Published"
              description="Packages are automatically compiled when manual processing completes. They bundle chunk texts, 384-d vectors, and manifest metadata into atomic ZIP archives."
              actionText="Upload a Manual"
              actionHref="/manuals/upload"
            />
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
              {packages.map((pkg) => (
                <div
                  key={pkg.id}
                  className="bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl p-6 shadow-apple hover:shadow-apple-hover transition-all duration-200 flex flex-col justify-between"
                >
                  <div>
                    <div className="flex items-start justify-between mb-3">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-2xl bg-slate-100 dark:bg-slate-800 flex items-center justify-center text-slate-800 dark:text-slate-200">
                          <Package className="w-5 h-5" />
                        </div>
                        <div>
                          <h3 className="font-semibold text-slate-900 dark:text-white text-sm">
                            {pkg.package_file_name}
                          </h3>
                          <p className="text-xs text-slate-400">
                            For: <strong className="text-slate-700 dark:text-slate-300">{getEquipmentName(pkg.equipment_id)}</strong>
                          </p>
                        </div>
                      </div>

                      <span className="px-2.5 py-1 rounded-full text-xs font-bold bg-slate-900 text-white dark:bg-white dark:text-slate-900">
                        {pkg.version}
                      </span>
                    </div>

                    <div className="mt-4 p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/50 border border-slate-100 dark:border-slate-800 space-y-2 text-xs">
                      <div className="flex items-center justify-between text-slate-500">
                        <span className="flex items-center gap-1.5">
                          <Layers className="w-3.5 h-3.5" /> Total Chunks:
                        </span>
                        <strong className="text-slate-900 dark:text-white font-semibold">{pkg.chunk_count}</strong>
                      </div>
                      <div className="flex items-center justify-between text-slate-500">
                        <span className="flex items-center gap-1.5">
                          <HardDrive className="w-3.5 h-3.5" /> Bundle Size:
                        </span>
                        <strong className="text-slate-900 dark:text-white font-semibold">
                          {(pkg.file_size_bytes / (1024 * 1024)).toFixed(2)} MB
                        </strong>
                      </div>
                      <div className="flex items-center justify-between text-slate-500">
                        <span className="flex items-center gap-1.5">
                          <ShieldCheck className="w-3.5 h-3.5 text-emerald-500" /> Vector Spec:
                        </span>
                        <strong className="text-slate-900 dark:text-white font-semibold">
                          {pkg.encoder_model} ({pkg.vector_dimension}-d)
                        </strong>
                      </div>
                    </div>

                    {/* SHA-256 Hash Display */}
                    <div className="mt-3 text-[11px] font-mono text-slate-400 break-all bg-slate-100 dark:bg-slate-800/80 p-2.5 rounded-xl flex items-start gap-2">
                      <Hash className="w-3.5 h-3.5 text-slate-400 flex-shrink-0 mt-0.5" />
                      <span>{pkg.sha256_hash}</span>
                    </div>
                  </div>

                  <div className="mt-6 pt-4 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between">
                    <span className="text-[11px] text-slate-400">
                      Published: {new Date(pkg.created_at).toLocaleDateString()}
                    </span>
                    <a
                      href={api.getPackageDownloadUrl(pkg.id)}
                      download
                      className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold bg-slate-100 dark:bg-slate-800 text-slate-900 dark:text-white hover:bg-slate-200 dark:hover:bg-slate-700 transition-colors"
                    >
                      <Download className="w-3.5 h-3.5" />
                      <span>Download ZIP</span>
                    </a>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </main>
    </div>
  );
}
