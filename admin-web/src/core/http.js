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

function errorMessage(data, status) {
  const detail = data?.detail;
  if (typeof detail === "string") return detail;
  if (Array.isArray(detail)) return `Dữ liệu không hợp lệ: ${detail.map((item) => item.loc?.at(-1)).join(", ")}`;
  return `Lỗi máy chủ (HTTP ${status}).`;
}
