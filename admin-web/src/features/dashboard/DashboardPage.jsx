import React, { useState } from "react";
import { navigate } from "../../core/useHashRoute.js";
import { useAuth } from "../../core/auth.jsx";
import { can } from "../../core/session.js";
import Icon from "../../shared/Icon.jsx";
import { ALL_TIME, Badge, DataTable, MockNotice, Panel, StatCard, TimeFilter, inTimeRange } from "../../shared/ui.jsx";
import { UserStatus, deletionRequests, users } from "../users/UsersPage.jsx";

export default function DashboardPage() {
  const { admin } = useAuth();
  const [range, setRange] = useState(ALL_TIME);
  const canSeeUsers = can(admin, "user.read");
  const pendingDeletions = deletionRequests.filter((request) => request.status === "pending" && inTimeRange(request.requested, range));
  const newestUsers = users.filter((user) => inTimeRange(user.joined, range)).slice(0, 5);

  return <div className="dashboard">
    <div className="dashboard-toolbar"><TimeFilter value={range} onChange={setRange} /></div>
    <MockNotice />
    <div className="stats-grid">
      <StatCard title="TỔNG NGƯỜI DÙNG" value="2.481" sub="+312 trong 30 ngày" icon="users" tone="green" chart={[3, 5, 4, 7, 6, 8, 7, 10, 9, 12]} />
      <StatCard title="HỒ SƠ TRẺ ĐANG THEO DÕI" value="3.847" sub="+8,2% so với tháng trước" icon="child" tone="blue" chart={[5, 4, 6, 5, 8, 7, 9, 8, 11, 13]} />
      <StatCard title="ĐÁNH GIÁ HOÀN THÀNH" value="1.284" sub="tỷ lệ hoàn thành 86%" icon="clipboard" tone="purple" chart={[2, 4, 3, 5, 5, 7, 6, 8, 9, 12]} />
      <StatCard title="TIN NHẮN CHATBOT" value="642" sub="94% có nguồn trích dẫn" icon="message" tone="orange" chart={[6, 7, 5, 8, 9, 7, 10, 9, 11, 12]} />
    </div>
    {canSeeUsers && <>
      <Panel title="Việc cần xử lý — Yêu cầu xóa tài khoản" subtitle={`${pendingDeletions.length} yêu cầu đang chờ · bấm một dòng để mở danh sách xử lý`} action={<button className="text-link" onClick={() => navigate("/users?tab=deletion")}>Xem tất cả <Icon name="arrow" size={14} /></button>}>
        <DataTable rowKey="id" rows={pendingDeletions} empty="Không có yêu cầu xóa tài khoản nào đang chờ" onRowClick={(request) => navigate(request.userId ? `/users/${request.userId}` : "/users?tab=deletion")} columns={[
          { key: "user", label: "NGƯỜI DÙNG", render: (request) => <div className="stack"><b>{request.user}</b><small>{request.email}</small></div> },
          { key: "reason", label: "LÝ DO" },
          { key: "requested", label: "NGÀY YÊU CẦU" },
          { key: "scheduled", label: "THỰC HIỆN LÚC", render: (request) => <span className="deletion-due">{request.scheduled}</span> },
          { key: "ownedChildren", label: "HỒ SƠ CÒN SỞ HỮU", render: (request) => request.ownedChildren > 0 ? <Badge tone="red">{request.ownedChildren} hồ sơ — chặn xóa</Badge> : <Badge tone="green">Không</Badge> },
        ]} />
      </Panel>
      <div className="panel-gap" />
      <Panel title="Người dùng mới nhất" subtitle="Những tài khoản vừa tham gia" action={<button className="text-link" onClick={() => navigate("/users")}>Xem tất cả <Icon name="arrow" size={14} /></button>}>
        <DataTable rowKey="id" rows={newestUsers} empty="Không có người dùng mới trong khoảng thời gian này" onRowClick={(user) => navigate(`/users/${user.id}`)} columns={[
          { key: "name", label: "NGƯỜI DÙNG", render: (user) => <div className="user-cell"><div className={`avatar avatar-${user.color}`}>{user.initials}</div><div><b>{user.name}</b><span>@{user.username}</span></div></div> },
          { key: "phone", label: "SỐ ĐIỆN THOẠI", render: (user) => user.phone ?? "—" },
          { key: "email", label: "EMAIL" },
          { key: "children", label: "HỒ SƠ SỞ HỮU", render: (user) => `${user.children} hồ sơ` },
          { key: "joined", label: "NGÀY THAM GIA" },
          { key: "status", label: "TRẠNG THÁI", render: (user) => <UserStatus status={user.status} /> },
        ]} />
      </Panel>
    </>}
  </div>;
}
