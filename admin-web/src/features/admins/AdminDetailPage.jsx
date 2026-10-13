import React, { useState } from "react";
import { useAuth } from "../../core/auth.jsx";
import { mockAdmins, passwordProblem } from "../../core/authApi.js";
import { ADMIN_ROLES, initialsOf, roleLabel } from "../../core/session.js";
import { navigate } from "../../core/useHashRoute.js";
import Icon from "../../shared/Icon.jsx";
import { Badge, DataTable, MockNotice, Panel } from "../../shared/ui.jsx";
import { AdminStatus, isProtectedAdmin } from "./AdminsPage.jsx";

// admin.admin_sessions — refresh token theo thiết bị, khóa admin sẽ thu hồi hết
const sessions = {
  a1: [
    { id: "s1", device: "Chrome 141 · Windows", ip: "113.161.24.8", lastUsed: "12/10/2026 08:02", status: "active" },
    { id: "s2", device: "Safari · macOS", ip: "14.232.10.77", lastUsed: "09/10/2026 19:20", status: "active" },
  ],
  a2: [{ id: "s3", device: "Edge 141 · Windows", ip: "171.244.3.15", lastUsed: "11/10/2026 17:40", status: "active" }],
  a3: [{ id: "s4", device: "Chrome 141 · Android", ip: "27.72.98.40", lastUsed: "12/10/2026 07:15", status: "active" }],
  a4: [{ id: "s5", device: "Chrome 140 · Windows", ip: "113.161.24.9", lastUsed: "20/09/2026 10:30", status: "revoked" }],
};

// admin.admin_audit_logs lọc theo admin_user_id
const auditLogs = {
  a1: [
    { id: "l1", action: "update", entity: "admin.admin_users", detail: "Khóa tài khoản Hà Phương", at: "03/10/2026 09:12" },
    { id: "l2", action: "upload", entity: "ai_kb.kb_documents", detail: "Tải lên tài liệu tri thức", at: "12/10/2026 07:10" },
  ],
  a2: [
    { id: "l3", action: "update", entity: "criteria.criteria", detail: "Cập nhật tiêu chí phát triển", at: "12/10/2026 07:50" },
    { id: "l4", action: "publish", entity: "activity.activities", detail: "Xuất bản 3 hoạt động nhóm Âm nhạc", at: "10/10/2026 15:02" },
  ],
  a3: [
    { id: "l5", action: "hide", entity: "community.posts", detail: "Ẩn bài viết bị báo cáo", at: "12/10/2026 07:26" },
    { id: "l6", action: "dismiss", entity: "community.content_reports", detail: "Bỏ qua báo cáo r4", at: "09/10/2026 10:20" },
  ],
  a4: [{ id: "l7", action: "lock", entity: "account.users", detail: "Khóa tài khoản Phạm Quốc Bảo", at: "03/10/2026 08:40" }],
};

function InfoList({ rows }) {
  return <dl className="info-list">{rows.map(([label, value]) => <React.Fragment key={label}><dt>{label}</dt><dd>{value ?? "—"}</dd></React.Fragment>)}</dl>;
}

function ChangePasswordForm({ onSave }) {
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [mustChange, setMustChange] = useState(true);
  const [error, setError] = useState("");

  function submit(event) {
    event.preventDefault();
    const problem = passwordProblem(password, confirm);
    if (problem) return setError(problem);
    onSave(password, mustChange);
    setPassword("");
    setConfirm("");
  }

  return <form className="form-stack" onSubmit={submit}>
    <label>MẬT KHẨU MỚI<input type="password" autoComplete="new-password" required value={password} onChange={(event) => { setPassword(event.target.value); setError(""); }} /></label>
    <label>XÁC NHẬN MẬT KHẨU<input type="password" autoComplete="new-password" required value={confirm} onChange={(event) => { setConfirm(event.target.value); setError(""); }} /></label>
    <p className="auth-hint">Tối thiểu 10 ký tự, gồm cả chữ và số.</p>
    <label className="check-row"><input type="checkbox" checked={mustChange} onChange={(event) => setMustChange(event.target.checked)} />Yêu cầu đổi mật khẩu ở lần đăng nhập tới</label>
    {error && <p className="auth-error">{error}</p>}
    <div><button className="button primary">Đổi mật khẩu</button></div>
  </form>;
}

export default function AdminDetailPage({ id, onNotify }) {
  const { admin: me } = useAuth();
  const stored = mockAdmins.find((item) => item.id === id);
  const [target, setTarget] = useState(() => stored && { ...stored });
  const [sessionList, setSessionList] = useState(() => sessions[id] ?? []);

  if (!target) {
    return <div className="panel empty-state"><h2>Không tìm thấy quản trị viên</h2><p>Tài khoản <code>{id}</code> không tồn tại.</p><button className="button secondary" onClick={() => navigate("/admins")}>Về danh sách</button></div>;
  }

  const isMe = target.id === me.id;
  const locked = isProtectedAdmin(target, me, mockAdmins);

  function update(changes, message) {
    setTarget((current) => ({ ...current, ...changes }));
    Object.assign(stored, changes);  // để danh sách và đăng nhập mock thấy thay đổi
    onNotify(message);
  }

  function revokeSessions(message) {
    setSessionList((current) => current.map((session) => ({ ...session, status: "revoked" })));
    onNotify(message);
  }

  function changePassword(password, mustChange) {
    update({ password, mustChangePassword: mustChange, failed: 0 }, mustChange
      ? `Đã đặt mật khẩu mới cho ${target.fullName} — sẽ phải đổi ở lần đăng nhập tới`
      : `Đã đổi mật khẩu của ${target.fullName}`);
    setSessionList((current) => current.map((session) => ({ ...session, status: "revoked" })));
  }

  function lock() {
    update({ status: "locked" }, `Đã khóa ${target.fullName} và đăng xuất mọi phiên`);
    setSessionList((current) => current.map((session) => ({ ...session, status: "revoked" })));
  }

  return <div>
    <button className="text-link detail-back" onClick={() => navigate("/admins")}><Icon name="arrow" size={14} /> Quản trị viên & vai trò</button>
    <div className="detail-header">
      <div className="avatar avatar-blue avatar-lg">{initialsOf(target.fullName)}</div>
      <div className="detail-title"><h1>{target.fullName}{isMe && " (bạn)"}</h1><p>{target.email} · {roleLabel(target.role)}</p></div>
      <AdminStatus admin={target} />
      {!locked && <div className="heading-actions">
        <button className="button secondary" onClick={() => onNotify(`Đã gửi link đặt lại mật khẩu tới ${target.email}`)}>Gửi link đặt lại mật khẩu</button>
        {target.status === "active"
          ? <button className="button secondary danger" onClick={lock}>Khóa</button>
          : <button className="button secondary" onClick={() => update({ status: "active" }, `Đã mở khóa ${target.fullName}`)}>Mở khóa</button>}
      </div>}
    </div>
    <MockNotice />
    {target.mustChangePassword && <div className="detail-alert info">Thành viên chưa đăng nhập lần đầu — đang dùng mật khẩu tạm do quản trị viên cấp và sẽ phải đổi mật khẩu khi đăng nhập.</div>}
    {locked && <div className="detail-alert">{isMe
      ? "Đây là tài khoản của bạn — không thể tự khóa hoặc tự đổi vai trò."
      : "Super Admin đang hoạt động cuối cùng — không thể khóa hoặc hạ vai trò."}</div>}

    <div className="content-grid detail-grid">
      <Panel title="Thông tin" subtitle="admin.admin_users">
        <InfoList rows={[
          ["Email", target.email],
          ["Vai trò", locked
            ? roleLabel(target.role)
            : <select className="inline-select" value={target.role} onChange={(event) => update({ role: event.target.value }, `Đã đổi vai trò của ${target.fullName} thành ${roleLabel(event.target.value)}`)}>{ADMIN_ROLES.map((role) => <option key={role.code} value={role.code}>{role.label}</option>)}</select>],
          ["Ngày tạo", target.createdAt],
          ["Đăng nhập gần nhất", target.lastLogin],
          ["Đăng nhập sai liên tiếp", target.failed > 0 ? <Badge tone="orange">{target.failed} lần</Badge> : 0],
        ]} />
      </Panel>
      <Panel title="Đổi mật khẩu" subtitle={isMe ? "Mật khẩu của chính bạn" : "Đặt mật khẩu mới cho thành viên — mọi phiên đăng nhập cũ bị đăng xuất"}>
        {isMe
          ? <><p className="panel-note">Đổi mật khẩu của bạn tại trang Tài khoản của tôi (cần nhập mật khẩu hiện tại).</p><button className="button secondary password-go" onClick={() => navigate("/account")}>Mở Tài khoản của tôi</button></>
          : <ChangePasswordForm key={target.id} onSave={changePassword} />}
      </Panel>
    </div>

    <div className="content-grid">
      <Panel title="Nhật ký thao tác" subtitle="admin.admin_audit_logs" action={<button className="text-link" onClick={() => navigate("/audit")}>Tất cả <Icon name="arrow" size={14} /></button>}>
        <DataTable rowKey="id" rows={auditLogs[target.id] ?? []} empty="Chưa có thao tác nào" columns={[
          { key: "detail", label: "THAO TÁC", wrap: true, render: (log) => <div className="stack"><span>{log.detail}</span><small><code>{log.action}</code> · {log.entity}</small></div> },
          { key: "at", label: "THỜI GIAN" },
        ]} />
      </Panel>
      <Panel title="Phiên đăng nhập" subtitle="admin.admin_sessions" action={!isMe && sessionList.some((session) => session.status === "active") && <button className="text-link danger" onClick={() => revokeSessions(`Đã đăng xuất ${target.fullName} khỏi mọi thiết bị`)}>Đăng xuất tất cả</button>}>
        <DataTable rowKey="id" rows={sessionList} empty="Không có phiên nào" columns={[
          { key: "device", label: "THIẾT BỊ", render: (session) => <div className="stack"><span>{session.device}</span><small>{session.ip} · {session.lastUsed}</small></div> },
          { key: "status", label: "", render: (session) => session.status === "active" ? <Badge tone="green">Hoạt động</Badge> : <Badge tone="gray">Đã thu hồi</Badge> },
        ]} />
      </Panel>
    </div>
  </div>;
}
