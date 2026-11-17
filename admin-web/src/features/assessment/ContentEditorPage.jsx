import React, { useEffect, useState } from 'react';
import { useAuth } from '../../core/auth.jsx';
import { navigate } from '../../core/useHashRoute.js';
import { PageHeading, Panel, Tabs } from '../../shared/ui.jsx';
import { DOMAINS, OPTIONS, VARIANT_LABELS, editorPayload, questionVersion, updatedDate } from './model.js';
import { AuditPanel, Availability, ErrorBox, QuestionActions, SpeakButton } from './components.jsx';
import { MediaEditor, QuestionPreview, mediaEntries } from './QuestionMedia.jsx';
import * as api from './assessmentApi.js';

export default function ContentEditorPage({ contentId, onNotify, initialTab = 'detail' }) {
  const { admin } = useAuth();
  const [item, setItem] = useState(null);
  const [draft, setDraft] = useState({});
  const [sources, setSources] = useState([]);
  const [domain, setDomain] = useState('');
  const [dirty, setDirty] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [conflict, setConflict] = useState(false);
  const [tab, setTab] = useState(initialTab);

  async function load() {
    try {
      const row = await api.getContent(admin, contentId);
      setItem(row);
      const payload = editorPayload(row.payload, row.kind);
      if (row.kind === 'skill') payload.media = mediaEntries(payload);
      setDraft(payload);
      setDomain(row.appDomain || '');
      setSources(structuredClone(row.sourceRefs || []));
      setDirty(false);
      setError('');
      setConflict(false);
    } catch (problem) { setError(problem.message); }
  }
  useEffect(() => { load(); }, [contentId]);
  useEffect(() => {
    if (!dirty) return;
    const unload = event => { event.preventDefault(); event.returnValue = ''; };
    const leave = event => { if (!window.confirm('Có thay đổi chưa lưu. Rời trang và bỏ thay đổi?')) event.preventDefault(); };
    window.addEventListener('beforeunload', unload);
    window.addEventListener('admin:navigate', leave);
    return () => { window.removeEventListener('beforeunload', unload); window.removeEventListener('admin:navigate', leave); };
  }, [dirty]);

  function change(key, value) { setDraft(current => ({ ...current, [key]: value })); setDirty(true); }
  async function save() {
    setBusy(true); setError('');
    try {
      if (item.kind === 'advice') {
        for (const [key, label] of [['title','tiêu đề'], ['body_text','nội dung'], ['tts_text','văn bản đọc'], ['cta_label','nhãn nút hành động']]) {
          if (!String(draft[key] || '').trim()) throw new Error(`Nhập ${label} của mẫu lời khuyên.`);
        }
      }
      await api.createRevision(admin, item.id, {
        expectedRevision: item.currentRevision, payload: draft, sourceRefs: sources,
        ...(item.kind === 'skill' && { appDomain: domain }),
      });
      await load();
      onNotify('Đã lưu bản nháp mới');
    } catch (problem) { setError(problem.message); setConflict(problem.status === 409); }
    finally { setBusy(false); }
  }

  if (!item) return <div className="panel empty-state"><h2>{error ? 'Không tải được câu hỏi' : 'Đang tải câu hỏi…'}</h2><ErrorBox message={error} /><button className="link-button" onClick={() => navigate('/assessment')}>Về bộ câu hỏi</button></div>;
  const advice = item.kind === 'advice';
  const back = advice ? '/assessment/advice' : `/assessment/set/${item.questionSetId}`;
  const title = advice ? VARIANT_LABELS[item.stableCode] || 'Mẫu lời khuyên phát triển' : `Câu hỏi ${item.orderIndex ?? ''}`;
  const textField = (key, label, rows = 3) => <label className={`question-field question-field-${key}`} key={key}>{label}<textarea rows={rows} value={draft[key] || ''} onChange={event => change(key, event.target.value)} /></label>;

  return <div className="assessment-detail-page question-detail-workspace">
    <button className="breadcrumb-link detail-back" onClick={() => navigate(back)}>&lt; {advice ? 'Danh sách mẫu lời khuyên' : 'Danh sách câu hỏi trong bộ'}</button>
    <PageHeading title={title}>
      <QuestionActions buttons admin={admin} item={item} allowDelete={!advice} onChanged={load} onError={setError} disabled={dirty || busy} />
    </PageHeading>
    <ErrorBox message={error} />
    {conflict && <button className="button secondary" onClick={() => { if (window.confirm('Tải bản mới và bỏ thay đổi chưa lưu?')) load(); }}>Tải lại bản mới</button>}
    {dirty && <p className="auth-hint">Có thay đổi chưa lưu. Lưu hoặc hủy thay đổi trước khi đổi trạng thái.</p>}
    <Tabs active={tab} onChange={setTab} tabs={[
      { id: 'detail', label: advice ? 'Chi tiết mẫu lời khuyên' : 'Chi tiết câu hỏi' },
      { id: 'edit', label: dirty ? 'Chỉnh sửa · Chưa lưu' : 'Chỉnh sửa' },
      { id: 'history', label: 'Lịch sử' },
    ]} />

    {tab === 'detail' && <div className="detail-grid content-grid">
      {advice ? <Panel title={draft.title || 'Chưa nhập tiêu đề'}><p className="assessment-prose">{draft.body_text || 'Chưa nhập nội dung.'}</p><dl className="assessment-info"><dt>Nút trên app</dt><dd>{draft.cta_label || 'Chưa nhập nhãn nút'}</dd></dl><div className="panel-gap" /><SpeakButton text={draft.tts_text} /></Panel> : <QuestionPreview payload={draft} />}
      <div><Panel title={advice ? "Thông tin mẫu lời khuyên" : "Thông tin câu hỏi"} action={<button className="link-button" onClick={() => setTab('edit')}>Chỉnh sửa nội dung</button>}>
        <dl className="assessment-info"><dt>Mã</dt><dd>{item.stableCode}</dd><dt>{advice ? 'Áp dụng khi' : 'Lĩnh vực'}</dt><dd>{advice ? VARIANT_LABELS[item.stableCode] : DOMAINS[item.appDomain] || 'Chưa chọn'}</dd><dt>Trạng thái</dt><dd><Availability row={item} /></dd><dt>Phiên bản</dt><dd>{questionVersion(item)}</dd><dt>Ngày cập nhật</dt><dd>{updatedDate(item.updatedAt)}</dd><dt>Nguồn nội dung</dt><dd>{draft.source_name === 'app_authored' ? 'Ứng dụng tự biên soạn' : draft.source_name || sources[0]?.organization || 'Chưa có nguồn nội dung'}</dd></dl>
      </Panel><div className="panel-gap" />{!advice && <Panel title="Nhận xét kỹ năng">{[
        ['skill_name', 'Kỹ năng'], ['not_yet_comment', 'Chưa làm được'], ['not_observed_comment', 'Chưa quan sát'], ['observation_guide', 'Cách quan sát'],
      ].map(([key, label]) => <div className="assessment-note" key={key}><b>{label}</b><p>{draft[key] || 'Chưa biên soạn.'}</p></div>)}</Panel>}</div>
    </div>}

    {tab === 'edit' && <section className="question-edit-layout" aria-label={advice ? 'Chỉnh sửa mẫu lời khuyên' : 'Chỉnh sửa câu hỏi'}>
      <div className="question-edit-top">
        <div className="question-edit-column">
        <Panel title={advice ? 'Biên tập mẫu lời khuyên' : 'Câu hỏi và hướng dẫn'} subtitle="Lưu tạo bản nháp mới. Nội dung trên app giữ nguyên cho đến khi xuất bản.">
          <div className="edit-form question-edit-fields">
            {advice ? <>{textField('title', 'TIÊU ĐỀ', 2)}{textField('body_text', 'NỘI DUNG HÀNH ĐỘNG CHÍNH', 5)}{textField('tts_text', 'VĂN BẢN ĐỌC', 3)}{textField('cta_label', 'NHÃN NÚT HÀNH ĐỘNG', 1)}{item.stableCode.startsWith('CONTACT_') && <>{textField('preparation_text', 'THÔNG TIN CẦN GHI LẠI CHO TÌNH HUỐNG NÀY', 3)}{textField('preparation_common', 'THÔNG TIN CHUNG CẦN MANG THEO', 2)}<p className="panel-note">Khi có nhiều tín hiệu cùng lúc, hệ thống lấy phần chuẩn bị của từng tín hiệu và chỉ hiển thị thông tin chung một lần.</p></>}<p className="panel-note">Điều kiện áp dụng và hành động trên app được cố định.</p></> : <>
              <label>LĨNH VỰC<select disabled={item.publishedRevision != null} value={domain} onChange={event => { setDomain(event.target.value); setDirty(true); }}><option value="">Chọn lĩnh vực</option>{Object.entries(DOMAINS).map(([key, label]) => <option key={key} value={key}>{label}</option>)}</select>{item.publishedRevision != null && <small className="question-field-hint">Lĩnh vực được cố định sau lần xuất bản đầu tiên.</small>}</label>
              {textField('question_vi', 'CÂU HỎI', 3)}{textField('instruction_vi', 'HƯỚNG DẪN QUAN SÁT', 4)}{textField('safety_note', 'LƯU Ý AN TOÀN', 2)}
              <fieldset className="assessment-answer-options"><legend>BA PHƯƠNG ÁN CỐ ĐỊNH</legend>{OPTIONS.map(option => <label key={option.value}><input type="radio" disabled /><span>{option.label}</span></label>)}</fieldset>
            </>}
          </div>
        </Panel>
      {!advice && <Panel title="Nhận xét kỹ năng" subtitle="Nội dung giải thích kết quả và hỗ trợ phụ huynh quan sát.">
        <div className="edit-form question-edit-fields question-edit-columns">{[
          ['skill_name', 'TÊN KỸ NĂNG'], ['observation_guide', 'CÁCH QUAN SÁT KỸ NĂNG'],
          ['not_yet_comment', 'NHẬN XÉT KHI CHƯA LÀM ĐƯỢC'], ['not_observed_comment', 'NHẬN XÉT KHI CHƯA QUAN SÁT'],
          ['tts_short_text', 'VĂN BẢN ĐỌC'],
        ].map(([key, label]) => textField(key, label))}</div>
        <div className="question-section-actions"><SpeakButton text={draft.tts_short_text} /></div>
      </Panel>}
        </div>
        <div className="question-edit-column">
        {!advice && <MediaEditor media={draft.media || []} onChange={value => change('media', value)} />}
      <Panel title="Nguồn tham khảo" subtitle="Ghi rõ tài liệu và căn cứ của nội dung.">
        {!advice && <div className="edit-form question-edit-fields question-edit-columns question-source-metadata">{[
          ['source_name', 'NGUỒN NỘI DUNG'], ['source_pdf', 'TÀI LIỆU'], ['source_version', 'PHIÊN BẢN TÀI LIỆU'], ['source_page', 'TRANG'],
        ].map(([key, label]) => <label key={key}>{label}<input value={draft[key] || ''} onChange={event => change(key, event.target.value)} /></label>)}{textField('source_excerpt', 'TRÍCH ĐOẠN GỐC', 3)}</div>}
        <div className="question-source-heading"><h3>Nguồn bổ sung</h3><button type="button" className="button secondary" onClick={() => { setSources(current => [...current, { organization: '', document: '', url: '' }]); setDirty(true); }}>Thêm nguồn</button></div>
        {sources.length === 0 && <p className="panel-note">Chưa có nguồn bổ sung.</p>}
        <div className="question-source-list">{sources.map((source, index) => <div className="question-source-card" key={index}>
          <div className="question-source-card-heading"><b>Nguồn {index + 1}</b><button type="button" className="link-button danger" aria-label={`Bỏ nguồn ${index + 1}`} onClick={() => { setSources(current => current.filter((_, i) => i !== index)); setDirty(true); }}>Bỏ nguồn</button></div>
          <div className="edit-form question-edit-fields question-edit-columns">{[['organization', 'TỔ CHỨC / NGƯỜI XÁC NHẬN'], ['document', 'TÀI LIỆU / CĂN CỨ'], ['page', 'TRANG'], ['url', 'LIÊN KẾT']].map(([key, label]) => <label key={key}>{label}<input value={source[key] || ''} onChange={event => { setSources(current => current.map((entry, i) => i === index ? { ...entry, [key]: event.target.value } : entry)); setDirty(true); }} /></label>)}</div>
        </div>)}</div>
      </Panel>
        </div>
      </div>
      <div className="question-edit-footer"><p>{dirty ? 'Có thay đổi chưa lưu' : 'Không có thay đổi chưa lưu'}</p><div className="question-edit-footer-actions">
        <button type="button" className="button secondary" disabled={!dirty || busy} onClick={() => { if (window.confirm('Bỏ thay đổi chưa lưu?')) load(); }}>Hủy thay đổi</button>
        <button type="button" className="button primary" disabled={!dirty || busy || !!item.deletedAt} onClick={save}>{busy ? 'Đang lưu…' : 'Lưu bản nháp'}</button>
      </div></div>
    </section>}

    {tab === 'history' && <AuditPanel admin={admin} id={item.id} refresh={item.currentRevision} fullDetails title="Lịch sử thay đổi" />}
  </div>;
}
