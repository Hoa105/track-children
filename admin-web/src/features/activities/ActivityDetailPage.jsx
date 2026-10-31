import React, { useEffect, useRef, useState } from "react";
import { useAuth } from "../../core/auth.jsx";
import { backendUrl } from "../../core/http.js";
import { navigate } from "../../core/useHashRoute.js";
import Icon from "../../shared/Icon.jsx";
import { blankToNull, numberOrNull, useFields } from "../../shared/form.jsx";
import { Badge, Panel } from "../../shared/ui.jsx";
import * as api from "./activitiesApi.js";

// Soạn 1 hoạt động: thông tin chung, các bước (kèm ảnh minh họa), thư viện ảnh.
// Mỗi khối lưu riêng; mobile thấy thay đổi ngay nếu hoạt động đang xuất bản.
export default function ActivityDetailPage({ id, onNotify }) {
  const { admin } = useAuth();
  const [activity, setActivity] = useState(null);
  const [groups, setGroups] = useState([]);
  const [error, setError] = useState("");

  useEffect(() => {
    Promise.all([api.getActivity(admin, id), api.listGroups(admin)])
      .then(([nextActivity, nextGroups]) => { setActivity(nextActivity); setGroups(nextGroups); })
      .catch((problem) => setError(problem.message));
  }, [id]);

  // Chạy 1 thao tác trả về hoạt động đã cập nhật; lỗi hiện ở toast
  async function run(action, message) {
    try {
      setActivity(await action());
      onNotify(message);
      return true;
    } catch (problem) {
      onNotify(problem.message);
      return false;
    }
  }

  const back = <button className="breadcrumb-link detail-back" onClick={() => navigate("/activities")}><Icon name="arrow" size={13} /> Danh sách hoạt động</button>;
  if (error) return <div>{back}<div className="panel empty-state"><h2>Không tải được hoạt động</h2><p>{error}</p></div></div>;
  if (!activity) return <div>{back}<p className="subtitle">Đang tải…</p></div>;

  const status = api.STATUS[activity.status];
  const setStatus = (next, message) => run(() => api.updateActivity(admin, id, { status: next }), message);

  return <div>
    {back}
    <div className="detail-header">
      {activity.thumbnailUrl ? <img className="detail-thumb" src={backendUrl(activity.thumbnailUrl)} alt="" /> : <span className="detail-thumb thumb-empty"><Icon name="spark" size={22} /></span>}
      <div className="detail-title"><h1>{activity.title}</h1><p>{activity.ageFromMonths}–{activity.ageToMonths} tháng · {groups.find((g) => g.id === activity.groupId)?.name ?? "Chưa có nhóm"} · cập nhật {new Date(activity.updatedAt).toLocaleString("vi-VN")}</p></div>
      <Badge tone={status.tone}>{status.label}</Badge>
      <div className="heading-actions">
        {activity.status !== "published" && <button className="button primary" onClick={() => setStatus("published", "Đã xuất bản — mobile đã thấy hoạt động này")}><Icon name="check" size={15} /> Xuất bản</button>}
        {activity.status === "published" && <button className="button secondary danger" onClick={() => setStatus("hidden", "Đã ẩn khỏi mobile")}>Ẩn khỏi mobile</button>}
        {activity.status !== "draft" && <button className="button secondary" onClick={() => setStatus("draft", "Đã chuyển về nháp")}>Chuyển về nháp</button>}
      </div>
    </div>
    {activity.status === "draft" && <div className="detail-alert info">Bản nháp: mobile chưa thấy hoạt động này. Kiểm tra nội dung, các bước và ảnh rồi bấm <b>Xuất bản</b>.</div>}

    <div className="detail-grid content-grid">
      {/* Form giữ nội dung đang sửa khi tải ảnh / đổi trạng thái; khối Các bước chỉ nạp lại
          khi bước trên server đổi (lưu bước, xóa ảnh đang dùng ở một bước) */}
      <InfoPanel activity={activity} groups={groups} onSave={(body) => run(() => api.updateActivity(admin, id, body), "Đã lưu thông tin")} />
      <div>
        <StepsPanel key={JSON.stringify(activity.steps)} activity={activity} onSave={(steps) => run(() => api.saveSteps(admin, id, steps), "Đã lưu các bước")} />
        <div className="panel-gap" />
        <MediaPanel activity={activity} admin={admin} run={run} />
      </div>
    </div>
  </div>;
}

function InfoPanel({ activity, groups, onSave }) {
  const [v, bind, check] = useFields({
    title: activity.title, groupId: activity.groupId ?? "", ageFromMonths: activity.ageFromMonths, ageToMonths: activity.ageToMonths,
    durationMinutes: activity.durationMinutes ?? "", summary: activity.summary ?? "", goal: activity.goal ?? "",
    materials: activity.materials ?? "", materialItems: activity.materialItems.join("\n"), safetyNote: activity.safetyNote ?? "",
    needsAdult: activity.needsAdult, lyrics: activity.lyrics ?? "", content: activity.content,
  });
  const [saving, setSaving] = useState(false);

  async function submit(event) {
    event.preventDefault();
    setSaving(true);
    await onSave({
      title: v.title.trim(), groupId: numberOrNull(v.groupId), ageFromMonths: Number(v.ageFromMonths), ageToMonths: Number(v.ageToMonths),
      durationMinutes: numberOrNull(v.durationMinutes), summary: blankToNull(v.summary), goal: blankToNull(v.goal),
      materials: blankToNull(v.materials), materialItems: v.materialItems.split("\n").map((line) => line.trim()).filter(Boolean),
      safetyNote: blankToNull(v.safetyNote), needsAdult: v.needsAdult, lyrics: blankToNull(v.lyrics), content: v.content,
    });
    setSaving(false);
  }

  return <Panel title="Thông tin chung" subtitle="activity.activities">
    <form className="edit-form" onSubmit={submit}>
      <label>TÊN HOẠT ĐỘNG<input required maxLength={300} {...bind("title")} /></label>
      <div className="form-row">
        <label>NHÓM<select {...bind("groupId")}><option value="">Chưa có nhóm</option>{groups.map((group) => <option key={group.id} value={group.id}>{group.name}{group.isActive ? "" : " (đã ẩn)"}</option>)}</select></label>
        <label>TỪ (THÁNG)<input type="number" required min={0} max={72} {...bind("ageFromMonths")} /></label>
        <label>ĐẾN (THÁNG)<input type="number" required min={0} max={72} {...bind("ageToMonths")} /></label>
        <label>THỜI LƯỢNG (PHÚT)<input type="number" min={1} max={240} placeholder="Linh hoạt" {...bind("durationMinutes")} /></label>
      </div>
      <label>MÔ TẢ NGẮN (HIỆN Ở DANH SÁCH)<textarea rows={2} {...bind("summary")} /></label>
      <label>MỤC TIÊU<textarea rows={2} {...bind("goal")} /></label>
      <label>ĐỒ DÙNG (MỖI DÒNG MỘT MÓN)<textarea rows={3} {...bind("materialItems")} /></label>
      <label>ĐỒ DÙNG (MÔ TẢ ĐẦY ĐỦ)<input {...bind("materials")} /></label>
      <label>LƯU Ý AN TOÀN<textarea rows={2} {...bind("safetyNote")} /></label>
      <label>LỜI BÀI HÁT / ĐỒNG DAO<textarea rows={3} {...bind("lyrics")} /></label>
      <label>NỘI DUNG CHI TIẾT (MARKDOWN)<textarea rows={12} className="mono" {...bind("content")} /></label>
      <p className="auth-hint">Mỗi tiêu đề <code>## …</code> thành một mục trên mobile (vd <code>## Chuẩn bị</code>, <code>## Hướng dẫn của chuyên gia</code>). Mục "Các bước thực hiện" lấy từ khối Các bước bên cạnh.</p>
      <div className="verify-list"><label><input type="checkbox" {...check("needsAdult")} />Cần người lớn ngồi cạnh</label></div>
      <div className="modal-actions"><button className="button primary" disabled={saving}>{saving ? "Đang lưu…" : "Lưu thông tin"}</button></div>
    </form>
  </Panel>;
}

function StepsPanel({ activity, onSave }) {
  const [steps, setSteps] = useState(activity.steps.map(({ title, instruction, imageUrl }) => ({ title, instruction, imageUrl })));
  const [saving, setSaving] = useState(false);
  const images = activity.media.filter((media) => media.mediaType === "image");
  const update = (index, changes) => setSteps((current) => current.map((step, i) => (i === index ? { ...step, ...changes } : step)));
  const move = (index, delta) => setSteps((current) => {
    const next = [...current];
    [next[index], next[index + delta]] = [next[index + delta], next[index]];
    return next;
  });
  const dirty = JSON.stringify(steps) !== JSON.stringify(activity.steps.map(({ title, instruction, imageUrl }) => ({ title, instruction, imageUrl })));

  async function save() {
    setSaving(true);
    await onSave(steps.map((step) => ({ ...step, instruction: step.instruction.trim() })).filter((step) => step.instruction));
    setSaving(false);
  }

  return <Panel title="Các bước thực hiện" subtitle={`${steps.length} bước · nhật ký của bé đánh dấu theo số thứ tự bước`} action={<button className="button secondary" onClick={() => setSteps((current) => [...current, { title: null, instruction: "", imageUrl: null }])}><Icon name="plus" size={14} /> Thêm bước</button>}>
    <ol className="step-editor">
      {steps.map((step, index) => <li key={index}>
        <span className="step-number">{index + 1}</span>
        <div className="step-body">
          <textarea aria-label={`Bước ${index + 1}`} rows={3} value={step.instruction} placeholder="Mô tả việc cần làm" onChange={(event) => update(index, { instruction: event.target.value })} />
          <div className="step-tools">
            <select aria-label={`Ảnh của bước ${index + 1}`} value={step.imageUrl ?? ""} onChange={(event) => update(index, { imageUrl: event.target.value || null })}>
              <option value="">Không có ảnh</option>
              {images.map((media, i) => <option key={media.id} value={media.url}>Ảnh {i + 1}{media.caption ? ` · ${media.caption.slice(0, 40)}` : ""}</option>)}
            </select>
            {step.imageUrl && <img src={backendUrl(step.imageUrl)} alt="" />}
            <button type="button" className="icon-action" aria-label="Lên" disabled={index === 0} onClick={() => move(index, -1)}>↑</button>
            <button type="button" className="icon-action" aria-label="Xuống" disabled={index === steps.length - 1} onClick={() => move(index, 1)}>↓</button>
            <button type="button" className="link-button danger" onClick={() => setSteps((current) => current.filter((_, i) => i !== index))}>Xóa</button>
          </div>
        </div>
      </li>)}
    </ol>
    {steps.length === 0 && <p className="table-empty">Chưa có bước nào.</p>}
    <div className="modal-actions">
      {dirty && <span className="auth-hint">Có thay đổi chưa lưu</span>}
      <button className="button primary" disabled={saving || !dirty} onClick={save}>{saving ? "Đang lưu…" : "Lưu các bước"}</button>
    </div>
  </Panel>;
}

function MediaPanel({ activity, admin, run }) {
  const input = useRef(null);
  const [uploading, setUploading] = useState(false);

  async function upload(files) {
    setUploading(true);
    for (const file of files) {
      if (!(await run(() => api.uploadImage(admin, activity.id, file), `Đã tải lên ${file.name}`))) break;
    }
    setUploading(false);
    input.current.value = "";
  }

  return <Panel title="Ảnh minh họa" subtitle="JPG / PNG / WebP ≤ 5 MB · ảnh đại diện hiện ở danh sách và đầu màn chi tiết trên mobile" action={<>
    <input ref={input} type="file" accept="image/jpeg,image/png,image/webp" multiple hidden onChange={(event) => upload([...event.target.files])} />
    <button className="button secondary" disabled={uploading} onClick={() => input.current.click()}><Icon name="upload" size={14} /> {uploading ? "Đang tải…" : "Tải ảnh lên"}</button>
  </>}>
    <div className="media-grid">
      {activity.media.map((media, index) => {
        const isThumb = media.url === activity.thumbnailUrl;
        return <figure key={media.id} className={isThumb ? "is-thumb" : ""}>
          <a href={backendUrl(media.url)} target="_blank" rel="noreferrer"><img src={backendUrl(media.url)} alt={media.caption ?? `Ảnh ${index + 1}`} loading="lazy" /></a>
          <figcaption>
            <b>Ảnh {index + 1}{isThumb && <Badge tone="green">Đại diện</Badge>}</b>
            <input aria-label={`Chú thích ảnh ${index + 1}`} defaultValue={media.caption ?? ""} placeholder="Chú thích" maxLength={300}
              onBlur={(event) => event.target.value !== (media.caption ?? "") && run(() => api.updateMedia(admin, media.id, { caption: blankToNull(event.target.value) }), "Đã lưu chú thích")} />
            <div className="row-actions">
              {!isThumb && <button className="link-button" onClick={() => run(() => api.updateActivity(admin, activity.id, { thumbnailUrl: media.url }), "Đã đặt làm ảnh đại diện")}>Đặt làm đại diện</button>}
              <button className="link-button danger" onClick={() => window.confirm(`Xóa ảnh ${index + 1}? Bước đang dùng ảnh này sẽ không còn ảnh.`) && run(() => api.deleteMedia(admin, media.id), "Đã xóa ảnh")}>Xóa</button>
            </div>
          </figcaption>
        </figure>;
      })}
    </div>
    {activity.media.length === 0 && <p className="table-empty">Chưa có ảnh. Bấm "Tải ảnh lên".</p>}
  </Panel>;
}
