import React, { useEffect, useState } from 'react';
import { useAuth } from '../../core/auth.jsx';
import { navigate } from '../../core/useHashRoute.js';
import { Badge, DataTable, Panel, stopRowClick } from '../../shared/ui.jsx';
import { REVIEW_TYPES, matches } from './model.js';
import { ErrorBox } from './components.jsx';
import * as api from './assessmentApi.js';

export default function ReviewPage() {
  const { admin } = useAuth();
  const [rows, setRows] = useState(null);
  const [sets, setSets] = useState([]);
  const [setId, setSetId] = useState('');
  const [q, setQ] = useState('');
  const [state, setState] = useState('pending');
  const [error, setError] = useState('');
  useEffect(() => {
    let cancelled = false;
    Promise.all([api.reviewQueue(admin), api.listQuestionSets(admin)]).then(([queue, questionSets]) => {
      if (!cancelled) { setRows(queue.filter(row => row.kind === 'skill')); setSets(questionSets); }
    }).catch(problem => !cancelled && setError(problem.message));
    return () => { cancelled = true; };
  }, [admin]);
  const ready = row => Object.keys(REVIEW_TYPES).every(type => row.reviews?.[type]?.decision === 'approved');
  const rejected = row => Object.values(row.reviews || {}).some(review => review.decision === 'rejected');
  const shown = (rows || []).filter(row => (!setId || row.questionSetId === setId) && matches(row, q) &&
    (state === 'all' || state === 'ready' && ready(row) || state === 'pending' && !ready(row) || state === 'rejected' && rejected(row)));
  function openQuestion(row) { navigate(`/assessment/question/${row.contentItemId}/review`); }
  return <>
    <ErrorBox message={error} />
    <div className="filter-bar"><div className="search-box"><input aria-label="Tìm câu cần duyệt" placeholder="Tìm mã hoặc nội dung câu hỏi…" value={q} onChange={event => setQ(event.target.value)} /></div>
      <select aria-label="Lọc bộ cần duyệt" value={setId} onChange={event => setSetId(event.target.value)}><option value="">Tất cả bộ câu hỏi</option>{sets.filter(set => !set.deletedAt).map(set => <option key={set.id} value={set.id}>{set.ageMonths} tháng · {set.code}</option>)}</select>
      <select aria-label="Lọc kiểm duyệt" value={state} onChange={event => setState(event.target.value)}><option value="pending">Chưa đủ 4 phê duyệt</option><option value="rejected">Có hạng mục bị từ chối</option><option value="ready">Đủ 4 phê duyệt</option><option value="all">Tất cả câu hỏi</option></select>
    </div>
    <Panel title="Kiểm duyệt & công bố" subtitle="Mở câu hỏi để xem nội dung, đáp án, media và ghi phê duyệt. Công bố cả bộ trong trang chi tiết bộ.">
      <DataTable rows={shown} rowKey="contentItemId" paginate empty={rows === null ? 'Đang tải danh sách kiểm duyệt…' : 'Không có câu phù hợp bộ lọc'} onRowClick={openQuestion} columns={[
        { key: 'question', label: 'CÂU HỎI', wrap: true, render: row => <div className="stack"><b>{row.payload?.question_vi || row.payload?.prompt || 'Chưa nhập câu hỏi'}</b><small>{row.stableCode} · Bản {row.revision}</small></div> },
        { key: 'set', label: 'BỘ CÂU HỎI', render: row => { const set = sets.find(item => item.id === row.questionSetId); return set ? `${set.ageMonths} tháng · ${set.version}` : 'Không tìm thấy bộ'; } },
        { key: 'reviews', label: 'KIỂM DUYỆT', render: row => <div className="chip-row">{Object.entries(REVIEW_TYPES).map(([type, label]) => <Badge key={type} tone={row.reviews?.[type]?.decision === 'approved' ? 'green' : row.reviews?.[type]?.decision === 'rejected' ? 'red' : 'orange'}>{label}: {row.reviews?.[type]?.decision === 'approved' ? 'Đã duyệt' : row.reviews?.[type]?.decision === 'rejected' ? 'Từ chối' : 'Chưa duyệt'}</Badge>)}</div> },
        { key: 'actions', label: 'THAO TÁC', render: row => <div className="row-actions" onClick={stopRowClick}><button className="link-button" onClick={() => openQuestion(row)}>Xem và duyệt câu</button><button className="link-button" onClick={() => navigate(`/assessment/set/${row.questionSetId}/review`)}>Công bố bộ</button></div> },
      ]} />
    </Panel>
  </>;
}
