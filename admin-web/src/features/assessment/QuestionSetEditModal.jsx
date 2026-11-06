import React, { useId, useState } from 'react';
import { AGES } from './model.js';
import { ErrorBox, Modal } from './components.jsx';

export default function QuestionSetEditModal({ item, onClose, onSave }) {
  const formId = useId();
  const [sourceName, setSourceName] = useState(item.sourceName || '');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const close = () => !busy && onClose();
  return <Modal title="Sửa thông tin bộ" className="question-set-edit-dialog" onClose={close} footer={<>
    <button type="button" className="button secondary" disabled={busy} onClick={close}>Hủy</button>
    <button type="submit" form={formId} className="button primary" disabled={busy}>{busy ? 'Đang lưu…' : 'Lưu thay đổi'}</button>
  </>}>
    <form id={formId} onSubmit={async event => {
      event.preventDefault(); setBusy(true); setError('');
      try { await onSave({ sourceName: sourceName.trim() }); }
      catch (problem) { setError(problem.message); }
      finally { setBusy(false); }
    }}>
      <ErrorBox message={error} />
      <div className="edit-form">
        <label>MỐC TUỔI<select value={item.ageMonths} disabled>{AGES.map(age => <option key={age} value={age}>{age} tháng</option>)}</select></label>
        <label>MÃ BỘ<input value={item.code} disabled /></label>
        <label>PHIÊN BẢN<input value={item.version} disabled /></label>
        <label>NGUỒN NỘI DUNG<input required maxLength={200} value={sourceName} disabled={busy} onChange={event => setSourceName(event.target.value)} /></label>
      </div>
    </form>
  </Modal>;
}
