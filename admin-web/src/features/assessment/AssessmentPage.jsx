import React, { useEffect, useState } from 'react';
import { useAuth } from '../../core/auth.jsx';
import { navigate } from '../../core/useHashRoute.js';
import Icon from '../../shared/Icon.jsx';
import { DataTable, PageHeading, Panel, Tabs, stopRowClick } from '../../shared/ui.jsx';
import { DOMAINS, assessmentRoute, matches, questionState, questionVersion, updatedDate, QUESTION_STATES, questionSetState, QUESTION_SET_STATES } from './model.js';
import { AuditPanel, Availability, ErrorBox, QuestionActions } from './components.jsx';
import { mediaEntries } from './QuestionMedia.jsx';
import ContentEditorPage from './ContentEditorPage.jsx';
import AdvicePage, { AdviceWorkspace } from './AdvicePage.jsx';
import QuestionSetList from './QuestionSetList.jsx';
import QuestionSetEditModal from './QuestionSetEditModal.jsx';
import QuestionCreateModal from './QuestionCreateModal.jsx';
import * as api from './assessmentApi.js';

export default function AssessmentPage({ id, onNotify }) {
  const route = assessmentRoute(id);
  if (route.page === 'advice') return <AdvicePage id={route.id} onNotify={onNotify} />;
  if (route.page === 'question') return <ContentEditorPage contentId={route.id} initialTab={route.tab} onNotify={onNotify} />;
  if (route.page === 'set') return <SetDetail setId={route.id} initialTab={route.tab} onNotify={onNotify} />;
  if (route.page === 'hub') return <QuestionSetsHub initialTab={route.tab} onNotify={onNotify} />;
  return <div className="panel empty-state"><h2>Không tìm thấy trang câu hỏi</h2><button className="link-button" onClick={() => navigate('/assessment')}>Về danh sách bộ câu hỏi</button></div>;
}

function QuestionSetsHub({ initialTab, onNotify }) {
  return <div className="assessment-workspace">
    <PageHeading eyebrow="NỘI DUNG CHUYÊN MÔN" title="Bộ câu hỏi & Lời khuyên" subtitle="Quản lý câu hỏi theo tuổi, mẫu lời khuyên và trạng thái hiển thị trên app." />
    <Tabs active={initialTab} onChange={tab => navigate(tab === 'advice' ? '/assessment/advice' : '/assessment')} tabs={[{ id: 'sets', label: 'Bộ câu hỏi' }, { id: 'advice', label: 'Lời khuyên' }]} />
    {initialTab === 'advice' ? <AdviceWorkspace /> : <QuestionSetList onNotify={onNotify} />}
  </div>;
}

function SetDetail({ setId, initialTab, onNotify }) {
  const { admin } = useAuth();
  const [item, setItem] = useState(null);
  const [rows, setRows] = useState([]);
  const [error, setError] = useState('');
  const [q, setQ] = useState('');
  const [domain, setDomain] = useState('');
  const [state, setState] = useState('all');
  const [media, setMedia] = useState('');
  const [creating, setCreating] = useState(false);
  const [busy, setBusy] = useState(false);
  const [sorting, setSorting] = useState(false);
  const [tab, setTab] = useState(initialTab === 'history' ? 'history' : 'questions');

  const [editingSet, setEditingSet] = useState(initialTab === 'edit');

  async function load() {
    try {
      const [nextSet, content] = await Promise.all([api.getSet(admin, setId), api.listContent(admin, setId)]);
      setItem(nextSet); setRows(content); setError('');
    } catch (problem) { setError(problem.message); }
  }
  useEffect(() => { load(); }, [setId]);
  async function move(row, offset) {
    const ordered = rows.filter(entry => !entry.deletedAt);
    const index = ordered.findIndex(entry => entry.id === row.id);
    if (index + offset < 0 || index + offset >= ordered.length) return;
    [ordered[index], ordered[index + offset]] = [ordered[index + offset], ordered[index]];
    setBusy(true);
    try { await api.reorder(admin, setId, ordered.map(entry => entry.id)); await load(); }
    catch (problem) { setError(problem.message); }
    finally { setBusy(false); }
  }
  if (!item) return <div className="panel empty-state"><h2>{error ? 'Không tải được bộ câu hỏi' : 'Đang tải bộ câu hỏi…'}</h2><ErrorBox message={error} /><button className="link-button" onClick={() => navigate('/assessment')}>Về danh sách bộ</button></div>;
  const shown = sorting ? rows.filter(row => !row.deletedAt) : rows.filter(row => matches(row, q) && (!domain || row.appDomain === domain) &&
    (state === 'all' || questionState(row) === state) &&
    (!media || media === 'none' && mediaEntries(row.payload).length === 0 || mediaEntries(row.payload).some(entry => entry.type === media)));
  const ordered = rows.filter(row => !row.deletedAt);
  const openQuestion = row => navigate(`/assessment/question/${row.id}`);

  return <div className="assessment-detail-page question-set-detail-workspace">
    <button className="breadcrumb-link detail-back" onClick={() => navigate('/assessment')}>&lt; Danh sách bộ câu hỏi</button>
    <PageHeading eyebrow="BỘ CÂU HỎI" title={`${item.ageMonths} tháng`} subtitle={`${item.version} · ${item.sourceName || 'Chưa có nguồn nội dung'} · ${ordered.length} câu hỏi`} children={<><Availability row={item} /><button className="button secondary" disabled={!!item.deletedAt} onClick={() => setEditingSet(true)}>Sửa thông tin</button><button className="button primary" disabled={!!item.deletedAt} onClick={() => setCreating(true)}>Thêm câu hỏi</button></>} />
    <div className="detail-alert info">{QUESTION_SET_STATES[questionSetState(item)][0]}. {questionSetState(item) === 'published' ? 'Bộ được dùng cho các bài đánh giá mới.' : 'Bộ chưa được dùng cho các bài đánh giá mới.'}</div>
    <ErrorBox message={error} />
    <Tabs active={tab} onChange={setTab} tabs={[{ id: 'questions', label: 'Câu hỏi', count: ordered.length }, { id: 'history', label: 'Lịch sử' }]} />
    {tab === 'questions' && <>
      <div className={`filter-bar ${sorting ? 'question-sorting-filters' : ''}`} inert={sorting ? '' : undefined}><div className="search-box"><Icon name="search" size={15} /><input aria-label="Tìm câu hỏi" placeholder="Tìm mã hoặc nội dung câu hỏi…" value={q} onChange={event => setQ(event.target.value)} /></div><select aria-label="Lọc lĩnh vực" value={domain} onChange={event => setDomain(event.target.value)}><option value="">Tất cả lĩnh vực</option>{Object.entries(DOMAINS).map(([key, label]) => <option key={key} value={key}>{label}</option>)}</select><select aria-label="Lọc trạng thái câu" value={state} onChange={event => setState(event.target.value)}><option value="all">Tất cả trạng thái</option>{Object.entries(QUESTION_STATES).map(([key, [label]]) => <option key={key} value={key}>{label}</option>)}</select><select aria-label="Lọc media" value={media} onChange={event => setMedia(event.target.value)}><option value="">Mọi ảnh / video</option><option value="image">Có ảnh</option><option value="youtube">Có video</option><option value="none">Chỉ văn bản</option></select></div>
      <Panel className="question-content-table" title="Câu hỏi trong bộ" subtitle={sorting ? 'Thứ tự được lưu ngay sau mỗi lần di chuyển. Hiển thị tất cả câu chưa xóa.' : 'Chọn câu hỏi để xem nội dung, đáp án và ảnh/video hướng dẫn.'} action={<button className="button secondary" disabled={busy || !!item.deletedAt} onClick={() => setSorting(!sorting)}>{sorting ? 'Xong' : 'Sắp xếp câu hỏi'}</button>}>

        <DataTable rowKey="id" rows={shown} paginate empty="Không có câu phù hợp bộ lọc" onRowClick={openQuestion} columns={[
          { key: 'question', label: 'CÂU HỎI', wrap: true, render: row => <div className="stack"><b>{row.orderIndex}. {row.payload.question_vi || row.payload.prompt || 'Chưa nhập câu hỏi'}</b><small>{mediaEntries(row.payload).length ? mediaEntries(row.payload).map(entry => entry.type === 'youtube' ? 'Video' : 'Ảnh').join(' · ') : 'Chỉ văn bản'}</small></div> },
          { key: 'domain', label: 'LĨNH VỰC', render: row => DOMAINS[row.appDomain] || 'Chưa chọn lĩnh vực' },
          { key: 'version', label: 'PHIÊN BẢN', render: row => questionVersion(row) },
          { key: 'state', label: 'TRẠNG THÁI', render: row => <Availability row={row} /> },
          { key: 'updated', label: 'NGÀY CẬP NHẬT', render: row => updatedDate(row.updatedAt) },
          { key: 'actions', label: sorting ? 'SẮP XẾP' : 'THAO TÁC', render: row => <div className="assessment-row-controls" onClick={stopRowClick}>{sorting ? <div className="row-actions"><button className="link-button" disabled={busy || row.id === ordered[0]?.id} onClick={() => move(row, -1)} aria-label={`Đưa ${row.stableCode} lên`}>↑ Lên</button><button className="link-button" disabled={busy || row.id === ordered.at(-1)?.id} onClick={() => move(row, 1)} aria-label={`Đưa ${row.stableCode} xuống`}>↓ Xuống</button></div> : <div className="row-actions"><button className="link-button" disabled={!!row.deletedAt || !!item.deletedAt} onClick={() => navigate(`/assessment/question/${row.id}`)}>Chi tiết</button><button className="link-button" disabled={!!row.deletedAt || !!item.deletedAt} onClick={() => navigate(`/assessment/question/${row.id}/edit`)}>Sửa</button><QuestionActions admin={admin} item={row} onChanged={load} onError={setError} disabled={!!item.deletedAt} /></div>}</div> },
        ]} />
      </Panel>
    </>}
    {tab === 'history' && <AuditPanel admin={admin} id={setId} fullDetails title="Lịch sử thay đổi" />}
    {editingSet && <QuestionSetEditModal item={item} onClose={() => setEditingSet(false)} onSave={async body => { await api.updateQuestionSet(admin, setId, { sourceName: body.sourceName }); setEditingSet(false); await load(); onNotify('Đã lưu thông tin bộ'); }} />}
    {creating && <QuestionCreateModal rows={rows} item={item} onClose={() => setCreating(false)} onSave={async body => { const row = await api.createContent(admin, setId, body); setCreating(false); navigate(`/assessment/question/${row.id}/edit`); }} />}
  </div>;
}
