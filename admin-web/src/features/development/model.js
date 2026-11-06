export const AGES=[2,4,6,9,12,15,18,24,30,36,48,60];
export const DOMAINS={gross_motor:'Vận động thô',fine_motor:'Vận động tinh',language_communication:'Ngôn ngữ và giao tiếp',cognitive:'Nhận thức',social_emotional:'Cảm xúc và xã hội'};
export const REVIEW_TYPES={medical:'Chuyên môn',language:'Ngôn ngữ',media_rights:'Quyền media',qa:'Kiểm thử'};
export const OPTIONS=[{value:'achieved',label:'Đã làm được'},{value:'not_yet',label:'Chưa làm được'},{value:'not_observed',label:'Chưa có cơ hội quan sát'}];
export const VARIANT_LABELS={CONTACT_REGRESSION_YES:'Báo mất kỹ năng',CONTACT_REGRESSION_UNSURE:'Chưa chắc về mất kỹ năng',CONTACT_NOT_YET:'Có kỹ năng chưa làm được',CONTACT_CONCERN_ONLY:'Phụ huynh có lo ngại',OBSERVE_UNCHECKED:'Cần quan sát thêm',CONTINUE_MONITORING:'Tiếp tục theo dõi'};
// Keep unknown and legacy fields, including every media entry, during round trips.
export function editorPayload(payload={},kind='skill') {
 const result=structuredClone(payload);
 if(kind==='advice') return result;
 result.question_vi??=result.prompt??'';
 result.instruction_vi??=result.observation_guide??'';
 result.answer_options=OPTIONS.map((option,i)=>({...option,label:result.answer_options?.find(x=>x?.value===option.value)?.label??result.answerOptions?.[i]?.label??(typeof result.answerOptions?.[i]==='string'?result.answerOptions[i]:option.label)}));
 result.media=Array.isArray(result.media)?result.media:result.media&&result.media.type!=='none'?[result.media]:[];
 return result;
}
export function publication(row){return row.publishedRevision==null?'Chưa công bố':row.currentRevision!==row.publishedRevision?`Đang dùng bản ${row.publishedRevision} · Có nháp ${row.currentRevision}`:`Đã công bố bản ${row.publishedRevision}`;}
export function matches(row,q){return `${row.stableCode??row.code} ${row.payload?.question_vi??row.payload?.prompt??''} ${row.payload?.skill_name??''} ${row.payload?.title??''} ${row.payload?.body_text??''}`.toLocaleLowerCase('vi').includes(q.toLocaleLowerCase('vi'));}
export function download(rows,format,name){
 const text=format==='json'?JSON.stringify(rows,null,2):'\ufeff'+['kind,stable_code,age_months,set_code,set_version,set_source_name,locale,app_domain,source_domain,order_index,payload,source_refs',...rows.map(row=>['kind','stable_code','age_months','set_code','set_version','set_source_name','locale','app_domain','source_domain','order_index','payload','source_refs'].map(k=>'"'+String(typeof row[k]==='object'&&row[k]!==null?JSON.stringify(row[k]):row[k]??'').replaceAll('"','""')+'"').join(','))].join('\r\n');
 const url=URL.createObjectURL(new Blob([text],{type:format==='json'?'application/json;charset=utf-8':'text/csv;charset=utf-8'}));const a=document.createElement('a');a.href=url;a.download=`${name}.${format}`;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
}
export function parseImport(text,name){
 if(name.toLowerCase().endsWith('.json')) {const data=JSON.parse(text.replace(/^\ufeff/,''));return Array.isArray(data)?data:data.rows??data.items;}
 const rows=[];let row=[],field='',quoted=false;
 for(let i=0;i<text.length;i++){const c=text[i];if(c==='"'){if(quoted&&text[i+1]==='"'){field+='"';i++;}else quoted=!quoted;}else if(c===','&&!quoted){row.push(field);field='';}else if((c==='\n'||c==='\r')&&!quoted){if(c==='\r'&&text[i+1]==='\n')i++;row.push(field);if(row.some(Boolean))rows.push(row);row=[];field='';}else field+=c;}
 if(quoted)throw new Error('CSV có dấu ngoặc kép chưa đóng');row.push(field);if(row.some(Boolean))rows.push(row);
 const headers=rows.shift()?.map(x=>x.replace(/^\ufeff/,''))??[];return rows.map(values=>Object.fromEntries(headers.map((key,i)=>[key,values[i]??''])));
}

// Old links resolve to the same workspace; no separate review/publish screen.
export function developmentRoute(id = '') {
 const parts = (id || '').split('/').filter(Boolean);
 if (!parts.length) return { page: 'hub', tab: 'sets' };
 if (parts[0] === 'advice' && parts[1] === 'skills') return { page: 'hub', tab: 'advice' };
 if (parts[0] === 'advice') return parts[1] ? { page: 'advice', id: parts.slice(1).join('/') } : { page: 'hub', tab: 'advice' };
 if (parts[0] === 'review') return { page: 'hub', tab: 'sets' };
 if (['set', 'question-sets'].includes(parts[0]) && parts[1]) return { page: 'set', id: parts[1], tab: parts[2] === 'history' ? 'history' : parts[2] === 'edit' ? 'edit' : 'questions' };
 if (['question', 'questions', 'content'].includes(parts[0]) && parts[1]) return { page: 'question', id: parts[1], tab: ['history','edit'].includes(parts[2]) ? parts[2] : 'detail' };
 if (/^[0-9a-f-]{36}$/i.test(parts[0])) return { page: 'set', id: parts[0], tab: 'questions' };
 return { page: 'missing' };
}

export const QUESTION_SET_STATES = { hidden: ['Ẩn', 'gray'], published: ['Xuất bản', 'green'], deleted: ['Đã xóa', 'gray'], draft: ['Nháp', 'orange'] };
export function isSetDisplayed(row) {
 return !row.deletedAt && row.isActive && row.status === 'published' && (row.visibleQuestionCount ?? row.publishedCount ?? 0) > 0;
}
export function questionSetState(row) {
 if (row.deletedAt) return 'deleted';
 if (isSetDisplayed(row)) return 'published';
 return row.status === 'published' || row.status === 'archived' ? 'hidden' : 'draft';
}

export const QUESTION_STATES = QUESTION_SET_STATES;
export function questionState(row) {
 if(row.deletedAt)return 'deleted';
 if(row.publishedRevision==null)return 'draft';
 return row.isActive?'published':'hidden';
}
export function questionVersion(row) {
 if(row.publishedRevision==null)return `v${row.currentRevision} · Nháp`;
 return row.publishedRevision===row.currentRevision?`v${row.currentRevision}`:`App v${row.publishedRevision} · Nháp v${row.currentRevision}`;
}
export function updatedDate(value) {
 return value?new Date(value).toLocaleDateString('vi-VN',{timeZone:'Asia/Ho_Chi_Minh'}):'—';
}
