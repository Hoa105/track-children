// API quản trị kho hoạt động (backend/app/features/activities/router.py, quyền activity.write)
import { adminRequest, adminUpload } from "../../core/http.js";

export const listGroups = (admin) => adminRequest(admin, "/admin/activity-groups");
export const createGroup = (admin, body) => adminRequest(admin, "/admin/activity-groups", { method: "POST", body });
export const updateGroup = (admin, id, body) => adminRequest(admin, `/admin/activity-groups/${id}`, { method: "PATCH", body });

export const listActivities = (admin) => adminRequest(admin, "/admin/activities");
export const getActivity = (admin, id) => adminRequest(admin, `/admin/activities/${id}`);
export const createActivity = (admin, body) => adminRequest(admin, "/admin/activities", { method: "POST", body });
export const updateActivity = (admin, id, body) => adminRequest(admin, `/admin/activities/${id}`, { method: "PATCH", body });
// Ghi đè toàn bộ các bước theo thứ tự (backend sửa tại chỗ để giữ bước đã đánh dấu trong nhật ký)
export const saveSteps = (admin, id, steps) => adminRequest(admin, `/admin/activities/${id}/steps`, { method: "PUT", body: { steps } });

export function uploadImage(admin, id, file, caption) {
  const form = new FormData();
  form.append("file", file);
  if (caption) form.append("caption", caption);
  return adminUpload(admin, `/admin/activities/${id}/media`, form);
}
export const updateMedia = (admin, mediaId, body) => adminRequest(admin, `/admin/activity-media/${mediaId}`, { method: "PATCH", body });
export const deleteMedia = (admin, mediaId) => adminRequest(admin, `/admin/activity-media/${mediaId}`, { method: "DELETE" });

export const STATUS = {
  draft: { label: "Nháp", tone: "orange" },
  published: { label: "Đã xuất bản", tone: "green" },
  hidden: { label: "Đã ẩn", tone: "gray" },
};
