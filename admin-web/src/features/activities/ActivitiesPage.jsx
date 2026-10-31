import React, { useEffect, useMemo, useState } from "react";
import { useAuth } from "../../core/auth.jsx";
import { backendUrl } from "../../core/http.js";
import { navigate } from "../../core/useHashRoute.js";
import Icon from "../../shared/Icon.jsx";
import { Modal, blankToNull, useFields, useSubmit } from "../../shared/form.jsx";
import { Badge, DataTable, PageHeading, Panel, Tabs, stopRowClick } from "../../shared/ui.jsx";
import * as api from "./activitiesApi.js";

// Kho hoạt động (F09, F20). Mobile chỉ thấy hoạt động "Đã xuất bản" của nhóm đang hiển thị;
// bấm một dòng để soạn nội dung, các bước và ảnh (#/activities/:id).
export default function ActivitiesPage({ onNotify }) {
  const { admin } = useAuth();
  const [tab, setTab] = useState("activities");
  const [activities, setActivities] = useState(null);
  const [groups, setGroups] = useState(null);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("all");
  const [groupId, setGroupId] = useState("all");
  const [age, setAge] = useState("all");
  const [creating, setCreating] = useState(false);
  const [editingGroup, setEditingGroup] = useState(null); // { item? }

  async function reload() {
    try {
      const [nextActivities, nextGroups] = await Promise.all([api.listActivities(admin), api.listGroups(admin)]);
      setActivities(nextActivities);
      setGroups(nextGroups);
      setError("");
    } catch (problem) {
      setError(problem.message);
    }
  }

  useEffect(() => { reload(); }, []);

  const counts = useMemo(() => {
    const result = { all: activities?.length ?? 0 };
    for (const item of activities ?? []) result[item.status] = (result[item.status] ?? 0) + 1;
    return result;
  }, [activities]);

  const shown = (activities ?? []).filter((item) => {
    if (status !== "all" && item.status !== status) return false;
    if (groupId !== "all" && String(item.groupId) !== groupId) return false;
    if (age !== "all") {
      const [from, to] = AGE_RANGES[age];
      if (item.ageToMonths < from || item.ageFromMonths > to) return false;
    }
    return !search.trim() || normalize(item.title).includes(normalize(search));
  });

  async function quickStatus(item, next) {
    try {
      await api.updateActivity(admin, item.id, { status: next });
      onNotify(next === "published" ? `Đã xuất bản "${item.title}"` : next === "hidden" ? `Đã ẩn "${item.title}" khỏi mobile` : "Đã chuyển về nháp");
      await reload();
    } catch (problem) {
      onNotify(problem.message);
    }
  }

  async function create(body) {
    try {
      const created = await api.createActivity(admin, body);
      onNotify("Đã tạo bản nháp — soạn nội dung rồi xuất bản");
      navigate(`/activities/${created.id}`);
    } catch (problem) {
      onNotify(problem.message);
    }
  }

  async function saveGroup(body) {
    const item = editingGroup.item;
    try {
      if (item) await api.updateGroup(admin, item.id, body);
      else await api.createGroup(admin, body);
      onNotify(item ? "Đã lưu nhóm" : "Đã thêm nhóm");
      setEditingGroup(null);
      await reload();
    } catch (problem) {
      onNotify(problem.message);
    }
  }

  async function toggleGroup(item) {
    try {
      await api.updateGroup(admin, item.id, { isActive: !item.isActive });
      onNotify(item.isActive ? `Đã ẩn nhóm ${item.name} trên mobile` : `Đã hiện lại nhóm ${item.name}`);
      await reload();
    } catch (problem) {
      onNotify(problem.message);
    }
  }

  const loading = activities === null || groups === null;

  return <div>
    <PageHeading eyebrow="NỘI DUNG CHUYÊN MÔN" title="Hoạt động & nhóm" subtitle="Thư viện hoạt động hỗ trợ phát triển và các nhóm hiển thị trên mobile (F09, F20). Mobile chỉ hiện hoạt động đã xuất bản.">
      <button className="button secondary" onClick={() => setEditingGroup({})}><Icon name="plus" size={16} /> Thêm nhóm</button>
      <button className="button primary" disabled={!groups?.length} onClick={() => setCreating(true)}><Icon name="plus" size={16} /> Thêm hoạt động</button>
    </PageHeading>
    {error && <div className="mock-notice">{error} Kiểm tra backend đang chạy với DEV_AUTH=true (backend/.env).</div>}
    <Tabs active={tab} onChange={setTab} tabs={[
      { id: "activities", label: "Hoạt động", count: activities?.length },
      { id: "groups", label: "Nhóm", count: groups?.length },
    ]} />

    {tab === "activities" && <>
      <div className="filter-bar">
        <div className="search-box"><Icon name="search" size={15} /><input aria-label="Tìm hoạt động" placeholder="Tìm theo tên…" value={search} onChange={(event) => setSearch(event.target.value)} /></div>
        <div className="status-chips" role="group" aria-label="Lọc theo trạng thái">
          {[["all", "Tất cả"], ...Object.entries(api.STATUS).map(([code, info]) => [code, info.label])].map(([code, label]) => <button key={code} className={status === code ? "active" : ""} aria-pressed={status === code} onClick={() => setStatus(code)}>{label} · {counts[code] ?? 0}</button>)}
        </div>
        <select aria-label="Lọc theo nhóm" value={groupId} onChange={(event) => setGroupId(event.target.value)}>
          <option value="all">Mọi nhóm</option>
          {(groups ?? []).map((group) => <option key={group.id} value={group.id}>{group.name}</option>)}
        </select>
        <select aria-label="Lọc theo độ tuổi" value={age} onChange={(event) => setAge(event.target.value)}>
          <option value="all">Mọi độ tuổi</option>
          {Object.keys(AGE_RANGES).map((key) => <option key={key} value={key}>{key} tháng</option>)}
        </select>
      </div>
      <Panel title="Danh sách hoạt động" subtitle={`${shown.length} kết quả · bấm một dòng để soạn nội dung, các bước và ảnh`}>
        <DataTable rowKey="id" rows={shown} paginate empty={loading ? "Đang tải…" : "Không có hoạt động phù hợp"} onRowClick={(item) => navigate(`/activities/${item.id}`)} columns={[
          { key: "title", label: "HOẠT ĐỘNG", render: (item) => <div className="activity-cell">{item.thumbnailUrl ? <img src={backendUrl(item.thumbnailUrl)} alt="" loading="lazy" /> : <span className="thumb-empty"><Icon name="spark" size={16} /></span>}<div className="stack"><b>{item.title}</b><small>{item.groupName ?? "Chưa có nhóm"}</small></div></div> },
          { key: "age", label: "ĐỘ TUỔI", render: (item) => `${item.ageFromMonths}–${item.ageToMonths} tháng` },
          { key: "duration", label: "THỜI LƯỢNG", render: (item) => item.durationMinutes ? `${item.durationMinutes} phút` : "—" },
          { key: "content", label: "NỘI DUNG", render: (item) => <div className="stack"><span>{item.stepCount} bước</span><small>{item.mediaCount} ảnh</small></div> },
          { key: "status", label: "TRẠNG THÁI", render: (item) => <Badge tone={api.STATUS[item.status].tone}>{api.STATUS[item.status].label}</Badge> },
          { key: "updatedAt", label: "CẬP NHẬT", render: (item) => new Date(item.updatedAt).toLocaleDateString("vi-VN") },
          { key: "actions", label: "", render: (item) => <div className="row-actions" onClick={stopRowClick}>
            {item.status !== "published" && <button className="link-button" onClick={() => quickStatus(item, "published")}>Xuất bản</button>}
            {item.status === "published" && <button className="link-button danger" onClick={() => quickStatus(item, "hidden")}>Ẩn</button>}
          </div> },
        ]} />
      </Panel>
    </>}

    {tab === "groups" && <Panel title="Nhóm hoạt động" subtitle="activity.activity_groups · mã nhóm (vd gross_motor) được mobile và AI nhận xét video dùng, không đổi được sau khi tạo">
      <DataTable rowKey="id" rows={groups ?? []} empty={loading ? "Đang tải…" : "Chưa có nhóm"} onRowClick={(item) => setEditingGroup({ item })} columns={[
        { key: "name", label: "NHÓM", render: (item) => <div className="activity-cell"><span className="group-swatch" style={{ background: item.tintHex ?? "#f0f3f1" }}>{item.emoji}</span><div className="stack"><b>{item.name}</b><small><code>{item.code}</code></small></div></div> },
        { key: "description", label: "MÔ TẢ", wrap: true, render: (item) => item.description ?? "—" },
        { key: "detailKind", label: "KIỂU MÀN CHI TIẾT", render: (item) => DETAIL_KINDS[item.detailKind] },
        { key: "count", label: "HOẠT ĐỘNG", render: (item) => <div className="stack"><span>{item.publishedCount} đã xuất bản</span><small>{item.activityCount} tổng</small></div> },
        { key: "sortOrder", label: "THỨ TỰ" },
        { key: "status", label: "TRÊN MOBILE", render: (item) => item.isActive ? <Badge tone="green">Hiển thị</Badge> : <Badge tone="gray">Đã ẩn</Badge> },
        { key: "actions", label: "", render: (item) => <div className="row-actions" onClick={stopRowClick}><button className="link-button" onClick={() => toggleGroup(item)}>{item.isActive ? "Ẩn" : "Hiện"}</button></div> },
      ]} />
    </Panel>}

    {creating && <CreateActivityModal groups={groups} onClose={() => setCreating(false)} onSave={create} />}
    {editingGroup && <GroupModal item={editingGroup.item} onClose={() => setEditingGroup(null)} onSave={saveGroup} />}
  </div>;
}

export const AGE_RANGES = { "0–6": [0, 6], "6–12": [6, 12], "12–18": [12, 18], "18–24": [18, 24], "24–36": [24, 36] };
export const DETAIL_KINDS = { move: "Vận động (các bước)", music: "Âm nhạc (lời bài hát)", story: "Kể chuyện (đoạn truyện)" };

// Tìm không dấu: "massage" khớp "Massage", "bo" khớp "Bò"
const normalize = (text) => text.normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/đ/gi, "d").toLowerCase();

function CreateActivityModal({ groups, onClose, onSave }) {
  const [v, bind] = useFields({ title: "", groupId: groups[0]?.id, ageFromMonths: 0, ageToMonths: 3 });
  const [saving, submit] = useSubmit(onSave, () => ({
    title: v.title.trim(), groupId: Number(v.groupId), ageFromMonths: Number(v.ageFromMonths), ageToMonths: Number(v.ageToMonths),
  }));
  return <Modal eyebrow="HOẠT ĐỘNG" title="Thêm hoạt động" onClose={onClose} onSubmit={submit} saving={saving}>
    <p className="modal-description">Hoạt động mới ở trạng thái <b>Nháp</b> — mobile chưa thấy cho đến khi bạn soạn nội dung và bấm Xuất bản.</p>
    <label>TÊN HOẠT ĐỘNG<input required maxLength={300} placeholder="vd: Bò qua đường hầm" {...bind("title")} /></label>
    <label>NHÓM<select {...bind("groupId")}>{groups.map((group) => <option key={group.id} value={group.id}>{group.name}</option>)}</select></label>
    <div className="form-row">
      <label>TỪ (THÁNG)<input type="number" required min={0} max={72} {...bind("ageFromMonths")} /></label>
      <label>ĐẾN (THÁNG)<input type="number" required min={Number(v.ageFromMonths) || 0} max={72} {...bind("ageToMonths")} /></label>
    </div>
  </Modal>;
}

function GroupModal({ item, onClose, onSave }) {
  const [v, bind, check] = useFields({
    code: item?.code ?? "", name: item?.name ?? "", description: item?.description ?? "", emoji: item?.emoji ?? "",
    tintHex: item?.tintHex ?? "#E4F3EA", detailKind: item?.detailKind ?? "move", sortOrder: item?.sortOrder ?? 100, isActive: item?.isActive ?? true,
  });
  const [saving, submit] = useSubmit(onSave, () => ({
    ...(!item && { code: v.code.trim() }),
    name: v.name.trim(), description: blankToNull(v.description), emoji: blankToNull(v.emoji), tintHex: v.tintHex,
    detailKind: v.detailKind, sortOrder: Number(v.sortOrder), isActive: v.isActive,
  }));
  return <Modal eyebrow="NHÓM HOẠT ĐỘNG" title={item ? "Sửa nhóm" : "Thêm nhóm"} onClose={onClose} onSubmit={submit} saving={saving}>
    <label>MÃ{item
      ? <input value={v.code} disabled />
      : <input required pattern="[a-z0-9_]{2,40}" title="2–40 ký tự: chữ thường, số, gạch dưới" placeholder="vd: outdoor" {...bind("code")} />}</label>
    <label>TÊN NHÓM<input required maxLength={100} {...bind("name")} /></label>
    <label>MÔ TẢ (HIỂN THỊ TRÊN MOBILE)<input {...bind("description")} /></label>
    <div className="form-row">
      <label>EMOJI<input maxLength={16} placeholder="🏃" {...bind("emoji")} /></label>
      <label>MÀU NỀN<input type="color" {...bind("tintHex")} /></label>
      <label>THỨ TỰ<input type="number" min={0} max={1000} {...bind("sortOrder")} /></label>
    </div>
    <label>KIỂU MÀN CHI TIẾT<select {...bind("detailKind")}>{Object.entries(DETAIL_KINDS).map(([code, label]) => <option key={code} value={code}>{label}</option>)}</select></label>
    <div className="verify-list"><label><input type="checkbox" {...check("isActive")} />Hiển thị nhóm trên mobile</label></div>
  </Modal>;
}
