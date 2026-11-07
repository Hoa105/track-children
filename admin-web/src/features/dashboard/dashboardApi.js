// Số liệu tổng quan (backend/app/features/admin_dashboard)
import { adminRequest } from "../../core/http.js";

const isoDate = (date) => `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;

// TimeFilter → ?from=&to= (ngày, tính cả hai đầu); "all" không gửi gì
export function rangeQuery(range) {
  const params = new URLSearchParams();
  if (range.preset === "custom") {
    if (range.from) params.set("from", range.from);
    if (range.to) params.set("to", range.to);
  } else if (range.preset !== "all") {
    const from = new Date();
    from.setDate(from.getDate() - Number(range.preset) + 1);
    params.set("from", isoDate(from));
  }
  const query = params.toString();
  return query ? `?${query}` : "";
}

export const getDashboard = (admin, range) => adminRequest(admin, `/admin/dashboard${rangeQuery(range)}`);
