import React, { useEffect, useState } from "react";
import { useAuth } from "../../core/auth.jsx";
import * as authApi from "../../core/authApi.js";
import { navigate } from "../../core/useHashRoute.js";
import { roleLabel } from "../../core/session.js";

function AuthLayout({ title, subtitle, children, footer }) {
  return <div className="auth-shell">
    <div className="auth-card">
      <div className="brand auth-brand"><div className="brand-mark"><span>+</span></div><div><strong>track<span>children</span></strong><small>ADMIN CONSOLE</small></div></div>
      <h1>{title}</h1>
      {subtitle && <p className="auth-subtitle">{subtitle}</p>}
      {children}
    </div>
    {footer && <p className="auth-footer">{footer}</p>}
  </div>;
}

function Field({ label, ...props }) {
  return <label className="auth-field">{label}<input {...props} /></label>;
}

function useSubmit() {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  async function run(action) {
    setBusy(true);
    setError("");
    try {
      await action();
    } catch (exception) {
      setError(exception instanceof authApi.AuthError ? exception.message : "Có lỗi xảy ra, vui lòng thử lại.");
    } finally {
      setBusy(false);
    }
  }
  return { busy, error, setError, run };
}

export function LoginPage() {
  const { login, sessionNotice } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const { busy, error, run } = useSubmit();

  return <AuthLayout title="Đăng nhập quản trị" subtitle="Dành cho quản trị viên Track Children." footer="Tài khoản quản trị do Super Admin tạo.">
    {sessionNotice && <p className="auth-success" role="status">{sessionNotice}</p>}
    <form onSubmit={(event) => { event.preventDefault(); run(async () => { await login(email, password); navigate("/"); }); }}>
      <Field label="EMAIL" type="email" autoComplete="username" required value={email} onChange={(event) => setEmail(event.target.value)} placeholder="ten@trackchildren.vn" />
      <Field label="MẬT KHẨU" type="password" autoComplete="current-password" required value={password} onChange={(event) => setPassword(event.target.value)} />
      <div className="auth-row"><span /><a href="#/forgot-password">Quên mật khẩu?</a></div>
      {error && <p className="auth-error" role="alert">{error}</p>}
      <button className="button primary auth-submit" disabled={busy}>{busy ? "Đang đăng nhập…" : "Đăng nhập"}</button>
    </form>
  </AuthLayout>;
}

export function ForgotPasswordPage() {
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
  const { busy, error, run } = useSubmit();

  return <AuthLayout title="Quên mật khẩu" subtitle="Nhập email quản trị, chúng tôi sẽ gửi link đặt lại mật khẩu (hiệu lực 30 phút).">
    {sent
      ? <p className="auth-success">Nếu <b>{email}</b> là tài khoản quản trị, link đặt lại mật khẩu đã được gửi tới email này.</p>
      : <form onSubmit={(event) => { event.preventDefault(); run(async () => { await authApi.requestPasswordReset(email); setSent(true); }); }}>
          <Field label="EMAIL" type="email" required value={email} onChange={(event) => setEmail(event.target.value)} />
          {error && <p className="auth-error" role="alert">{error}</p>}
          <button className="button primary auth-submit" disabled={busy}>Gửi link đặt lại</button>
        </form>}
    <p className="auth-back"><a href="#/login">← Quay lại đăng nhập</a></p>
  </AuthLayout>;
}

// Lần đăng nhập đầu: nhập lại mật khẩu admin cấp rồi đặt mật khẩu mới
export function FirstLoginPasswordPage() {
  const { admin, completeFirstLogin, logout } = useAuth();
  const [temporary, setTemporary] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const { busy, error, setError, run } = useSubmit();

  function submit(event) {
    event.preventDefault();
    const problem = authApi.passwordProblem(password, confirm);
    if (problem) return setError(problem);
    run(async () => { await completeFirstLogin(temporary, password); navigate("/"); });
  }

  return <AuthLayout title="Đổi mật khẩu lần đầu" subtitle={<>Chào {admin.fullName}! Tài khoản <b>{roleLabel(admin.role)}</b> đang dùng mật khẩu do quản trị viên cấp. Hãy đặt mật khẩu mới để tiếp tục.</>}>
    <form onSubmit={submit}>
      <Field label="EMAIL" type="email" value={admin.email} disabled />
      <Field label="MẬT KHẨU ĐƯỢC CẤP" type="password" autoComplete="current-password" required value={temporary} onChange={(event) => setTemporary(event.target.value)} />
      <Field label="MẬT KHẨU MỚI" type="password" autoComplete="new-password" required value={password} onChange={(event) => setPassword(event.target.value)} />
      <Field label="XÁC NHẬN MẬT KHẨU MỚI" type="password" autoComplete="new-password" required value={confirm} onChange={(event) => setConfirm(event.target.value)} />
      <p className="auth-hint">Tối thiểu 10 ký tự, gồm cả chữ và số, khác mật khẩu được cấp.</p>
      {error && <p className="auth-error" role="alert">{error}</p>}
      <button className="button primary auth-submit" disabled={busy}>{busy ? "Đang lưu…" : "Lưu mật khẩu & vào hệ thống"}</button>
    </form>
    <p className="auth-back"><a href="#/login" onClick={(event) => { event.preventDefault(); logout(); }}>← Đăng xuất</a></p>
  </AuthLayout>;
}

// mode = "invite": kích hoạt tài khoản từ lời mời (thay cho đăng ký)
// mode = "reset": đặt lại mật khẩu từ link quên mật khẩu
export function SetPasswordPage({ mode, token }) {
  const { acceptInvitation } = useAuth();
  const [info, setInfo] = useState(null);
  const [loadError, setLoadError] = useState("");
  const [fullName, setFullName] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [done, setDone] = useState(false);
  const { busy, error, setError, run } = useSubmit();
  const isInvite = mode === "invite";

  useEffect(() => {
    const load = isInvite ? authApi.getInvitation(token) : authApi.checkResetToken(token);
    load.then((result) => { setInfo(result); setFullName(result.fullName ?? ""); })
      .catch((exception) => setLoadError(exception.message));
  }, [isInvite, token]);

  function submit(event) {
    event.preventDefault();
    const problem = passwordProblemOrName();
    if (problem) return setError(problem);
    run(async () => {
      if (isInvite) {
        await acceptInvitation(token, { fullName: fullName.trim(), password });
        navigate("/");
      } else {
        await authApi.resetPassword(token, password);
        setDone(true);
      }
    });
  }

  function passwordProblemOrName() {
    if (isInvite && fullName.trim().length < 2) return "Vui lòng nhập họ tên.";
    return authApi.passwordProblem(password, confirm);
  }

  const title = isInvite ? "Kích hoạt tài khoản quản trị" : "Đặt lại mật khẩu";
  if (loadError) return <AuthLayout title={title}><p className="auth-error">{loadError}</p><p className="auth-back"><a href="#/login">← Về trang đăng nhập</a></p></AuthLayout>;
  if (!info) return <AuthLayout title={title}><p className="auth-subtitle">Đang kiểm tra link…</p></AuthLayout>;
  if (done) return <AuthLayout title={title}><p className="auth-success">Đã đặt mật khẩu mới. Các phiên đăng nhập cũ đã bị đăng xuất.</p><button className="button primary auth-submit" onClick={() => navigate("/login")}>Đăng nhập</button></AuthLayout>;

  return <AuthLayout title={title} subtitle={isInvite ? <>Bạn được mời với vai trò <b>{roleLabel(info.role)}</b>{info.invitedBy && <> bởi {info.invitedBy}</>}.</> : null}>
    <form onSubmit={submit}>
      <Field label="EMAIL" type="email" value={info.email} disabled />
      {isInvite && <Field label="HỌ VÀ TÊN" required value={fullName} onChange={(event) => setFullName(event.target.value)} />}
      <Field label="MẬT KHẨU MỚI" type="password" autoComplete="new-password" required value={password} onChange={(event) => setPassword(event.target.value)} />
      <Field label="XÁC NHẬN MẬT KHẨU" type="password" autoComplete="new-password" required value={confirm} onChange={(event) => setConfirm(event.target.value)} />
      <p className="auth-hint">Tối thiểu 10 ký tự, gồm cả chữ và số.</p>
      {error && <p className="auth-error" role="alert">{error}</p>}
      <button className="button primary auth-submit" disabled={busy}>{isInvite ? "Kích hoạt & đăng nhập" : "Lưu mật khẩu mới"}</button>
    </form>
  </AuthLayout>;
}
