import React, { useState } from "react";
import { useAuth } from "../../core/auth.jsx";
import * as authApi from "../../core/authApi.js";
import { PERMISSIONS, roleLabel } from "../../core/session.js";
import { Badge, DataTable, MockNotice, PageHeading, Panel } from "../../shared/ui.jsx";

// admin.admin_sessions của admin đang đăng nhập (dữ liệu mẫu)
const initialSessions = [
  { id: "s1", device: "Chrome · Windows", ip: "113.161.x.x", lastUsed: "Đang dùng", current: true },
  { id: "s2", device: "Safari · macOS", ip: "14.232.x.x", lastUsed: "Hôm qua 21:14", current: false },
];

export default function AccountPage({ onNotify }) {
  const { admin, updateProfile, logout } = useAuth();
  const [fullName, setFullName] = useState(admin.fullName);
  const [current, setCurrent] = useState("");
  const [next, setNext] = useState("");
  const [confirm, setConfirm] = useState("");
  const [passwordError, setPasswordError] = useState("");
  const [busy, setBusy] = useState(false);
  const [sessions, setSessions] = useState(initialSessions);

  function saveProfile(event) {
    event.preventDefault();
    if (fullName.trim().length < 2) return;
    updateProfile({ fullName: fullName.trim() });
    onNotify("Đã cập nhật thông tin");
  }

  async function savePassword(event) {
    event.preventDefault();
    const problem = authApi.passwordProblem(next, confirm);
    if (problem) return setPasswordError(problem);
    setBusy(true);
    setPasswordError("");
    try {
      await authApi.changePassword(admin.id, current, next);
      setCurrent(""); setNext(""); setConfirm("");
      setSessions((list) => list.filter((session) => session.current));
      onNotify("Đã đổi mật khẩu, các thiết bị khác đã bị đăng xuất");
    } catch (exception) {
      setPasswordError(exception.message);
    } finally {
      setBusy(false);
    }
  }

  const permissionLabels = PERMISSIONS.filter((permission) => admin.permissions.includes(permission.code)).map((permission) => permission.label);

  return <div>
    <PageHeading eyebrow="TÀI KHOẢN" title="Tài khoản của tôi" subtitle={admin.email}>
      <button className="button secondary" onClick={logout}>Đăng xuất</button>
    </PageHeading>
    <MockNotice />
    <div className="content-grid">
      <Panel title="Thông tin">
        <form className="form-stack" onSubmit={saveProfile}>
          <label>HỌ VÀ TÊN<input value={fullName} onChange={(event) => setFullName(event.target.value)} /></label>
          <label>EMAIL<input value={admin.email} disabled /></label>
          <label>VAI TRÒ<input value={roleLabel(admin.role)} disabled /></label>
          <div><button className="button primary" disabled={fullName.trim() === admin.fullName}>Lưu</button></div>
        </form>
        <p className="eyebrow perm-title">QUYỀN CỦA BẠN</p>
        <div className="chip-row">{permissionLabels.map((label) => <Badge key={label} tone="green">{label}</Badge>)}</div>
      </Panel>
      <Panel title="Đổi mật khẩu" subtitle="Đổi mật khẩu sẽ đăng xuất các thiết bị khác">
        <form className="form-stack" onSubmit={savePassword}>
          <label>MẬT KHẨU HIỆN TẠI<input type="password" autoComplete="current-password" required value={current} onChange={(event) => setCurrent(event.target.value)} /></label>
          <label>MẬT KHẨU MỚI<input type="password" autoComplete="new-password" required value={next} onChange={(event) => setNext(event.target.value)} /></label>
          <label>XÁC NHẬN MẬT KHẨU MỚI<input type="password" autoComplete="new-password" required value={confirm} onChange={(event) => setConfirm(event.target.value)} /></label>
          <p className="auth-hint">Tối thiểu 10 ký tự, gồm cả chữ và số.</p>
          {passwordError && <p className="auth-error">{passwordError}</p>}
          <div><button className="button primary" disabled={busy}>Đổi mật khẩu</button></div>
        </form>
      </Panel>
    </div>
    <Panel title="Phiên đăng nhập" subtitle="admin.admin_sessions" action={sessions.length > 1 && <button className="link-button danger" onClick={() => { setSessions((list) => list.filter((session) => session.current)); onNotify("Đã đăng xuất các thiết bị khác"); }}>Đăng xuất thiết bị khác</button>}>
      <DataTable rowKey="id" rows={sessions} columns={[
        { key: "device", label: "THIẾT BỊ", render: (session) => <>{session.device} {session.current && <Badge tone="green">Phiên này</Badge>}</> },
        { key: "ip", label: "IP" },
        { key: "lastUsed", label: "HOẠT ĐỘNG GẦN NHẤT" },
        { key: "actions", label: "", render: (session) => !session.current && <button className="link-button danger" onClick={() => { setSessions((list) => list.filter((item) => item.id !== session.id)); onNotify("Đã đăng xuất phiên"); }}>Đăng xuất</button> },
      ]} />
    </Panel>
  </div>;
}
