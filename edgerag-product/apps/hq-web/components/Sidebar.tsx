'use client';

import React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  LayoutDashboard,
  Cpu,
  BookOpen,
  UploadCloud,
  Layers,
  Package,
  Smartphone,
  AlertTriangle,
  Sparkles,
  Settings,
  ShieldCheck,
  LogOut,
} from 'lucide-react';

const navigation = [
  { name: 'Ask Edge AI', href: '/chat', icon: Sparkles },
  { name: 'Dashboard', href: '/', icon: LayoutDashboard },
  { name: 'Equipment', href: '/equipment', icon: Cpu },
  { name: 'Manuals', href: '/manuals', icon: BookOpen },
  { name: 'Upload Manual', href: '/manuals/upload', icon: UploadCloud },
  { name: 'Processing Jobs', href: '/jobs', icon: Layers },
  { name: 'Knowledge Packages', href: '/packages', icon: Package },
  { name: 'Field Devices', href: '/devices', icon: Smartphone },
  { name: 'Incidents', href: '/incidents', icon: AlertTriangle },
  { name: 'AI Providers', href: '/settings/ai', icon: Sparkles },
  { name: 'Settings', href: '/settings', icon: Settings },
];

export function Sidebar() {
  const pathname = usePathname();

  const handleLogout = () => {
    if (typeof window !== 'undefined') {
      localStorage.removeItem('edgerag_token');
      localStorage.removeItem('edgerag_user');
      window.location.href = '/login';
    }
  };

  return (
    <aside className="app-sidebar w-64 bg-white dark:bg-slate-900 border-r border-slate-200 dark:border-slate-800 flex flex-col h-screen sticky top-0 z-30 transition-colors">
      {/* Brand Header */}
      <div className="h-16 flex items-center px-6 gap-3 border-b border-slate-100 dark:border-slate-800">
        <div className="w-9 h-9 rounded-xl bg-blue-600 dark:bg-blue-300 text-white dark:text-blue-950 flex items-center justify-center font-bold text-lg shadow-sm">
          <Layers className="w-5 h-5" />
        </div>
        <div className="sidebar-wordmark">
          <span className="font-semibold text-slate-900 dark:text-white tracking-tight">EdgeRAG</span>
          <span className="text-[10px] uppercase font-bold text-slate-400 dark:text-slate-500 tracking-wider ml-2 px-1.5 py-0.5 bg-slate-100 dark:bg-slate-800 rounded">
            HQ
          </span>
        </div>
      </div>

      {/* Navigation Links */}
      <nav className="flex-1 px-3 py-4 space-y-1 overflow-y-auto">
        <div className="text-[11px] font-semibold text-slate-400 dark:text-slate-500 px-3 pb-2 uppercase tracking-wider">
          Management
        </div>
        {navigation.map((item) => {
          const isActive = pathname === item.href || (item.href !== '/' && (pathname.startsWith(item.href) && !navigation.some(other => other.href !== item.href && other.href.startsWith(item.href) && pathname.startsWith(other.href))));
          const Icon = item.icon;

          return (
            <Link
              key={item.name}
              href={item.href}
              aria-current={isActive ? "page" : undefined}
              title={item.name}
              className={`flex items-center gap-3 px-3.5 py-2.5 rounded-xl text-sm font-medium transition-all ${
                isActive
                  ? 'bg-blue-100 text-blue-800 dark:bg-blue-950 dark:text-blue-200'
                  : 'text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800/60 hover:text-slate-900 dark:hover:text-white'
              }`}
            >
              <Icon className={`w-4 h-4 ${isActive ? 'text-inherit' : 'text-slate-400 dark:text-slate-500'}`} />
              <span className="nav-label">{item.name}</span>
            </Link>
          );
        })}
      </nav>

      {/* Air-Gap / Safety Indicator */}
      <div className="sidebar-footer p-3 mx-3 mb-2 rounded-xl bg-emerald-50 dark:bg-emerald-950/30 border border-emerald-200 dark:border-emerald-800/40 text-emerald-800 dark:text-emerald-300 flex items-center gap-2.5 text-xs">
        <ShieldCheck className="w-4 h-4 text-emerald-600 dark:text-emerald-400 flex-shrink-0" />
        <div>
          <p className="font-semibold">Knowledge workspace</p>
          <p className="text-[11px] opacity-80">Documents • Answers • Devices</p>
        </div>
      </div>

      {/* User Footer */}
      <div className="sidebar-footer p-3 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between">
        <div className="flex items-center gap-2.5 min-w-0">
          <div className="w-8 h-8 rounded-full bg-slate-200 dark:bg-slate-700 flex items-center justify-center text-xs font-semibold text-slate-700 dark:text-slate-300">
            AD
          </div>
          <div className="min-w-0">
            <p className="text-xs font-semibold text-slate-900 dark:text-white truncate">Administrator</p>
            <p className="text-[10px] text-slate-400 dark:text-slate-500 truncate">admin@edgerag.internal</p>
          </div>
        </div>
        <button
          onClick={handleLogout}
          title="Sign Out"
          className="p-1.5 text-slate-400 hover:text-red-600 dark:hover:text-red-400 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        >
          <LogOut className="w-4 h-4" />
        </button>
      </div>
    </aside>
  );
}

