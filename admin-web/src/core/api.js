// Backend và AI service đi qua proxy của Vite (vite.config.js).
// Mọi API quản trị của AI service sẽ được gọi QUA backend (admin xác thực ở backend);
// riêng /health gọi thẳng để hiển thị trạng thái hệ thống.
export const BACKEND = "/api/backend";
export const AI_SERVICE = "/api/ai";

export async function checkHealth(baseUrl) {
  const started = performance.now();
  try {
    const response = await fetch(`${baseUrl}/health`, { signal: AbortSignal.timeout(4000) });
    const latency = Math.round(performance.now() - started);
    return response.ok ? { ok: true, latency } : { ok: false, error: `HTTP ${response.status}` };
  } catch {
    return { ok: false, error: "Không kết nối được" };
  }
}
