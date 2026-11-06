import React from 'react';
import { VARIANT_LABELS } from './model.js';
import { SpeakButton } from './components.jsx';

export default function ResultPreviewView({ view }) {
  const overview = view.sections.overview;
  const skills = view.sections.skills_to_note;
  const commentary = view.sections.overall_comment;
  const next = view.sections.next_steps;
  const plan = next.action_plan;
  const diagnostics = view.preview_diagnostics;
  return <div className="development-preview-result">
    <section aria-label="Tổng quan kết quả"><h3>Tổng quan</h3><div className="preview-counts">{[['achieved','Đã làm được'],['not_yet','Chưa làm được'],['not_observed','Chưa quan sát']].map(([key,label]) => <div key={key}><b>{overview[key]}</b><span>{label}</span></div>)}</div></section>
    <section aria-label="Kỹ năng cần chú ý"><h3>Kỹ năng cần chú ý</h3>{skills.total ? <ul className="preview-skill-summary">{(skills.all || skills.preview || []).map(skill => <li key={skill.question_id}><b>{skill.skill_name}</b><span>{skill.status === 'not_yet' ? 'Chưa làm được' : 'Chưa quan sát'}</span></li>)}</ul> : <p>Không có kỹ năng chưa làm được hoặc chưa được quan sát trong tình huống này.</p>}</section>
    {commentary && <section className="preview-overall-comment" aria-label="Nhận xét chung"><h3>Nhận xét chung</h3>
      {commentary.paragraphs.map(paragraph => <p key={paragraph.id}>{paragraph.text}</p>)}
      <div className="question-section-actions"><SpeakButton text={commentary.tts_text} /></div>
      <details className="commentary-sources"><summary>Căn cứ biên soạn nhận xét</summary><p>Nội dung tiếng Việt được biên soạn tham khảo tài liệu dưới đây; số liệu mô tả được lấy từ câu trả lời trong lần theo dõi này.</p><ul>{commentary.sources.map(source => <li key={source.id}><a href={source.url} target="_blank" rel="noreferrer">{source.organization} — {source.title}</a></li>)}</ul></details>
    </section>}
    <section className="preview-next-steps" aria-label="Hướng dẫn tiếp theo"><h3>Hướng dẫn tiếp theo</h3>
      {plan ? <div className="preview-guidance-prose">
        {plan.actions.map(action => action.id === 'prepare' && action.items?.length > 0 ? <div key={action.id} data-action={action.id}><p>Khi gặp bác sĩ, bạn nên chuẩn bị:</p>{action.body && <p>{action.body}</p>}<ul className="preview-preparation-list">{action.items.map((text, index) => <li key={index}>{text}</li>)}</ul></div> : <p key={action.id} data-action={action.id}>{[action.body, ...(action.items || [])].filter(Boolean).join(' ')}</p>)}
        {plan.observation_timing && <p>{plan.observation_timing}</p>}
      </div> : <div className="preview-general-advice preview-guidance-prose">{next.advice_items.filter(item => item.body_text?.trim()).map(item => <article key={item.variant_id}><p>{item.body_text}</p></article>)}</div>}


      <div className="question-section-actions"><SpeakButton text={next.tts_text} /></div>
    </section>
    {!commentary && <p className="preview-help">{view.disclaimer}</p>}
    {diagnostics && <details className="preview-diagnostics"><summary>Thông tin kiểm tra dành cho Admin</summary><p>Phần này không hiển thị trong kết quả trên app.</p><h4>Mẫu tình huống được chọn</h4><ul>{diagnostics.selected_templates.map(item => <li key={item.variant_id}>{item.reason}</li>)}</ul>{diagnostics.preparation_variants?.length > 0 && <><h4>Thông tin chuẩn bị được kết hợp</h4><ul>{diagnostics.preparation_variants.map(code => <li key={code}>{VARIANT_LABELS[code] || code}</li>)}</ul></>}
    </details>}
  </div>;
}
