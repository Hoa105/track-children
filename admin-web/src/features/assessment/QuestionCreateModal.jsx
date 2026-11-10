import React, { useId, useState } from 'react';
import { Panel } from '../../shared/ui.jsx';
import { DOMAINS, OPTIONS } from './model.js';
import { ErrorBox, Modal } from './components.jsx';
import { MediaEditor } from './QuestionMedia.jsx';

export default function QuestionCreateModal({ rows, item, onClose, onSave }) {
  const formId = useId();
  const next = Math.max(0, ...rows.filter(row => !row.deletedAt).map(row => row.orderIndex)) + 1;
  const [code] = useState(() => `BLK-${item.ageMonths}-${crypto.randomUUID().slice(0, 8).toUpperCase()}`);
  const [domain, setDomain] = useState('');
  const [payload, setPayload] = useState({ question_vi: '', instruction_vi: '', safety_note: '', skill_name: '', not_yet_comment: '', not_observed_comment: '', observation_guide: '', tts_short_text: '', source_name: 'app_authored', source_pdf: '', source_version: '', source_page: '', source_excerpt: '', media: [] });
  const [sources, setSources] = useState([]);
  const [dirty, setDirty] = useState(false);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const change = (key, value) => { setPayload(current => ({ ...current, [key]: value })); setDirty(true); };
  const close = () => { if (!busy && (!dirty || window.confirm('Bỏ nội dung câu hỏi chưa lưu?'))) onClose(); };
  const field = (key, label, required = false, lines = 3) => <label key={key}>{label}{required && ' *'}<textarea rows={lines} required={required} minLength={key === 'question_vi' ? 10 : undefined} value={payload[key]} onChange={event => change(key, event.target.value)} /></label>;
  async function submit(event) {
    event.preventDefault(); if (busy) return; setError('');
    if (!domain) { setError('Chọn lĩnh vực phát triển.'); return; }
    if (payload.question_vi.trim().length < 10 || !payload.instruction_vi.trim()) { setError('Nhập câu hỏi từ 10 ký tự và hướng dẫn quan sát.'); return; }
    if (rows.some(row => row.stableCode === code)) { setError('Mã câu hỏi đã tồn tại. Đóng và mở lại form để tạo mã mới.'); return; }
    if (next > 1000) { setError('Bộ đã đạt giới hạn thứ tự câu hỏi.'); return; }
    if (sources.some(source => ![source.organization, source.document, source.url].some(value => value.trim()))) { setError('Mỗi nguồn cần có tổ chức, tài liệu hoặc liên kết. Điền thông tin hoặc bỏ nguồn trống.'); return; }
    setBusy(true);
    try {
      await onSave({ kind: 'skill', stableCode: code, appDomain: domain, sourceDomain: ['gross_motor', 'fine_motor'].includes(domain) ? 'movement_physical' : domain, orderIndex: next,
        payload: { ...Object.fromEntries(Object.entries(payload).map(([key, value]) => [key, typeof value === 'string' ? value.trim() : value])), answer_options: OPTIONS.map(option => ({ ...option })) },
        sourceRefs: sources.map(source => Object.fromEntries(Object.entries(source).map(([key, value]) => [key, value.trim()]))) });
    } catch (problem) { setError(problem.message); }
    finally { setBusy(false); }
  }
  return <Modal title="Thêm câu hỏi" eyebrow={`${item.ageMonths} THÁNG · ${item.version}`} wide className="question-create-dialog question-detail-workspace" onClose={close} footer={<>
    <p>Tạo ở trạng thái Nháp, chưa hiển thị trên app.</p>
    <button type="button" className="button secondary" disabled={busy} onClick={close}>Hủy</button>
    <button type="submit" form={formId} className="button primary" disabled={busy || next > 1000}>{busy ? 'Đang tạo…' : 'Tạo bản nháp'}</button>
  </>}>
    <form id={formId} onSubmit={submit}>
      <ErrorBox message={error} />
      <p className="question-create-help">* Bắt buộc để tạo nháp. Hoàn thiện nhận xét kỹ năng, văn bản đọc và ít nhất một nguồn tham khảo trước khi xuất bản. Ảnh/video không bắt buộc.</p>
      <fieldset disabled={busy} className="question-create-fields">
        <div className="question-edit-top">
          <div className="question-edit-column">
            <Panel title="Câu hỏi và hướng dẫn"><div className="edit-form question-edit-fields">
              <div className="question-create-identifiers"><label>MÃ CÂU HỎI<input readOnly value={code} /></label><label>THỨ TỰ<input readOnly value={next} /></label></div>
              <p className="question-field-hint">Mã tự tạo. Câu mới được thêm cuối bộ; có thể sắp xếp lại sau.</p>
              <label>LĨNH VỰC *<select required value={domain} onChange={event => { setDomain(event.target.value); setDirty(true); }}><option value="">Chọn lĩnh vực</option>{Object.entries(DOMAINS).map(([key, label]) => <option key={key} value={key}>{label}</option>)}</select></label>
              {field('question_vi', 'CÂU HỎI', true)}{field('instruction_vi', 'HƯỚNG DẪN QUAN SÁT', true, 4)}{field('safety_note', 'LƯU Ý AN TOÀN', false, 2)}
              <fieldset className="assessment-answer-options"><legend>BA PHƯƠNG ÁN CỐ ĐỊNH</legend>{OPTIONS.map(option => <label key={option.value}><input type="radio" disabled /><span>{option.label}</span></label>)}</fieldset>
            </div></Panel>
            <Panel title="Nhận xét kỹ năng" subtitle="Cần hoàn thiện trước khi xuất bản."><div className="edit-form question-edit-fields">
              {field('skill_name', 'TÊN KỸ NĂNG', false, 2)}{field('observation_guide', 'CÁCH QUAN SÁT KỸ NĂNG')}{field('not_yet_comment', 'NHẬN XÉT KHI CHƯA LÀM ĐƯỢC')}{field('not_observed_comment', 'NHẬN XÉT KHI CHƯA QUAN SÁT')}{field('tts_short_text', 'VĂN BẢN ĐỌC')}
            </div></Panel>
          </div>
          <div className="question-edit-column">
            <MediaEditor media={payload.media} onChange={value => change('media', value)} />
            <Panel title="Nguồn tham khảo" subtitle="Ít nhất một nguồn có tổ chức, tài liệu hoặc liên kết khi xuất bản."><div className="edit-form question-edit-fields">
              <label>NGUỒN NỘI DUNG<input readOnly value="Ứng dụng tự biên soạn" /></label>
              {[['source_pdf', 'TÀI LIỆU GỐC'], ['source_version', 'PHIÊN BẢN TÀI LIỆU'], ['source_page', 'TRANG']].map(([key, label]) => <label key={key}>{label}<input value={payload[key]} onChange={event => change(key, event.target.value)} /></label>)}
              {field('source_excerpt', 'TRÍCH ĐOẠN GỐC')}
            </div>
            <div className="question-source-heading"><h3>Các nguồn tham khảo</h3><button type="button" className="button secondary" onClick={() => { setSources(current => [...current, { organization: '', document: '', page: '', url: '' }]); setDirty(true); }}>Thêm nguồn</button></div>
            {!sources.length && <p className="panel-note">Chưa thêm nguồn. Có thể bổ sung khi chỉnh sửa bản nháp.</p>}
            <div className="question-source-list">{sources.map((source, index) => <div className="question-source-card" key={index}>
              <div className="question-source-card-heading"><b>Nguồn {index + 1}</b><button type="button" className="link-button danger" onClick={() => { setSources(current => current.filter((_, i) => i !== index)); setDirty(true); }}>Bỏ nguồn</button></div>
              <div className="edit-form question-edit-fields">{[['organization', 'TỔ CHỨC / TÁC GIẢ'], ['document', 'TÀI LIỆU / CĂN CỨ'], ['page', 'TRANG'], ['url', 'LIÊN KẾT']].map(([key, label]) => <label key={key}>{label}<input value={source[key]} onChange={event => { setSources(current => current.map((entry, i) => i === index ? { ...entry, [key]: event.target.value } : entry)); setDirty(true); }} /></label>)}</div>
            </div>)}</div></Panel>
          </div>
        </div>
      </fieldset>
    </form>
  </Modal>;
}
