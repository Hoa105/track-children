import React, { useState } from "react";
import { useAuth } from "../../core/auth.jsx";
import * as authApi from "../../core/authApi.js";
import { PERMISSIONS, roleLabel } from "../../core/session.js";
import { Badge, PageHeading, Panel } from "../../shared/ui.jsx";

export default function AccountPage({ onNotify }) {
  const { admin, updateProfile, logout } = useAuth();
  const [fullName, setFullName] = useState(admin.fullName);
  const [profileError, setProfileError] = useState("");
  const [profileBusy, setProfileBusy] = useState(false);
  const [current, setCurrent] = useState("");
  const [next, setNext] = useState("");
  const [confirm, setConfirm] = useState("");
  const [passwordError, setPasswordError] = useState("");
  const [passwordBusy, setPasswordBusy] = useState(false);
  const [logoutBusy, setLogoutBusy] = useState(false);
  const busy = profileBusy || passwordBusy || logoutBusy;

  async function saveProfile(event) {
    event.preventDefault();
    const problem = authApi.profileProblem(fullName);
    if (problem) return setProfileError(problem);
    setProfileBusy(true);
    setProfileError("");
    try {
      const saved = await updateProfile({ fullName });
      setFullName(saved.fullName);
      onNotify("Đã cập nhật thông tin");
    } catch (error) {
      setProfileError(error.message);
    } finally {
      setProfileBusy(false);
    }
  }

  async function savePassword(event) {
    event.preventDefault();
    const problem = authApi.passwordProblem(next, confirm);
    if (problem) return setPasswordError(problem);
    if (next === current) return setPasswordError("Mật khẩu mới phải khác mật khẩu hiện tại.");
    setPasswordBusy(true);
    setPasswordError("");
    try {
      await authApi.changePassword(admin.id, current, next);
      setCurrent(""); setNext(""); setConfirm("");
    } catch (error) {
      setPasswordError(error.message);
    } finally {
      setPasswordBusy(false);
    }
  }

  async function signOut() {
    setLogoutBusy(true);
    setProfileError("");
    try { await logout(); }
    catch (error) { setProfileError(error.message); }
    finally { setLogoutBusy(false); }
  }

  const permissionLabels = PERMISSIONS.filter((permission) => admin.permissions.includes(permission.code)).map((permission) => permission.label);
  const roles = admin.roles?.length ? admin.roles.map(roleLabel).join(", ") : roleLabel(admin.role);

  return <div>
    <PageHeading eyebrow="TÀI KHOẢN" title="Tài khoản của tôi" subtitle={admin.email}>
      <button className="button secondary" onClick={signOut} disabled={busy}>Đăng xuất</button>
    </PageHeading>
    <div className="content-grid">
      <Panel title="Thông tin">
        <form className="form-stack" onSubmit={saveProfile} aria-busy={profileBusy}>
          <label>HỌ VÀ TÊN<input autoComplete="name" required maxLength={150} disabled={busy} value={fullName} onChange={(event) => setFullName(event.target.value)} /></label>
          <label>EMAIL<input value={admin.email} disabled /></label>
          <label>VAI TRÒ<input value={roles} disabled /></label>
          {profileError && <p className="auth-error" role="alert">{profileError}</p>}
          <div><button className="button primary" disabled={busy || fullName.trim() === admin.fullName}>{profileBusy ? "Đang lưu…" : "Lưu thông tin"}</button></div>
        </form>
        <p className="eyebrow perm-title">QUYỀN CỦA BẠN</p>
        <div className="chip-row">{permissionLabels.map((label) => <Badge key={label} tone="green">{label}</Badge>)}</div>
      </Panel>
      <Panel title="Đổi mật khẩu" subtitle="Đổi thành công sẽ đăng xuất mọi phiên, gồm phiên hiện tại.">
        <form className="form-stack" onSubmit={savePassword} aria-busy={passwordBusy}>
          <label>MẬT KHẨU HIỆN TẠI<input type="password" autoComplete="current-password" required maxLength={1024} disabled={busy} value={current} onChange={(event) => setCurrent(event.target.value)} /></label>
          <label>MẬT KHẨU MỚI<input type="password" autoComplete="new-password" required minLength={10} maxLength={128} disabled={busy} value={next} onChange={(event) => setNext(event.target.value)} /></label>
          <label>XÁC NHẬN MẬT KHẨU MỚI<input type="password" autoComplete="new-password" required maxLength={128} disabled={busy} value={confirm} onChange={(event) => setConfirm(event.target.value)} /></label>
          <p className="auth-hint">10–128 ký tự, gồm chữ và số, khác mật khẩu hiện tại.</p>
          {passwordError && <p className="auth-error" role="alert">{passwordError}</p>}
          <div><button className="button primary" disabled={busy}>{passwordBusy ? "Đang đổi…" : "Đổi mật khẩu"}</button></div>
        </form>
      </Panel>
    </div>
  </div>;
}
