import React, { useState } from "react";
import { Badge, DataTable, MockNotice, PageHeading, Panel, StatCard, Tabs } from "../../shared/ui.jsx";

// ai_chatbot.unanswered_questions (F18.2)
const initialUnanswered = [
  { id: "q1", question: "Bé 9 tháng bị sốt sau tiêm 5 trong 1 bao lâu thì hết?", reason: "low_score", score: 0.41, status: "new", at: "12/10 08:15" },
  { id: "q2", question: "Có nên cho bé 7 tháng uống nước dừa không?", reason: "no_relevant_source", score: 0.22, status: "new", at: "12/10 07:52" },
  { id: "q3", question: "Thuốc hạ sốt cho bé 2 tuổi liều bao nhiêu?", reason: "safety_blocked", score: null, status: "new", at: "11/10 21:30" },
  { id: "q4", question: "Giá vé xem phim cuối tuần?", reason: "out_of_scope", score: null, status: "ignored", at: "11/10 19:04" },
];

// ai_chatbot.chat_request_logs (F18.1, F18.3) — chỉ hiển thị câu hỏi đã rút gọn
const requestLogs = [
  { id: 1, query: "Bé 18 tháng chưa nói được câu…", intent: "milestone", chunks: 5, score: 0.86, tokens: 1840, ms: 2310, status: "success" },
  { id: 2, query: "Hoạt động giúp bé khéo tay hơn…", intent: "home_support", chunks: 4, score: 0.79, tokens: 1522, ms: 1980, status: "success" },
  { id: 3, query: "Kết quả đánh giá của bé có ý nghĩa…", intent: "assessment_result", chunks: 3, score: 0.74, tokens: 2104, ms: 3420, status: "success" },
  { id: 4, query: "Lịch tiêm mũi sởi thứ 2…", intent: "knowledge", chunks: 0, score: null, tokens: 0, ms: 15000, status: "timeout" },
];

// ai_chatbot.chat_messages có feedback = -1
const negativeFeedback = [
  { id: "f1", question: "Bé mấy tháng thì mọc răng hàm?", answer: "Răng hàm thứ nhất thường mọc khoảng 13–19 tháng…", sources: 2, at: "12/10 09:01" },
  { id: "f2", question: "Bé ngủ ít có sao không?", answer: "Mỗi bé có nhu cầu ngủ khác nhau, mẹ nên…", sources: 0, at: "11/10 22:47" },
];

const reasons = { no_relevant_source: "Không có nguồn", low_score: "Điểm truy xuất thấp", out_of_scope: "Ngoài phạm vi", safety_blocked: "Chặn an toàn" };
const reviewStatus = { new: ["orange", "Mới"], reviewed: ["blue", "Đã xem"], kb_updated: ["green", "Đã bổ sung KB"], ignored: ["gray", "Bỏ qua"] };
const requestStatus = { success: "green", error: "red", timeout: "orange", blocked: "gray" };

export default function ChatbotMonitorPage({ onNotify }) {
  const [tab, setTab] = useState("unanswered");
  const [unanswered, setUnanswered] = useState(initialUnanswered);

  function mark(id, status, message) {
    setUnanswered((current) => current.map((item) => item.id === id ? { ...item, status } : item));
    onNotify(message);
  }

  return <div>
    <PageHeading eyebrow="AI & CHATBOT" title="Giám sát chatbot" subtitle="Chất lượng câu trả lời, câu hỏi chưa có nguồn và hiệu năng (F18)." />
    <MockNotice />
    <div className="stats-grid">
      <StatCard title="YÊU CẦU 24 GIỜ QUA" value="642" icon="message" tone="green" sub="tỷ lệ lỗi / timeout 1,4%" />
      <StatCard title="CÓ NGUỒN TRÍCH DẪN" value="94%" icon="book" tone="blue" sub="has_source = true" />
      <StatCard title="ĐỘ TRỄ TRUNG BÌNH" value="2,4 s" icon="activity" tone="purple" sub="p95: 4,8 s · truy xuất 180 ms" />
      <StatCard title="PHẢN HỒI TÍCH CỰC" value="87%" icon="check" tone="orange" sub="312 👍 · 46 👎" />
    </div>
    <Tabs active={tab} onChange={setTab} tabs={[
      { id: "unanswered", label: "Câu hỏi chưa trả lời được", count: unanswered.filter((item) => item.status === "new").length },
      { id: "feedback", label: "Phản hồi tiêu cực", count: negativeFeedback.length },
      { id: "logs", label: "Log yêu cầu" },
    ]} />
    {tab === "unanswered" && <Panel title="Câu hỏi chưa trả lời được" subtitle="Bổ sung tài liệu vào kho tri thức rồi đánh dấu “Đã bổ sung KB”">
      <DataTable rowKey="id" rows={unanswered} paginate columns={[
        { key: "question", label: "CÂU HỎI", wrap: true },
        { key: "reason", label: "LÝ DO", render: (item) => reasons[item.reason] },
        { key: "score", label: "ĐIỂM CAO NHẤT", render: (item) => item.score ?? "—" },
        { key: "status", label: "TRẠNG THÁI", render: (item) => <Badge tone={reviewStatus[item.status][0]}>{reviewStatus[item.status][1]}</Badge> },
        { key: "at", label: "THỜI GIAN" },
        { key: "actions", label: "", render: (item) => item.status === "new" && <div className="row-actions"><button className="link-button" onClick={() => mark(item.id, "kb_updated", "Đã đánh dấu bổ sung kho tri thức")}>Đã bổ sung KB</button><button className="link-button muted" onClick={() => mark(item.id, "ignored", "Đã bỏ qua câu hỏi")}>Bỏ qua</button></div> },
      ]} />
    </Panel>}
    {tab === "feedback" && <Panel title="Câu trả lời bị đánh giá 👎" subtitle="ai_chatbot.chat_messages · feedback = -1">
      <DataTable rowKey="id" rows={negativeFeedback} paginate columns={[
        { key: "question", label: "CÂU HỎI", wrap: true },
        { key: "answer", label: "CÂU TRẢ LỜI", wrap: true },
        { key: "sources", label: "SỐ NGUỒN", render: (item) => item.sources === 0 ? <Badge tone="red">Không có</Badge> : item.sources },
        { key: "at", label: "THỜI GIAN" },
      ]} />
    </Panel>}
    {tab === "logs" && <Panel title="Log yêu cầu" subtitle="ai_chatbot.chat_request_logs — câu hỏi rút gọn để hạn chế lộ thông tin của trẻ">
      <DataTable rowKey="id" rows={requestLogs} paginate columns={[
        { key: "query", label: "CÂU HỎI", wrap: true },
        { key: "intent", label: "Ý ĐỊNH", render: (log) => <code>{log.intent}</code> },
        { key: "chunks", label: "CHUNK" },
        { key: "score", label: "TOP SCORE", render: (log) => log.score ?? "—" },
        { key: "tokens", label: "TOKEN" },
        { key: "ms", label: "TỔNG (MS)" },
        { key: "status", label: "TRẠNG THÁI", render: (log) => <Badge tone={requestStatus[log.status]}>{log.status}</Badge> },
      ]} />
    </Panel>}
  </div>;
}
