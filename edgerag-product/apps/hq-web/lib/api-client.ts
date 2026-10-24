import { Equipment, Manual, ProcessingJob, KnowledgePackage, Device, Incident, AiProvider, HealthStatus } from './types';

export function getApiBaseUrl(): string {
  if (process.env.NEXT_PUBLIC_API_BASE_URL) {
    return process.env.NEXT_PUBLIC_API_BASE_URL;
  }
  if (typeof window !== 'undefined' && window.location && window.location.hostname) {
    const protocol = window.location.protocol || 'http:';
    const host = window.location.hostname;
    return `${protocol}//${host}:8000/api/v1`;
  }
  return 'http://localhost:8000/api/v1';
}

export class ApiError extends Error {
  constructor(message: string, public readonly status: number) {
    super(message);
    this.name = 'ApiError';
  }
}

class ApiClient {
  private getToken(): string | null {
    if (typeof window === 'undefined') return null;
    return localStorage.getItem('edgerag_token');
  }

  private async request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const token = this.getToken();
    const headers: Record<string, string> = {
      ...(options.headers as Record<string, string>),
    };

    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    if (!(options.body instanceof FormData)) {
      headers['Content-Type'] = 'application/json';
    }

    const res = await fetch(`${getApiBaseUrl()}${endpoint}`, {
      ...options,
      headers,
    });

    if (!res.ok) {
      let errorMessage = `API error: ${res.statusText} (${res.status})`;
      try {
        const errorData = await res.json();
        if (errorData.detail) {
          errorMessage = typeof errorData.detail === 'string' ? errorData.detail : JSON.stringify(errorData.detail);
        }
      } catch {
        // Fallback to status text
      }
      throw new ApiError(errorMessage, res.status);
    }

    // Handle 204 No Content
    if (res.status === 204) {
      return {} as T;
    }

    return res.json();
  }

  // Auth
  async login(username: string, password: string): Promise<{ access_token: string; user: any }> {
    return this.request<{ access_token: string; user: any }>('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ username, password }),
    });
  }

  async getMe(): Promise<any> {
    return this.request('/auth/me');
  }

  // Health
  async getHealth(): Promise<HealthStatus> {
    return this.request<HealthStatus>('/health');
  }

  // Equipment
  async deleteEquipment(id: string): Promise<{ deleted: boolean; cleanup_pending: number }> {
    return this.request(`/equipment/${encodeURIComponent(id)}`, { method: 'DELETE' });
  }

  async deleteManual(id: string): Promise<{ deleted: boolean; cleanup_pending: number }> {
    return this.request(`/manuals/${encodeURIComponent(id)}`, { method: 'DELETE' });
  }

  async listEquipment(): Promise<Equipment[]> {
    return this.request<Equipment[]>('/equipment');
  }

  async createEquipment(data: Omit<Equipment, 'id' | 'created_at'>): Promise<Equipment> {
    return this.request<Equipment>('/equipment', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async getEquipment(id: string): Promise<Equipment> {
    return this.request<Equipment>(`/equipment/${id}`);
  }

  // Manuals
  async listManuals(equipmentId?: string): Promise<Manual[]> {
    const query = equipmentId ? `?equipment_id=${equipmentId}` : '';
    return this.request<Manual[]>(`/manuals${query}`);
  }

  async uploadManual(formData: FormData): Promise<{ manual_id: string; job_id: string; status: string }> {
    return this.request('/manuals', {
      method: 'POST',
      body: formData,
    });
  }

  // Jobs
  async retryJob(id: string): Promise<ProcessingJob> {
    return this.request(`/jobs/${encodeURIComponent(id)}/retry`, { method: 'POST' });
  }
  async extractionReport(id: string): Promise<{manuals: {title: string; warnings: string[]; skipped_pages: number[]}[]}> {
    return this.request(`/jobs/${encodeURIComponent(id)}/extraction`);
  }
  async manualPage(id: string, page: number, excerpt: string): Promise<Blob> {
    const token = this.getToken();
    if (!token) throw new Error('Sign in to view private manual pages');
    const res = await fetch(`${getApiBaseUrl()}/manuals/${encodeURIComponent(id)}/pages/${page}?excerpt=${encodeURIComponent(excerpt.slice(0,180))}`, {
      headers: {Authorization: `Bearer ${token}`}, cache: 'no-store',
    });
    if (!res.ok) throw new ApiError('Unable to load source page', res.status);
    return res.blob();
  }
  async getJob(jobId: string): Promise<ProcessingJob> {
    return this.request<ProcessingJob>(`/jobs/${jobId}`);
  }

  // Packages
  async listPackages(equipmentId?: string): Promise<KnowledgePackage[]> {
    const query = equipmentId ? `?equipment_id=${equipmentId}` : '';
    return this.request<KnowledgePackage[]>(`/packages${query}`);
  }

  getPackageDownloadUrl(packageId: string): string {
    return `${getApiBaseUrl()}/packages/${packageId}/download`;
  }

  // Devices
  async listDevices(): Promise<Device[]> {
    return this.request<Device[]>('/devices');
  }

  async revokeDevice(deviceId: string): Promise<void> {
    return this.request<void>(`/devices/${deviceId}/revoke`, {
      method: 'POST',
    });
  }

  // Incidents
  async listIncidents(status?: string, equipmentId?: string): Promise<Incident[]> {
    const params = new URLSearchParams();
    if (status) params.append('status', status);
    if (equipmentId) params.append('equipment_id', equipmentId);
    const queryString = params.toString() ? `?${params.toString()}` : '';
    return this.request<Incident[]>(`/incidents${queryString}`);
  }

  async reviewIncident(incidentId: string, status: string, reviewNotes: string): Promise<Incident> {
    return this.request<Incident>(`/incidents/${incidentId}/review`, {
      method: 'PATCH',
      body: JSON.stringify({ status, review_notes: reviewNotes }),
    });
  }

  // AI Providers
  async listAiProviders(): Promise<AiProvider[]> {
    return this.request<AiProvider[]>('/ai/providers');
  }

  async updateAiProvider(providerId: string, apiKey: string, modelName: string, isActive: boolean): Promise<AiProvider> {
    return this.request<AiProvider>('/ai/providers', {
      method: 'POST',
      body: JSON.stringify({
        provider_id: providerId,
        api_key: apiKey,
        model_name: modelName,
        is_active: isActive,
      }),
    });
  }

  async testAiProvider(providerId: string): Promise<{ success: boolean; message: string; latency_ms: number }> {
    return this.request(`/ai/providers/${providerId}/test`, {
      method: 'POST',
    });
  }
}

export const api = new ApiClient();
