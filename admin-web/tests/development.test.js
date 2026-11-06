import assert from 'node:assert/strict';
import test from 'node:test';
import {editorPayload,parseImport,download,OPTIONS} from '../src/features/development/model.js';

test('CSV export and import preserve the question set source name',async()=>{
 const originalDocument=globalThis.document,createURL=URL.createObjectURL;let blob;
 globalThis.document={createElement:()=>({click(){}})};
 URL.createObjectURL=value=>{blob=value;return createURL(value);};
 try{
  download([{kind:'skill',stable_code:'BLK-2-TEST',set_source_name:'Nguồn bộ, "bản thử"',payload:{question_vi:'Câu hỏi'},source_refs:[]}],'csv','test');
  const rows=parseImport(await blob.text(),'test.csv');
  assert.equal(rows[0].set_source_name,'Nguồn bộ, "bản thử"');
 }finally{URL.createObjectURL=createURL;if(originalDocument===undefined)delete globalThis.document;else globalThis.document=originalDocument;}
});
test('editing preserves all skill comments, unknown fields and every media entry',()=>{
 const original={question_vi:'A question',skill_name:'Skill',not_yet_comment:'Not yet',not_observed_comment:'Unobserved',observation_guide:'Observe',custom:{version:2},media:[{type:'image',url:'https://www.cdc.gov/a.png'},{type:'youtube',youtube_id:'abcdefghijk'}]};
 const draft=editorPayload(original);assert.equal(draft.media.length,2);assert.equal(draft.not_yet_comment,'Not yet');assert.deepEqual(draft.custom,{version:2});draft.media[0].url='changed';assert.notEqual(original.media[0].url,'changed');
});
test('legacy object media and prompt remain editable without dropping original metadata',()=>{const draft=editorPayload({prompt:'Legacy prompt',answerOptions:['A','B','C'],media:{type:'image',url:'url',rights_status:'pending'}});assert.equal(draft.question_vi,'Legacy prompt');assert.equal(draft.prompt,'Legacy prompt');assert.equal(draft.media[0].rights_status,'pending');assert.deepEqual(draft.answer_options.map(x=>x.value),OPTIONS.map(x=>x.value));});
test('advice roundtrip preserves locked routing metadata',()=>{const input={variant_id:'CONTACT_NOT_YET',variant_priority:3,match_condition:'not_yet_count >= 1',action_kind:'contact_healthcare',title:'Title'};assert.deepEqual(editorPayload(input,'advice'),input);});
test('CSV import preserves Vietnamese, embedded quotes, commas and newlines',()=>{const rows=parseImport('\ufeffkind,stable_code,payload,source_refs\r\nskill,BLK-12-A,"{""question_vi"":""Bé, nói \\n thêm""}","[]"','test.csv');assert.equal(rows.length,1);assert.equal(JSON.parse(rows[0].payload).question_vi,'Bé, nói \n thêm');assert.equal(rows[0].source_refs,'[]');});
test('malformed CSV quotes fail before any import request',()=>{assert.throws(()=>parseImport('kind,payload\nskill,"unfinished','test.csv'));});
test('development navigation has one combined question and advice entry',async()=>{const {allNavItems}=await import('../src/app/navigation.js');const entries=allNavItems.filter(x=>x.path.startsWith('/development'));assert.deepEqual(entries.map(x=>x.label),['Bộ câu hỏi & Lời khuyên']);assert.deepEqual(entries.map(x=>x.path),['/development']);});


test('question status follows app visibility while keeping unpublished edits separate',async()=>{
 const {questionState,questionVersion}=await import('../src/features/development/model.js');
 const row={publishedRevision:1,currentRevision:2,isActive:true,deletedAt:null};
 assert.equal(questionState(row),'published');assert.equal(questionVersion(row),'App v1 · Nháp v2');
 assert.equal(questionState({...row,isActive:false}),'hidden');
 assert.equal(questionState({...row,publishedRevision:null}),'draft');
 assert.equal(questionState({...row,deletedAt:'2026-11-06'}),'deleted');
});
