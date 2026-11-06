import React,{useEffect,useRef,useState} from 'react';
import {useAuth} from '../../core/auth.jsx';
import {navigate} from '../../core/useHashRoute.js';
import Icon from '../../shared/Icon.jsx';
import {DataTable,Panel,stopRowClick} from '../../shared/ui.jsx';
import {OPTIONS,VARIANT_LABELS,matches,questionState,questionVersion,updatedDate,QUESTION_STATES} from './model.js';
import {Availability,ErrorBox,QuestionActions,Modal,SpeakButton} from './components.jsx';
import ResultPreviewView from './ResultPreviewView.jsx';
import ContentEditorPage from './ContentEditorPage.jsx';
import * as api from './assessmentApi.js';
export default function AdvicePage({id,onNotify}){
 if(id){const [contentId,tab]=id.split('/');return <ContentEditorPage contentId={contentId} initialTab={['edit','history'].includes(tab)?tab:'detail'} onNotify={onNotify}/>;}
 return <AdviceList/>;
}
export function AdviceWorkspace() {
 return <AdviceList />;
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
 const [sets,setSets]=useState([]),[setId,setSetId]=useState(''),[questions,setQuestions]=useState([]),[answers,setAnswers]=useState({}),[regression,setRegression]=useState('no'),[concern,setConcern]=useState('no'),[view,setView]=useState(null),[error,setError]=useState(''),[busy,setBusy]=useState(false);
 useEffect(()=>{api.listQuestionSets(admin).then(x=>setSets(x.filter(r=>!r.deletedAt))).catch(e=>setError(e.message));},[]);
 useEffect(()=>{setView(null);setQuestions([]);setAnswers({});if(!setId)return;let cancelled=false;setBusy(true);api.listContent(admin,setId).then(rows=>{if(cancelled)return;const qs=rows.filter(r=>!r.deletedAt);setQuestions(qs);setAnswers(Object.fromEntries(qs.map(r=>[r.stableCode,'achieved'])));}).catch(e=>!cancelled&&setError(e.message)).finally(()=>!cancelled&&setBusy(false));return()=>{cancelled=true;};},[setId]);
 function presetAnswers(key){
  return Object.fromEntries(questions.map((row,index)=>[row.stableCode,
   index===0&&(key==='not_yet'||key==='mixed')?'not_yet':
   (index===0&&key==='observe')||(index===1&&key==='mixed')?'not_observed':'achieved']));
 }
 function skillPresetSelected(key){
  if(!questions.length||(key==='mixed'&&questions.length<2))return false;
  return Object.entries(presetAnswers(key)).every(([code,value])=>answers[code]===value);
 }
 function parentPresetSelected(key){
  return key==='concern'?concern==='yes':regression===(key==='regression'?'yes':'unsure');
 }
 function scenario(key){
  setView(null);
  if(key==='regression'||key==='unsure'){setRegression(key==='regression'?'yes':'unsure');return;}
  if(key==='concern'){setConcern('yes');return;}
  const next=presetAnswers(key);
  if(key==='reset'){setRegression('no');setConcern('no');}
  setAnswers(next);
 }

 const previewVersion=useRef(0);
 useEffect(()=>{previewVersion.current++;setView(null);},[setId,answers,regression,concern]);
 async function runPreview(){
  const version=++previewVersion.current;
  setBusy(true);setError('');setView(null);
  try{
   const result=await api.request(admin,'/preview-result','POST',{question_set_id:setId,answers,regression,caregiver_concern:concern});
   if(version===previewVersion.current)setView(result);
  }catch(problem){if(version===previewVersion.current)setError(problem.message);}
  finally{setBusy(false);}
 }

 return <Modal className="advice-preview-dialog" title="Thử kết quả đánh giá" wide onClose={onClose}><p className="detail-alert">Thử tình huống giả lập bằng bản nháp mới nhất, gồm cả nội dung đang ẩn. Kết quả chỉ dùng để xem trước; không lưu bài đánh giá hoặc hồ sơ trẻ.</p><ErrorBox message={error}/><label>1. Chọn bộ câu hỏi<select aria-label="Chọn bộ câu hỏi để thử" value={setId} onChange={e=>setSetId(e.target.value)}><option value="">Chọn bộ câu hỏi</option>{sets.map(r=><option key={r.id} value={r.id}>{r.ageMonths} tháng · {r.code}</option>)}</select></label>{questions.length>0&&<><h3 className="preview-section-title">2. Chọn đáp án cho các kỹ năng</h3><p className="preview-help">Điền nhanh đáp án kỹ năng, sau đó chỉnh từng câu bên dưới. Các lựa chọn này giữ nguyên thông tin phụ huynh đã nhập.</p><div className="development-toolbar preview-scenarios">{[['all','Đã làm được hết'],['not_yet','Một kỹ năng chưa làm'],['observe','Một kỹ năng chưa quan sát'],['mixed','Có kỹ năng chưa làm và chưa quan sát']].map(([k,v])=><button type="button" className={`button ${skillPresetSelected(k)?'primary':'secondary'}`} aria-pressed={skillPresetSelected(k)} disabled={k==='mixed'&&questions.length<2} key={k} onClick={()=>scenario(k)}>{v}</button>)}</div><div className="development-scroll">{questions.map(r=><label className="development-answer" key={r.id}><span>{r.payload.question_vi||r.payload.prompt}</span><select value={answers[r.stableCode]??'achieved'} onChange={e=>{setAnswers(x=>({...x,[r.stableCode]:e.target.value}));setView(null);}}>{OPTIONS.map(x=><option key={x.value} value={x.value}>{x.label}</option>)}</select></label>)}</div><h3 className="preview-section-title">3. Giả lập thông tin phụ huynh cung cấp</h3>
<p className="preview-help">Thông tin phụ huynh được chọn độc lập với đáp án kỹ năng.</p><div className="development-toolbar preview-parent-presets">{[['regression','Có mất kỹ năng từng làm được'],['unsure','Chưa chắc về mất kỹ năng'],['concern','Có lo ngại về phát triển']].map(([key,label])=><button type="button" className={`button ${parentPresetSelected(key)?'primary':'secondary'}`} aria-pressed={parentPresetSelected(key)} key={key} onClick={()=>scenario(key)}>{label}</button>)}</div>
<div className="preview-parent-inputs">
  <div className="preview-parent-field">
    <label htmlFor="preview-regression">Bé có mất kỹ năng từng làm được không?</label>
    <p id="preview-regression-help">Bé từng làm được một kỹ năng nhưng hiện không còn làm được. Có thể thuộc bất kỳ lĩnh vực phát triển nào.</p>
    <select id="preview-regression" aria-describedby="preview-regression-help preview-regression-scope" value={regression} onChange={e=>{setRegression(e.target.value);setView(null);}}><option value="no">Không</option><option value="yes">Có</option><option value="unsure">Chưa chắc</option></select>
    <small id="preview-regression-scope">Bản thử chỉ ghi nhận câu trả lời tổng quát, chưa chọn kỹ năng cụ thể.</small>
  </div>
  <div className="preview-parent-field">
    <label htmlFor="preview-concern">Phụ huynh có lo ngại về sự phát triển của bé không?</label>
    <p id="preview-concern-help">Lo ngại về vận động, ngôn ngữ và giao tiếp, nhận thức, cảm xúc hoặc tương tác xã hội của bé.</p>
    <select id="preview-concern" aria-describedby="preview-concern-help preview-concern-scope" value={concern} onChange={e=>{setConcern(e.target.value);setView(null);}}><option value="no">Không</option><option value="yes">Có</option></select>
    <small id="preview-concern-scope">Bản thử chỉ ghi nhận Có/Không, chưa nhập nội dung lo ngại cụ thể.</small>
  </div>
</div>
<p className="preview-help">Hai câu trả lời này dùng để chọn mẫu lời khuyên phù hợp, không thay đổi số kỹ năng Đã làm được / Chưa làm được / Chưa quan sát. Đây là thông tin phụ huynh báo, không phải kết luận của hệ thống.</p>
</>}<div className="preview-submit-actions"><button type="button" className="button secondary" disabled={!questions.length||busy} onClick={()=>scenario('reset')}>Đặt lại toàn bộ</button><button className="button primary" disabled={busy||!questions.length} onClick={runPreview}>{busy?'Đang xử lý…':'Xem kết quả thử'}</button></div>{view&&<ResultPreviewView view={view}/>}</Modal>;
}
