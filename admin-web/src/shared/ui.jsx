import React, { useState } from "react";
import Icon from "./Icon.jsx";

export function PageHeading({ eyebrow, title, subtitle, children }) {
  return <div className="page-heading"><div>{eyebrow && <p className="eyebrow">{eyebrow}</p>}<h1>{title}</h1>{subtitle && <p className="subtitle">{subtitle}</p>}</div>{children && <div className="heading-actions">{children}</div>}</div>;
}

export function Panel({ title, subtitle, action, className = "", children }) {
  return <section className={`panel ${className}`}>{(title || action) && <div className="panel-header"><div>{title && <h2>{title}</h2>}{subtitle && <p>{subtitle}</p>}</div>{action}</div>}{children}</section>;
}

export function StatCard({ title, value, sub, icon, tone, chart = [] }) {
  return <div className="stat-card"><div className={`stat-icon ${tone}`}><Icon name={icon} size={21} /></div><p>{title}</p><strong>{value}</strong>{sub && <div className="stat-sub">{sub}</div>}{chart.length > 0 && <div className={`mini-chart ${tone}`}>{chart.map((height, index) => <i key={index} style={{ height: `${height * 5 + 8}px` }} />)}</div>}</div>;
}

// tone: green | orange | red | blue | purple | gray
export function Badge({ tone = "gray", children }) {
  return <span className={`badge ${tone}`}><i />{children}</span>;
}

export function Tabs({ tabs, active, onChange }) {
  return <div className="tabs" role="tablist">{tabs.map((tab) => <button key={tab.id} role="tab" aria-selected={active === tab.id} className={active === tab.id ? "active" : ""} onClick={() => onChange(tab.id)}>{tab.label}{tab.count != null && <em>{tab.count}</em>}</button>)}</div>;
}

// paginate: hiện chân bảng chọn 20 / 40 / 60 dòng mỗi trang
// onRowClick: bấm vào bất kỳ chỗ nào trên dòng — nút / ô chọn trong dòng cần stopPropagation
export function DataTable({ columns, rows, rowKey, empty = "Không có dữ liệu", paginate = false, onRowClick }) {
  const [pageSize, setPageSize] = useState(PAGE_SIZES[0]);
  const [page, setPage] = useState(1);
  const pageCount = Math.max(1, Math.ceil(rows.length / pageSize));
  const current = Math.min(page, pageCount);
  const shown = paginate ? rows.slice((current - 1) * pageSize, current * pageSize) : rows;

  return <>
    <div className="table-wrap"><table><thead><tr>{columns.map((column) => <th key={column.key}>{column.label}</th>)}</tr></thead><tbody>{shown.length === 0 ? <tr><td colSpan={columns.length} className="table-empty">{empty}</td></tr> : shown.map((row) => <tr key={row[rowKey]} className={onRowClick ? "clickable-row" : ""} onClick={onRowClick && (() => onRowClick(row))}>{columns.map((column) => <td key={column.key} className={column.wrap ? "wrap" : ""}>{column.render ? column.render(row) : row[column.key]}</td>)}</tr>)}</tbody></table></div>
    {paginate && <div className="pagination">
      <label>Hiển thị<select value={pageSize} onChange={(event) => { setPageSize(Number(event.target.value)); setPage(1); }}>{PAGE_SIZES.map((size) => <option key={size} value={size}>{size} dòng</option>)}</select></label>
      <span>{rows.length === 0 ? "0" : `${(current - 1) * pageSize + 1}–${Math.min(current * pageSize, rows.length)}`} / {rows.length}</span>
      <div className="pager">
        <button aria-label="Trang trước" disabled={current === 1} onClick={() => setPage(current - 1)}><Icon name="arrow" size={14} /></button>
        <b>{current} / {pageCount}</b>
        <button aria-label="Trang sau" disabled={current === pageCount} onClick={() => setPage(current + 1)}><Icon name="arrow" size={14} /></button>
      </div>
    </div>}
  </>;
}

const PAGE_SIZES = [20, 40, 60];

// Chặn click lan lên dòng (dùng cho nút / select nằm trong dòng có onRowClick)
export function stopRowClick(event) {
  event.stopPropagation();
}

// Bộ lọc thời gian dùng chung — value: { preset, from, to } (from/to dạng yyyy-mm-dd)
export const ALL_TIME = { preset: "all", from: "", to: "" };
const TIME_PRESETS = [
  { id: "all", label: "Mọi thời gian" },
  { id: "7", label: "7 ngày qua" },
  { id: "30", label: "30 ngày qua" },
  { id: "90", label: "90 ngày qua" },
  { id: "custom", label: "Tùy chọn khoảng ngày" },
];

export function TimeFilter({ value, onChange, label = "Thời gian" }) {
  return <div className="time-filter">
    <Icon name="calendar" size={15} />
    <select aria-label={label} value={value.preset} onChange={(event) => onChange({ ...value, preset: event.target.value })}>{TIME_PRESETS.map((preset) => <option key={preset.id} value={preset.id}>{preset.id === "all" ? `${label}: ${preset.label.toLowerCase()}` : preset.label}</option>)}</select>
    {value.preset === "custom" && <>
      <input type="date" aria-label="Từ ngày" value={value.from} max={value.to || undefined} onChange={(event) => onChange({ ...value, from: event.target.value })} />
      <span>–</span>
      <input type="date" aria-label="Đến ngày" value={value.to} min={value.from || undefined} onChange={(event) => onChange({ ...value, to: event.target.value })} />
    </>}
  </div>;
}

// date: chuỗi "dd/mm/yyyy" (có thể kèm giờ) như dữ liệu mẫu
export function inTimeRange(date, range) {
  if (range.preset === "all") return true;
  const match = /^(\d{1,2})\/(\d{1,2})\/(\d{4})/.exec(date ?? "");
  if (!match) return false;
  const day = new Date(Number(match[3]), Number(match[2]) - 1, Number(match[1]));
  if (range.preset === "custom") {
    return (!range.from || day >= new Date(`${range.from}T00:00`)) && (!range.to || day <= new Date(`${range.to}T00:00`));
  }
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  return day <= today && day > new Date(today.getTime() - Number(range.preset) * 86400000);
}

export function MockNotice() {
  return <div className="mock-notice">Dữ liệu mẫu — sẽ thay bằng API quản trị của backend khi endpoint sẵn sàng.</div>;
}

export function TableTags({ tables }) {
  return <div className="table-tags">{tables.map((table) => <code key={table}>{table}</code>)}</div>;
}
