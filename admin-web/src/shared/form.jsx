import React, { useState } from "react";
import Icon from "./Icon.jsx";

// Form trong modal dùng chung cho các màn quản trị danh mục (tiêm chủng, hoạt động…)

export const blankToNull = (value) => (value.trim() === "" ? null : value.trim());
export const numberOrNull = (value) => (value === "" || value == null ? null : Number(value));

export function Modal({ eyebrow, title, onClose, onSubmit, saving, children }) {
  return <div className="modal-backdrop" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
    <form className="modal modal-wide" onSubmit={onSubmit}>
      <div className="modal-header"><div><p className="eyebrow">{eyebrow}</p><h2>{title}</h2></div><button type="button" className="close-button" onClick={onClose} aria-label="Đóng"><Icon name="close" /></button></div>
      {children}
      <div className="modal-actions"><button type="button" className="button secondary" onClick={onClose}>Hủy</button><button className="button primary" disabled={saving}>{saving ? "Đang lưu…" : "Lưu"}</button></div>
    </form>
  </div>;
}

export function useSubmit(onSave, build) {
  const [saving, setSaving] = useState(false);
  return [saving, async (event) => {
    event.preventDefault();
    setSaving(true);
    try { await onSave(build()); } finally { setSaving(false); }
  }];
}

// Giá trị form trong 1 state; bind/check trả props cho input text / checkbox
export function useFields(initial) {
  const [values, setValues] = useState(initial);
  const bind = (name) => ({ value: values[name] ?? "", onChange: (event) => setValues((current) => ({ ...current, [name]: event.target.value })) });
  const check = (name) => ({ checked: Boolean(values[name]), onChange: (event) => setValues((current) => ({ ...current, [name]: event.target.checked })) });
  return [values, bind, check, setValues];
}
