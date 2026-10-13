import React, { useState } from "react";
import { ALL_TIME, DataTable, MockNotice, PageHeading, Panel, StatCard, TimeFilter } from "../../shared/ui.jsx";

// Chỉ số liệu TỔNG HỢP — admin không duyệt từng hồ sơ trẻ (dữ liệu sức khỏe
// của trẻ thuộc phụ huynh). Tra cứu hỗ trợ một hồ sơ cụ thể cần quyền riêng
// và được ghi vào admin.admin_audit_logs.
const byAge = [
  { band: "0–6 tháng", children: 642, assessed: 71, growthUpdated: 88 },
  { band: "6–12 tháng", children: 815, assessed: 78, growthUpdated: 82 },
  { band: "1–2 tuổi", children: 1104, assessed: 74, growthUpdated: 69 },
  { band: "2–3 tuổi", children: 731, assessed: 62, growthUpdated: 55 },
  { band: "3–6 tuổi", children: 555, assessed: 48, growthUpdated: 41 },
];

const levels = [
  { domain: "Vận động thô", onTrack: 84, monitor: 12, support: 4 },
  { domain: "Vận động tinh", onTrack: 79, monitor: 16, support: 5 },
  { domain: "Ngôn ngữ", onTrack: 71, monitor: 21, support: 8 },
  { domain: "Xã hội – Cảm xúc", onTrack: 82, monitor: 14, support: 4 },
];

// Mô tả khoảng thời gian đang lọc — API thống kê sẽ nhận from / to tương ứng
function rangeLabel(range) {
  if (range.preset === "all") return "từ trước tới nay";
  if (range.preset !== "custom") return `trong ${range.preset} ngày qua`;
  const format = (value) => value ? new Date(`${value}T00:00`).toLocaleDateString("vi-VN") : "…";
  return `từ ${format(range.from)} đến ${format(range.to)}`;
}

export default function ChildrenStatsPage() {
  const [range, setRange] = useState(ALL_TIME);
  const period = rangeLabel(range);

  return <div>
    <PageHeading eyebrow="NGƯỜI DÙNG" title="Hồ sơ trẻ" subtitle={`Số liệu tổng hợp ${period}, không hiển thị thông tin định danh của trẻ.`}>
      <TimeFilter value={range} onChange={setRange} label="Ngày tạo hồ sơ" />
    </PageHeading>
    <MockNotice />
    <div className="stats-grid">
      <StatCard title="HỒ SƠ ĐANG THEO DÕI" value="3.847" icon="child" tone="blue" sub="child.children · chưa xóa" />
      <StatCard title="HỒ SƠ ĐƯỢC CHIA SẺ" value="1.126" icon="users" tone="green" sub="có ≥ 1 thành viên active" />
      <StatCard title="TRẺ SINH NON" value="214" icon="heart" tone="purple" sub="gestational_weeks < 37" />
      <StatCard title="CHỜ CHUYỂN QUYỀN CHỦ" value="9" icon="refresh" tone="orange" sub="ownership_transfers · pending" />
    </div>
    <div className="content-grid">
      <Panel title="Theo nhóm tuổi" subtitle={`% hồ sơ có đánh giá / số đo ${period}`}>
        <DataTable rowKey="band" rows={byAge} columns={[
          { key: "band", label: "NHÓM TUỔI" },
          { key: "children", label: "SỐ HỒ SƠ" },
          { key: "assessed", label: "CÓ ĐÁNH GIÁ", render: (row) => `${row.assessed}%` },
          { key: "growthUpdated", label: "CÓ SỐ ĐO", render: (row) => `${row.growthUpdated}%` },
        ]} />
      </Panel>
      <Panel title="Kết quả đánh giá theo lĩnh vực" subtitle={`Lần đánh giá gần nhất của mỗi trẻ ${period}`}>
        <div className="level-bars">{levels.map((row) => <div key={row.domain} className="level-row"><span>{row.domain}</span><div className="level-bar"><i className="green" style={{ width: `${row.onTrack}%` }} /><i className="orange" style={{ width: `${row.monitor}%` }} /><i className="red" style={{ width: `${row.support}%` }} /></div></div>)}</div>
        <div className="legend"><span><i className="green" />Phát triển tốt</span><span><i className="orange" />Cần theo dõi</span><span><i className="red" />Cần hỗ trợ</span></div>
      </Panel>
    </div>
  </div>;
}
