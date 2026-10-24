'use client';

import React, { useEffect, useState } from 'react';
import { api } from '@/lib/api-client';
import { Activity, Moon, Sun, Wifi, WifiOff } from 'lucide-react';

interface HeaderProps {
  title: string;
  subtitle?: string;
  action?: React.ReactNode;
}

export function Header({ title, subtitle, action }: HeaderProps) {
  const [isOnline, setIsOnline] = useState<boolean | null>(null);
  const [isDark, setIsDark] = useState<boolean>(false);

  useEffect(() => {
    // Initial health probe
    api
      .getHealth()
      .then(() => setIsOnline(true))
      .catch(() => setIsOnline(false));

    const interval = setInterval(() => {
      api
        .getHealth()
        .then(() => setIsOnline(true))
        .catch(() => setIsOnline(false));
    }, 15000);

    return () => clearInterval(interval);
  }, []);

  const toggleDarkMode = () => {
    if (typeof document !== 'undefined') {
      const isDarkMode = document.documentElement.classList.toggle('dark');
      setIsDark(isDarkMode);
    }
  };

  return (
    <header className="app-header h-16 border-b border-slate-200 dark:border-slate-800 bg-white/80 dark:bg-slate-900/80 backdrop-blur-md sticky top-0 z-20 px-8 flex items-center justify-between transition-colors">
      <div>
        <h1 className="text-lg font-semibold text-slate-900 dark:text-white tracking-tight">{title}</h1>
        {subtitle && <p className="text-xs text-slate-500 dark:text-slate-400">{subtitle}</p>}
      </div>

      <div className="flex items-center gap-4">
        {/* Backend Connectivity Status Pill */}
        <div
          className={`flex items-center gap-2 px-3 py-1 rounded-full text-xs font-medium border transition-colors ${
            isOnline === true
              ? 'bg-emerald-50 dark:bg-emerald-950/40 text-emerald-700 dark:text-emerald-300 border-emerald-200 dark:border-emerald-800/40'
              : isOnline === false
              ? 'bg-rose-50 dark:bg-rose-950/40 text-rose-700 dark:text-rose-300 border-rose-200 dark:border-rose-800/40'
              : 'bg-slate-50 dark:bg-slate-800 text-slate-500 border-slate-200 dark:border-slate-700'
          }`}
        >
          {isOnline === true ? (
            <>
              <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
              <span>Backend Connected</span>
            </>
          ) : isOnline === false ? (
            <>
              <span className="w-2 h-2 rounded-full bg-rose-500" />
              <span>Backend Offline</span>
            </>
          ) : (
            <>
              <Activity className="w-3.5 h-3.5 animate-spin" />
              <span>Connecting...</span>
            </>
          )}
        </div>

        {/* Dark Mode Toggle */}
        <button
          onClick={toggleDarkMode}
          title="Toggle Theme"
          className="p-2 rounded-xl text-slate-500 hover:text-slate-900 dark:text-slate-400 dark:hover:text-white hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        >
          {isDark ? <Sun className="w-4 h-4" /> : <Moon className="w-4 h-4" />}
        </button>

        {/* Custom Page Action (e.g., Add Equipment, Upload PDF) */}
        {action && <div>{action}</div>}
      </div>
    </header>
  );
}

