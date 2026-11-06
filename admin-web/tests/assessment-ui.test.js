import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdir, writeFile, unlink } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
import { build } from 'esbuild';
import { JSDOM } from 'jsdom';
const dom=new JSDOM('<!doctype html><div id="root"></div>',{url:'http://localhost:5173/#/assessment',pretendToBeVisual:true});
Object.assign(globalThis,{window:dom.window,document:dom.window.document,HTMLElement:dom.window.HTMLElement,Event:dom.window.Event,MouseEvent:dom.window.MouseEvent,IS_REACT_ACT_ENVIRONMENT:true});
Object.defineProperty(globalThis,'navigator',{value:dom.window.navigator,configurable:true});window.confirm=()=>true;
const React=await import('react');const {act}=React;const {createRoot}=await import('react-dom/client');
globalThis.__assessmentAuth={admin:{id:'admin-test',fullName:'Admin kiểm thử',role:'admin',permissions:['assessment.read','assessment.write','assessment.review','assessment.publish']},loading:false,logout(){}};
const names=['listQuestionSets','getSet','createQuestionSet','updateQuestionSet','listContent','listAdvice','listSkills','createContent','getContent','listRevisions','createRevision','getGate','createReview','publishContent','publishQuestionSet','releaseQuestionSet','releaseContent','lifecycle','reorder','audit','exported','seedPreview','importPreview','importCommit','importTemplate','reviewQueue','request'];
const built=await build({entryPoints:[resolve('src/app/App.jsx')],bundle:true,platform:'node',format:'esm',write:false,external:['react','react-dom','react-dom/client'],plugins:[{name:'isolated-api',setup(builder){
 builder.onResolve({filter:/core\/auth\.jsx$/},()=>({path:'auth',namespace:'test'}));builder.onResolve({filter:/assessmentApi\.js$/},()=>({path:'api',namespace:'test'}));
 builder.onLoad({filter:/.*/,namespace:'test'},({path})=>({contents:path==='auth'?'export const useAuth=()=>globalThis.__assessmentAuth;export const AuthProvider=({children})=>children;':names.map(name=>`export const ${name}=(...args)=>globalThis.__assessmentApi.${name}(...args);`).join('\n'),loader:'js'}));
}}]});
const cache=resolve('node_modules/.cache');await mkdir(cache,{recursive:true});const file=resolve(cache,`assessment-ui-${process.pid}.mjs`);await writeFile(file,built.outputFiles[0].text);const {default:App}=await import(pathToFileURL(file));await unlink(file);
const clone=x=>structuredClone(x);let sets,questions,calls,root;
function reset(){calls=[];sets=[{id:'set-12',code:'cdc-12m-v1',ageMonths:12,version:'v1',sourceName:'CDC',locale:'vi-VN',updatedAt:'2026-11-05T12:00:00Z',status:'published',contentCount:2,publishedCount:2,isActive:true,deletedAt:null}];
 const base={kind:'skill',questionSetId:'set-12',appDomain:'gross_motor',currentRevision:1,publishedRevision:1,isActive:true,deletedAt:null,sourceRefs:[{organization:'CDC'}]};
 questions=[{...clone(base),id:'q-image',stableCode:'CDC-12-01',orderIndex:1,payload:{question_vi:'Bé có thể tự đứng lên không?',instruction_vi:'Quan sát bé trên nền phẳng an toàn.',skill_name:'Tự đứng',not_yet_comment:'Chưa ghi nhận tự đứng.',not_observed_comment:'Chưa có dịp quan sát.',observation_guide:'Quan sát khi bé sẵn sàng.',media:[{type:'image',url:'https://www.cdc.gov/example.png',alt:'Bé đứng',attribution:'CDC'}]}},{...clone(base),id:'q-video',stableCode:'CDC-12-02',orderIndex:2,payload:{question_vi:'Bé có bước đi khi được hỗ trợ không?',instruction_vi:'Người lớn ở bên cạnh bé.',media:[{type:'youtube',url:'https://www.youtube-nocookie.com/embed/abcdefghijk',youtube_id:'abcdefghijk',alt:'Video bước đi',attribution:'CDC'}]}}];
 globalThis.__assessmentApi={listSkills:async()=>clone(questions.filter(row=>row.kind==='skill')),releaseContent:async(_a,id,v)=>{calls.push({type:'content',id,action:'release',isActive:true});const row=questions.find(x=>x.id===id);row.isActive=true;row.publishedRevision=v;return clone(row);},listQuestionSets:async()=>clone(sets),getSet:async(_a,id)=>clone(sets.find(x=>x.id===id)),listContent:async()=>clone(questions),getContent:async(_a,id)=>clone(questions.find(x=>x.id===id)),listRevisions:async(_a,id)=>[{revision:1,createdAt:'2026-11-05T12:00:00Z',payload:clone(questions.find(x=>x.id===id).payload),sourceRefs:[]}],getGate:async()=>({revision:1,blockers:[],reviews:Object.fromEntries(['medical','language','media_rights','qa'].map(type=>[type,{decision:'approved'}]))}),lifecycle:async(_a,type,id,action,isActive)=>{calls.push({type,id,action,isActive});const row=(type==='question-sets'?sets:questions).find(x=>x.id===id);if(action==='delete'){row.deletedAt='2026-11-05T12:00:00Z';row.isActive=false;}else if(action==='restore'){row.deletedAt=null;row.isActive=false;}else row.isActive=isActive;return {saved:true};},reviewQueue:async()=>questions.map(x=>({contentItemId:x.id,stableCode:x.stableCode,questionSetId:x.questionSetId,kind:'skill',revision:1,payload:clone(x.payload),reviews:{}})),audit:async()=>[],listAdvice:async()=>[],publishQuestionSet:async()=>({}),releaseQuestionSet:async(_a,id)=>{calls.push({type:'question-sets',id,action:'release',isActive:true});const row=sets.find(x=>x.id===id);row.isActive=true;row.status='published';return clone(row);}};
}
async function flush(){await act(async()=>{await new Promise(resolve=>setTimeout(resolve,30));});}
async function mount(path='/assessment',configure){reset();configure?.();window.history.replaceState(null,'',`#${path}`);root=createRoot(document.getElementById('root'));await act(async()=>root.render(React.createElement(App)));await flush();}
async function unmount(){await act(async()=>root.unmount());}
function button(text,scope=document){const found=[...scope.querySelectorAll('button')].find(x=>x.textContent.trim()===text||x.getAttribute('aria-label')===text);assert.ok(found,`Missing button: ${text}`);return found;}
async function click(text,scope=document){const node=button(text,scope);assert.equal(node.disabled,false,`${text} disabled`);await act(async()=>node.dispatchEvent(new MouseEvent('click',{bubbles:true})));await flush();}

test('App router: toggle sets and questions off/on, open full question with answers and image',async()=>{
 await mount();try{
 await click('Ẩn');assert.equal(calls.at(-1).isActive,false);assert.equal(button('xuất bản').disabled,false);await click('xuất bản');assert.equal(calls.at(-1).isActive,true);
 await click('Mở bộ 12 tháng');assert.match(document.querySelector('h1').textContent,/12 tháng/);
 const row=()=>[...document.querySelectorAll('tbody tr')].find(x=>x.textContent.includes('Bé có thể tự đứng lên không?'));
 await click('Ẩn',row());assert.equal(calls.at(-1).id,'q-image');assert.equal(calls.at(-1).isActive,false);await click('xuất bản',row());assert.equal(calls.at(-1).isActive,true);assert.ok(!row().querySelector('td').textContent.includes('CDC-12-01'));assert.ok(!row().querySelector('td').textContent.includes('Vận động thô'));assert.ok(document.querySelector('thead').textContent.includes('LĨNH VỰC'));await click('Chi tiết',row());assert.equal(window.location.hash,'#/assessment/question/q-image');
 assert.match(document.querySelector('main').textContent,/Bé có thể tự đứng lên không/);assert.equal(document.querySelectorAll('input[type="radio"]').length,3);
 for(const label of ['Đã làm được','Chưa làm được','Chưa có cơ hội quan sát'])assert.ok(document.querySelector('fieldset').textContent.includes(label));
 assert.equal(document.querySelector('img[alt="Bé đứng"]').getAttribute('src'),'https://www.cdc.gov/example.png');assert.match(document.querySelector('main').textContent,/Quan sát bé trên nền phẳng an toàn/);assert.equal(document.querySelector('[role="tab"][aria-selected="true"]').textContent,'Chi tiết câu hỏi');
 }finally{await unmount();}
});
test('video question detail renders iframe and three answers',async()=>{await mount('/assessment/question/q-video');try{assert.equal(document.querySelector('iframe').getAttribute('src'),'https://www.youtube-nocookie.com/embed/abcdefghijk');assert.equal(document.querySelectorAll('input[type="radio"]').length,3);assert.match(document.querySelector('main').textContent,/Bé có bước đi khi được hỗ trợ/);}finally{await unmount();}});
test('removed question review route opens detail without review controls',async()=>{await mount('/assessment/question/q-image/review');try{assert.ok(document.querySelector('img[alt="Bé đứng"]'));assert.equal(document.querySelectorAll('input[type="radio"]').length,3);assert.equal(document.querySelector('[role="tab"][aria-selected="true"]').textContent,'Chi tiết câu hỏi');assert.ok(!document.querySelector('main').textContent.includes('Kiểm duyệt & công bố'));}finally{await unmount();}});
test('legacy edit and review links remain inside the same workspace',async()=>{await mount('/assessment/content/q-image/edit');try{assert.equal(document.querySelector('[role="tab"][aria-selected="true"]').textContent,'Chỉnh sửa');assert.ok([...document.querySelectorAll('textarea')].some(x=>x.value==='Bé có thể tự đứng lên không?'));assert.ok(document.querySelector('img[alt="Bé đứng"]'));assert.equal(document.querySelectorAll('input[type="radio"]').length,3);}finally{await unmount();}await mount('/assessment/review');try{assert.equal(document.querySelector('[role="tab"][aria-selected="true"]').textContent,'Bộ câu hỏi');assert.equal(document.querySelector('h1').textContent,'Bộ câu hỏi & Lời khuyên');}finally{await unmount();}});


test('set list has a dropdown, four lifecycle states, update dates and only hide/publish actions',async()=>{
 await mount('/assessment',()=>{
  const base=clone(sets[0]);
  sets.push({...base,id:'set-hidden',ageMonths:18,isActive:false},{...base,id:'set-draft',ageMonths:24,status:'draft',isActive:false},{...base,id:'set-deleted',ageMonths:30,deletedAt:'2026-11-05T12:00:00Z',isActive:false});
 });try{
  assert.deepEqual([...document.querySelectorAll('thead th')].map(x=>x.textContent),['BỘ CÂU HỎI','PHIÊN BẢN','SỐ CÂU','TRẠNG THÁI','NGÀY CẬP NHẬT','THAO TÁC']);
  const filter=document.querySelector('select[aria-label="Lọc trạng thái bộ"]');
  assert.deepEqual([...filter.options].map(x=>x.textContent),['Tất cả','Ẩn','Xuất bản','Đã xóa','Nháp']);
  assert.equal(document.querySelectorAll('tbody tr.clickable-row').length,4);assert.deepEqual([...document.querySelectorAll('.question-set-name')].map(node=>node.textContent),['12 tháng','18 tháng','24 tháng','30 tháng']);assert.equal(document.querySelector('tbody tr td:nth-child(2)').textContent,'v1');
  assert.equal(document.querySelectorAll('tbody time').length,4);
  for(const cell of [...document.querySelectorAll('tbody tr')].map(x=>x.lastElementChild)) for(const b of cell.querySelectorAll('button')) assert.ok(['Sửa','Ẩn','xuất bản','Xóa'].includes(b.textContent));
  for(const [value,label] of [['hidden','Ẩn'],['published','Xuất bản'],['deleted','Đã xóa'],['draft','Nháp']]){
   await act(async()=>{filter.value=value;filter.dispatchEvent(new Event('change',{bubbles:true}));});await flush();
   assert.equal(document.querySelectorAll('tbody tr.clickable-row').length,1);
   assert.equal(document.querySelector('tbody .badge').textContent,label);
  }
  assert.equal([...document.querySelectorAll('[role="tab"]')].some(x=>x.textContent==='Nhập / xuất'),false);
  await act(async()=>{filter.value='published';filter.dispatchEvent(new Event('change',{bubbles:true}));});await flush();
  assert.ok(button('Tải mẫu nhập'));assert.ok(button('Nhập tệp'));assert.ok(button('Xuất tệp'));await click('Mở bộ 12 tháng');assert.equal([...document.querySelectorAll('button')].some(x=>x.textContent==='Nhập tệp'),false);
 }finally{await unmount();}
});
test('set with no visible published questions is labelled hidden even if its switch is on',async()=>{
 await mount('/assessment',()=>{sets[0].visibleQuestionCount=0;});try{
  assert.equal(sets[0].isActive,true);
  assert.ok(document.querySelector('tbody').textContent.includes('Ẩn'));
 }finally{await unmount();}
});





test('template and filtered export controls are grouped on the set list',async()=>{
 await mount();const originalClick=window.HTMLAnchorElement.prototype.click;const downloads=[];
 window.HTMLAnchorElement.prototype.click=function(){downloads.push(this.download);};
 globalThis.__assessmentApi.importTemplate=async(_admin,kind)=>{calls.push({template:kind});return [{kind:'skill',stable_code:'BLK-2-MAU-01',payload:{question_vi:'Mẫu nhập'},source_refs:[]}];};
 globalThis.__assessmentApi.exported=async(_admin,setId,kind,setIds)=>{calls.push({setId,kind,setIds});return [{kind:'skill',stable_code:'CDC-12-01',payload:{question_vi:'Câu hỏi'},source_refs:[]}];};
 try{
  await click('Tải mẫu nhập');assert.ok(document.querySelector('.assessment-transfer-dialog>.modal-header'));assert.ok(document.querySelector('.assessment-modal-footer .button.primary'));await click('Tải mẫu');assert.equal(calls.at(-1).template,'skill');assert.equal(downloads.at(-1),'mau-nhap-bo-cau-hoi.csv');
  await act(async()=>document.querySelector('input[name=template-format][value=json]').click());await click('Tải mẫu');assert.equal(downloads.at(-1),'mau-nhap-bo-cau-hoi.json');await click('Đóng');
  await click('Nhập tệp');assert.ok(document.querySelector('.transfer-file-picker'));assert.equal(document.querySelectorAll('.transfer-steps li').length,3);assert.ok(document.querySelector('.assessment-modal-footer'));assert.ok(button('Chọn tệp CSV / JSON'));assert.ok(document.querySelector('input[type="file"]').accept.includes('.csv'));await click('Đóng');
  await click('Xuất tệp');assert.equal(document.querySelectorAll('.transfer-formats input[type=radio]').length,2);assert.ok(document.querySelector('.assessment-modal-footer .button.primary'));const scope=document.querySelector('select[aria-label="Phạm vi xuất"]');
  await act(async()=>{scope.value='filtered';scope.dispatchEvent(new Event('change',{bubbles:true}));});
  await click('Tải tệp xuất');assert.deepEqual(calls.at(-1).setIds,['set-12']);assert.equal(calls.at(-1).kind,'skill');assert.equal(downloads.at(-1),'bo-cau-hoi.json');
 }finally{window.HTMLAnchorElement.prototype.click=originalClick;await unmount();}
});




test('edit action in set list opens the existing set information form',async()=>{
 await mount();try{
  await click('Sửa');
  const dialog=document.querySelector('[role=dialog]');
  assert.ok(dialog);assert.equal(dialog.getAttribute('aria-label'),'Sửa thông tin bộ');
  assert.ok([...dialog.querySelectorAll('input')].some(input=>input.value==='CDC'&&!input.disabled));
  assert.ok([...dialog.querySelectorAll('input')].some(input=>input.value==='cdc-12m-v1'&&input.disabled));
  assert.equal(window.location.hash,'#/assessment');assert.equal(document.querySelector('h1').textContent,'Bộ câu hỏi & Lời khuyên');assert.equal(document.querySelector('[role=tab][aria-selected=true]').textContent,'Bộ câu hỏi');assert.ok(!document.querySelector('main').textContent.includes('Câu hỏi trong bộ'));
  await click('Đóng',dialog);assert.equal(document.querySelector('[role=dialog]'),null);
 }finally{await unmount();}
});


test('saving the inline edit refreshes the list and keeps its filters and route',async()=>{
 await mount();try{
  globalThis.__assessmentApi.updateQuestionSet=async(_admin,id,body)=>{calls.push({action:'edit-set',id,body});const row=sets.find(x=>x.id===id);row.sourceName=body.sourceName;return clone(row);};
  const filter=document.querySelector('select[aria-label="Lọc trạng thái bộ"]');
  await act(async()=>{filter.value='published';filter.dispatchEvent(new Event('change',{bubbles:true}));});await flush();
  await click('Sửa');const dialog=document.querySelector('[role=dialog]');
  const field=[...dialog.querySelectorAll('input')].find(input=>!input.disabled);
  await act(async()=>{Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value').set.call(field,'Nguồn đã sửa');field.dispatchEvent(new Event('input',{bubbles:true}));});
  await click('Lưu thay đổi',dialog);
  assert.deepEqual(calls.at(-1),{action:'edit-set',id:'set-12',body:{sourceName:'Nguồn đã sửa'}});
  assert.equal(document.querySelector('[role=dialog]'),null);
  assert.equal(window.location.hash,'#/assessment');assert.equal(filter.value,'published');
  assert.ok(document.querySelector('tbody').textContent.includes('Nguồn đã sửa'));
 }finally{await unmount();}
});


test('delete link confirms soft deletion without navigating to set detail',async()=>{
 await mount();try{
  window.confirm=()=>false;await click('Xóa');assert.equal(calls.length,0);assert.equal(sets[0].deletedAt,null);
  window.confirm=()=>true;await click('Xóa');
  assert.equal(calls.at(-1).action,'delete');assert.equal(calls.at(-1).id,'set-12');
  assert.equal(window.location.hash,'#/assessment');assert.equal(document.querySelector('tbody .badge').textContent,'Đã xóa');
  assert.equal([...document.querySelector('tbody tr').lastElementChild.querySelectorAll('button')].length,0);
 }finally{window.confirm=()=>true;await unmount();}
});

test('question list uses four statuses and separates ordering from lifecycle actions',async()=>{
 await mount('/assessment/set/set-12',()=>{
  questions[0].publishedRevision=null;questions[0].isActive=false;
  questions[1].isActive=false;
 });try{
  assert.ok(document.querySelector('.detail-back').textContent.startsWith('< '));
  const filter=document.querySelector('select[aria-label="Lọc trạng thái câu"]');
  assert.deepEqual([...filter.options].map(x=>x.textContent),['Tất cả trạng thái','Ẩn','Xuất bản','Đã xóa','Nháp']);
  assert.ok(document.querySelector('thead').textContent.includes('TRẠNG THÁI'));
  assert.ok(document.querySelector('thead').textContent.includes('NGÀY CẬP NHẬT'));
  assert.ok(!document.querySelector('thead').textContent.includes('SỬ DỤNG'));
  await act(async()=>{filter.value='draft';filter.dispatchEvent(new Event('change',{bubbles:true}));});await flush();
  assert.equal(document.querySelectorAll('tbody tr').length,1);
  assert.equal(document.querySelector('tbody .badge').textContent,'Nháp');
  await click('Sắp xếp câu hỏi');assert.equal(document.querySelectorAll('tbody tr').length,2);
  assert.ok(document.querySelector('thead').textContent.includes('SẮP XẾP'));
  assert.ok(!document.querySelector('tbody').textContent.includes('xuất bản'));
  await click('Xong');assert.equal(document.querySelectorAll('tbody tr').length,1);
 }finally{await unmount();}
});

test('set detail keeps only questions and history, with all change details visible',async()=>{
 const longText='Nội dung nguồn tham khảo đầy đủ. '.repeat(40)+'Kết thúc nội dung';
 await mount('/assessment/set/set-12/review',()=>{
  globalThis.__assessmentApi.audit=async()=>[{id:'log-1',created_at:'2026-11-06T12:00:00Z',actor:'Admin',action:'update',before_data:{sourceName:'Nguồn cũ'},after_data:{sourceName:longText,custom_note:{description:'Chi tiết bổ sung đầy đủ'}}}];
 });try{
  assert.deepEqual([...document.querySelectorAll('[role=tab]')].map(x=>x.textContent.replace(/\d+$/,'').trim()),['Câu hỏi','Lịch sử']);
  assert.ok(document.querySelector('.question-content-table'));
  await click('Lịch sử');
  const panel=document.querySelector('.assessment-history-table');
  assert.ok(panel);assert.ok(panel.textContent.includes(longText));
  assert.ok(panel.textContent.includes('Nguồn cũ'));assert.ok(panel.textContent.includes('Chi tiết bổ sung đầy đủ'));
  assert.equal(panel.querySelector('details'),null);assert.ok(!panel.textContent.includes('Xem thay đổi'));
 }finally{await unmount();}
});

test('question editor groups fields and has one save bar with header action buttons',async()=>{
 await mount('/assessment/question/q-image/edit',()=>{
  questions[0].publishedRevision=null;questions[0].isActive=false;
  globalThis.__assessmentApi.createRevision=async(_admin,id,body)=>{calls.push({action:'save-revision',id,body});const row=questions.find(x=>x.id===id);row.payload=clone(body.payload);row.sourceRefs=clone(body.sourceRefs);row.currentRevision+=1;return clone(row);};
 });try{
  const header=document.querySelector('.page-heading');
  assert.ok(button('Xuất bản',header).classList.contains('primary'));assert.ok(button('Xóa',header).classList.contains('button'));
  assert.equal([...document.querySelectorAll('button')].filter(x=>x.textContent==='Lưu bản nháp').length,1);
  const editor=document.querySelector('.question-edit-layout');assert.ok(editor.querySelector('.question-edit-top'));assert.ok(editor.querySelector('.question-source-card'));
  assert.ok(button('Lưu bản nháp',editor).disabled);
  const field=editor.querySelector('.question-field-question_vi textarea');
  await act(async()=>{Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype,'value').set.call(field,'Bé có thể tự đứng vững trên sàn không?');field.dispatchEvent(new Event('input',{bubbles:true}));});await flush();
  assert.ok(button('Xuất bản',header).disabled);
  await click('Lưu bản nháp',editor);
  const saved=calls.find(x=>x.action==='save-revision');assert.equal(saved.body.payload.question_vi,'Bé có thể tự đứng vững trên sàn không?');assert.equal(saved.body.payload.media.length,1);assert.equal(saved.body.sourceRefs[0].organization,'CDC');
  assert.ok(button('Lưu bản nháp').disabled);
 }finally{await unmount();}
});

test('question history matches set history without a revision comparison tab',async()=>{
 const fullText='Chi tiết thay đổi nội dung câu hỏi. '.repeat(30)+'Kết thúc';
 await mount('/assessment/question/q-image/history',()=>{
  globalThis.__assessmentApi.audit=async()=>[{id:'question-log',created_at:'2026-11-06T12:00:00Z',actor:'Admin',action:'create_revision',before_data:{payload:{question_vi:'Câu hỏi trước'}},after_data:{payload:{question_vi:fullText}}}];
 });try{
  assert.deepEqual([...document.querySelectorAll('[role=tab]')].map(x=>x.textContent),['Chi tiết câu hỏi','Chỉnh sửa','Lịch sử']);
  const panel=document.querySelector('.assessment-history-table');assert.ok(panel);assert.ok(panel.textContent.includes(fullText));assert.ok(panel.textContent.includes('Câu hỏi trước'));assert.equal(panel.querySelector('details'),null);
  assert.ok(!document.querySelector('main').textContent.includes('So sánh phiên bản'));
  assert.ok(![...document.querySelectorAll('[role=tab]')].some(x=>x.textContent==='Phiên bản'));
 }finally{await unmount();}
});

test('create question captures complete draft, validates fields and preserves data after failure',async()=>{
 let attempts=0;
 await mount('/assessment/set/set-12',()=>{
  globalThis.__assessmentApi.createContent=async(_admin,setId,body)=>{calls.push({action:'create-content',setId,body:clone(body)});if(++attempts===1)throw new Error('Lưu thất bại, thử lại');const row={id:'q-new',questionSetId:setId,currentRevision:1,publishedRevision:null,isActive:false,deletedAt:null,...clone(body)};questions.push(row);return clone(row);};
 });try{
  await click('Thêm câu hỏi');const dialog=document.querySelector('[role=dialog]');
  assert.equal(dialog.getAttribute('aria-label'),'Thêm câu hỏi');assert.equal(dialog.querySelectorAll('input[type=radio]').length,3);
  const labels=[...dialog.querySelectorAll('label')];
  const control=name=>labels.find(label=>label.textContent.startsWith(name)).querySelector('input,textarea,select');
  async function fill(name,value){const node=control(name);await act(async()=>{const proto=node.tagName==='TEXTAREA'?window.HTMLTextAreaElement.prototype:window.HTMLInputElement.prototype;Object.getOwnPropertyDescriptor(proto,'value').set.call(node,value);node.dispatchEvent(new Event('input',{bubbles:true}));});}
  assert.ok(control('MÃ CÂU HỎI').readOnly);assert.equal(control('THỨ TỰ').value,'3');
  await act(async()=>dialog.querySelector('form').dispatchEvent(new Event('submit',{bubbles:true,cancelable:true})));await flush();assert.equal(calls.length,0);assert.ok(dialog.textContent.includes('Chọn lĩnh vực phát triển.'));
  const domain=control('LĨNH VỰC');await act(async()=>{domain.value='fine_motor';domain.dispatchEvent(new Event('change',{bubbles:true}));});
  await fill('CÂU HỎI','Bé có thể cầm đồ vật bằng hai ngón tay không?');await fill('HƯỚNG DẪN QUAN SÁT','Quan sát khi bé chơi an toàn.');await fill('TÊN KỸ NĂNG','Cầm đồ vật');await fill('VĂN BẢN ĐỌC','Quan sát kỹ năng cầm đồ vật.');
  await click('Thêm nguồn',dialog);
  const source=dialog.querySelector('.question-source-card input');await act(async()=>{Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value').set.call(source,'Tác giả nội dung');source.dispatchEvent(new Event('input',{bubbles:true}));});
  await act(async()=>dialog.querySelector('form').dispatchEvent(new Event('submit',{bubbles:true,cancelable:true})));await flush();assert.ok(dialog.textContent.includes('Lưu thất bại, thử lại'));assert.equal(control('TÊN KỸ NĂNG').value,'Cầm đồ vật');
  window.confirm=()=>false;await click('Hủy',dialog);assert.ok(document.querySelector('[role=dialog]'));window.confirm=()=>true;
  await act(async()=>dialog.querySelector('form').dispatchEvent(new Event('submit',{bubbles:true,cancelable:true})));await flush();
  const body=calls.at(-1).body;assert.equal(body.orderIndex,3);assert.match(body.stableCode,/^BLK-12-/);assert.equal(body.appDomain,'fine_motor');assert.equal(body.sourceDomain,'movement_physical');assert.equal(body.payload.source_name,'app_authored');assert.equal(body.payload.skill_name,'Cầm đồ vật');assert.equal(body.payload.answer_options.length,3);assert.equal(body.sourceRefs[0].organization,'Tác giả nội dung');assert.equal(window.location.hash,'#/assessment/question/q-new/edit');
 }finally{window.confirm=()=>true;await unmount();}
});

test('advice uses unified states and list/detail/edit/history layouts without redundant tools',async()=>{
 await mount('/assessment-advice',()=>{
  const codes=['CONTACT_REGRESSION_YES','CONTACT_REGRESSION_UNSURE','CONTACT_NOT_YET','CONTACT_CONCERN_ONLY','OBSERVE_UNCHECKED','CONTINUE_MONITORING'];
  const advice=codes.map((code,i)=>({id:`a-${i}`,kind:'advice',stableCode:code,currentRevision:1,publishedRevision:i===0?null:1,isActive:i===1,deletedAt:i===3?'2026-11-06T00:00:00Z':null,updatedAt:'2026-11-06T00:00:00Z',sourceRefs:[{organization:'CDC'}],payload:{title:`Lời khuyên ${i+1}`,body_text:'Nội dung hướng dẫn phụ huynh.',tts_text:'Văn bản đọc lời khuyên.',cta_label:'Xem hướng dẫn',variant_id:code,variant_priority:i,match_condition:'fixed condition',action_kind:'contact_healthcare'}}));
  questions.push(...advice);globalThis.__assessmentApi.listAdvice=async()=>clone(questions.filter(x=>x.kind==='advice'));
  globalThis.__assessmentApi.createRevision=async(_a,id,body)=>{calls.push({action:'save-advice',id,body:clone(body)});const row=questions.find(x=>x.id===id);row.payload=clone(body.payload);row.sourceRefs=clone(body.sourceRefs);row.currentRevision++;return clone(row);};
  globalThis.__assessmentApi.audit=async()=>[{id:'a-log',created_at:'2026-11-06T00:00:00Z',actor:'Admin',action:'create_revision',before_data:{title:'Cũ'},after_data:{title:'Mới'}}];
 });try{
  assert.deepEqual([...document.querySelectorAll('thead th')].map(x=>x.textContent),['MẪU LỜI KHUYÊN','ÁP DỤNG KHI','PHIÊN BẢN','TRẠNG THÁI','NGÀY CẬP NHẬT','THAO TÁC']);
  const filter=document.querySelector('[aria-label="Lọc trạng thái mẫu lời khuyên"]');assert.deepEqual([...filter.options].map(x=>x.textContent),['Tất cả','Ẩn','Xuất bản','Đã xóa','Nháp']);
  assert.ok(!document.querySelector('main').textContent.includes('Nhập tệp'));assert.ok(![...document.querySelectorAll('button')].some(x=>x.textContent==='Xóa'));
  let row=[...document.querySelectorAll('tbody tr')].find(x=>x.textContent.includes('Lời khuyên 1'));
  assert.equal(row.querySelector('.badge').textContent,'Nháp');await click('xuất bản',row);assert.equal(calls.at(-1).action,'release');
  row=[...document.querySelectorAll('tbody tr')].find(x=>x.textContent.includes('Lời khuyên 1'));assert.equal(row.querySelector('.badge').textContent,'Xuất bản');await click('Ẩn',row);
  row=[...document.querySelectorAll('tbody tr')].find(x=>x.textContent.includes('Lời khuyên 1'));assert.equal(row.querySelector('.badge').textContent,'Ẩn');await click('Sửa',row);assert.equal(window.location.hash,'#/assessment/advice/a-0/edit');
  assert.deepEqual([...document.querySelectorAll('[role=tab]')].map(x=>x.textContent),['Chi tiết mẫu lời khuyên','Chỉnh sửa','Lịch sử']);assert.equal(document.querySelectorAll('button').length>0,true);
  const title=document.querySelector('.question-field-title textarea');await act(async()=>{Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype,'value').set.call(title,'Tiêu đề lời khuyên mới');title.dispatchEvent(new Event('input',{bubbles:true}));});await click('Lưu bản nháp');
  const saved=calls.find(x=>x.action==='save-advice');assert.equal(saved.body.payload.match_condition,'fixed condition');assert.equal(saved.body.payload.action_kind,'contact_healthcare');assert.equal(saved.body.payload.title,'Tiêu đề lời khuyên mới');
  await click('Lịch sử');assert.ok(document.querySelector('.assessment-history-table'));assert.equal(document.querySelector('.assessment-history-table details'),null);
 }finally{await unmount();}
});

test('combined assessment menu switches between sets and advice with one active entry',async()=>{
 await mount('/assessment');try{
  assert.equal(document.querySelector('h1').textContent,'Bộ câu hỏi & Lời khuyên');
  assert.deepEqual([...document.querySelectorAll('[role=tab]')].map(x=>x.textContent),['Bộ câu hỏi','Lời khuyên']);
  await click('Lời khuyên');assert.equal(window.location.hash,'#/assessment/advice');
  assert.equal(document.querySelector('[role=tab][aria-selected=true]').textContent,'Lời khuyên');assert.ok(document.querySelector('.advice-list-table'));
  assert.equal(document.querySelectorAll('.nav-item.active').length,1);assert.equal(document.querySelector('.nav-item.active span').textContent,'Bộ câu hỏi & Lời khuyên');
  assert.ok(!document.querySelector('.breadcrumb').textContent.includes('Chi tiết'));
  await click('Bộ câu hỏi');assert.equal(window.location.hash,'#/assessment');assert.ok(document.querySelector('.question-set-table'));
 }finally{await unmount();}
});

test('result preview explains parent inputs and sends the selected simulation values',async()=>{
 await mount('/assessment/advice',()=>{
  globalThis.__assessmentApi.request=async(_admin,path,method,body)=>{calls.push({path,method,body});return {sections:{overview:{achieved:2,not_yet:0,not_observed:0},skills_to_note:{total:0,has_more:false},next_steps:{advice_items:[],tts_text:''}},disclaimer:'Dữ liệu giả lập'};};
 });try{
  await click('Thử kết quả đánh giá');const dialog=document.querySelector('[role=dialog]');
  const set=dialog.querySelector('[aria-label="Chọn bộ câu hỏi để thử"]');await act(async()=>{set.value='set-12';set.dispatchEvent(new Event('change',{bubbles:true}));});await flush();
  assert.ok(dialog.textContent.includes('Bé có mất kỹ năng từng làm được không?'));assert.ok(dialog.textContent.includes('Phụ huynh có lo ngại về sự phát triển của bé không?'));assert.ok(dialog.textContent.includes('chưa chọn kỹ năng cụ thể'));assert.ok(dialog.textContent.includes('chưa nhập nội dung lo ngại cụ thể'));
  const regression=dialog.querySelector('#preview-regression'),concern=dialog.querySelector('#preview-concern');
  assert.deepEqual([...regression.options].map(x=>x.textContent),['Không','Có','Chưa chắc']);assert.equal(concern.options.length,2);
  await act(async()=>{regression.value='unsure';regression.dispatchEvent(new Event('change',{bubbles:true}));concern.value='yes';concern.dispatchEvent(new Event('change',{bubbles:true}));});await click('Xem kết quả thử',dialog);
  assert.equal(calls.at(-1).body.regression,'unsure');assert.equal(calls.at(-1).body.caregiver_concern,'yes');assert.equal(calls.at(-1).path,'/preview-result');assert.deepEqual(Object.values(calls.at(-1).body.answers),['achieved','achieved']);
 }finally{await unmount();}
});

test('removed skill advice routes show situational templates without skill editors',async()=>{
 for(const path of ['/assessment/advice/skills','/assessment/advice/skills/q-image/edit']){
  await mount(path);try{
   assert.ok(!document.querySelector('.skill-guidance-table'));
   assert.ok(!document.body.textContent.includes('Theo kỹ năng'));
   assert.ok(document.body.textContent.includes('Thử kết quả đánh giá'));
  }finally{await unmount();}
 }
 await mount('/assessment/question/q-image/edit');try{
  assert.ok(!document.body.textContent.includes('GIẢI THÍCH KỸ NĂNG'));
  assert.ok(!document.body.textContent.includes('Thêm bước hỗ trợ'));
 }finally{await unmount();}
});

test('preview renders one next steps section with situational advice only',async()=>{
 await mount('/assessment/advice',()=>{
  globalThis.__assessmentApi.request=async()=>({sections:{overview:{achieved:1,not_yet:1,not_observed:0},skills_to_note:{total:1,all:[{question_id:'q1',skill_name:'Kỹ năng thử',status:'not_yet'}]},next_steps:{advice_items:[{variant_id:'CONTACT_NOT_YET',title:'Hướng xử lý chung',body_text:'Nội dung chung đã biên soạn.'}],skill_guidance:[{question_id:'q1',skill_name:'Kỹ năng thử',status:'not_yet',domain:'gross_motor',comment:'Nhận xét đã biên soạn.',explanation:'Giải thích chuyên sâu thử nghiệm.',how_to_observe:'Cách quan sát thử nghiệm.',support_steps:['Hỗ trợ bước một.','Hỗ trợ bước hai.'],discussion_points:'Điều cần ghi lại.',source_refs:[{organization:'Nguồn kiểm thử'}],extended_content_complete:true,revision:2,content_id:'q-image'}],tts_text:'Văn bản đọc.'}},preview_diagnostics:{selected_templates:[{variant_id:'CONTACT_NOT_YET',reason:'Có kỹ năng chưa làm được'}],missing_extended_guidance:[]},disclaimer:'Kết quả giả lập'});
 });try{
  await click('Thử kết quả đánh giá');const dialog=document.querySelector('[role=dialog]'),select=dialog.querySelector('[aria-label="Chọn bộ câu hỏi để thử"]');await act(async()=>{select.value='set-12';select.dispatchEvent(new Event('change',{bubbles:true}));});await flush();await click('Xem kết quả thử',dialog);
  assert.equal([...dialog.querySelectorAll('h3')].filter(x=>x.textContent==='Hướng dẫn tiếp theo').length,1);
  const next=dialog.querySelector('[aria-label="Hướng dẫn tiếp theo"]');assert.ok(next.textContent.includes('Nội dung chung đã biên soạn.'));for(const text of ['Giải thích chuyên sâu thử nghiệm.','Hỗ trợ bước một.','Điều cần ghi lại.','Nguồn kiểm thử'])assert.ok(!next.textContent.includes(text));
  const summary=dialog.querySelector('[aria-label="Kỹ năng cần chú ý"]');assert.ok(!summary.textContent.includes('Hỗ trợ bước một.'));assert.ok(dialog.querySelector('.preview-diagnostics').textContent.includes('Có kỹ năng chưa làm được'));
 }finally{await unmount();}
});

test('preview discards a response when the simulated inputs changed during the request',async()=>{
 let finish;
 await mount('/assessment/advice',()=>{globalThis.__assessmentApi.request=()=>new Promise(resolve=>{finish=resolve;});});try{
  await click('Thử kết quả đánh giá');const dialog=document.querySelector('[role=dialog]'),set=dialog.querySelector('[aria-label="Chọn bộ câu hỏi để thử"]');await act(async()=>{set.value='set-12';set.dispatchEvent(new Event('change',{bubbles:true}));});await flush();await click('Xem kết quả thử',dialog);assert.ok(finish);
  const concern=dialog.querySelector('#preview-concern');await act(async()=>{concern.value='yes';concern.dispatchEvent(new Event('change',{bubbles:true}));});await flush();
  await act(async()=>finish({sections:{overview:{achieved:2,not_yet:0,not_observed:0},skills_to_note:{total:0},next_steps:{advice_items:[],tts_text:''}}}));await flush();assert.equal(dialog.querySelector('.assessment-preview-result'),null);assert.equal(button('Xem kết quả thử',dialog).disabled,false);
 }finally{await unmount();}
});

test('preview hides an advice card whose repeated body was fully removed',async()=>{
 await mount('/assessment/advice',()=>{globalThis.__assessmentApi.request=async()=>({sections:{overview:{achieved:2,not_yet:0,not_observed:0},skills_to_note:{total:0},next_steps:{advice_items:[{variant_id:'A',title:'Hướng dẫn chính',body_text:'Nội dung duy nhất.'},{variant_id:'B',title:'Thẻ đã bị loại vì trùng',body_text:''}],tts_text:'Nội dung duy nhất.'}}});});try{
  await click('Thử kết quả đánh giá');const dialog=document.querySelector('[role=dialog]'),set=dialog.querySelector('[aria-label="Chọn bộ câu hỏi để thử"]');await act(async()=>{set.value='set-12';set.dispatchEvent(new Event('change',{bubbles:true}));});await flush();await click('Xem kết quả thử',dialog);
  assert.equal(dialog.querySelectorAll('.preview-general-advice article').length,1);assert.ok(!dialog.querySelector('.preview-next-steps').textContent.includes('Thẻ đã bị loại vì trùng'));
 }finally{await unmount();}
});

test('mixed result shows one ordered plan and all parent signals without concatenating template articles',async()=>{
 await mount('/assessment/advice',()=>{globalThis.__assessmentApi.request=async()=>({sections:{overview:{achieved:0,not_yet:1,not_observed:1},skills_to_note:{total:2,all:[]},next_steps:{advice_items:[{variant_id:'CONTACT',title:'Không ghép tiêu đề này',body_text:'Nội dung thừa của mẫu nguyên bài.'}],action_plan:{facts:[{id:'not_yet',text:'Có kỹ năng chưa làm được.'},{id:'not_observed',text:'Có kỹ năng chưa được quan sát.'},{id:'regression_yes',text:'Phụ huynh báo mất kỹ năng.'},{id:'caregiver_concern',text:'Phụ huynh có lo ngại.'}],actions:[{id:'contact',title:'Trao đổi với bác sĩ',body:'Hành động chính.',items:[]},{id:'prepare',title:'Chuẩn bị thông tin trao đổi',body:'',items:['Ghi thay đổi.','Ghi điều lo ngại.']},{id:'observe',title:'Bổ sung quan sát',body:'Cập nhật khi có thông tin.',items:[]}],observation_timing:'Có thể bổ sung quan sát song song.'},tts_text:'Văn bản đọc.'}}});});try{
  await click('Thử kết quả đánh giá');const dialog=document.querySelector('[role=dialog]'),set=dialog.querySelector('[aria-label="Chọn bộ câu hỏi để thử"]');await act(async()=>{set.value='set-12';set.dispatchEvent(new Event('change',{bubbles:true}));});await flush();await click('Xem kết quả thử',dialog);
  const next=dialog.querySelector('[aria-label="Hướng dẫn tiếp theo"]');assert.deepEqual([...next.querySelectorAll('[data-action]')].map(x=>x.dataset.action),['contact','prepare','observe']);assert.equal(next.querySelectorAll('[data-signal]').length,0);assert.ok(!next.textContent.includes('Phụ huynh báo mất kỹ năng.'));assert.ok(!next.textContent.includes('Phụ huynh có lo ngại.'));assert.equal(next.querySelector('[data-signal=not_yet]'),null);assert.equal(next.querySelector('[data-signal=not_observed]'),null);assert.ok(!next.textContent.includes('Nội dung thừa của mẫu nguyên bài.'));assert.equal(next.querySelectorAll('h3').length,1);assert.equal(next.querySelectorAll('[data-action=contact]').length,1);assert.equal(next.querySelectorAll('h4,h5,ol').length,0);assert.equal(next.querySelectorAll('ul').length,1);assert.deepEqual([...next.querySelectorAll('[data-action=prepare] li')].map(item=>item.textContent),['Ghi thay đổi.','Ghi điều lo ngại.']);assert.equal(next.querySelector('[data-action=contact]').tagName,'P');
 }finally{await unmount();}
});

test('skill answer presets preserve both parent flags and parent presets preserve skill answers',async()=>{
 await mount('/assessment/advice',()=>{globalThis.__assessmentApi.request=async(_a,path,method,body)=>{calls.push({body});return {sections:{overview:{achieved:0,not_yet:1,not_observed:1},skills_to_note:{total:0},next_steps:{advice_items:[],tts_text:''}}};};});try{
  await click('Thử kết quả đánh giá');const dialog=document.querySelector('[role=dialog]'),set=dialog.querySelector('[aria-label="Chọn bộ câu hỏi để thử"]');await act(async()=>{set.value='set-12';set.dispatchEvent(new Event('change',{bubbles:true}));});await flush();
  const selected=label=>{const node=button(label,dialog);assert.equal(node.getAttribute('aria-pressed'),'true');assert.ok(node.classList.contains('primary'));};
  selected('Đã làm được hết');
  await click('Có mất kỹ năng từng làm được',dialog);await click('Có lo ngại về phát triển',dialog);await click('Có kỹ năng chưa làm và chưa quan sát',dialog);
  selected('Có kỹ năng chưa làm và chưa quan sát');selected('Có mất kỹ năng từng làm được');selected('Có lo ngại về phát triển');
  assert.equal(button('Đã làm được hết',dialog).getAttribute('aria-pressed'),'false');
  assert.equal(dialog.querySelector('#preview-regression').value,'yes');assert.equal(dialog.querySelector('#preview-concern').value,'yes');
  await click('Chưa chắc về mất kỹ năng',dialog);await click('Xem kết quả thử',dialog);assert.deepEqual(Object.values(calls.at(-1).body.answers),['not_yet','not_observed']);assert.equal(calls.at(-1).body.regression,'unsure');assert.equal(calls.at(-1).body.caregiver_concern,'yes');
  selected('Chưa chắc về mất kỹ năng');selected('Có lo ngại về phát triển');assert.equal(button('Có mất kỹ năng từng làm được',dialog).getAttribute('aria-pressed'),'false');
  const answer=dialog.querySelector('.assessment-answer select');await act(async()=>{answer.value='not_observed';answer.dispatchEvent(new Event('change',{bubbles:true}));});
  assert.equal(dialog.querySelectorAll('.preview-scenarios [aria-pressed="true"]').length,0);
  const parent=dialog.querySelector('#preview-concern');await act(async()=>{parent.value='no';parent.dispatchEvent(new Event('change',{bubbles:true}));});assert.equal(button('Có lo ngại về phát triển',dialog).getAttribute('aria-pressed'),'false');selected('Chưa chắc về mất kỹ năng');
  await click('Đặt lại toàn bộ',dialog);assert.equal(dialog.querySelector('#preview-regression').value,'no');assert.equal(dialog.querySelector('#preview-concern').value,'no');
  selected('Đã làm được hết');assert.equal(dialog.querySelectorAll('.preview-parent-presets [aria-pressed="true"]').length,0);
 }finally{await unmount();}
});

test('general commentary precedes next steps, shows sources and never leaks into instructions',async()=>{
 await mount('/assessment/advice',()=>{globalThis.__assessmentApi.request=async()=>({sections:{overview:{achieved:1,not_yet:1,not_observed:0},skills_to_note:{total:1,all:[]},overall_comment:{paragraphs:[{id:'interpretation',text:'Nhận xét có căn cứ về thông tin được ghi nhận.'},{id:'professional',text:'Cần trao đổi với bác sĩ hoặc nhân viên y tế có chuyên môn.'}],domain_observations:[{domain:'gross_motor',text:'Vận động thô: 1 kỹ năng chưa làm được.'}],sources:[{id:'cdc',organization:'CDC',title:'Developmental Monitoring and Screening',url:'https://www.cdc.gov/act-early/about/developmental-monitoring-and-screening.html'}],tts_text:'Văn bản nhận xét.'},next_steps:{advice_items:[],action_plan:{actions:[{id:'contact',body:'Hướng dẫn hành động.',items:[]}],observation_timing:''},tts_text:'Văn bản hướng dẫn.'}},disclaimer:'Phạm vi nhận xét.'});});try{
  await click('Thử kết quả đánh giá');const dialog=document.querySelector('[role=dialog]'),set=dialog.querySelector('[aria-label="Chọn bộ câu hỏi để thử"]');await act(async()=>{set.value='set-12';set.dispatchEvent(new Event('change',{bubbles:true}));});await flush();await click('Xem kết quả thử',dialog);
  const comment=dialog.querySelector('[aria-label="Nhận xét chung"]'),next=dialog.querySelector('[aria-label="Hướng dẫn tiếp theo"]');assert.ok(comment);assert.ok(comment.textContent.includes('nhân viên y tế có chuyên môn'));assert.equal(comment.querySelector('a').hostname,'www.cdc.gov');assert.ok(!comment.textContent.includes('Vận động thô'));
  const sections=[...dialog.querySelectorAll('.assessment-preview-result > section')];assert.ok(sections.indexOf(comment)<sections.indexOf(next));assert.ok(!next.textContent.includes('Nhận xét có căn cứ'));assert.ok(next.textContent.includes('Hướng dẫn hành động.'));
 }finally{await unmount();}
});
