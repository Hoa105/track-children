import React, { useState } from "react";
import { Badge, DataTable, MockNotice, PageHeading, Panel, Tabs } from "../../shared/ui.jsx";

// community.content_reports — bài đăng hiển thị ngay (status mặc định 'published'),
// nên kiểm duyệt dựa trên báo cáo; mỗi xử lý ghi community.moderation_actions.
const initialReports = [
  { id: "r1", targetType: "post", excerpt: "Mua thuốc tăng chiều cao này cho bé, cam kết cao thêm 5cm…", author: "@banhang247", reason: "spam", detail: "Quảng cáo sản phẩm", reports: 6, status: "pending", at: "12/10 08:30" },
  { id: "r2", targetType: "comment", excerpt: "Mẹ kiểu gì mà để con chậm nói thế…", author: "@user8812", reason: "harassment", detail: null, reports: 2, status: "pending", at: "11/10 22:10" },
  { id: "r3", targetType: "post", excerpt: "Bé nhà mình sốt 39 độ, mình cho uống … là hết ngay…", author: "@me_bong", reason: "medical_misinformation", detail: "Khuyên dùng thuốc không đúng liều", reports: 3, status: "pending", at: "11/10 15:42" },
  { id: "r4", targetType: "post", excerpt: "Chia sẻ thực đơn ăn dặm 7 tháng…", author: "@thuha_mom", reason: "other", detail: "Nhầm", reports: 1, status: "dismissed", at: "09/10 10:05" },
];

const reasons = { spam: "Spam / quảng cáo", harassment: "Xúc phạm", medical_misinformation: "Thông tin y tế sai", other: "Khác" };

export default function ReportsPage({ onNotify }) {
  const [reports, setReports] = useState(initialReports);
  const [tab, setTab] = useState("pending");
  const shown = reports.filter((report) => tab === "all" || (tab === "pending" ? report.status === "pending" : report.status !== "pending"));

  function handle(report, status, message) {
    setReports((current) => current.map((item) => item.id === report.id ? { ...item, status } : item));
    onNotify(message);
  }

  return <div>
    <PageHeading eyebrow="CỘNG ĐỒNG" title="Báo cáo vi phạm" subtitle="Nội dung bị người dùng báo cáo (F21.4, F22)." />
    <MockNotice />
    <Tabs active={tab} onChange={setTab} tabs={[{ id: "pending", label: "Chờ xử lý", count: reports.filter((report) => report.status === "pending").length }, { id: "handled", label: "Đã xử lý" }, { id: "all", label: "Tất cả" }]} />
    <Panel title="Danh sách báo cáo" subtitle="Gộp theo nội dung bị báo cáo">
      <DataTable rowKey="id" rows={shown} paginate columns={[
        { key: "excerpt", label: "NỘI DUNG", wrap: true, render: (report) => <div className="stack"><span>{report.excerpt}</span><small>{report.targetType === "post" ? "Bài viết" : "Bình luận"} · {report.author}</small></div> },
        { key: "reason", label: "LÝ DO", render: (report) => <div className="stack"><span>{reasons[report.reason]}</span>{report.detail && <small>{report.detail}</small>}</div> },
        { key: "reports", label: "SỐ BÁO CÁO" },
        { key: "at", label: "GẦN NHẤT" },
        { key: "status", label: "TRẠNG THÁI", render: (report) => report.status === "pending" ? <Badge tone="orange">Chờ xử lý</Badge> : report.status === "resolved" ? <Badge tone="green">Đã xử lý</Badge> : <Badge tone="gray">Bỏ qua</Badge> },
        { key: "actions", label: "", render: (report) => report.status === "pending" && <div className="row-actions"><button className="link-button danger" onClick={() => handle(report, "resolved", "Đã ẩn nội dung")}>Ẩn</button><button className="link-button danger" onClick={() => handle(report, "resolved", `Đã ẩn nội dung và khóa ${report.author}`)}>Ẩn + khóa tác giả</button><button className="link-button muted" onClick={() => handle(report, "dismissed", "Đã bỏ qua báo cáo")}>Bỏ qua</button></div> },
      ]} />
    </Panel>
  </div>;
}
