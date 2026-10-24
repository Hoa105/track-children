import React, { useEffect, useState } from "react";
import { useAuth } from "../../core/auth.jsx";
import Icon from "../../shared/Icon.jsx";
import { Badge, DataTable, PageHeading, Panel, Tabs, stopRowClick } from "../../shared/ui.jsx";
import * as api from "./vaccinationApi.js";

// Danh mục vắc xin, sản phẩm và lịch tiêm TCMR + dịch vụ (F16.1). Mobile tải lịch qua
// GET /vaccines/schedule và tự tính ngày dự kiến: theo tuổi, theo mũi trước, lặp lại.
// Mũi bị ẩn không còn trong lịch của bé, nhưng sổ tiêm đã ghi vẫn giữ nguyên.
export default function VaccinationPage({ onNotify }) {
  const { admin } = useAuth();
  const [tab, setTab] = useState("schedules");
  const [vaccines, setVaccines] = useState(null);
  const [schedules, setSchedules] = useState(null);
  const [products, setProducts] = useState(null);
  const [customReport, setCustomReport] = useState(null);
  const [kind, setKind] = useState("all"); // all | tcmr | service
  const [error, setError] = useState("");
  // { kind: "vaccine" | "schedule" | "product", item? (sửa), preset? (giá trị điền sẵn khi thêm) }
  const [editing, setEditing] = useState(null);

  async function reload() {
    try {
      const [nextVaccines, nextSchedules, nextProducts, nextReport] = await Promise.all([
        api.listVaccines(admin), api.listSchedules(admin), api.listProducts(admin), api.getCustomDoseReport(admin),
      ]);
      setVaccines(nextVaccines);
      setSchedules(nextSchedules);
      setProducts(nextProducts);
      setCustomReport(nextReport);
      setError("");
    } catch (problem) {
      setError(problem.message);
    }
  }

  useEffect(() => { reload(); }, []);

  // Tab "Mũi ngoài lịch": tự làm mới để thấy ngay mũi phụ huynh vừa thêm trên app
  const [reportAt, setReportAt] = useState(null);
  useEffect(() => {
    if (tab !== "custom") return undefined;
    let cancelled = false;
    async function refresh() {
      if (document.hidden) return;
      try {
        const next = await api.getCustomDoseReport(admin);
        if (!cancelled) { setCustomReport(next); setReportAt(new Date()); }
      } catch {
        // giữ dữ liệu cũ, lần sau thử lại
      }
    }
    refresh();
    const timer = window.setInterval(refresh, REPORT_REFRESH_MS);
    return () => { cancelled = true; window.clearInterval(timer); };
  }, [tab]);

  async function run(action, message) {
    try {
      await action();
      onNotify(message);
      await reload();
      return true;
    } catch (problem) {
      onNotify(problem.message);
      return false;
    }
  }

  const toggleSchedule = (item) => run(() => api.updateSchedule(admin, item.id, { isActive: !item.isActive }), item.isActive ? "Đã ẩn mũi khỏi lịch tiêm của mobile" : "Đã hiện lại mũi trong lịch tiêm");
  const toggleVaccine = (item) => run(() => api.updateVaccine(admin, item.id, { isActive: !item.isActive }), item.isActive ? `Đã ngừng dùng ${item.name}` : `Đã dùng lại ${item.name}`);
  const toggleProduct = (item) => run(() => api.updateProduct(admin, item.id, { isActive: !item.isActive }), item.isActive ? `Đã ẩn ${item.name}` : `Đã hiện ${item.name}`);
  const removeSchedule = (item) => window.confirm(`Xóa mũi "${item.vaccineName} · ${item.doseLabel ?? item.code}"?`) && run(() => api.deleteSchedule(admin, item.id), "Đã xóa mũi tiêm");

  async function save(body) {
    const { kind: entity, item } = editing;
    const calls = {
      vaccine: [api.createVaccine, api.updateVaccine],
      schedule: [api.createSchedule, api.updateSchedule],
      product: [api.createProduct, api.updateProduct],
    }[entity];
    const action = item ? () => calls[1](admin, item.id, body) : () => calls[0](admin, body);
    if (await run(action, item ? "Đã lưu thay đổi" : "Đã thêm mới")) setEditing(null);
  }

  const loading = vaccines === null || schedules === null || products === null;
  const shownSchedules = (schedules ?? []).filter((item) => kind === "all" || (kind === "tcmr") === item.isTcmr);
  const shownVaccines = (vaccines ?? []).filter((item) => kind === "all" || (kind === "tcmr") === item.isMandatory);
  const kindFilter = <select className="inline-select" aria-label="Loại vắc xin" value={kind} onChange={(event) => setKind(event.target.value)}>
    <option value="all">TCMR + dịch vụ</option><option value="tcmr">Chỉ TCMR</option><option value="service">Chỉ dịch vụ</option>
  </select>;

  return <div>
    <PageHeading eyebrow="NỘI DUNG CHUYÊN MÔN" title="Tiêm chủng" subtitle="Danh mục vắc xin, sản phẩm và lịch tiêm theo mốc tuổi (TCMR + dịch vụ) — mobile tải lịch này cho sổ tiêm của bé (F16.1).">
      <button className="button secondary" onClick={() => setEditing({ kind: "vaccine" })}><Icon name="plus" size={16} /> Thêm vắc xin</button>
      <button className="button secondary" disabled={!vaccines?.length} onClick={() => setEditing({ kind: "product" })}><Icon name="plus" size={16} /> Thêm sản phẩm</button>
      <button className="button primary" disabled={!vaccines?.length} onClick={() => setEditing({ kind: "schedule" })}><Icon name="plus" size={16} /> Thêm mũi tiêm</button>
    </PageHeading>
    {error && <div className="mock-notice">{error} Kiểm tra backend đang chạy với DEV_AUTH=true (backend/.env).</div>}
    <Tabs active={tab} onChange={setTab} tabs={[
      { id: "schedules", label: "Lịch tiêm", count: schedules?.length },
      { id: "vaccines", label: "Danh mục vắc xin", count: vaccines?.length },
      { id: "products", label: "Sản phẩm", count: products?.length },
      { id: "custom", label: "Mũi ngoài lịch", count: customReport?.items.length },
    ]} />

    {tab === "schedules" && <Panel title="Lịch tiêm theo mốc tuổi" subtitle="health.vaccine_schedules · mã mũi là id mobile dùng để ghi sổ tiêm, không nên đổi sau khi đã có dữ liệu" action={kindFilter}>
      <DataTable rowKey="id" rows={shownSchedules} paginate empty={loading ? "Đang tải…" : "Chưa có mũi tiêm"} onRowClick={(item) => setEditing({ kind: "schedule", item })} columns={[
        { key: "age", label: "MỐC TUỔI", render: (item) => ageLabel(item) },
        { key: "vaccine", label: "VẮC XIN", render: (item) => <div className="stack"><b>{item.vaccineName}</b><small><code>{item.code ?? "—"}</code></small></div> },
        { key: "dose", label: "MŨI", render: (item) => item.doseLabel ?? `Mũi ${item.doseNumber}` },
        { key: "rule", label: "QUY TẮC", wrap: true, render: (item) => ruleLabel(item) },
        { key: "kind", label: "LOẠI", render: (item) => item.isTcmr ? <Badge tone="blue">TCMR</Badge> : <Badge tone="purple">Dịch vụ</Badge> },
        { key: "records", label: "ĐÃ GHI SỔ", render: (item) => item.recordCount },
        { key: "status", label: "TRẠNG THÁI", render: (item) => item.isActive ? <Badge tone="green">Đang áp dụng</Badge> : <Badge tone="gray">Đã ẩn</Badge> },
        { key: "actions", label: "", render: (item) => <div className="row-actions" onClick={stopRowClick}>
          <button className="link-button" onClick={() => toggleSchedule(item)}>{item.isActive ? "Ẩn" : "Hiện"}</button>
          {item.recordCount === 0 && <button className="link-button danger" onClick={() => removeSchedule(item)}>Xóa</button>}
        </div> },
      ]} />
    </Panel>}

    {tab === "vaccines" && <Panel title="Danh mục vắc xin" subtitle="health.vaccines · vắc xin cùng nhóm phác đồ là các phương án thay thế nhau — mỗi bé theo 1 phương án" action={kindFilter}>
      <DataTable rowKey="id" rows={shownVaccines} empty={loading ? "Đang tải…" : "Chưa có vắc xin"} onRowClick={(item) => setEditing({ kind: "vaccine", item })} columns={[
        { key: "name", label: "VẮC XIN", render: (item) => <div className="stack"><b>{item.name}</b><small><code>{item.code}</code></small></div> },
        { key: "disease", label: "PHÒNG BỆNH", wrap: true, render: (item) => item.disease ?? "—" },
        { key: "type", label: "LOẠI", render: (item) => item.isMandatory ? <Badge tone="blue">TCMR</Badge> : <Badge tone="purple">Dịch vụ</Badge> },
        { key: "choice", label: "PHÁC ĐỒ", wrap: true, render: (item) => item.choiceGroup ? <div className="stack"><span>{item.choiceLabel ?? item.choiceOption}</span><small><code>{item.choiceGroup}/{item.choiceOption}</code>{item.choiceDefault && " · mặc định"}</small></div> : "—" },
        { key: "scheduleCount", label: "SỐ MŨI" },
        { key: "status", label: "TRẠNG THÁI", render: (item) => item.isActive ? <Badge tone="green">Đang dùng</Badge> : <Badge tone="gray">Ngừng dùng</Badge> },
        { key: "actions", label: "", render: (item) => <div className="row-actions" onClick={stopRowClick}><button className="link-button" onClick={() => toggleVaccine(item)}>{item.isActive ? "Ngừng dùng" : "Dùng lại"}</button></div> },
      ]} />
    </Panel>}

    {tab === "products" && <Panel title="Sản phẩm vắc xin" subtitle="health.vaccine_products · phụ huynh chọn khi ghi nhận mũi đã tiêm; số liều khác lịch chung (vd RotaTeq 3 liều) sẽ ẩn bớt mũi thừa">
      <DataTable rowKey="id" rows={products ?? []} paginate empty={loading ? "Đang tải…" : "Chưa có sản phẩm"} onRowClick={(item) => setEditing({ kind: "product", item })} columns={[
        { key: "name", label: "SẢN PHẨM", render: (item) => <div className="stack"><b>{item.name}</b><small><code>{item.code}</code></small></div> },
        { key: "vaccineName", label: "VẮC XIN" },
        { key: "origin", label: "NƯỚC SẢN XUẤT", render: (item) => item.origin ?? "—" },
        { key: "doseCount", label: "SỐ LIỀU", render: (item) => item.doseCount ?? "Theo lịch" },
        { key: "recordCount", label: "ĐÃ GHI SỔ" },
        { key: "status", label: "TRẠNG THÁI", render: (item) => item.isActive ? <Badge tone="green">Đang dùng</Badge> : <Badge tone="gray">Đã ẩn</Badge> },
        { key: "actions", label: "", render: (item) => <div className="row-actions" onClick={stopRowClick}><button className="link-button" onClick={() => toggleProduct(item)}>{item.isActive ? "Ẩn" : "Hiện"}</button></div> },
      ]} />
    </Panel>}

    {tab === "custom" && <Panel title="Mũi tiêm ngoài lịch" subtitle={customReport
      ? `${customReport.totalDoses} mũi phụ huynh tự thêm ở ${customReport.totalChildren} bé · gộp theo tên · mới nhất lên đầu`
      : "Đang tải…"} action={<span className="subtitle">{reportAt ? `Tự cập nhật · ${reportAt.toLocaleTimeString("vi-VN")}` : ""}</span>}>
      <p className="modal-description">Gồm cả mũi đã tiêm và đang hẹn, kể cả chỉ 1 bé. Không hiện tên bé hay phụ huynh. Mũi tự thêm chỉ nằm trong sổ tiêm của từng bé — không tự vào lịch chuẩn của các bé khác. Muốn đưa vào lịch chuẩn, bấm "Thêm vào danh mục" (cần chuyên môn duyệt).</p>
      <DataTable rowKey="key" rows={customReport?.items ?? []} paginate empty={loading ? "Đang tải…" : "Chưa có tên nào đủ số bé tối thiểu"} columns={[
        { key: "name", label: "TÊN PHỤ HUYNH NHẬP", render: (item) => <div className="stack"><b>{item.name}</b><small>{item.prevents ?? "Chưa ghi bệnh phòng ngừa"}</small></div> },
        { key: "childCount", label: "SỐ BÉ" },
        { key: "doses", label: "SỐ MŨI", render: (item) => <div className="stack"><span>{item.doseCount}</span><small>{item.givenCount} đã tiêm · {item.plannedCount} hẹn</small></div> },
        { key: "last", label: "GHI NHẬN GẦN NHẤT", render: (item) => <span>{new Date(item.lastRecordedAt).toLocaleString("vi-VN")} {Date.now() - new Date(item.lastRecordedAt) < 86400000 && <Badge tone="blue">Mới</Badge>}</span> },
        { key: "catalog", label: "DANH MỤC", render: (item) => item.catalogVaccine ? <Badge tone="green">Đã có · {item.catalogVaccine}</Badge> : <Badge tone="orange">Chưa có</Badge> },
        { key: "actions", label: "", render: (item) => item.catalogVaccine ? null : <div className="row-actions"><button className="link-button" onClick={() => setEditing({ kind: "vaccine", preset: { name: item.name, disease: item.prevents ?? "" } })}>Thêm vào danh mục</button></div> },
      ]} />
    </Panel>}

    {editing?.kind === "vaccine" && <VaccineModal item={editing.item} preset={editing.preset} onClose={() => setEditing(null)} onSave={save} />}
    {editing?.kind === "product" && <ProductModal item={editing.item} vaccines={vaccines} onClose={() => setEditing(null)} onSave={save} />}
    {editing?.kind === "schedule" && <ScheduleModal item={editing.item} vaccines={vaccines} schedules={schedules} onClose={() => setEditing(null)} onSave={save} />}
  </div>;
}

const REPORT_REFRESH_MS = 10000;

function ageLabel({ ageWeeks, ageMonths, offsetDays }) {
  if (ageWeeks != null) return `${ageWeeks} tuần`;
  const base = ageMonths === 0 ? "Sơ sinh" : `${ageMonths} tháng`;
  return offsetDays ? `${base} + ${offsetDays} ngày` : base;
}

function ruleLabel(item) {
  const parts = [];
  if (item.afterCode) parts.push(`≥ ${item.minIntervalDays ?? 0} ngày sau ${item.afterCode}`);
  if (item.repeatEveryMonths) parts.push(`lặp mỗi ${item.repeatEveryMonths} tháng đến ${item.repeatUntilMonths} tháng tuổi`);
  if (item.note) parts.push(item.note);
  return parts.length ? parts.join(" · ") : "—";
}

const blankToNull = (value) => (value.trim() === "" ? null : value.trim());
const numberOrNull = (value) => (value === "" || value == null ? null : Number(value));

function Modal({ eyebrow, title, onClose, onSubmit, saving, children }) {
  return <div className="modal-backdrop" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
    <form className="modal modal-wide" onSubmit={onSubmit}>
      <div className="modal-header"><div><p className="eyebrow">{eyebrow}</p><h2>{title}</h2></div><button type="button" className="close-button" onClick={onClose} aria-label="Đóng"><Icon name="close" /></button></div>
      {children}
      <div className="modal-actions"><button type="button" className="button secondary" onClick={onClose}>Hủy</button><button className="button primary" disabled={saving}>{saving ? "Đang lưu…" : "Lưu"}</button></div>
    </form>
  </div>;
}

function useSubmit(onSave, build) {
  const [saving, setSaving] = useState(false);
  return [saving, async (event) => {
    event.preventDefault();
    setSaving(true);
    try { await onSave(build()); } finally { setSaving(false); }
  }];
}

// Giá trị form trong 1 state; bind/check trả props cho input text / checkbox
function useFields(initial) {
  const [values, setValues] = useState(initial);
  const bind = (name) => ({ value: values[name] ?? "", onChange: (event) => setValues((current) => ({ ...current, [name]: event.target.value })) });
  const check = (name) => ({ checked: Boolean(values[name]), onChange: (event) => setValues((current) => ({ ...current, [name]: event.target.checked })) });
  return [values, bind, check];
}

function VaccineModal({ item, preset, onClose, onSave }) {
  const [v, bind, check] = useFields({
    code: item?.code ?? "", name: item?.name ?? preset?.name ?? "", disease: item?.disease ?? preset?.disease ?? "", description: item?.description ?? "",
    isMandatory: item?.isMandatory ?? false, choiceGroup: item?.choiceGroup ?? "", choiceOption: item?.choiceOption ?? "",
    choiceLabel: item?.choiceLabel ?? "", choiceDefault: item?.choiceDefault ?? false, sortOrder: item?.sortOrder ?? 100,
  });
  const grouped = v.choiceGroup.trim() !== "";
  const [saving, submit] = useSubmit(onSave, () => ({
    ...(!item && { code: v.code.trim() }),
    name: v.name.trim(), disease: blankToNull(v.disease), description: blankToNull(v.description), isMandatory: v.isMandatory,
    choiceGroup: grouped ? v.choiceGroup.trim() : null, choiceOption: grouped ? blankToNull(v.choiceOption) : null,
    choiceLabel: grouped ? blankToNull(v.choiceLabel) : null, choiceDefault: grouped && v.choiceDefault, sortOrder: Number(v.sortOrder),
  }));

  return <Modal eyebrow="DANH MỤC VẮC XIN" title={item ? "Sửa vắc xin" : "Thêm vắc xin"} onClose={onClose} onSubmit={submit} saving={saving}>
    <label>MÃ{item
      ? <input value={v.code} disabled />
      : <input required pattern="[a-z0-9\-]{2,30}" title="2–30 ký tự: chữ thường, số, gạch ngang" placeholder="vd: flu" {...bind("code")} />}</label>
    <label>TÊN VẮC XIN<input required maxLength={150} placeholder="vd: Cúm mùa" {...bind("name")} /></label>
    <label>PHÒNG BỆNH<input maxLength={200} placeholder="Hiển thị dưới tên vắc xin trên mobile" {...bind("disease")} /></label>
    <label>MÔ TẢ<input {...bind("description")} /></label>
    <label>THỨ TỰ HIỂN THỊ<input type="number" min={0} max={1000} {...bind("sortOrder")} /></label>
    <div className="verify-list"><label><input type="checkbox" {...check("isMandatory")} />Thuộc chương trình tiêm chủng mở rộng (TCMR)</label></div>
    <p className="modal-description">Phác đồ thay thế: các vắc xin cùng <b>nhóm</b> nhưng khác <b>phương án</b> loại trừ nhau, vd nhóm <code>dtp</code>: <code>tcmr</code> (5 trong 1 + bại liệt + DPT) hoặc <code>6in1</code>. Để trống nếu không thuộc nhóm nào.</p>
    <label>NHÓM PHÁC ĐỒ<input pattern="[a-z0-9\-]{2,30}" placeholder="vd: dtp" {...bind("choiceGroup")} /></label>
    {grouped && <>
      <label>PHƯƠNG ÁN<input required pattern="[a-z0-9\-]{2,30}" placeholder="vd: 6in1" {...bind("choiceOption")} /></label>
      <label>TÊN PHƯƠNG ÁN (HIỂN THỊ CHO PHỤ HUYNH)<input maxLength={100} {...bind("choiceLabel")} /></label>
      <div className="verify-list"><label><input type="checkbox" {...check("choiceDefault")} />Phương án mặc định khi bé chưa chọn</label></div>
    </>}
  </Modal>;
}

function ProductModal({ item, vaccines, onClose, onSave }) {
  const [v, bind] = useFields({
    vaccineId: item?.vaccineId ?? vaccines[0]?.id, code: item?.code ?? "", name: item?.name ?? "",
    origin: item?.origin ?? "", doseCount: item?.doseCount ?? "", note: item?.note ?? "",
  });
  const [saving, submit] = useSubmit(onSave, () => ({
    ...(!item && { vaccineId: Number(v.vaccineId), code: v.code.trim() }),
    name: v.name.trim(), origin: blankToNull(v.origin), doseCount: numberOrNull(v.doseCount), note: blankToNull(v.note),
  }));

  return <Modal eyebrow="SẢN PHẨM VẮC XIN" title={item ? "Sửa sản phẩm" : "Thêm sản phẩm"} onClose={onClose} onSubmit={submit} saving={saving}>
    <label>VẮC XIN<select disabled={Boolean(item)} {...bind("vaccineId")}>{vaccines.map((vaccine) => <option key={vaccine.id} value={vaccine.id}>{vaccine.name}</option>)}</select></label>
    <label>MÃ<input required disabled={Boolean(item)} pattern="[a-z0-9\-]{2,40}" placeholder="vd: rotarix" {...bind("code")} /></label>
    <label>TÊN THƯƠNG MẠI<input required maxLength={100} placeholder="vd: Rotarix" {...bind("name")} /></label>
    <label>NƯỚC SẢN XUẤT<input maxLength={60} {...bind("origin")} /></label>
    <label>SỐ LIỀU (ĐỂ TRỐNG = THEO LỊCH CHUNG)<input type="number" min={1} max={20} {...bind("doseCount")} /></label>
    <label>GHI CHÚ<input {...bind("note")} /></label>
  </Modal>;
}

function ScheduleModal({ item, vaccines, schedules, onClose, onSave }) {
  const [v, bind] = useFields({
    vaccineId: item?.vaccineId ?? vaccines[0]?.id, code: item?.code ?? "", doseNumber: item?.doseNumber ?? 1,
    doseLabel: item?.doseLabel ?? "", ageUnit: item?.ageWeeks != null ? "weeks" : "months",
    ageWeeks: item?.ageWeeks ?? 6, ageMonths: item?.ageMonths ?? 0, offsetDays: item?.offsetDays ?? 0,
    afterScheduleId: item?.afterScheduleId ?? "", minIntervalDays: item?.minIntervalDays ?? "",
    repeatEveryMonths: item?.repeatEveryMonths ?? "", repeatUntilMonths: item?.repeatUntilMonths ?? "",
    funding: item?.isMandatory == null ? "inherit" : item.isMandatory ? "tcmr" : "service", note: item?.note ?? "",
  });
  const sameVaccine = schedules.filter((other) => other.vaccineId === Number(v.vaccineId) && other.id !== item?.id);
  const weeks = v.ageUnit === "weeks";
  const [saving, submit] = useSubmit(onSave, () => ({
    ...(!item && { vaccineId: Number(v.vaccineId) }),
    code: v.code.trim(), doseNumber: Number(v.doseNumber), doseLabel: blankToNull(v.doseLabel),
    ageWeeks: weeks ? Number(v.ageWeeks) : null,
    ...(!weeks && { ageMonths: Number(v.ageMonths), offsetDays: Number(v.offsetDays) }),
    afterScheduleId: numberOrNull(v.afterScheduleId), minIntervalDays: numberOrNull(v.minIntervalDays),
    repeatEveryMonths: numberOrNull(v.repeatEveryMonths), repeatUntilMonths: v.repeatEveryMonths === "" ? null : numberOrNull(v.repeatUntilMonths) ?? 72,
    isMandatory: { inherit: null, tcmr: true, service: false }[v.funding], note: blankToNull(v.note),
  }));

  return <Modal eyebrow="LỊCH TIÊM" title={item ? "Sửa mũi tiêm" : "Thêm mũi tiêm"} onClose={onClose} onSubmit={submit} saving={saving}>
    {item?.recordCount > 0 && <p className="modal-description">Mũi này đã có trong sổ tiêm của {item.recordCount} trẻ — đổi mã sẽ làm bản ghi cũ trên mobile không khớp mũi mới.</p>}
    <label>VẮC XIN<select disabled={Boolean(item)} {...bind("vaccineId")}>{vaccines.map((vaccine) => <option key={vaccine.id} value={vaccine.id}>{vaccine.name}</option>)}</select></label>
    <label>MÃ MŨI<input required pattern="[a-z0-9\-]{2,40}" title="2–40 ký tự: chữ thường, số, gạch ngang" placeholder="vd: flu-1" {...bind("code")} /></label>
    <label>SỐ THỨ TỰ MŨI<input type="number" required min={1} max={20} {...bind("doseNumber")} /></label>
    <label>NHÃN LIỀU<input maxLength={50} placeholder="vd: Mũi 1, Liều sơ sinh, Nhắc lại" {...bind("doseLabel")} /></label>
    <label>MỐC TUỔI THEO<select {...bind("ageUnit")}><option value="months">Tháng</option><option value="weeks">Tuần (vd 6 tuần)</option></select></label>
    {weeks
      ? <label>SỐ TUẦN TUỔI<input type="number" required min={0} max={52} {...bind("ageWeeks")} /></label>
      : <>
        <label>MỐC TUỔI (THÁNG, 0 = SƠ SINH)<input type="number" required min={0} max={216} {...bind("ageMonths")} /></label>
        <label>CỘNG THÊM (NGÀY)<input type="number" min={0} max={365} {...bind("offsetDays")} /></label>
      </>}
    <label>TÍNH TỪ MŨI TRƯỚC<select {...bind("afterScheduleId")}><option value="">Không — chỉ theo tuổi</option>{sameVaccine.map((other) => <option key={other.id} value={other.id}>{other.code} · {other.doseLabel ?? `Mũi ${other.doseNumber}`}</option>)}</select></label>
    <label>KHOẢNG CÁCH TỐI THIỂU VỚI MŨI TRƯỚC (NGÀY)<input type="number" min={0} {...bind("minIntervalDays")} /></label>
    <label>LẶP LẠI MỖI (THÁNG, ĐỂ TRỐNG = KHÔNG LẶP)<input type="number" min={1} max={120} placeholder="vd: 12 cho cúm hằng năm" {...bind("repeatEveryMonths")} /></label>
    {v.repeatEveryMonths !== "" && <label>LẶP ĐẾN (THÁNG TUỔI)<input type="number" min={1} max={216} placeholder="72" {...bind("repeatUntilMonths")} /></label>}
    <label>LOẠI MŨI<select {...bind("funding")}><option value="inherit">Theo vắc xin</option><option value="tcmr">TCMR (miễn phí)</option><option value="service">Dịch vụ</option></select></label>
    <label>GHI CHÚ HIỂN THỊ TRÊN MOBILE<input placeholder="vd: Theo lịch địa phương." {...bind("note")} /></label>
  </Modal>;
}
