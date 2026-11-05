import React, { useEffect, useState } from 'react';
import { useAuth } from '../../core/auth.jsx';
import { navigate } from '../../core/useHashRoute.js';
import { Badge, DataTable, Panel, stopRowClick } from '../../shared/ui.jsx';
import { AGES, questionSetState, QUESTION_SET_STATES } from './model.js';
import { ErrorBox, Modal, TransferTools } from './components.jsx';
import * as api from './developmentApi.js';
import QuestionSetEditModal from './QuestionSetEditModal.jsx';

export default function QuestionSetList({ onNotify }) {
  const { admin } = useAuth();
  const [rows, setRows] = useState(null);
  const [error, setError] = useState('');
  const [age, setAge] = useState('');
  const [status, setStatus] = useState('all');
  const [creating, setCreating] = useState(false);
  const [editing, setEditing] = useState(null);
  const [pending, setPending] = useState(null);
  async function load() {
    try { setRows(await api.listQuestionSets(admin)); setError(''); }
    catch (problem) { setError(problem.message); }
  }
  useEffect(() => { load(); }, []);
  const shown = (rows || []).filter(row => (!age || row.ageMonths === Number(age)) && (status === 'all' || questionSetState(row) === status))
    .sort((a, b) => a.ageMonths - b.ageMonths || a.sourceName.localeCompare(b.sourceName, 'vi') || a.version.localeCompare(b.version, 'vi', { numeric: true }));
  const open = row => navigate(`/development/set/${row.id}`);
  async function toggle(row) {
    const hide = questionSetState(row) === 'published';
    if (!window.confirm(`${hide ? 'Ẩn' : 'Xuất bản'} bộ ${row.ageMonths} tháng? Chỉ áp dụng cho bài đánh giá mới.`)) return;
    setPending(row.id); setError('');
    try {
      if (hide) await api.lifecycle(admin, 'question-sets', row.id, 'availability', false);
      else await api.releaseQuestionSet(admin, row.id);
      await load();
      onNotify?.(hide ? 'Đã ẩn bộ khỏi app' : 'Đã xuất bản bộ lên app');
    } catch (problem) { setError(problem.message); }
    finally { setPending(null); }
  }
  async function remove(row) {
    if (!window.confirm(`Xóa bộ ${row.ageMonths} tháng (${row.version})? Bộ sẽ ngừng hiển thị trên app; lịch sử được giữ nguyên và có thể khôi phục.`)) return;
    setPending(row.id); setError('');
    try {
      await api.lifecycle(admin, 'question-sets', row.id, 'delete');
      await load(); onNotify?.('Đã xóa bộ câu hỏi');
    } catch (problem) { setError(problem.message); }
    finally { setPending(null); }
  }
  return <section className="question-set-list">
    <ErrorBox message={error} />
    <div className="question-set-list-toolbar"><div className="filter-bar">
      <label className="question-set-age-filter">Mốc tuổi<select aria-label="Lọc mốc tuổi" value={age} onChange={event => setAge(event.target.value)}><option value="">Tất cả</option>{AGES.map(months => <option key={months} value={months}>{months} tháng</option>)}</select></label>
      <label className="question-set-age-filter">Trạng thái<select aria-label="Lọc trạng thái bộ" value={status} onChange={event => setStatus(event.target.value)}><option value="all">Tất cả</option><option value="hidden">Ẩn</option><option value="published">Xuất bản</option><option value="deleted">Đã xóa</option><option value="draft">Nháp</option></select></label>
    </div></div>
    <Panel className="question-set-table" title="Danh sách bộ câu hỏi" subtitle={rows === null ? 'Đang tải…' : `${shown.length} bộ`} action={<div className="question-set-header-actions"><TransferTools admin={admin} kind="skill" filteredSetIds={shown.filter(row => !row.deletedAt).map(row => row.id)} onChanged={load} /><button className="button primary" onClick={() => setCreating(true)}>Thêm bộ</button></div>}>
      <DataTable rows={shown} rowKey="id" paginate empty={rows === null ? error ? 'Không tải được danh sách' : 'Đang tải…' : 'Không có bộ phù hợp bộ lọc'} onRowClick={open} columns={[
        { key: 'name', label: 'BỘ CÂU HỎI', render: row => <div className="stack"><button className="link-button question-set-name" onClick={event => { event.stopPropagation(); open(row); }} aria-label={`Mở bộ ${row.ageMonths} tháng`}>{row.ageMonths} tháng</button><small>{row.sourceName || 'Chưa có nguồn nội dung'}</small></div> },
        { key: 'version', label: 'PHIÊN BẢN', render: row => row.version },
        { key: 'count', label: 'SỐ CÂU', render: row => row.contentCount },
        { key: 'status', label: 'TRẠNG THÁI', render: row => { const [label, tone] = QUESTION_SET_STATES[questionSetState(row)]; return <Badge tone={tone}>{label}</Badge>; } },
        { key: 'updated', label: 'NGÀY CẬP NHẬT', render: row => row.updatedAt ? <time dateTime={row.updatedAt} title={new Date(row.updatedAt).toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' })}>{new Date(row.updatedAt).toLocaleDateString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' })}</time> : '—' },
        { key: 'actions', label: 'THAO TÁC', render: row => <div className="question-set-list-actions" onClick={stopRowClick}>
          {!row.deletedAt && <button className="link-button" disabled={pending !== null} onClick={() => setEditing(row)}>Sửa</button>}
          {row.deletedAt ? '—' : <button className={questionSetState(row) === 'published' ? 'link-button danger' : 'link-button'} disabled={pending !== null} onClick={() => toggle(row)}>{pending === row.id ? 'Đang xử lý…' : questionSetState(row) === 'published' ? 'Ẩn' : 'xuất bản'}</button>}
          {!row.deletedAt && <button className="link-button danger" disabled={pending !== null} onClick={() => remove(row)}>Xóa</button>}
        </div> },
      ]} />
      {error && rows === null && <button className="button secondary" onClick={load}>Tải lại</button>}
    </Panel>
    {creating && <CreateSet existing={rows || []} onClose={() => setCreating(false)} onSave={async body => { const row = await api.createQuestionSet(admin, body); setCreating(false); onNotify?.('Đã tạo bộ nháp. Thêm câu hỏi trong trang chi tiết.'); open(row); }} />}
    {editing && <QuestionSetEditModal item={editing} onClose={() => setEditing(null)} onSave={async body => {
      await api.updateQuestionSet(admin, editing.id, body);
      setEditing(null); await load(); onNotify?.('Đã lưu thông tin bộ');
    }} />}
  </section>;
}
function CreateSet({ existing, onClose, onSave }) {
  const [age, setAge] = useState(12);
  const [source, setSource] = useState('Bé lớn khôn');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  return <Modal title="Thêm bộ câu hỏi" onClose={() => !busy && onClose()}><form onSubmit={async event => {
    event.preventDefault(); setBusy(true);
    let number = 1;
    while (existing.some(row => row.ageMonths === age && row.locale === 'vi-VN' && row.version === `v${number}`)) number++;
    try { await onSave({ ageMonths: age, sourceName: source.trim(), version: `v${number}`, locale: 'vi-VN', code: `blk-${age}m-${crypto.randomUUID().slice(0, 8)}` }); }
    catch (problem) { setError(problem.message); }
    finally { setBusy(false); }
  }}><ErrorBox message={error} /><div className="edit-form"><label>MỐC TUỔI<select value={age} onChange={event => setAge(Number(event.target.value))}>{AGES.map(months => <option key={months} value={months}>{months} tháng</option>)}</select></label><label>NGUỒN NỘI DUNG<input required maxLength={200} value={source} onChange={event => setSource(event.target.value)} /></label></div><p className="panel-note">Bộ mới ở trạng thái Nháp. Thêm câu hỏi và hoàn thiện nội dung trước khi xuất bản.</p><div className="modal-actions"><button type="button" className="button secondary" disabled={busy} onClick={onClose}>Hủy</button><button className="button primary" disabled={busy}>{busy ? 'Đang tạo…' : 'Tạo bộ'}</button></div></form></Modal>;
}



