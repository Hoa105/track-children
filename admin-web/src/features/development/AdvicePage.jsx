import React,{useEffect,useState} from 'react';
import {useAuth} from '../../core/auth.jsx';
import {navigate} from '../../core/useHashRoute.js';
import Icon from '../../shared/Icon.jsx';
import {DataTable,Panel,stopRowClick} from '../../shared/ui.jsx';
import {OPTIONS,VARIANT_LABELS,matches,questionState,questionVersion,updatedDate,QUESTION_STATES} from './model.js';
import {Availability,ErrorBox,QuestionActions,Modal,SpeakButton} from './components.jsx';
import ContentEditorPage from './ContentEditorPage.jsx';
import * as api from './developmentApi.js';
export default function AdvicePage({id,onNotify}){
 if(id){const [contentId,tab]=id.split('/');return <ContentEditorPage contentId={contentId} initialTab={['edit','history'].includes(tab)?tab:'detail'} onNotify={onNotify}/>;}
 return <AdviceList/>;
}
export function AdviceList(){
 const {admin}=useAuth();const [rows,setRows]=useState(null),[q,setQ]=useState(''),[state,setState]=useState('all'),[error,setError]=useState(''),[preview,setPreview]=useState(false);
 async function load(){try{setRows(await api.listAdvice(admin));setError('');}catch(e){setError(e.message);}}
 useEffect(()=>{load();},[]);
 const visible=(rows??[]).filter(row=>matches(row,q)&&(state==='all'||questionState(row)===state));
 const open=row=>navigate(`/development/advice/${row.id}`);
 return <div className="development-workspace advice-workspace">
  <ErrorBox message={error}/>
  <div className="question-set-list-toolbar"><div className="filter-bar">
   <div className="search-box"><Icon name="search" size={15}/><input placeholder="Tìm tiêu đề hoặc nội dung…" aria-label="Tìm mẫu lời khuyên" value={q} onChange={event=>setQ(event.target.value)}/></div>
   <label className="question-set-age-filter">Trạng thái<select aria-label="Lọc trạng thái mẫu lời khuyên" value={state} onChange={event=>setState(event.target.value)}><option value="all">Tất cả</option>{Object.entries(QUESTION_STATES).map(([key,[label]])=><option key={key} value={key}>{label}</option>)}</select></label>
  </div></div>
  <Panel className="advice-list-table" title="Danh sách mẫu lời khuyên" subtitle={rows===null?'Đang tải…':`${visible.length} mẫu lời khuyên`} action={<button className="button secondary" onClick={()=>setPreview(true)}>Thử kết quả đánh giá</button>}>
   <DataTable rowKey="id" rows={visible} paginate empty={rows===null?error?'Không tải được danh sách':'Đang tải mẫu lời khuyên…':'Không có mẫu lời khuyên phù hợp bộ lọc'} onRowClick={open} columns={[
    {key:'title',label:'MẪU LỜI KHUYÊN',wrap:true,render:row=><div className="stack"><button className="link-button advice-name" onClick={event=>{event.stopPropagation();open(row);}}>{row.payload.title||'Chưa nhập tiêu đề'}</button><small>{row.payload.source_name==='app_authored'?'Ứng dụng tự biên soạn':row.payload.source_name||row.sourceRefs?.[0]?.organization||row.sourceRefs?.[0]?.document||'Chưa có nguồn nội dung'}</small></div>},
    {key:'condition',label:'ÁP DỤNG KHI',wrap:true,render:row=>VARIANT_LABELS[row.stableCode]||'Chưa xác định tình huống'},
    {key:'version',label:'PHIÊN BẢN',render:questionVersion},
    {key:'state',label:'TRẠNG THÁI',render:row=><Availability row={row}/>},
    {key:'updated',label:'NGÀY CẬP NHẬT',render:row=>updatedDate(row.updatedAt)},
    {key:'actions',label:'THAO TÁC',render:row=><div className="advice-list-actions" onClick={stopRowClick}>{!row.deletedAt&&<button className="link-button" onClick={()=>navigate(`/development/advice/${row.id}/edit`)}>Sửa</button>}<QuestionActions admin={admin} item={row} allowDelete={false} onChanged={load} onError={setError}/></div>},
   ]}/>
   {error&&rows===null&&<button className="button secondary" onClick={load}>Tải lại</button>}
  </Panel>
  {preview&&<ResultPreview admin={admin} onClose={()=>setPreview(false)}/>}
 </div>;
}

function ResultPreview({admin,onClose}){
 const [sets,setSets]=useState([]),[setId,setSetId]=useState(''),[questions,setQuestions]=useState([]),[answers,setAnswers]=useState({}),[regression,setRegression]=useState('no'),[concern,setConcern]=useState('no'),[view,setView]=useState(null),[error,setError]=useState(''),[busy,setBusy]=useState(false),[all,setAll]=useState(false);
 useEffect(()=>{api.listQuestionSets(admin).then(x=>setSets(x.filter(r=>!r.deletedAt))).catch(e=>setError(e.message));},[]);
 useEffect(()=>{setView(null);setQuestions([]);setAnswers({});if(!setId)return;let cancelled=false;setBusy(true);api.listContent(admin,setId).then(rows=>{if(cancelled)return;const qs=rows.filter(r=>!r.deletedAt);setQuestions(qs);setAnswers(Object.fromEntries(qs.map(r=>[r.stableCode,'achieved'])));}).catch(e=>!cancelled&&setError(e.message)).finally(()=>!cancelled&&setBusy(false));return()=>{cancelled=true;};},[setId]);
 function scenario(key){const next=Object.fromEntries(questions.map(r=>[r.stableCode,'achieved']));setRegression(key==='regression'?'yes':key==='unsure'?'unsure':'no');setConcern(key==='concern'?'yes':'no');if(key==='not_yet'||key==='mixed')next[questions[0]?.stableCode]='not_yet';if(key==='observe')next[questions[0]?.stableCode]='not_observed';if(key==='mixed'&&questions[1])next[questions[1].stableCode]='not_observed';setAnswers(next);setView(null);}
 return <Modal className="advice-preview-dialog" title="Thử kết quả đánh giá" wide onClose={onClose}><p className="detail-alert">Dùng bản nháp hiện hành, kể cả nội dung đang ẩn. Không tạo hồ sơ, bài đánh giá hoặc kết quả thật.</p><ErrorBox message={error}/><label>Bộ câu hỏi<select value={setId} onChange={e=>setSetId(e.target.value)}><option value="">Chọn bộ câu hỏi</option>{sets.map(r=><option key={r.id} value={r.id}>{r.ageMonths} tháng · {r.code}</option>)}</select></label>{questions.length>0&&<><div className="development-toolbar">{[['all','Đã làm được hết'],['not_yet','Một kỹ năng chưa làm'],['observe','Một kỹ năng chưa quan sát'],['mixed','Cả hai loại'],['regression','Báo mất kỹ năng'],['unsure','Chưa chắc mất kỹ năng'],['concern','Phụ huynh lo ngại']].map(([k,v])=><button className="button secondary" key={k} onClick={()=>scenario(k)}>{v}</button>)}</div><div className="development-scroll">{questions.map(r=><label className="development-answer" key={r.id}><span>{r.payload.question_vi||r.payload.prompt}</span><select value={answers[r.stableCode]??'achieved'} onChange={e=>{setAnswers(x=>({...x,[r.stableCode]:e.target.value}));setView(null);}}>{OPTIONS.map(x=><option key={x.value} value={x.value}>{x.label}</option>)}</select></label>)}</div><div className="development-toolbar"><label>Mất kỹ năng<select value={regression} onChange={e=>{setRegression(e.target.value);setView(null);}}><option value="no">Không</option><option value="yes">Có</option><option value="unsure">Chưa chắc</option></select></label><label>Phụ huynh lo ngại<select value={concern} onChange={e=>{setConcern(e.target.value);setView(null);}}><option value="no">Không</option><option value="yes">Có</option></select></label></div></>}<button className="button primary" disabled={busy||!questions.length} onClick={async()=>{setBusy(true);setError('');setView(null);try{setView(await api.request(admin,'/preview-result','POST',{question_set_id:setId,answers,regression,caregiver_concern:concern}));setAll(false);}catch(e){setError(e.message);}finally{setBusy(false);}}}>{busy?'Đang xử lý…':'Xem kết quả thử'}</button>{view&&<div className="development-preview-result"><h3>Tổng quan</h3><p>Đã làm được: {view.sections.overview.achieved} · Chưa làm được: {view.sections.overview.not_yet} · Chưa quan sát: {view.sections.overview.not_observed}</p><h3>Kỹ năng cần chú ý</h3>{view.sections.skills_to_note.total===0?<p>Không có kỹ năng cần liệt kê trong tình huống này.</p>:(all?view.sections.skills_to_note.all:view.sections.skills_to_note.preview).map(x=><article key={x.question_id}><h4>{x.skill_name}</h4><p>{x.comment}</p><p>{x.how_to_observe}</p>{x.safety_note&&<p>Lưu ý: {x.safety_note}</p>}</article>)}{view.sections.skills_to_note.has_more&&<button className="link-button" onClick={()=>setAll(!all)}>{all?'Thu gọn':'Xem tất cả kỹ năng'}</button>}<h3>Hướng dẫn tiếp theo</h3>{view.sections.next_steps.advice_items.map(x=><article key={x.variant_id}><h4>{x.title}</h4><p>{x.body_text}</p></article>)}<SpeakButton text={view.sections.next_steps.tts_text}/><p>{view.disclaimer}</p></div>}</Modal>;
}
