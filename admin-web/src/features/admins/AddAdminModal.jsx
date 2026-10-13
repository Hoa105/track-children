import React, { useState } from "react";
import Icon from "../../shared/Icon.jsx";
import { ADMIN_ROLES } from "../../core/session.js";
import { passwordProblem } from "../../core/authApi.js";

export default function AddAdminModal({ onClose, onSave, existingEmails }) {
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [role, setRole] = useState("support");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState("");

  function submit(event) {
    event.preventDefault();
    const normalized = email.trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized)) return setError("Email không hợp lệ.");
    if (existingEmails.includes(normalized)) return setError("Email này đã là thành viên quản trị.");
    const problem = passwordProblem(password, confirm);
    if (problem) return setError(problem);
    onSave({ fullName: fullName.trim(), email: normalized, role, password });
  }

  return <div className="modal-backdrop" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
    <form className="modal" onSubmit={submit}>
      <div className="modal-header"><div><p className="eyebrow">QUẢN TRỊ VIÊN</p><h2>Thêm thành viên</h2></div><button type="button" className="close-button" onClick={onClose} aria-label="Đóng"><Icon name="close" /></button></div>
      <p className="modal-description">Đặt mật khẩu tạm và gửi cho thành viên. Lần đăng nhập đầu tiên, thành viên phải nhập mật khẩu này rồi đổi sang mật khẩu mới.</p>
      <label>HỌ VÀ TÊN<input required value={fullName} onChange={(event) => setFullName(event.target.value)} placeholder="Ví dụ: Nguyễn Văn A" /></label>
      <label>ĐỊA CHỈ EMAIL<input type="email" required value={email} onChange={(event) => { setEmail(event.target.value); setError(""); }} placeholder="email@trackchildren.vn" /></label>
      <label>MẬT KHẨU TẠM<input type="password" autoComplete="new-password" required value={password} onChange={(event) => { setPassword(event.target.value); setError(""); }} /></label>
      <label>XÁC NHẬN MẬT KHẨU<input type="password" autoComplete="new-password" required value={confirm} onChange={(event) => { setConfirm(event.target.value); setError(""); }} /></label>
      <p className="auth-hint">Tối thiểu 10 ký tự, gồm cả chữ và số.</p>
      <label>VAI TRÒ<select value={role} onChange={(event) => setRole(event.target.value)}>{ADMIN_ROLES.map((item) => <option key={item.code} value={item.code}>{item.label}</option>)}</select></label>
      {error && <p className="auth-error">{error}</p>}
      <div className="modal-actions"><button type="button" className="button secondary" onClick={onClose}>Hủy</button><button className="button primary">Thêm thành viên</button></div>
    </form>
  </div>;
}
