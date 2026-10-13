import React, { useMemo, useState } from "react";
import { useAuth } from "../../core/auth.jsx";
import { can } from "../../core/session.js";
import { navigate } from "../../core/useHashRoute.js";
import { ALL_TIME, Badge, DataTable, MockNotice, PageHeading, Panel, Tabs, TimeFilter, inTimeRange, stopRowClick } from "../../shared/ui.jsx";

// account.users
export const users = [
  { id: "u1", name: "Nguyễn Minh Anh", username: "minhanh", email: "minhanh.nguyen@gmail.com", phone: "+84912345678", children: 2, shared: 1, joined: "12/06/2026", status: "active", initials: "MA", color: "mint" },
  { id: "u2", name: "Trần Hoàng Nam", username: "nam.bo", email: "nam.tran@email.com", phone: null, children: 1, shared: 0, joined: "11/06/2026", status: "active", initials: "TN", color: "blue" },
  { id: "u3", name: "Lê Thu Hà", username: "thuha_mom", email: "thuha.le@gmail.com", phone: "+84987654321", children: 3, shared: 2, joined: "10/06/2026", status: "pending", initials: "TH", color: "peach" },
  { id: "u4", name: "Phạm Quốc Bảo", username: "quocbao", email: "bao.pham@gmail.com", phone: null, children: 1, shared: 0, joined: "08/06/2026", status: "locked", initials: "PB", color: "violet" },
  { id: "u5", name: "Đỗ Ngọc Linh", username: "ngoclinh", email: "linh.do@email.com", phone: "+84903111222", children: 0, shared: 1, joined: "07/06/2026", status: "pending_deletion", initials: "NL", color: "yellow" },
];

// account.data_deletion_requests — thực thi bằng account.anonymize_user()
// (docs/database/README.md § Chiến lược xóa tài khoản)
export const deletionRequests = [
  { id: "d1", userId: "u5", user: "Đỗ Ngọc Linh", email: "linh.do@email.com", reason: "Không còn sử dụng", requested: "10/09/2026", scheduled: "10/10/2026", ownedChildren: 0, status: "pending" },
  { id: "d2", user: "Vũ Thị Hằng", email: "hang.vu@gmail.com", reason: "Lo ngại về dữ liệu", requested: "05/09/2026", scheduled: "05/10/2026", ownedChildren: 1, status: "pending" },
  { id: "d3", user: "Ngô Văn Tú", email: "tu.ngo@gmail.com", reason: "Chuyển sang ứng dụng khác", requested: "01/08/2026", scheduled: "31/08/2026", ownedChildren: 0, status: "completed" },
];

const statusInfo = {
  active: ["green", "Đang hoạt động"],
  pending: ["orange", "Chờ xác minh"],
  locked: ["red", "Đã khóa"],
  pending_deletion: ["purple", "Chờ xóa"],
  deleted: ["gray", "Đã xóa"],
};

export function UserStatus({ status }) {
  const [tone, label] = statusInfo[status];
  return <Badge tone={tone}>{label}</Badge>;
}

// Mở thẳng tab qua link, ví dụ #/users?tab=deletion (từ Dashboard)
function initialTab() {
  return new URLSearchParams(window.location.hash.split("?")[1] ?? "").get("tab") === "deletion" ? "deletion" : "users";
}

export default function UsersPage({ query, onNotify }) {
  const { admin } = useAuth();
  const canLock = can(admin, "user.lock");
  const [tab, setTab] = useState(initialTab);
  const [status, setStatus] = useState("all");
  const [range, setRange] = useState(ALL_TIME);
  const filtered = useMemo(() => users.filter((user) =>
    (status === "all" || user.status === status) &&
    inTimeRange(user.joined, range) &&
    `${user.name} ${user.username} ${user.email} ${user.phone ?? ""}`.toLowerCase().includes(query.toLowerCase())), [query, status, range]);
  const requests = deletionRequests.filter((request) => inTimeRange(request.requested, range));
  const openRequests = deletionRequests.filter((request) => request.status === "pending");

  return <div>
    <PageHeading eyebrow="NGƯỜI DÙNG" title="Người dùng" subtitle="Tài khoản phụ huynh / người chăm sóc. Admin không xem được dữ liệu sức khỏe của trẻ ở đây." />
    <MockNotice />
    <Tabs active={tab} onChange={setTab} tabs={[{ id: "users", label: "Tài khoản" }, { id: "deletion", label: "Yêu cầu xóa tài khoản", count: openRequests.length }]} />
    <div className="filter-bar">
      <TimeFilter value={range} onChange={setRange} label={tab === "users" ? "Ngày tham gia" : "Ngày yêu cầu"} />
      {tab === "users" && <div className="status-chips" role="group" aria-label="Lọc theo trạng thái">
        {[["all", "Tất cả"], ...Object.entries(statusInfo).map(([code, [, label]]) => [code, label])].map(([code, label]) => <button key={code} className={status === code ? "active" : ""} aria-pressed={status === code} onClick={() => setStatus(code)}>{label}</button>)}
      </div>}
    </div>
    {tab === "users" ? (
      <Panel title="Danh sách tài khoản" subtitle={`${filtered.length} kết quả · bấm một dòng để xem chi tiết`}>
        <DataTable rowKey="id" rows={filtered} paginate onRowClick={(user) => navigate(`/users/${user.id}`)} columns={[
          { key: "name", label: "NGƯỜI DÙNG", render: (user) => <div className="user-cell"><div className={`avatar avatar-${user.color}`}>{user.initials}</div><div><b>{user.name}</b><span>@{user.username}</span></div></div> },
          { key: "phone", label: "SỐ ĐIỆN THOẠI", render: (user) => user.phone ?? "—" },
          { key: "email", label: "EMAIL" },
          { key: "children", label: "HỒ SƠ SỞ HỮU", render: (user) => `${user.children} hồ sơ` },
          { key: "shared", label: "ĐƯỢC CHIA SẺ", render: (user) => `${user.shared} hồ sơ` },
          { key: "joined", label: "NGÀY THAM GIA" },
          { key: "status", label: "TRẠNG THÁI", render: (user) => <UserStatus status={user.status} /> },
          { key: "actions", label: "", render: (user) => !canLock ? null : user.status === "locked"
            ? <button className="link-button" onClick={(event) => { stopRowClick(event); onNotify(`Đã mở khóa ${user.name}`); }}>Mở khóa</button>
            : <button className="link-button danger" onClick={(event) => { stopRowClick(event); onNotify(`Đã khóa ${user.name}`); }}>Khóa</button> },
        ]} />
      </Panel>
    ) : (
      <Panel title="Yêu cầu xóa tài khoản (F01.6)" subtitle="Chờ 30 ngày — người dùng đăng nhập lại là hủy. Tới hạn, hệ thống ẩn danh hóa tài khoản; hồ sơ trẻ đang sở hữu phải được chuyển quyền hoặc xóa trước.">
        <DataTable rowKey="id" rows={requests} paginate onRowClick={(request) => request.userId && navigate(`/users/${request.userId}`)} columns={[
          { key: "user", label: "NGƯỜI DÙNG", render: (request) => <div className="stack"><b>{request.user}</b><small>{request.email}</small></div> },
          { key: "reason", label: "LÝ DO" },
          { key: "requested", label: "NGÀY YÊU CẦU" },
          { key: "scheduled", label: "THỰC HIỆN LÚC" },
          { key: "ownedChildren", label: "HỒ SƠ CÒN SỞ HỮU", render: (request) => request.ownedChildren > 0 ? <Badge tone="red">{request.ownedChildren} hồ sơ — chặn xóa</Badge> : <Badge tone="green">Không</Badge> },
          { key: "status", label: "TRẠNG THÁI", render: (request) => request.status === "pending" ? <Badge tone="orange">Đang chờ</Badge> : <Badge tone="gray">Đã ẩn danh hóa</Badge> },
        ]} />
      </Panel>
    )}
  </div>;
}
