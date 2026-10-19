// API quản trị danh mục vắc xin, sản phẩm & lịch tiêm (backend/app/features/vaccination/router.py)
import { adminRequest } from "../../core/http.js";

export const listVaccines = (admin) => adminRequest(admin, "/admin/vaccines");
export const createVaccine = (admin, body) => adminRequest(admin, "/admin/vaccines", { method: "POST", body });
export const updateVaccine = (admin, id, body) => adminRequest(admin, `/admin/vaccines/${id}`, { method: "PATCH", body });

export const listSchedules = (admin) => adminRequest(admin, "/admin/vaccine-schedules");
export const createSchedule = (admin, body) => adminRequest(admin, "/admin/vaccine-schedules", { method: "POST", body });
export const updateSchedule = (admin, id, body) => adminRequest(admin, `/admin/vaccine-schedules/${id}`, { method: "PATCH", body });
export const deleteSchedule = (admin, id) => adminRequest(admin, `/admin/vaccine-schedules/${id}`, { method: "DELETE" });

export const listProducts = (admin) => adminRequest(admin, "/admin/vaccine-products");
export const createProduct = (admin, body) => adminRequest(admin, "/admin/vaccine-products", { method: "POST", body });
export const updateProduct = (admin, id, body) => adminRequest(admin, `/admin/vaccine-products/${id}`, { method: "PATCH", body });

// Mũi phụ huynh tự thêm ngoài lịch, gộp theo tên — ẩn danh, chỉ tên có đủ số bé tối thiểu
export const getCustomDoseReport = (admin) => adminRequest(admin, "/admin/vaccinations/custom-summary");
