import { authorizedFetch } from "./adminAuth.js";
import { BACKEND } from "./api.js";

export class ApiError extends Error {
  constructor(message, status) {
    super(message);
    this.status = status;
  }
}

// Protected admin APIs use the live JWT and refresh session.
export async function adminRequest(admin, path, { method = "GET", body } = {}) {
  let response;
  try {
    response = await authorizedFetch(`${BACKEND}${path}`, {
      method,
      headers: { ...(body !== undefined && { "Content-Type": "application/json" }) },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    throw new ApiError("Không kết nối được backend.", 0);
  }
  if (response.status === 204) return null;
  const data = await response.json().catch(() => null);
  if (!response.ok) throw new ApiError(errorMessage(data, response.status), response.status);
  return data;
}

// Tải file (multipart) — trình duyệt tự đặt Content-Type kèm boundary
export async function adminUpload(admin, path, formData) {
  let response;
  try {
    response = await authorizedFetch(`${BACKEND}${path}`, { method: "POST", body: formData });
  } catch {
    throw new ApiError("Không kết nối được backend.", 0);
  }
  const data = await response.json().catch(() => null);
  if (!response.ok) throw new ApiError(errorMessage(data, response.status), response.status);
  return data;
}

// Đường dẫn ảnh backend trả về (/static/...) → qua proxy của admin web
export const backendUrl = (path) => (path?.startsWith("/") ? `${BACKEND}${path}` : path);

function errorMessage(data, status) {
  const detail = data?.detail;
  if (typeof detail === "string") return detail;
  if (Array.isArray(detail)) return `Dữ liệu không hợp lệ: ${detail.map((item) => item.loc?.at(-1)).join(", ")}`;
  return `Lỗi máy chủ (HTTP ${status}).`;
}
