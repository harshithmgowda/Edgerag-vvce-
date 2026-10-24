'use client';

import React, { useEffect, useState } from 'react';
import { Sidebar } from '@/components/Sidebar';
import { Header } from '@/components/Header';
import { api } from '@/lib/api-client';
import { AiProvider } from '@/lib/types';
import { Sparkles, Key, CheckCircle2, AlertCircle, RefreshCw, Shield, ExternalLink } from 'lucide-react';

export default function AiProvidersPage() {
  const [providers, setProviders] = useState<AiProvider[]>([]);

  const [activeProvider, setActiveProvider] = useState<string>('gemini');
  const [inputKey, setInputKey] = useState<string>('');
  const [selectedModel, setSelectedModel] = useState<string>('gemini-flash-latest');
  const [testResult, setTestResult] = useState<{ success: boolean; message: string; latency_ms: number } | null>(null);
  const [testing, setTesting] = useState(false);
  const [saving, setSaving] = useState(false);
  const [saveSuccess, setSaveSuccess] = useState(false);

  useEffect(() => {
    api
      .listAiProviders()
      .then((data) => {
        if (data && data.length > 0) {
          setProviders(data);
          const gem = data.find((p) => p.provider_id === 'gemini');
          if (gem) {
            setSelectedModel(gem.default_model);
            setInputKey('');
          }
        }
      })
      .catch(() => {
        // Fallback to initial definitions
      });
  }, []);

  const handleTestConnection = async () => {
    setTesting(true);
    setTestResult(null);
    try {
      const res = await api.testAiProvider(activeProvider);
      setTestResult(res);
    } catch (err: any) {
      setTestResult({
        success: false,
        message: err.message || 'Connection test failed',
        latency_ms: 0,
      });
    } finally {
      setTesting(false);
    }
  };

  const handleSaveConfig = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setSaveSuccess(false);

    try {
      await api.updateAiProvider(activeProvider, inputKey, selectedModel, true);
      setSaveSuccess(true);
      setTimeout(() => setSaveSuccess(false), 3000);
    } catch (err: any) {
      alert(err.message || 'Failed to save provider settings');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="flex min-h-screen">
      <Sidebar />

      <main className="flex-1 flex flex-col min-w-0">
        <Header
          title="External AI Providers & Key Vault"
          subtitle="Configure Google Gemini and external LLMs for online LangGraph Agentic RAG and BYOK management."
        />

        <div className="p-8 space-y-8 flex-1 max-w-5xl mx-auto w-full">
          {/* Provider Selection Tabs */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {providers.map((p) => {
              const isSelected = activeProvider === p.provider_id;
              return (
                <button
                  key={p.provider_id}
                  onClick={() => {
                    setActiveProvider(p.provider_id);
                    setSelectedModel(p.default_model);
                    setInputKey('');
                    setTestResult(null);
                  }}
                  className={`p-4 rounded-3xl border text-left transition-all flex flex-col justify-between ${
                    isSelected
                      ? 'bg-slate-900 text-white dark:bg-white dark:text-slate-900 border-transparent shadow-apple'
                      : 'bg-white dark:bg-slate-900 border-slate-200/80 dark:border-slate-800 text-slate-700 dark:text-slate-300 hover:border-slate-300'
                  }`}
                >
                  <div className="flex items-center justify-between mb-2">
                    <Sparkles className="w-4 h-4" />
                    {p.is_configured && (
                      <span className="text-[10px] font-bold uppercase tracking-wider text-emerald-500">
                        Configured
                      </span>
                    )}
                  </div>
                  <div>
                    <h4 className="font-semibold text-sm">{p.display_name}</h4>
                    <p className={`text-[11px] mt-0.5 truncate ${isSelected ? 'opacity-70' : 'text-slate-400'}`}>
                      {p.default_model}
                    </p>
                  </div>
                </button>
              );
            })}
          </div>

          {/* Configuration Form Card */}
          <div className="bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl p-8 shadow-apple">
            <div className="flex items-center justify-between pb-6 border-b border-slate-100 dark:border-slate-800">
              <div>
                <h3 className="text-base font-semibold text-slate-900 dark:text-white">
                  {providers.find((p) => p.provider_id === activeProvider)?.display_name} Configuration
                </h3>
                <p className="text-xs text-slate-400 mt-0.5">
                  Securely stored on headquarters server. Never sent to field devices without authorization.
                </p>
              </div>

              {activeProvider === 'gemini' && (
                <a
                  href="https://aistudio.google.com/app/apikey"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1.5 text-xs text-blue-600 dark:text-blue-400 hover:underline"
                >
                  <span>Get Gemini API Key</span>
                  <ExternalLink className="w-3.5 h-3.5" />
                </a>
              )}
            </div>

            {saveSuccess && (
              <div className="mt-4 p-3 rounded-2xl bg-emerald-50 text-emerald-700 dark:bg-emerald-950/40 dark:text-emerald-300 text-xs flex items-center gap-2">
                <CheckCircle2 className="w-4 h-4" />
                <span>Provider settings saved successfully!</span>
              </div>
            )}

            <form onSubmit={handleSaveConfig} className="mt-6 space-y-6">
              <div>
                <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5">
                  API Key Secret *
                </label>
                <div className="relative">
                  <Key className="w-4 h-4 text-slate-400 absolute left-3.5 top-3" />
                  <input
                    type="password"
                    placeholder="Enter API key (e.g. AIzaSy...)"
                    value={inputKey}
                    onChange={(e) => setInputKey(e.target.value)}
                    className="w-full pl-10 pr-4 py-2.5 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-800/50 text-xs text-slate-900 dark:text-white font-mono focus:outline-none focus:ring-2 focus:ring-slate-900"
                  />
                </div>
                <p className="text-[11px] text-slate-400 mt-1">
                  Keys are stored in server-side encrypted vault. Masked in UI.
                </p>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5">
                  Target AI Model
                </label>
                {activeProvider === 'nvidia' ? (
                  <select
                    value={selectedModel}
                    onChange={(e) => setSelectedModel(e.target.value)}
                    className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-800/50 text-xs text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-slate-900"
                  >
                    <option value="nvidia/nemotron-3-ultra-550b-a55b">nvidia/nemotron-3-ultra-550b-a55b (550B Ultra Reasoning - Recommended)</option>
                    <option value="meta/llama-3.2-11b-vision-instruct">meta/llama-3.2-11b-vision-instruct (Multimodal Vision)</option>
                    <option value="deepseek-ai/deepseek-v4.1-flash">deepseek-ai/deepseek-v4.1-flash (High Throughput Reasoning)</option>
                    <option value="google/gemma-3-12b-it">google/gemma-3-12b-it (Google Gemma on NVIDIA NIM)</option>
                  </select>
                ) : activeProvider === 'gemini' ? (
                  <select
                    value={selectedModel}
                    onChange={(e) => setSelectedModel(e.target.value)}
                    className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-800/50 text-xs text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-slate-900"
                  >
                    <option value="gemini-flash-latest">gemini-flash-latest (Current Active High Speed Model)</option>
                    <option value="gemini-3.8-flash">gemini-3.8-flash (Latest Low Latency RAG)</option>
                    <option value="gemini-2.5-flash">gemini-2.5-flash</option>
                  </select>
                ) : (
                  <input
                    type="text"
                    value={selectedModel}
                    onChange={(e) => setSelectedModel(e.target.value)}
                    className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-800/50 text-xs text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-slate-900"
                  />
                )}
              </div>

              {/* Test Connection Output */}
              {testResult && (
                <div
                  className={`p-4 rounded-2xl text-xs border flex items-center justify-between ${
                    testResult.success
                      ? 'bg-emerald-50 dark:bg-emerald-950/40 border-emerald-200 text-emerald-800 dark:text-emerald-300'
                      : 'bg-rose-50 dark:bg-rose-950/40 border-rose-200 text-rose-800 dark:text-rose-300'
                  }`}
                >
                  <div className="flex items-center gap-2.5">
                    {testResult.success ? (
                      <CheckCircle2 className="w-4 h-4 text-emerald-500" />
                    ) : (
                      <AlertCircle className="w-4 h-4 text-rose-500" />
                    )}
                    <span>{testResult.message}</span>
                  </div>
                  {testResult.latency_ms > 0 && (
                    <span className="font-mono text-[11px] opacity-80">{testResult.latency_ms}ms</span>
                  )}
                </div>
              )}

              {/* Action Buttons */}
              <div className="pt-4 flex items-center justify-between">
                <button
                  type="button"
                  onClick={handleTestConnection}
                  disabled={testing}
                  className="inline-flex items-center gap-2 px-4 py-2 rounded-xl border border-slate-200 dark:border-slate-800 text-xs font-semibold text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors disabled:opacity-50"
                >
                  <RefreshCw className={`w-3.5 h-3.5 ${testing ? 'animate-spin' : ''}`} />
                  <span>{testing ? 'Testing Live Request...' : 'Test Connection'}</span>
                </button>

                <button
                  type="submit"
                  disabled={saving}
                  className="px-6 py-2 rounded-xl bg-slate-900 text-white dark:bg-white dark:text-slate-900 text-xs font-semibold shadow-sm hover:opacity-90 disabled:opacity-50 transition-all"
                >
                  {saving ? 'Saving...' : 'Save Configuration'}
                </button>
              </div>
            </form>
          </div>
        </div>
      </main>
    </div>
  );
}
