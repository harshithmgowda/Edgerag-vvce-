import React from 'react';

type BadgeType =
  | 'QUEUED'
  | 'RUNNING'
  | 'SUCCEEDED'
  | 'FAILED'
  | 'UPLOADED'
  | 'PROCESSING'
  | 'PROCESSED'
  | 'ACTIVE'
  | 'REVOKED'
  | 'LOW'
  | 'MEDIUM'
  | 'HIGH'
  | 'CRITICAL'
  | 'OPEN'
  | 'IN_REVIEW'
  | 'RESOLVED'
  | 'DISMISSED';

interface StatusBadgeProps {
  status: BadgeType | string;
}

export function StatusBadge({ status }: StatusBadgeProps) {
  const normalized = status.toUpperCase();

  const getStyle = (): string => {
    switch (normalized) {
      case 'SUCCEEDED':
      case 'PROCESSED':
      case 'ACTIVE':
      case 'RESOLVED':
        return 'bg-emerald-50 dark:bg-emerald-950/40 text-emerald-700 dark:text-emerald-300 border-emerald-200 dark:border-emerald-800/40';
      case 'RUNNING':
      case 'PROCESSING':
      case 'IN_REVIEW':
        return 'bg-blue-50 dark:bg-blue-950/40 text-blue-700 dark:text-blue-300 border-blue-200 dark:border-blue-800/40';
      case 'QUEUED':
      case 'UPLOADED':
      case 'OPEN':
      case 'MEDIUM':
        return 'bg-amber-50 dark:bg-amber-950/40 text-amber-700 dark:text-amber-300 border-amber-200 dark:border-amber-800/40';
      case 'FAILED':
      case 'REVOKED':
      case 'CRITICAL':
      case 'HIGH':
        return 'bg-rose-50 dark:bg-rose-950/40 text-rose-700 dark:text-rose-300 border-rose-200 dark:border-rose-800/40';
      case 'LOW':
      case 'DISMISSED':
      default:
        return 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 border-slate-200 dark:border-slate-700';
    }
  };

  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-semibold border ${getStyle()}`}>
      {status}
    </span>
  );
}
