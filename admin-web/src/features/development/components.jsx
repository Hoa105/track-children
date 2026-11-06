import React,{useEffect,useRef,useState} from 'react';
import {Badge,Panel,DataTable} from '../../shared/ui.jsx';
import Icon from '../../shared/Icon.jsx';
import {REVIEW_TYPES,DOMAINS,parseImport,download,questionSetState,QUESTION_SET_STATES,questionState,QUESTION_STATES} from './model.js';
import * as api from './developmentApi.js';

export function Availability({row}) {
 if (row.ageMonths != null) {
  const [label,tone]=QUESTION_SET_STATES[questionSetState(row)];
  return <Badge tone={tone}>{label}</Badge>;
 }
 if(['skill','advice'].includes(row.kind)) {
  const [label,tone]=QUESTION_STATES[questionState(row)];
  return <Badge tone={tone}>{label}</Badge>;
 }
 return <Badge tone={row.deletedAt?'gray':row.isActive?'green':'gray'}>{row.deletedAt?'Đã xóa':row.isActive?'Hiển thị':'Đã ẩn'}</Badge>;
}
export function QuestionActions({admin,item,onChanged,onError,disabled=false,buttons=false,allowDelete=true}) {
 const [busy,setBusy]=useState(false);
 async function perform(action) {
  const label=action==='delete'?'Xóa':action==='restore'?'Khôi phục':action==='publish'?'Xuất bản':'Ẩn';
  if(!window.confirm(`${label} ${item.kind==='advice'?'mẫu lời khuyên':`câu hỏi ${item.orderIndex??item.stableCode}`}? Bài và kết quả đã lưu không thay đổi.`))return;
  setBusy(true);
  try {
   if(action==='publish')await api.releaseContent(admin,item.id,item.currentRevision);
   else await api.lifecycle(admin,'content',item.id,action==='hide'?'availability':action,false);
   await onChanged();
  }catch(problem){onError(problem.message);}finally{setBusy(false);}
 }
 return <div className={`question-content-actions ${buttons ? 'question-action-buttons' : ''}`}>
  {item.deletedAt?<button className={buttons?"button secondary":"link-button"} disabled={busy||disabled} onClick={()=>perform('restore')}>Khôi phục</button>:<>
   <button className={buttons ? `button ${questionState(item)==='published'?'secondary':'primary'}` : `link-button ${questionState(item)==='published'?'danger':''}`} disabled={busy||disabled} onClick={()=>perform(questionState(item)==='published'?'hide':'publish')}>{questionState(item)==='published'?'Ẩn':buttons?'Xuất bản':'xuất bản'}</button>
   {questionState(item)==='published'&&item.currentRevision!==item.publishedRevision&&<button className={buttons?'button primary':'link-button'} disabled={busy||disabled} onClick={()=>perform('publish')}>{buttons?'Xuất bản bản nháp':'xuất bản nháp'}</button>}
   <>{allowDelete&&<button className={buttons?"button secondary danger":"link-button danger"} disabled={busy||disabled} onClick={()=>perform('delete')}>Xóa</button>}</>
  </>}
 </div>;
}
export function Modal({title,children,onClose,wide=false,className='',eyebrow,footer}){
 const dialog=useRef(null),close=useRef(onClose);close.current=onClose;
 useEffect(()=>{const previous=document.activeElement;const root=dialog.current;const focusable=()=>[...root.querySelectorAll('button,input,select,textarea,a[href],[tabindex="0"]')].filter(x=>!x.disabled&&x.offsetParent!==null);focusable()[0]?.focus();const keyboard=e=>{if(e.key==='Escape'){e.preventDefault();close.current();}if(e.key==='Tab'){const list=focusable();const first=list[0],last=list.at(-1);if(e.shiftKey&&document.activeElement===first){e.preventDefault();last?.focus();}else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first?.focus();}}};root.addEventListener('keydown',keyboard);return()=>{root.removeEventListener('keydown',keyboard);previous?.focus();};},[]);
 return <div className="modal-backdrop"><section ref={dialog} className={`modal development-dialog ${wide?'modal-wide':''} ${className}`} role="dialog" aria-modal="true" aria-label={title}><div className="modal-header"><div>{eyebrow&&<p className="eyebrow">{eyebrow}</p>}<h2>{title}</h2></div><button type="button" className="close-button" aria-label="Đóng" onClick={onClose}><Icon name="close" size={17}/></button></div><div className={className?'development-modal-body':undefined}>{children}</div>{footer&&<div className="development-modal-footer">{footer}</div>}</section></div>;
}
export function ErrorBox({message}){return message?<div className="auth-error" role="alert">{message}</div>:null;}
export function LifecycleButtons({admin,row,type,reload,onError,noun,disabled=false}) {
 const [busy,setBusy]=useState(false);
 const label=noun || (type==='question-sets'?'bộ':'câu');
 async function act(action,active) {
  const message=action==='delete'?`Xóa mềm ${label}? Giữ toàn bộ lịch sử; không dùng cho bài mới.`:action==='restore'?`Khôi phục ${label} ở trạng thái tắt?`:`${active?'Bật':'Tắt'} ${label}? Chỉ áp dụng cho bài đánh giá mới.`;
  if(!window.confirm(message)) return;
  setBusy(true);
  try {await api.lifecycle(admin,type,row.id,action,active);await reload();}
  catch(problem){onError(problem.message);}
  finally{setBusy(false);}
 }
 return <div className="development-lifecycle">
  {row.deletedAt?<button className="button secondary" disabled={busy||disabled} onClick={()=>act('restore')}>Khôi phục {label}</button>:<>
   <button className="button secondary" disabled={busy||disabled||row.isActive} title={row.isActive?'Đã bật':`Bật ${label} sau khi công bố nội dung hợp lệ`} onClick={()=>act('availability',true)}>Bật {label}</button>
   <button className="button secondary danger" disabled={busy||disabled||!row.isActive} title={!row.isActive?'Đã tắt':`Ngừng dùng ${label} cho bài mới`} onClick={()=>act('availability',false)}>Tắt {label}</button>
   <button className="link-button danger" disabled={busy||disabled} onClick={()=>act('delete')}>Xóa mềm</button>
  </>}
 </div>;
}
export function TransferTools({ admin, setId, kind = 'skill', filteredSetIds, onChanged }) {
  const [preview, setPreview] = useState(null);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [dialog, setDialog] = useState('');
  const [format, setFormat] = useState('json');
  const [templateFormat, setTemplateFormat] = useState('csv');
  const [scope, setScope] = useState('all');
  const [fileName, setFileName] = useState('');
  const [notice, setNotice] = useState('');
  const input = useRef(null);
  const subject = kind === 'advice' ? 'mẫu lời khuyên' : 'bộ câu hỏi';
  const frame = { className: 'development-transfer-dialog', eyebrow: kind === 'advice' ? 'MẪU LỜI KHUYÊN PHÁT TRIỂN' : 'BỘ CÂU HỎI' };

  async function run(action) {
    setBusy(true); setError(''); setNotice('');
    try { await action(); } catch (problem) { setError(problem.message); } finally { setBusy(false); }
  }
  function open(name) { setError(''); setNotice(''); setDialog(name); }
  const cancel = () => !busy && setDialog('');
  const cancelButton = <button className="button secondary" disabled={busy} onClick={cancel}>Đóng</button>;
  async function file(event) {
    const selected = event.target.files[0]; event.target.value = '';
    if (!selected) return;
    setFileName(selected.name);
    if (selected.size > 5 * 1024 * 1024) { setError('Tệp tối đa 5 MB'); return; }
    await run(async () => {
      const rows = parseImport(await selected.text(), selected.name);
      const next = await api.importPreview(admin, rows);
      setDialog(''); setPreview(next);
    });
  }
  async function exportFile() {
    await run(async () => {
      const rows = await api.exported(admin, setId, kind, scope === 'filtered' ? filteredSetIds : undefined);
      if (!rows.length) throw new Error('Không có nội dung trong phạm vi đã chọn');
      download(rows, format, kind === 'advice' ? 'loi-khuyen-phat-trien' : 'bo-cau-hoi'); setDialog('');
    });
  }

  return <>
    <div className="development-transfer-actions" role="group" aria-label={`Nhập xuất ${subject}`}>
      <button className="button secondary" disabled={busy} onClick={() => open('template')}><Icon name="file" size={15} />Tải mẫu nhập</button>
      <button className="button secondary" disabled={busy} onClick={() => open('import')}><Icon name="upload" size={15} />Nhập tệp</button>
      <button className="button secondary" disabled={busy} onClick={() => open('export')}><Icon name="download" size={15} />Xuất tệp</button>
    </div>
    {!dialog && !preview && <ErrorBox message={error} />}

    {dialog === 'template' && <Modal {...frame} title="Tải mẫu nhập" onClose={cancel} footer={<>{cancelButton}<button className="button primary" disabled={busy} onClick={() => run(async () => {
      download(await api.importTemplate(admin, kind), templateFormat, `mau-nhap-${kind === 'advice' ? 'loi-khuyen' : 'bo-cau-hoi'}`);
      setNotice(`Đã tải mẫu ${templateFormat.toUpperCase()}.`);
    })}><Icon name="download" size={15} />{busy ? 'Đang tải…' : 'Tải mẫu'}</button></>}>
      <p className="transfer-description">Chọn định dạng mẫu để biên soạn nội dung theo đúng cấu trúc nhập.</p>
      <ErrorBox message={error} />
      <TransferFormat name="template-format" value={templateFormat} onChange={setTemplateFormat} disabled={busy} />
      <div className="transfer-info"><Icon name="file" size={17} /><p>Mẫu có một nội dung minh họa. Đổi mã bộ, mã câu khi thêm mới; giữ mã khi cập nhật nội dung đã có.</p></div>
      <details className="transfer-help"><summary>Quy cách tệp</summary><p>CSV: giữ tên cột, các ô payload và source_refs chứa JSON theo mẫu. JSON: giữ danh sách và cấu trúc các trường bên trong. Dữ liệu nhập vào là bản nháp.</p></details>
      {notice && <p className="transfer-notice" role="status"><Icon name="check" size={15} />{notice}</p>}
    </Modal>}

    {dialog === 'import' && <Modal {...frame} title={`Nhập ${subject}`} onClose={cancel} footer={<>{cancelButton}<button className="link-button" disabled={busy} onClick={() => open('template')}>Tải mẫu nhập</button></>}>
      <p className="transfer-description">Chọn tệp đã điền theo mẫu. Hệ thống sẽ kiểm tra trước khi ghi dữ liệu.</p>
      <TransferSteps />
      <ErrorBox message={error} />
      <div className={`transfer-file-picker ${busy ? 'is-busy' : ''}`}>
        <span className="transfer-file-icon"><Icon name="upload" size={25} /></span>
        <b>{fileName || 'Chọn tệp để nhập'}</b>
        <span>CSV hoặc JSON · Tối đa 5 MB · 500 dòng</span>
        <input ref={input} type="file" accept=".csv,.json" hidden onChange={file} />
        <button className="button primary" disabled={busy} onClick={() => input.current.click()}>{busy ? 'Đang kiểm tra…' : 'Chọn tệp CSV / JSON'}</button>
      </div>
      <div className="transfer-info"><Icon name="shield" size={17} /><p>Chỉ nhập bản nháp. Nội dung đang xuất bản trên app được giữ nguyên.</p></div>
      {kind === 'skill' && <details className="transfer-help"><summary>Dữ liệu CDC có sẵn</summary><p>159 kỹ năng và 6 mẫu lời khuyên từ tài liệu dự án.</p><button className="link-button" disabled={busy} onClick={() => run(async () => { const next = await api.seedPreview(admin); setDialog(''); setPreview(next); })}>Xem trước dữ liệu CDC</button></details>}
    </Modal>}

    {dialog === 'export' && <Modal {...frame} title={`Xuất ${subject}`} onClose={cancel} footer={<>{cancelButton}<button className="button primary" disabled={busy || scope === 'filtered' && filteredSetIds?.length === 0} onClick={exportFile}><Icon name="download" size={15} />{busy ? 'Đang xuất…' : 'Tải tệp xuất'}</button></>}>
      <p className="transfer-description">Chọn phạm vi và định dạng cho tệp tải về.</p>
      <ErrorBox message={error} />
      {filteredSetIds !== undefined && <label className="transfer-field">Phạm vi xuất<select aria-label="Phạm vi xuất" value={scope} disabled={busy} onChange={event => setScope(event.target.value)}><option value="all">Tất cả bộ chưa xóa</option><option value="filtered" disabled={!filteredSetIds.length}>Các bộ đang lọc ({filteredSetIds.length} bộ)</option></select></label>}
      <TransferFormat name="export-format" value={format} onChange={setFormat} disabled={busy} />
      <div className="transfer-info"><Icon name="file" size={17} /><p>Xuất nội dung mới nhất, gồm bản nháp. Không kèm dữ liệu đã xóa hoặc câu trả lời của trẻ.</p></div>
    </Modal>}

    {preview && <Modal {...frame} title="Kiểm tra dữ liệu nhập" wide onClose={() => !busy && setPreview(null)} footer={<><button className="button secondary" disabled={busy} onClick={() => setPreview(null)}>Hủy</button><button className="button primary" disabled={busy || preview.errors.length > 0 || preview.changes.every(row => row.action === 'unchanged')} onClick={() => run(async () => { await api.importCommit(admin, preview); setPreview(null); setFileName(''); await onChanged(); })}>{busy ? 'Đang nhập…' : 'Nhập bản nháp'}</button></>}>
      <p className="transfer-description">Kiểm tra thay đổi và sửa các dòng lỗi trước khi xác nhận.</p>
      <TransferSteps current={2} />
      <ErrorBox message={error} />
      <div className="transfer-summary">{[
        ['Nội dung mới', preview.changes.filter(row => row.action === 'create').length],
        ['Bản sửa', preview.changes.filter(row => row.action === 'revision').length],
        ['Không đổi', preview.changes.filter(row => row.action === 'unchanged').length], ['Lỗi', preview.errors.length],
      ].map(([label, value]) => <div key={label} className={label === 'Lỗi' && value ? 'has-error' : ''}><span>{label}</span><b>{value}</b></div>)}</div>
      {preview.errors.map((row, index) => <ErrorBox key={index} message={`Dòng ${row.row}: ${row.message}`} />)}
      <div className="transfer-changes">{preview.changes.map(row => <details key={row.code}><summary><b>{row.code}</b><span>{{ create: 'Tạo nháp', revision: 'Tạo bản sửa', unchanged: 'Không đổi' }[row.action]}</span></summary><ContentDiff before={{ ...row.before, source_refs: row.before_sources }} after={{ ...row.after, source_refs: row.after_sources }} /></details>)}</div>
    </Modal>}
  </>;
}

function TransferFormat({ name, value, onChange, disabled }) {
  return <fieldset className="transfer-formats"><legend>Định dạng tệp</legend><div>{[
    ['csv', 'CSV', 'Mở và chỉnh sửa bằng Excel.'], ['json', 'JSON', 'Giữ cấu trúc dữ liệu đầy đủ.'],
  ].map(([code, label, description]) => <label key={code} className={value === code ? 'selected' : ''}><input type="radio" name={name} value={code} checked={value === code} disabled={disabled} onChange={() => onChange(code)} /><span><b>{label}</b><small>{description}</small></span><Icon name="file" size={20} /></label>)}</div></fieldset>;
}
function TransferSteps({ current = 1 }) {
  return <ol className="transfer-steps" aria-label="Các bước nhập">{['Chọn tệp', 'Kiểm tra', 'Nhập nháp'].map((label, index) => <li key={label} className={current === index + 1 ? 'current' : current > index + 1 ? 'complete' : ''} aria-current={current === index + 1 ? 'step' : undefined}><span>{index + 1}</span>{label}</li>)}</ol>;
}

export function AuditPanel({admin,id,refresh=0,fullDetails=false,title="Nhật ký thay đổi"}){
 const [rows,setRows]=useState([]),[error,setError]=useState('');useEffect(()=>{api.audit(admin,id).then(setRows).catch(e=>setError(e.message));},[id,refresh]);
 const actions={release:'Xuất bản',create:'Tạo mới',update:'Sửa thông tin',create_revision:'Lưu bản nháp',review:'Ghi kiểm duyệt',publish:'Công bố',availability:'Bật/tắt sử dụng',delete:'Xóa mềm',restore:'Khôi phục',reorder:'Sắp xếp',import:'Nhập dữ liệu'};
 return <Panel className={fullDetails?"development-history-table":""} title={title} subtitle="100 thao tác gần nhất"><ErrorBox message={error}/><DataTable rows={rows} rowKey="id" paginate columns={[{key:'at',label:'THỜI GIAN',render:r=>new Date(r.created_at).toLocaleString('vi-VN')},{key:'actor',label:'NGƯỜI THỰC HIỆN',render:r=>r.actor||'Hệ thống / chưa ghi người thao tác'},{key:'action',label:'THAO TÁC',render:r=>actions[r.action]||r.action},{key:'detail',label:'CHI TIẾT',wrap:true,render:r=>fullDetails?<ContentDiff allFields before={r.before_data} after={{...r.before_data,...r.after_data}}/>:<details><summary>Xem thay đổi</summary><ContentDiff before={r.before_data} after={{...r.before_data,...r.after_data}}/></details>}]} /></Panel>;
}
export function ReviewPanel({admin,item,onChanged,disabled=false}){
 const [gate,setGate]=useState(null),[type,setType]=useState('medical'),[note,setNote]=useState(''),[evidence,setEvidence]=useState(''),[error,setError]=useState(''),[busy,setBusy]=useState(false);
 async function load(){try{setGate(await api.getGate(admin,item.id));}catch(e){setError(e.message);}}
 useEffect(()=>{load();},[item.id,item.currentRevision]);
 async function act(decision){setBusy(true);setError('');try{await api.createReview(admin,item.id,{revision:item.currentRevision,reviewType:type,decision,evidenceRef:evidence.trim()||null,note:note.trim()||null});setNote('');setEvidence('');await load();await onChanged();}catch(e){setError(e.message);}finally{setBusy(false);}}
 async function publish(){if(!window.confirm(`Công bố bản ${item.currentRevision}? Kết quả đã lưu không thay đổi.`))return;setBusy(true);try{await (item.kind==='skill'?api.releaseContent:api.publishContent)(admin,item.id,item.currentRevision);await load();await onChanged();}catch(e){setError(e.message);}finally{setBusy(false);}}
 return <Panel title={`Kiểm duyệt và công bố bản ${item.currentRevision}`} subtitle={item.kind==='skill'?'Mỗi bản sửa cần đủ 4 phê duyệt trước khi xuất bản lên app.':'Mỗi bản sửa cần được duyệt lại. Công bố không tự bật sử dụng.'}><ErrorBox message={error}/>{disabled&&<p className="detail-alert">Lưu hoặc hủy thay đổi trong biểu mẫu trước khi duyệt.</p>}<div className="chip-row">{Object.entries(REVIEW_TYPES).map(([key,label])=><Badge key={key} tone={gate?.reviews[key]?.decision==='approved'?'green':gate?.reviews[key]?.decision==='rejected'?'red':'orange'}>{label}: {gate?.reviews[key]?.decision==='approved'?'Đã duyệt':gate?.reviews[key]?.decision==='rejected'?'Từ chối':'Chưa duyệt'}</Badge>)}</div><div className="edit-form"><label>Hạng mục kiểm duyệt<select value={type} onChange={e=>setType(e.target.value)}>{Object.entries(REVIEW_TYPES).map(([k,v])=><option key={k} value={k}>{v}</option>)}</select></label><label>Căn cứ phê duyệt<input value={evidence} onChange={e=>setEvidence(e.target.value)} placeholder="Tài liệu hoặc xác nhận của người kiểm tra"/></label><label>Ghi chú<textarea value={note} onChange={e=>setNote(e.target.value)} rows={2}/></label></div><div className="development-toolbar"><button className="button secondary danger" disabled={busy||disabled||!!item.deletedAt||!note.trim()} onClick={()=>act('rejected')}>Từ chối hạng mục</button><button className="button secondary" disabled={busy||disabled||!!item.deletedAt||!evidence.trim()} onClick={()=>act('approved')}>Duyệt hạng mục</button></div>{gate?.blockers.length>0&&<div className="detail-alert"><b>Chưa thể công bố:</b><ul>{gate.blockers.map(x=><li key={x}>{x}</li>)}</ul></div>}<button className="button primary" disabled={busy||disabled||!gate||gate.blockers.length>0||(item.publishedRevision===item.currentRevision&&(item.kind!=='skill'||item.isActive))} onClick={publish}>{item.kind==='skill'?(item.publishedRevision===item.currentRevision&&item.isActive?'Đã xuất bản':`Xuất bản v${item.currentRevision}`):item.publishedRevision===item.currentRevision?'Bản này đã công bố':`Công bố bản ${item.currentRevision}`}</button></Panel>;
}
export function SpeakButton({text}){
 const [error,setError]=useState('');useEffect(()=>()=>window.speechSynthesis?.cancel(),[]);
 return <><button className="button secondary" disabled={!text} onClick={()=>{if(!window.speechSynthesis){setError('Trình duyệt chưa hỗ trợ đọc văn bản');return;}window.speechSynthesis.cancel();const utterance=new SpeechSynthesisUtterance(text);utterance.lang='vi-VN';utterance.onerror=()=>setError('Không đọc được văn bản. Kiểm tra giọng tiếng Việt trên thiết bị.');window.speechSynthesis.speak(utterance);}}>Nghe thử</button><ErrorBox message={error}/></>;
}


const FIELD_LABELS={preparation_text:'Chuẩn bị theo tình huống',preparation_common:'Thông tin chung mang theo',combined_body_text:'Nội dung dùng kèm mẫu trao đổi',combined_tts_text:'Văn bản đọc khi dùng kèm',skill_guidance:'Hướng dẫn theo kỹ năng',explanation:'Giải thích kỹ năng',support_steps:'Các bước hỗ trợ',discussion_points:'Nội dung cần trao đổi',sourceName:'Nguồn nội dung',questionSetId:'Bộ câu hỏi',question_set_id:'Bộ câu hỏi',ids:'Thứ tự câu hỏi',description:'Mô tả',question_vi:'Câu hỏi',prompt:'Câu hỏi cũ',instruction_vi:'Hướng dẫn thực hiện',skill_name:'Tên kỹ năng',not_yet_comment:'Nhận xét chưa làm được',not_observed_comment:'Nhận xét chưa quan sát',observation_guide:'Cách quan sát',safety_note:'Lưu ý an toàn',tts_short_text:'Văn bản đọc kỹ năng',title:'Tiêu đề',body_text:'Nội dung hướng dẫn',tts_text:'Văn bản đọc mẫu lời khuyên',cta_label:'Nhãn nút hành động',action_kind:'Hành động hệ thống',source_name:'Nguồn',source_pdf:'Tài liệu',source_page:'Trang / liên kết nguồn',source_version:'Phiên bản nguồn',source_excerpt:'Trích đoạn nguồn',source_refs:'Nguồn tham khảo',sourceRefs:'Nguồn tham khảo',media:'Ảnh/video',answer_options:'Đáp án',answerOptions:'Đáp án cũ',kind:'Loại nội dung',stable_code:'Mã nội dung',code:'Mã',revision:'Phiên bản',current_revision:'Bản mới nhất',published_revision:'Bản công bố',is_active:'Sử dụng',isActive:'Sử dụng',deleted_at:'Thời điểm xóa',status:'Công bố',age_months:'Tuổi (tháng)',version:'Phiên bản bộ',locale:'Ngôn ngữ',app_domain:'Lĩnh vực',source_domain:'Lĩnh vực nguồn',order_index:'Thứ tự',review_type:'Hạng mục duyệt',reviewType:'Hạng mục duyệt',decision:'Quyết định',evidence_ref:'Căn cứ',note:'Ghi chú',count:'Số câu',variant_id:'Mẫu lời khuyên',variant_priority:'Độ ưu tiên cố định',match_condition:'Điều kiện cố định',organization:'Tổ chức',document:'Tài liệu',page:'Trang',url:'Liên kết',type:'Loại media',youtube_id:'YouTube ID',alt:'Mô tả',caption:'Chú thích',attribution:'Ghi công',rights_status:'Quyền sử dụng',runtime_test_status:'Kiểm tra thiết bị',content_version:'Phiên bản nội dung',release_status:'Trạng thái phát hành'};
function readable(value){
 if(value===null||value===undefined||value==='')return 'Chưa có';
 if(typeof value==='boolean')return value?'Bật':'Tắt';
 if(Array.isArray(value))return value.length?value.map(readable).join('\n'):'Không có';
 if(typeof value==='object')return Object.entries(value).filter(([k])=>FIELD_LABELS[k]||k==='label').map(([k,v])=>`${FIELD_LABELS[k]||'Nội dung'}: ${readable(v)}`).join(' · ');
 const labels={...DOMAINS,...REVIEW_TYPES,approved:'Đã duyệt',rejected:'Từ chối',pending:'Chờ kiểm tra',not_tested:'Chưa thử trên thiết bị',draft:'Chưa công bố',in_review:'Chờ kiểm duyệt',published:'Đã công bố',archived:'Lưu trữ',skill:'Kỹ năng',advice:'Mẫu lời khuyên',image:'Ảnh',youtube:'YouTube',none:'Không có',app_authored:'Ứng dụng tự biên soạn',contact_healthcare:'Trao đổi nhân viên y tế',observe_skills:'Quan sát kỹ năng',continue_monitoring:'Tiếp tục theo dõi'};
 return labels[value]||String(value);
}
export function ContentDiff({before,after,allFields=false}){
 const flatten=value=>value?{...value,...value.payload,payload:undefined}:{};
 const old=flatten(before),next=flatten(after);
 const format=value=>allFields&&value&&typeof value==='object'?Object.entries(value).map(([key,entry])=>`${FIELD_LABELS[key]||key}: ${format(entry)}`).join('\n'):readable(value);
 const keys=[...new Set([...Object.keys(old),...Object.keys(next)])].filter(k=>(allFields?k!=='payload':FIELD_LABELS[k])&&JSON.stringify(old[k])!==JSON.stringify(next[k]));
 return keys.length?<div className="table-wrap"><table><thead><tr><th>TRƯỜNG</th><th>TRƯỚC</th><th>SAU</th></tr></thead><tbody>{keys.map(k=><tr key={k}><td>{FIELD_LABELS[k]||k}</td><td className="development-diff-value">{format(old[k])}</td><td className="development-diff-value">{format(next[k])}</td></tr>)}</tbody></table></div>:<p>Nội dung hiển thị không thay đổi.</p>;
}







