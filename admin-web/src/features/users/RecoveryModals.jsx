import React, { useState } from "react";
import Icon from "../../shared/Icon.jsx";

// Khôi phục tài khoản qua hotline (migration 004, quyền user.recover).
// Người gọi điện có thể mạo danh → bắt đối chiếu tối thiểu 3 mục trước mọi thao tác.
export const verifyItems = [
  { code: "full_name", label: "Họ tên đầy đủ khớp tài khoản" },
  { code: "old_contact", label: "Email hoặc SĐT cũ đã đăng ký" },
  { code: "child_birth", label: "Tên và tháng / năm sinh của một hồ sơ trẻ" },
  { code: "signup_month", label: "Thời điểm đăng ký (tháng / năm)" },
  { code: "last_device", label: "Thiết bị đăng nhập gần nhất" },
  { code: "id_card", label: "Ảnh CCCD khớp họ tên tài khoản" },
];
const MIN_VERIFIED = 3;

function VerifyChecklist({ checked, onChange }) {
  return <fieldset className="verify-list">
    <legend>XÁC MINH DANH TÍNH — TỐI THIỂU {MIN_VERIFIED} MỤC ({checked.length}/{verifyItems.length})</legend>
    {verifyItems.map((item) => <label key={item.code}>
      <input type="checkbox" checked={checked.includes(item.code)} onChange={(event) => onChange(event.target.checked ? [...checked, item.code] : checked.filter((code) => code !== item.code))} />
      {item.label}
    </label>)}
  </fieldset>;
}

function Modal({ eyebrow, title, description, onClose, onSubmit, submitLabel, error, children }) {
  return <div className="modal-backdrop" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
    <form className="modal modal-wide" onSubmit={(event) => { event.preventDefault(); onSubmit(); }}>
      <div className="modal-header"><div><p className="eyebrow">{eyebrow}</p><h2>{title}</h2></div><button type="button" className="close-button" onClick={onClose} aria-label="Đóng"><Icon name="close" /></button></div>
      <p className="modal-description">{description}</p>
      {children}
      {error && <p className="auth-error">{error}</p>}
      <div className="modal-actions"><button type="button" className="button secondary" onClick={onClose}>Hủy</button><button className="button primary">{submitLabel}</button></div>
    </form>
  </div>;
}

export function ContactChangeModal({ user, takenContacts, onClose, onSave }) {
  const [phone, setPhone] = useState("");
  const [email, setEmail] = useState("");
  const [checked, setChecked] = useState([]);
  const [note, setNote] = useState("");
  const [error, setError] = useState("");

  function submit() {
    const newPhone = phone.replace(/[\s.-]/g, "").replace(/^0/, "+84");
    const newEmail = email.trim().toLowerCase();
    if (!newPhone && !newEmail) return setError("Nhập SĐT hoặc email mới.");
    if (newPhone && !/^\+[1-9][0-9]{7,14}$/.test(newPhone)) return setError("SĐT không hợp lệ — dạng 0912345678 hoặc +84912345678.");
    if (newEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(newEmail)) return setError("Email không hợp lệ.");
    if (newPhone === user.phone || newEmail === user.email) return setError("Thông tin mới trùng với thông tin hiện tại.");
    if (takenContacts.includes(newPhone) || takenContacts.includes(newEmail)) return setError("SĐT hoặc email này đã thuộc tài khoản khác.");
    if (checked.length < MIN_VERIFIED) return setError(`Cần xác minh tối thiểu ${MIN_VERIFIED} mục.`);
    if (note.trim().length < 10) return setError("Ghi chú cần mô tả kênh liên hệ và nội dung yêu cầu.");
    onSave({ newPhone: newPhone || null, newEmail: newEmail || null, verified: checked, note: note.trim() });
  }

  return <Modal eyebrow="KHÔI PHỤC TÀI KHOẢN" title="Đổi SĐT / email đăng nhập" submitLabel="Tạo yêu cầu (chờ 48 giờ)" error={error} onClose={onClose} onSubmit={submit}
    description="Dùng khi người dùng mất cả SĐT lẫn email nên không tự đặt lại mật khẩu được. Thay đổi có hiệu lực sau 48 giờ; trong thời gian đó hệ thống gửi cảnh báo tới thông tin cũ để chủ thật có thể chặn.">
    <div className="current-contact"><span>Hiện tại</span><b>{user.phone ?? "—"}</b><b>{user.email ?? "—"}</b></div>
    <label>SĐT MỚI<input value={phone} onChange={(event) => { setPhone(event.target.value); setError(""); }} placeholder="0912345678" inputMode="tel" /></label>
    <label>EMAIL MỚI (KHÔNG BẮT BUỘC)<input type="email" value={email} onChange={(event) => { setEmail(event.target.value); setError(""); }} placeholder="email@gmail.com" /></label>
    <VerifyChecklist checked={checked} onChange={(next) => { setChecked(next); setError(""); }} />
    <label>GHI CHÚ<input value={note} onChange={(event) => { setNote(event.target.value); setError(""); }} placeholder="VD: Gọi hotline 12/10, mất máy cũ, số cũ đã bị nhà mạng thu hồi" /></label>
  </Modal>;
}

export function CancelDeletionModal({ user, request, onClose, onSave }) {
  const [checked, setChecked] = useState([]);
  const [note, setNote] = useState("");
  const [error, setError] = useState("");

  function submit() {
    if (checked.length < MIN_VERIFIED) return setError(`Cần xác minh tối thiểu ${MIN_VERIFIED} mục.`);
    if (note.trim().length < 10) return setError("Ghi chú cần mô tả kênh liên hệ và lý do hủy.");
    onSave({ verified: checked, note: note.trim() });
  }

  return <Modal eyebrow="KHÔI PHỤC TÀI KHOẢN" title="Hủy yêu cầu xóa tài khoản" submitLabel="Hủy yêu cầu xóa" error={error} onClose={onClose} onSubmit={submit}
    description={`${user.name} yêu cầu xóa ngày ${request.requested}, dự kiến ẩn danh hóa ${request.scheduled}. Người dùng tự đăng nhập lại cũng hủy được — chỉ dùng khi họ không đăng nhập được. Sau khi ẩn danh hóa thì không khôi phục được nữa.`}>
    <VerifyChecklist checked={checked} onChange={(next) => { setChecked(next); setError(""); }} />
    <label>GHI CHÚ<input value={note} onChange={(event) => { setNote(event.target.value); setError(""); }} placeholder="VD: Gọi hotline 12/10, đổi ý muốn tiếp tục dùng app" /></label>
  </Modal>;
}
