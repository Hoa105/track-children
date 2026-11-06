import React, { useEffect, useState } from 'react';
import { Panel } from '../../shared/ui.jsx';
import { OPTIONS } from './model.js';

export function mediaEntries(payload = {}) {
  const raw = Array.isArray(payload.media) ? payload.media : payload.media ? [payload.media] : [];
  return raw.filter(entry => entry && entry.type !== 'none').map(entry => ({
    ...entry,
    type: entry.type === 'video' ? 'youtube' : entry.type,
    url: entry.url || entry.media_embed_url || entry.media_direct_url || '',
    youtube_id: entry.youtube_id || entry.youtube_video_id || '',
  }));
}

export function MediaPreview({ media }) {
  const [failed, setFailed] = useState(false);
  useEffect(() => setFailed(false), [media.url]);
  let safe = false;
  try {
    const url = new URL(media.url);
    safe = url.protocol === 'https:' && !url.username && !url.password &&
      ['cdc.gov', 'youtube.com', 'youtube-nocookie.com', 'youtu.be'].some(domain => url.hostname === domain || url.hostname.endsWith(`.${domain}`));
  } catch { /* The draft URL may still be incomplete. */ }
  if (!safe) return <p className="detail-alert">Chưa có liên kết ảnh/video hợp lệ.</p>;
  if (failed) return <p className="detail-alert">Không tải được ảnh. Xem hướng dẫn bằng văn bản bên trên.</p>;
  if (media.type === 'youtube') {
    if (!/^[A-Za-z0-9_-]{11}$/.test(media.youtube_id || '')) return <p className="detail-alert">Video chưa có YouTube ID hợp lệ.</p>;
    return <figure className="assessment-media-figure">
      <iframe className="assessment-video" src={`https://www.youtube-nocookie.com/embed/${media.youtube_id}`} title={media.alt || 'Video hướng dẫn kỹ năng'} allowFullScreen />
      <figcaption>{media.alt || 'Video hướng dẫn'}{media.attribution && ` · ${media.attribution}`}</figcaption>
      <p className="panel-note">Video không tự phát. Nếu bị chặn, dùng hướng dẫn văn bản.</p>
    </figure>;
  }
  return <figure className="assessment-media-figure">
    <img className="assessment-media" src={media.url} alt={media.alt || 'Ảnh hướng dẫn kỹ năng'} onError={() => setFailed(true)} />
    <figcaption>{media.alt || 'Ảnh hướng dẫn'}{media.attribution && ` · ${media.attribution}`}</figcaption>
  </figure>;
}

export function QuestionPreview({ payload, title = 'Nội dung câu hỏi' }) {
  const [selected, setSelected] = useState('');
  const media = mediaEntries(payload);
  return <Panel title={title} subtitle="Nội dung hiển thị cho phụ huynh">
    <div className="assessment-question-text">{payload.question_vi || payload.prompt || 'Chưa nhập nội dung câu hỏi'}</div>
    <h3 className="assessment-section-label">Hướng dẫn quan sát</h3>
    <p className="assessment-prose">{payload.instruction_vi || payload.observation_guide || 'Chưa nhập hướng dẫn quan sát.'}</p>
    {payload.safety_note && <div className="detail-alert"><b>Lưu ý an toàn:</b> {payload.safety_note}</div>}
    <h3 className="assessment-section-label">Ảnh / video hướng dẫn</h3>
    {media.length ? media.map((entry, index) => <MediaPreview key={`${entry.url}-${index}`} media={entry} />) : <p className="panel-note">Câu hỏi này chỉ có hướng dẫn bằng văn bản.</p>}
    <fieldset className="assessment-answer-options"><legend>Ba phương án trả lời</legend>
      {OPTIONS.map(option => <label key={option.value}>
        <input type="radio" name="question-preview-answer" value={option.value} checked={selected === option.value} onChange={() => setSelected(option.value)} />
        <span>{option.label}</span>
      </label>)}
    </fieldset>
    <p className="panel-note">Chọn thử để xem giao diện; không lưu câu trả lời.</p>
  </Panel>;
}

export function MediaEditor({ media, onChange }) {
  const update = (index, key, value) => onChange(media.map((entry, i) => i === index ? { ...entry, [key]: value } : entry));
  return <Panel title="Ảnh / video hướng dẫn" subtitle="Không bắt buộc có media. Giữ hướng dẫn văn bản khi ảnh/video không tải được.">
    {!media.length && <p className="table-empty">Chưa có ảnh hoặc video.</p>}
    {media.map((entry, index) => <div className="assessment-media-editor" key={index}>
      <div className="question-source-card-heading"><b>Ảnh / video {index + 1}</b><button type="button" className="link-button danger" aria-label={`Bỏ ảnh / video ${index + 1}`} onClick={() => onChange(media.filter((_, i) => i !== index))}>Bỏ ảnh / video</button></div>
      <div className="edit-form question-edit-fields">
        <label>LOẠI MEDIA<select value={entry.type} onChange={event => update(index, 'type', event.target.value)}><option value="image">Ảnh CDC</option><option value="youtube">Video YouTube</option></select></label>
        {[
          ['url', 'LIÊN KẾT ẢNH / VIDEO'],
          ...(entry.type === 'youtube' ? [['youtube_id', 'YOUTUBE ID (11 KÝ TỰ)']] : []),
          ['source_page', 'TRANG NGUỒN CDC'], ['alt', 'MÔ TẢ ẢNH / VIDEO'], ['attribution', 'GHI CÔNG NGUỒN'],
        ].map(([key, label]) => <label key={key}>{label}<input value={entry[key] || ''} onChange={event => update(index, key, event.target.value)} /></label>)}
      </div>
      <MediaPreview media={entry} />
    </div>)}
    <div className="question-section-actions"><button type="button" className="button secondary" disabled={media.length >= 5} onClick={() => onChange([...media, { type: 'image', url: '', alt: '', attribution: '', rights_status: 'pending' }])}>Thêm ảnh / video</button><span className="question-field-hint">{media.length}/5 ảnh / video</span></div>
  </Panel>;
}
