import React, { useEffect, useState } from "react";
import { navigate } from "../../core/useHashRoute.js";
import { useAuth } from "../../core/auth.jsx";
import { can, initialsOf } from "../../core/session.js";
import Icon from "../../shared/Icon.jsx";
import { ALL_TIME, Badge, DataTable, Panel, StatCard, TimeFilter } from "../../shared/ui.jsx";
import { UserStatus } from "../users/UsersPage.jsx";
import { getDashboard } from "./dashboardApi.js";

const AVATAR_COLORS = ["mint", "blue", "peach", "violet", "yellow"];
const number = new Intl.NumberFormat("vi-VN");
const formatDate = (value) => (value ? new Date(value).toLocaleDateString("vi-VN", { day: "2-digit", month: "2-digit", year: "numeric" }) : "—");

// Cột biểu đồ nhỏ của StatCard cao h*5+8 px — đưa số đếm về thang 0…12
const scaled = (series = []) => {
  const max = Math.max(...series, 0);
  return series.map((value) => (max ? Math.round((value / max) * 12) : 0));
};

const avatarColor = (id) => AVATAR_COLORS[[...id].reduce((sum, char) => sum + char.charCodeAt(0), 0) % AVATAR_COLORS.length];

export default function DashboardPage() {
  const { admin } = useAuth();
  const [range, setRange] = useState(ALL_TIME);
  const [data, setData] = useState(null);
  const [error, setError] = useState("");
  const canSeeUsers = can(admin, "user.read");

  useEffect(() => {
    if (range.preset === "custom" && (!range.from || !range.to)) return;
    let current = true;
    setError("");
    getDashboard(admin, range)
      .then((result) => current && setData(result))
      .catch((problem) => current && setError(problem.message));
    return () => { current = false; };
  }, [admin, range]);

  const allTime = range.preset === "all";
  const inRange = allTime ? "" : " trong khoảng đã chọn";
  const show = (value) => (data ? number.format(value) : "…");
  const users = data?.users;
  const children = data?.children;
  const assessments = data?.assessments;
  const diary = data?.diary;

  return <div className="dashboard">
    <div className="dashboard-toolbar"><TimeFilter value={range} onChange={setRange} /></div>
    {error && <div className="mock-notice">{error}</div>}
    <div className="stats-grid">
      <StatCard title="TỔNG NGƯỜI DÙNG" value={show(users?.total)} icon="users" tone="green" chart={scaled(users?.series)}
        sub={users && (allTime ? `+${number.format(users.new30d)} trong 30 ngày` : `+${number.format(users.newInRange)} mới${inRange}`)} />
      <StatCard title="HỒ SƠ TRẺ ĐANG THEO DÕI" value={show(children?.total)} icon="child" tone="blue" chart={scaled(children?.series)}
        sub={children && (allTime ? `+${number.format(children.new30d)} trong 30 ngày` : `+${number.format(children.newInRange)} mới${inRange}`)} />
      <StatCard title="ĐÁNH GIÁ HOÀN THÀNH" value={show(assessments?.completedInRange)} icon="clipboard" tone="purple" chart={scaled(assessments?.series)}
        sub={assessments && (assessments.completionRate == null ? `Chưa có lượt đánh giá${inRange}` : `tỷ lệ hoàn thành ${assessments.completionRate}%`)} />
      <StatCard title="NHẬT KÝ ĐÃ GHI" value={show(diary?.entriesInRange)} icon="book" tone="orange" chart={scaled(diary?.series)}
        sub={diary && `từ ${number.format(diary.childrenInRange)} hồ sơ trẻ`} />
    </div>
    {canSeeUsers && <>
      <Panel title="Việc cần xử lý — Yêu cầu xóa tài khoản" subtitle={`${data?.pendingDeletions.length ?? "…"} yêu cầu đang chờ · bấm một dòng để mở danh sách xử lý`} action={<button className="text-link" onClick={() => navigate("/users?tab=deletion")}>Xem tất cả <Icon name="arrow" size={14} /></button>}>
        <DataTable rowKey="id" rows={data?.pendingDeletions ?? []} empty={data ? "Không có yêu cầu xóa tài khoản nào đang chờ" : "Đang tải…"} onRowClick={(request) => navigate(`/users/${request.userId}`)} columns={[
          { key: "user", label: "NGƯỜI DÙNG", render: (request) => <div className="stack"><b>{request.name}</b><small>{request.contact ?? "—"}</small></div> },
          { key: "reason", label: "LÝ DO", render: (request) => request.reason ?? "—" },
          { key: "requested", label: "NGÀY YÊU CẦU", render: (request) => formatDate(request.requestedAt) },
          { key: "scheduled", label: "THỰC HIỆN LÚC", render: (request) => <span className="deletion-due">{formatDate(request.scheduledAt)}</span> },
          { key: "ownedChildren", label: "HỒ SƠ CÒN SỞ HỮU", render: (request) => request.ownedChildren > 0 ? <Badge tone="red">{request.ownedChildren} hồ sơ — chặn xóa</Badge> : <Badge tone="green">Không</Badge> },
        ]} />
      </Panel>
      <div className="panel-gap" />
      <Panel title="Người dùng mới nhất" subtitle="Những tài khoản vừa tham gia" action={<button className="text-link" onClick={() => navigate("/users")}>Xem tất cả <Icon name="arrow" size={14} /></button>}>
        <DataTable rowKey="id" rows={data?.newestUsers ?? []} empty={data ? "Không có người dùng mới trong khoảng thời gian này" : "Đang tải…"} onRowClick={(user) => navigate(`/users/${user.id}`)} columns={[
          { key: "name", label: "NGƯỜI DÙNG", render: (user) => <div className="user-cell"><div className={`avatar avatar-${avatarColor(user.id)}`}>{initialsOf(user.name)}</div><div><b>{user.name}</b></div></div> },
          { key: "phone", label: "SỐ ĐIỆN THOẠI", render: (user) => user.phone ?? "—" },
          { key: "email", label: "EMAIL", render: (user) => user.email ?? "—" },
          { key: "children", label: "HỒ SƠ SỞ HỮU", render: (user) => `${user.ownedChildren} hồ sơ` },
          { key: "joined", label: "NGÀY THAM GIA", render: (user) => formatDate(user.joinedAt) },
          { key: "status", label: "TRẠNG THÁI", render: (user) => <UserStatus status={user.status} /> },
        ]} />
      </Panel>
    </>}
  </div>;
}
