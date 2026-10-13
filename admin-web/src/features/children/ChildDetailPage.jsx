import React, { useState } from "react";
import { useAuth } from "../../core/auth.jsx";
import { navigate } from "../../core/useHashRoute.js";
import Icon from "../../shared/Icon.jsx";
import { Badge, DataTable, MockNotice, Panel } from "../../shared/ui.jsx";

// Tra cứu MỘT hồ sơ trẻ để hỗ trợ phụ huynh (quyền child.support_view).
// Chỉ thông tin hành chính: child.children (tên, tuổi, giới tính), child.child_members,
// child.child_invitations, child.ownership_transfers. KHÔNG đọc ngày sinh đầy đủ,
// dị ứng, nhóm máu, số đo, đánh giá, tiêm chủng, nhật ký.
// Mỗi lần mở phải nhập lý do — backend ghi admin.admin_audit_logs (action = 'view', entity_type = 'child').
// Người dùng có userId thì mở được trang chi tiết; null = tài khoản ngoài dữ liệu mẫu.
const children = {
  c1: {
    name: "Nguyễn Ngọc Na", nickname: "Bé Na", birth: "2025-04", gender: "female", createdAt: "12/06/2026", deleted: false,
    members: [
      { userId: "u1", name: "Nguyễn Minh Anh", relationship: "Mẹ", role: "owner", status: "active", joined: "12/06/2026" },
      { userId: "u3", name: "Lê Thu Hà", relationship: "Dì", role: "member", status: "active", joined: "03/07/2026" },
    ],
    invitations: [{ id: "ci1", invitee: "ba***@gmail.com", relationship: "Bố", inviter: "Nguyễn Minh Anh", status: "pending", expires: "15/10/2026" }],
    transfers: [],
  },
  c2: {
    name: "Nguyễn Gia Bin", nickname: "Bé Bin", birth: "2026-01", gender: "male", createdAt: "02/08/2026", deleted: false,
    members: [{ userId: "u1", name: "Nguyễn Minh Anh", relationship: "Mẹ", role: "owner", status: "active", joined: "02/08/2026" }],
    invitations: [], transfers: [],
  },
  c3: {
    name: "Trần Minh Sóc", nickname: "Bé Sóc", birth: "2024-11", gender: "male", createdAt: "11/06/2026", deleted: false,
    members: [
      { userId: "u2", name: "Trần Hoàng Nam", relationship: "Bố", role: "owner", status: "active", joined: "11/06/2026" },
      { userId: "u1", name: "Nguyễn Minh Anh", relationship: "Cô", role: "member", status: "active", joined: "20/07/2026" },
      { userId: "u5", name: "Đỗ Ngọc Linh", relationship: "Bà", role: "member", status: "active", joined: "05/08/2026" },
    ],
    invitations: [], transfers: [],
  },
  c4: {
    name: "Lê Bảo Mít", nickname: "Bé Mít", birth: "2024-03", gender: "female", createdAt: "10/06/2026", deleted: false,
    members: [
      { userId: "u3", name: "Lê Thu Hà", relationship: "Mẹ", role: "owner", status: "active", joined: "10/06/2026" },
      { userId: null, name: "Phạm Văn Đức", relationship: "Bố", role: "member", status: "active", joined: "15/06/2026" },
    ],
    invitations: [],
    transfers: [{ id: "t1", from: "Lê Thu Hà", to: "Phạm Văn Đức", status: "pending", created: "12/10/2026", expires: "19/10/2026" }],
  },
  c5: {
    name: "Lê Gia Bơ", nickname: "Bé Bơ", birth: "2025-09", gender: "male", createdAt: "10/06/2026", deleted: false,
    members: [{ userId: "u3", name: "Lê Thu Hà", relationship: "Mẹ", role: "owner", status: "active", joined: "10/06/2026" }],
    invitations: [], transfers: [],
  },
  c6: {
    name: "Lê An Cốm", nickname: "Bé Cốm", birth: "2026-07", gender: "female", createdAt: "01/09/2026", deleted: false,
    members: [{ userId: "u3", name: "Lê Thu Hà", relationship: "Mẹ", role: "owner", status: "active", joined: "01/09/2026" }],
    invitations: [{ id: "ci2", invitee: "+8490***4521", relationship: "Bà", inviter: "Lê Thu Hà", status: "expired", expires: "08/09/2026" }],
    transfers: [],
  },
  c7: {
    name: "Lê Minh Đậu", nickname: "Bé Đậu", birth: "2023-12", gender: "male", createdAt: "02/05/2026", deleted: false,
    members: [
      { userId: null, name: "Lê Văn Hùng", relationship: "Bố", role: "owner", status: "active", joined: "02/05/2026" },
      { userId: "u3", name: "Lê Thu Hà", relationship: "Cô", role: "member", status: "active", joined: "15/08/2026" },
    ],
    invitations: [], transfers: [],
  },
  c8: {
    name: "Phạm Quốc Tôm", nickname: "Bé Tôm", birth: "2025-06", gender: "male", createdAt: "08/06/2026", deleted: false,
    members: [{ userId: "u4", name: "Phạm Quốc Bảo", relationship: "Bố", role: "owner", status: "active", joined: "08/06/2026" }],
    invitations: [], transfers: [],
  },
};

const reasons = [
  "Hỗ trợ theo yêu cầu của phụ huynh",
  "Xử lý chuyển quyền chủ hồ sơ",
  "Xử lý lời mời / thành viên chia sẻ",
  "Điều tra báo cáo vi phạm",
  "Yêu cầu xóa tài khoản còn hồ sơ trẻ",
];

// Các lượt tra cứu trong phiên mock — thật sự sẽ đọc từ admin.admin_audit_logs
const accessLogs = [
  { id: "v1", childId: "c4", admin: "Hà Phương", reason: "Xử lý chuyển quyền chủ hồ sơ", note: "Ticket #482", at: "12/10/2026 08:15" },
  { id: "v2", childId: "c1", admin: "Lan Nguyễn", reason: "Xử lý lời mời / thành viên chia sẻ", note: "Mẹ báo bố không nhận được lời mời", at: "11/10/2026 16:02" },
];

const memberStatus = { active: ["green", "Đang chia sẻ"], revoked: ["red", "Đã thu hồi"], left: ["gray", "Đã rời"] };
const requestStatus = { pending: ["orange", "Đang chờ"], accepted: ["green", "Đã chấp nhận"], declined: ["gray", "Từ chối"], cancelled: ["gray", "Đã hủy"], expired: ["red", "Hết hạn"] };

function ageText(birth) {
  const [year, month] = birth.split("-").map(Number);
  const now = new Date();
  const months = (now.getFullYear() - year) * 12 + (now.getMonth() + 1 - month);
  return months < 24 ? `${months} tháng tuổi` : `${Math.floor(months / 12)} tuổi ${months % 12} tháng`;
}

function StatusBadge({ map, status }) {
  const [tone, label] = map[status];
  return <Badge tone={tone}>{label}</Badge>;
}

function PersonLink({ userId, name }) {
  return userId ? <button className="cell-link" onClick={() => navigate(`/users/${userId}`)}><b>{name}</b></button> : <b>{name}</b>;
}

function InfoList({ rows }) {
  return <dl className="info-list">{rows.map(([label, value]) => <React.Fragment key={label}><dt>{label}</dt><dd>{value ?? "—"}</dd></React.Fragment>)}</dl>;
}

function ReasonGate({ child, backPath, onSubmit }) {
  const [reason, setReason] = useState(reasons[0]);
  const [note, setNote] = useState("");
  const valid = note.trim().length >= 5;
  return <div className="panel reason-gate">
    <div className="stat-icon purple"><Icon name="shield" size={20} /></div>
    <h2>Tra cứu hồ sơ {child.nickname}</h2>
    <p>Hồ sơ trẻ thuộc về phụ huynh. Chỉ mở khi cần hỗ trợ — lý do và người tra cứu được ghi vào nhật ký quản trị, Super Admin có thể kiểm tra lại.</p>
    <form className="form-stack" onSubmit={(event) => { event.preventDefault(); if (valid) onSubmit(reason, note.trim()); }}>
      <label><span>Lý do</span><select value={reason} onChange={(event) => setReason(event.target.value)}>{reasons.map((item) => <option key={item}>{item}</option>)}</select></label>
      <label><span>Mã ticket / mô tả yêu cầu</span><input value={note} onChange={(event) => setNote(event.target.value)} placeholder="VD: Ticket #482 — phụ huynh nhờ kiểm tra chuyển quyền" autoFocus /></label>
      <div className="modal-actions">
        <button type="button" className="button secondary" onClick={() => navigate(backPath)}>Quay lại</button>
        <button type="submit" className="button primary" disabled={!valid}>Xem hồ sơ</button>
      </div>
    </form>
  </div>;
}

export default function ChildDetailPage({ id, onNotify }) {
  const { admin } = useAuth();
  const child = children[id];
  const [access, setAccess] = useState(null);

  if (!child) {
    return <div className="panel empty-state"><h2>Không tìm thấy hồ sơ</h2><p>Hồ sơ <code>{id}</code> không tồn tại hoặc đã bị xóa.</p><button className="button secondary" onClick={() => navigate("/children")}>Về thống kê hồ sơ trẻ</button></div>;
  }

  const owner = child.members.find((member) => member.role === "owner");
  const backPath = owner.userId ? `/users/${owner.userId}` : "/children";

  if (!access) {
    return <ReasonGate child={child} backPath={backPath} onSubmit={(reason, note) => {
      const entry = { id: `v${Date.now()}`, childId: id, admin: admin.fullName, reason, note, at: new Date().toLocaleString("vi-VN", { dateStyle: "short", timeStyle: "short" }) };
      accessLogs.unshift(entry);
      setAccess(entry);
      onNotify("Đã ghi lượt tra cứu vào nhật ký quản trị");
    }} />;
  }

  const logs = accessLogs.filter((log) => log.childId === id);

  return <div>
    <button className="text-link detail-back" onClick={() => navigate(backPath)}><Icon name="arrow" size={14} /> {owner.userId ? `Người dùng ${owner.name}` : "Thống kê hồ sơ trẻ"}</button>
    <div className="detail-header">
      <div className={`avatar avatar-lg ${child.gender === "female" ? "avatar-peach" : "avatar-blue"}`}><Icon name="child" size={22} /></div>
      <div className="detail-title"><h1>{child.nickname}</h1><p>{child.name} · {ageText(child.birth)} · {child.gender === "female" ? "Nữ" : "Nam"}</p></div>
      {child.deleted ? <Badge tone="gray">Đã xóa</Badge> : <Badge tone="green">Đang theo dõi</Badge>}
    </div>
    <MockNotice />
    <div className="detail-alert">
      Đang tra cứu với lý do <b>{access.reason}</b> — “{access.note}”. Dữ liệu sức khỏe (số đo, đánh giá, tiêm chủng, nhật ký, dị ứng) không hiển thị cho quản trị viên.
    </div>

    <div className="content-grid">
      <Panel title="Thành viên chia sẻ" subtitle="child.child_members — quyền từng mục do chủ hồ sơ cấp trên app">
        <DataTable rowKey="name" rows={child.members} columns={[
          { key: "name", label: "NGƯỜI DÙNG", render: (member) => <PersonLink {...member} /> },
          { key: "relationship", label: "QUAN HỆ" },
          { key: "role", label: "VAI TRÒ", render: (member) => member.role === "owner" ? <Badge tone="green">Chủ sở hữu</Badge> : <Badge tone="blue">Thành viên</Badge> },
          { key: "joined", label: "TỪ NGÀY" },
          { key: "status", label: "TRẠNG THÁI", render: (member) => <StatusBadge map={memberStatus} status={member.status} /> },
        ]} />
      </Panel>
      <Panel title="Thông tin hồ sơ" subtitle="child.children — chỉ trường hành chính">
        <InfoList rows={[
          ["Chủ hồ sơ", <PersonLink {...owner} />],
          ["Tháng / năm sinh", child.birth.split("-").reverse().join("/")],
          ["Giới tính", child.gender === "female" ? "Nữ" : "Nam"],
          ["Số thành viên", child.members.filter((member) => member.status === "active").length],
          ["Ngày tạo hồ sơ", child.createdAt],
        ]} />
      </Panel>
    </div>

    <div className="content-grid">
      <Panel title="Chuyển quyền chủ hồ sơ" subtitle="child.ownership_transfers (F23.9) — người nhận phải chấp nhận trên app">
        <DataTable rowKey="id" rows={child.transfers} empty="Không có yêu cầu chuyển quyền" columns={[
          { key: "from", label: "TỪ" },
          { key: "to", label: "SANG" },
          { key: "created", label: "NGÀY TẠO" },
          { key: "expires", label: "HẾT HẠN" },
          { key: "status", label: "TRẠNG THÁI", render: (transfer) => <StatusBadge map={requestStatus} status={transfer.status} /> },
        ]} />
      </Panel>
      <Panel title="Lời mời tham gia" subtitle="child.child_invitations — email / SĐT đã che bớt">
        <DataTable rowKey="id" rows={child.invitations} empty="Không có lời mời" columns={[
          { key: "invitee", label: "NGƯỜI ĐƯỢC MỜI", render: (invitation) => <div className="stack"><span>{invitation.invitee}</span><small>{invitation.relationship} · mời bởi {invitation.inviter}</small></div> },
          { key: "status", label: "", render: (invitation) => <div className="stack"><StatusBadge map={requestStatus} status={invitation.status} /><small>hết hạn {invitation.expires}</small></div> },
        ]} />
      </Panel>
    </div>

    <Panel title="Lượt tra cứu hồ sơ này" subtitle="admin.admin_audit_logs — action = view, entity_type = child">
      <DataTable rowKey="id" rows={logs} columns={[
        { key: "admin", label: "QUẢN TRỊ VIÊN" },
        { key: "reason", label: "LÝ DO", wrap: true, render: (log) => <div className="stack"><span>{log.reason}</span><small>{log.note}</small></div> },
        { key: "at", label: "THỜI GIAN" },
      ]} />
    </Panel>
  </div>;
}
