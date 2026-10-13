import React, { useState } from "react";
import Icon from "../../shared/Icon.jsx";
import { Badge, DataTable, MockNotice, PageHeading, Panel, Tabs } from "../../shared/ui.jsx";

// ai_kb.kb_documents (+ số chunk từ ai_kb.kb_chunks)
const initialDocuments = [
  { id: "k1", title: "WHO – Mốc phát triển vận động 0–24 tháng", category: "development", fileType: "pdf", version: 2, status: "indexed", active: true, chunks: 184, updated: "02/10/2026" },
  { id: "k2", title: "Bộ Y tế – Lịch tiêm chủng mở rộng 2025", category: "vaccination", fileType: "pdf", version: 1, status: "indexed", active: true, chunks: 46, updated: "28/09/2026" },
  { id: "k3", title: "Hướng dẫn ăn bổ sung cho trẻ 6–24 tháng", category: "nutrition", fileType: "docx", version: 1, status: "processing", active: true, chunks: 0, updated: "12/10/2026" },
  { id: "k4", title: "Hoạt động hỗ trợ ngôn ngữ tại nhà", category: "home_support", fileType: "md", version: 3, status: "failed", active: false, chunks: 0, updated: "11/10/2026" },
  { id: "k5", title: "CDC – Learn the Signs. Act Early (bản cũ)", category: "development", fileType: "html", version: 1, status: "archived", active: false, chunks: 97, updated: "15/05/2026" },
];

// ai_kb.kb_index_jobs
const jobs = [
  { id: "j1", document: "Hướng dẫn ăn bổ sung cho trẻ 6–24 tháng", type: "index", status: "running", model: "bge-m3", chunkSize: 800, chunks: null, error: null, at: "12/10 09:42" },
  { id: "j2", document: "Hoạt động hỗ trợ ngôn ngữ tại nhà", type: "reindex", status: "failed", model: "bge-m3", chunkSize: 800, chunks: null, error: "Không trích xuất được văn bản: file rỗng", at: "11/10 16:05" },
  { id: "j3", document: "WHO – Mốc phát triển vận động 0–24 tháng", type: "reindex", status: "succeeded", model: "bge-m3", chunkSize: 800, chunks: 184, error: null, at: "02/10 10:11" },
];

const documentStatus = { uploaded: ["gray", "Đã tải lên"], processing: ["blue", "Đang xử lý"], indexed: ["green", "Đã index"], failed: ["red", "Lỗi"], archived: ["gray", "Lưu trữ"] };
const jobStatus = { queued: ["gray", "Chờ"], running: ["blue", "Đang chạy"], succeeded: ["green", "Thành công"], failed: ["red", "Lỗi"] };
const categories = { development: "Phát triển", nutrition: "Dinh dưỡng", vaccination: "Tiêm chủng", home_support: "Hỗ trợ tại nhà" };

export default function KnowledgeBasePage({ onNotify }) {
  const [tab, setTab] = useState("documents");
  const [documents, setDocuments] = useState(initialDocuments);

  function toggleActive(id) {
    setDocuments((current) => current.map((doc) => doc.id === id ? { ...doc, active: !doc.active } : doc));
  }

  return <div>
    <PageHeading eyebrow="AI & CHATBOT" title="Kho tri thức" subtitle="Tài liệu chatbot dùng để trả lời (RAG, F14). Chatbot chỉ truy xuất tài liệu đã index và đang bật.">
      <button className="button primary" onClick={() => onNotify("Đã thêm tài liệu vào hàng đợi index")}><Icon name="upload" size={16} /> Tải tài liệu lên</button>
    </PageHeading>
    <MockNotice />
    <Tabs active={tab} onChange={setTab} tabs={[{ id: "documents", label: "Tài liệu", count: documents.length }, { id: "jobs", label: "Job index", count: jobs.filter((job) => job.status === "failed").length || null }]} />
    {tab === "documents" ? (
      <Panel title="Tài liệu" subtitle="ai_kb.kb_documents">
        <DataTable rowKey="id" rows={documents} paginate columns={[
          { key: "title", label: "TÀI LIỆU", wrap: true, render: (doc) => <div className="stack"><b>{doc.title}</b><small>{doc.fileType.toUpperCase()} · phiên bản {doc.version}</small></div> },
          { key: "category", label: "CHỦ ĐỀ", render: (doc) => categories[doc.category] },
          { key: "chunks", label: "CHUNK" },
          { key: "status", label: "TRẠNG THÁI", render: (doc) => <Badge tone={documentStatus[doc.status][0]}>{documentStatus[doc.status][1]}</Badge> },
          { key: "active", label: "DÙNG CHO CHATBOT", render: (doc) => <label className="switch"><input type="checkbox" checked={doc.active} disabled={doc.status !== "indexed"} onChange={() => toggleActive(doc.id)} /><span /></label> },
          { key: "updated", label: "CẬP NHẬT" },
          { key: "actions", label: "", render: (doc) => <button className="link-button" onClick={() => onNotify(`Đã tạo job reindex cho "${doc.title}"`)}>Index lại</button> },
        ]} />
      </Panel>
    ) : (
      <Panel title="Job index" subtitle="ai_kb.kb_index_jobs — tách chunk + tạo embedding">
        <DataTable rowKey="id" rows={jobs} paginate columns={[
          { key: "document", label: "TÀI LIỆU", wrap: true },
          { key: "type", label: "LOẠI" },
          { key: "model", label: "EMBEDDING", render: (job) => <code>{job.model}</code> },
          { key: "chunkSize", label: "CHUNK SIZE" },
          { key: "chunks", label: "CHUNK TẠO RA", render: (job) => job.chunks ?? "—" },
          { key: "status", label: "TRẠNG THÁI", render: (job) => <Badge tone={jobStatus[job.status][0]}>{jobStatus[job.status][1]}</Badge> },
          { key: "error", label: "LỖI", wrap: true, render: (job) => job.error ?? "—" },
          { key: "at", label: "THỜI GIAN" },
        ]} />
      </Panel>
    )}
  </div>;
}
