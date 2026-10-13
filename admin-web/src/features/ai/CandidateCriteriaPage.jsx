import React, { useState } from "react";
import { Badge, MockNotice, PageHeading, Panel, Tabs } from "../../shared/ui.jsx";

// ai_kb.candidate_criteria — LLM trích xuất từ tài liệu tri thức (F14.3/F14.4).
// Duyệt = backend tạo criteria.criteria (+ câu hỏi) trong phiên bản NHÁP của bộ tiêu chí,
// rồi ghi promoted_criterion_id. Không bao giờ đưa thẳng vào bản đang published.
const initialCandidates = [
  { id: "cc1", domain: "Ngôn ngữ", milestone: "18 tháng", title: "Nói được ít nhất 10 từ có nghĩa", description: "Trẻ dùng từ đơn để gọi tên người, đồ vật quen thuộc.", questions: ["Bé có nói được ít nhất 10 từ mà người thân hiểu không?"], excerpt: "By 18 months, most children say several single words…", document: "WHO – Mốc phát triển vận động 0–24 tháng", confidence: 0.91, status: "pending" },
  { id: "cc2", domain: "Vận động tinh", milestone: "24 tháng", title: "Xếp chồng 6 khối vuông", description: "Trẻ xếp được tháp 6 khối mà không đổ.", questions: ["Bé có xếp được tháp 6 khối gỗ không?", "Bé có lật từng trang sách không?"], excerpt: "Builds tower of 6 cubes; turns pages one at a time…", document: "CDC – Learn the Signs. Act Early (bản cũ)", confidence: 0.84, status: "pending" },
  { id: "cc3", domain: "Xã hội – Cảm xúc", milestone: "12 tháng", title: "Chơi trò ú òa, vỗ tay", description: null, questions: ["Bé có thích chơi ú òa với người lớn không?"], excerpt: "Plays games such as peek-a-boo and pat-a-cake…", document: "CDC – Learn the Signs. Act Early (bản cũ)", confidence: 0.62, status: "pending" },
  { id: "cc4", domain: "Vận động thô", milestone: "12 tháng", title: "Đứng vững không cần vịn", description: null, questions: [], excerpt: "Stands alone…", document: "WHO – Mốc phát triển vận động 0–24 tháng", confidence: 0.88, status: "approved" },
];

const statusInfo = { pending: ["orange", "Chờ duyệt"], approved: ["green", "Đã duyệt"], rejected: ["red", "Từ chối"], merged: ["blue", "Đã gộp"] };

export default function CandidateCriteriaPage({ onNotify }) {
  const [candidates, setCandidates] = useState(initialCandidates);
  const [tab, setTab] = useState("pending");
  const shown = candidates.filter((candidate) => tab === "all" || candidate.status === tab);

  function review(candidate, status, message) {
    setCandidates((current) => current.map((item) => item.id === candidate.id ? { ...item, status } : item));
    onNotify(message);
  }

  return <div>
    <PageHeading eyebrow="AI & CHATBOT" title="Tiêu chí AI đề xuất" subtitle="Tiêu chí LLM trích xuất từ kho tri thức. Chuyên gia duyệt trước khi đưa vào bộ tiêu chí nháp." />
    <MockNotice />
    <Tabs active={tab} onChange={setTab} tabs={[
      { id: "pending", label: "Chờ duyệt", count: candidates.filter((candidate) => candidate.status === "pending").length },
      { id: "approved", label: "Đã duyệt" },
      { id: "rejected", label: "Từ chối" },
      { id: "all", label: "Tất cả" },
    ]} />
    <div className="card-list">
      {shown.length === 0 && <Panel><p className="table-empty">Không có đề xuất nào.</p></Panel>}
      {shown.map((candidate) => <Panel key={candidate.id} className="candidate-card">
        <div className="candidate-head">
          <div><div className="chip-row"><Badge tone="blue">{candidate.domain}</Badge><Badge tone="gray">Mốc {candidate.milestone}</Badge><Badge tone={statusInfo[candidate.status][0]}>{statusInfo[candidate.status][1]}</Badge></div><h3>{candidate.title}</h3>{candidate.description && <p>{candidate.description}</p>}</div>
          <div className={`confidence ${candidate.confidence < 0.7 ? "low" : ""}`}><b>{Math.round(candidate.confidence * 100)}%</b><span>độ tin cậy</span></div>
        </div>
        {candidate.questions.length > 0 && <div className="candidate-section"><p className="eyebrow">CÂU HỎI GỢI Ý</p><ul>{candidate.questions.map((question) => <li key={question}>{question}</li>)}</ul></div>}
        <blockquote>“{candidate.excerpt}”<cite>{candidate.document}</cite></blockquote>
        {candidate.status === "pending" && <div className="candidate-actions">
          <button className="button secondary" onClick={() => review(candidate, "rejected", "Đã từ chối đề xuất")}>Từ chối</button>
          <button className="button secondary" onClick={() => review(candidate, "merged", "Đã gộp vào tiêu chí có sẵn")}>Gộp vào tiêu chí có sẵn</button>
          <button className="button primary" onClick={() => review(candidate, "approved", "Đã thêm vào bộ tiêu chí nháp")}>Duyệt → bộ tiêu chí nháp</button>
        </div>}
      </Panel>)}
    </div>
  </div>;
}
