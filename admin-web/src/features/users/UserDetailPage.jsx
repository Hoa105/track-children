import React, { useState } from "react";
import { useAuth } from "../../core/auth.jsx";
import { can } from "../../core/session.js";
import { navigate } from "../../core/useHashRoute.js";
import Icon from "../../shared/Icon.jsx";
import { Badge, DataTable, MockNotice, Panel } from "../../shared/ui.jsx";
import { UserStatus, deletionRequests, users } from "./UsersPage.jsx";
import { CancelDeletionModal, ContactChangeModal } from "./RecoveryModals.jsx";

// Thông tin bổ sung cho trang chi tiết (account.users, account.user_sessions,
// account.user_consents, child.child_members, community.*).
// Hồ sơ trẻ chỉ hiện tên + vai trò của người dùng — KHÔNG có số đo, đánh giá
// hay ghi chú sức khỏe (dữ liệu đó thuộc phụ huynh).
const details = {
  u1: {
    relationship: "Mẹ", emailVerified: "12/06/2026", phoneVerified: "12/06/2026", lastLogin: "12/10/2026 07:48",
    children: [
      { id: "c1", name: "Bé Na", role: "owner", members: 2, since: "12/06/2026" },
      { id: "c2", name: "Bé Bin", role: "owner", members: 1, since: "02/08/2026" },
      { id: "c3", name: "Bé Sóc", role: "member", members: 3, since: "20/07/2026" },
    ],
    devices: [{ id: "s1", device: "iPhone 14 · iOS 19", lastUsed: "12/10/2026 07:48", status: "active" }],
    consents: [{ id: "k1", document: "Điều khoản sử dụng", version: "v2.0", acceptedAt: "12/06/2026", current: true }, { id: "k2", document: "Chính sách quyền riêng tư", version: "v1.3", acceptedAt: "12/06/2026", current: false }],
    community: { posts: 14, comments: 52, reportsAgainst: 0, hidden: 0 },
    history: [{ id: "h1", action: "Xác minh số điện thoại", by: "Hệ thống", at: "12/06/2026" }],
  },
  u3: {
    relationship: "Mẹ", emailVerified: null, phoneVerified: null, lastLogin: "11/10/2026 21:12",
    children: [
      { id: "c4", name: "Bé Mít", role: "owner", members: 2, since: "10/06/2026" },
      { id: "c5", name: "Bé Bơ", role: "owner", members: 1, since: "10/06/2026" },
      { id: "c6", name: "Bé Cốm", role: "owner", members: 1, since: "01/09/2026" },
      { id: "c7", name: "Bé Đậu", role: "member", members: 2, since: "15/08/2026" },
      { id: "c1", name: "Bé Na", role: "member", members: 2, since: "03/07/2026" },
    ],
    devices: [{ id: "s2", device: "Samsung A54 · Android 16", lastUsed: "11/10/2026 21:12", status: "active" }],
    consents: [{ id: "k3", document: "Điều khoản sử dụng", version: "v2.0", acceptedAt: "10/06/2026", current: true }],
    community: { posts: 31, comments: 118, reportsAgainst: 1, hidden: 0 },
    history: [{ id: "h2", action: "Báo cáo vi phạm bị bỏ qua (r4)", by: "Minh Trí", at: "09/10/2026" }],
  },
  u4: {
    relationship: "Bố", emailVerified: "08/06/2026", phoneVerified: null, lastLogin: "02/10/2026 22:05",
    children: [{ id: "c8", name: "Bé Tôm", role: "owner", members: 1, since: "08/06/2026" }],
    devices: [{ id: "s3", device: "Pixel 9 · Android 16", lastUsed: "02/10/2026 22:05", status: "revoked" }],
    consents: [{ id: "k4", document: "Điều khoản sử dụng", version: "v1.0", acceptedAt: "08/06/2026", current: false }],
    community: { posts: 9, comments: 40, reportsAgainst: 5, hidden: 3 },
    history: [
      { id: "h3", action: "Khóa tài khoản — spam quảng cáo lặp lại", by: "Hà Phương", at: "03/10/2026" },
      { id: "h4", action: "Ẩn bài viết bị báo cáo", by: "Minh Trí", at: "01/10/2026" },
    ],
  },
};

// account.contact_change_requests đang chờ 48 giờ (migration 004)
const contactChanges = [];

function formatNow(offsetHours = 0) {
  return new Date(Date.now() + offsetHours * 3600000).toLocaleString("vi-VN", { dateStyle: "short", timeStyle: "short" });
}

const emptyDetail = { relationship: null, emailVerified: null, phoneVerified: null, lastLogin: "—", children: [], devices: [], consents: [], community: { posts: 0, comments: 0, reportsAgainst: 0, hidden: 0 }, history: [] };

function InfoList({ rows }) {
  return <dl className="info-list">{rows.map(([label, value]) => <React.Fragment key={label}><dt>{label}</dt><dd>{value ?? "—"}</dd></React.Fragment>)}</dl>;
}

function Verified({ value, at }) {
  if (!value) return "—";
  return <span className="stack"><span>{value}</span><small>{at ? `Đã xác minh ${at}` : "Chưa xác minh"}</small></span>;
}

export default function UserDetailPage({ id, onNotify }) {
  const { admin } = useAuth();
  const user = users.find((item) => item.id === id);
  // Sửa thẳng vào dữ liệu mẫu để danh sách người dùng thấy thay đổi
  const detail = user ? (details[user.id] ??= { ...emptyDetail, history: [] }) : emptyDetail;
  const [status, setStatus] = useState(user?.status);
  const [history, setHistory] = useState(detail.history);
  const [contactChange, setContactChange] = useState(() => contactChanges.find((request) => request.userId === id && request.status === "pending"));
  const [modal, setModal] = useState(null);

  if (!user) {
    return <div className="panel empty-state"><h2>Không tìm thấy người dùng</h2><p>Tài khoản <code>{id}</code> không tồn tại hoặc đã bị ẩn danh hóa.</p><button className="button secondary" onClick={() => navigate("/users")}>Về danh sách</button></div>;
  }

  const deletion = deletionRequests.find((request) => request.email === user.email && request.status === "pending");
  const canRecover = can(admin, "user.recover") && status !== "deleted";
  const canViewChild = can(admin, "child.stats") && can(admin, "child.support_view");
  const canLock = can(admin, "user.lock") && status !== "pending_deletion" && status !== "deleted";

  function log(action) {
    detail.history.unshift({ id: `h${Date.now()}`, action, by: admin.fullName, at: formatNow() });
    setHistory([...detail.history]);
  }

  function changeStatus(next) {
    user.status = next;
    setStatus(next);
  }

  function toggleLock() {
    const next = status === "locked" ? "active" : "locked";
    changeStatus(next);
    log(next === "locked" ? "Khóa tài khoản" : "Mở khóa tài khoản");
    onNotify(next === "locked" ? `Đã khóa ${user.name} và đăng xuất mọi thiết bị` : `Đã mở khóa ${user.name}`);
  }

  function requestContactChange({ newPhone, newEmail, verified, note }) {
    const request = { id: `cc${Date.now()}`, userId: user.id, newPhone, newEmail, verified, note, status: "pending", by: admin.fullName, effectiveAt: formatNow(48) };
    contactChanges.push(request);
    setContactChange(request);
    setModal(null);
    log(`Tạo yêu cầu đổi ${[newPhone && "SĐT", newEmail && "email"].filter(Boolean).join(" + ")} — ${note}`);
    onNotify("Đã tạo yêu cầu — gửi cảnh báo tới SĐT / email cũ, có hiệu lực sau 48 giờ");
  }

  function cancelContactChange() {
    contactChange.status = "cancelled";
    setContactChange(null);
    log("Hủy yêu cầu đổi thông tin đăng nhập");
    onNotify("Đã hủy yêu cầu đổi thông tin đăng nhập");
  }

  function cancelDeletion({ note }) {
    deletion.status = "cancelled";
    changeStatus("active");
    setModal(null);
    log(`Hủy yêu cầu xóa tài khoản — ${note}`);
    onNotify(`Đã hủy yêu cầu xóa — tài khoản ${user.name} hoạt động trở lại`);
  }

  const takenContacts = users.filter((other) => other.id !== user.id).flatMap((other) => [other.phone, other.email]).filter(Boolean);

  return <div>
    <button className="text-link detail-back" onClick={() => navigate("/users")}><Icon name="arrow" size={14} /> Danh sách người dùng</button>
    <div className="detail-header">
      <div className={`avatar avatar-${user.color} avatar-lg`}>{user.initials}</div>
      <div className="detail-title"><h1>{user.name}</h1><p>@{user.username} · {user.email}</p></div>
      <UserStatus status={status} />
      {(canLock || canRecover) && <div className="heading-actions">
        {canRecover && !contactChange && <button className="button secondary" onClick={() => setModal("contact")}><Icon name="refresh" size={15} /> Đổi SĐT / email</button>}
        {canLock && (status === "locked"
          ? <button className="button secondary" onClick={toggleLock}>Mở khóa</button>
          : <button className="button secondary danger" onClick={toggleLock}>Khóa tài khoản</button>)}
      </div>}
    </div>
    <MockNotice />

    {deletion && <div className="detail-alert">
      <b>Đang chờ xóa tài khoản</b> — yêu cầu ngày {deletion.requested}, ẩn danh hóa vào {deletion.scheduled}. Lý do: {deletion.reason}.
      {deletion.ownedChildren > 0 && " Còn hồ sơ trẻ đang sở hữu — phải chuyển quyền hoặc xóa trước."}
      {canRecover && <button className="text-link" onClick={() => setModal("deletion")}>Hủy yêu cầu xóa <Icon name="arrow" size={13} /></button>}
    </div>}

    {contactChange && <div className="detail-alert info">
      <b>Đang chờ đổi thông tin đăng nhập</b> — {[contactChange.newPhone && `SĐT → ${contactChange.newPhone}`, contactChange.newEmail && `email → ${contactChange.newEmail}`].filter(Boolean).join(", ")}.
      Có hiệu lực lúc {contactChange.effectiveAt} (tạo bởi {contactChange.by}). Đã gửi cảnh báo tới thông tin cũ; người dùng bấm "Không phải tôi" sẽ tự hủy. Khi áp dụng, mọi thiết bị bị đăng xuất.
      {canRecover && <button className="text-link danger" onClick={cancelContactChange}>Hủy yêu cầu</button>}
    </div>}

    {modal === "contact" && <ContactChangeModal user={user} takenContacts={takenContacts} onClose={() => setModal(null)} onSave={requestContactChange} />}
    {modal === "deletion" && <CancelDeletionModal user={user} request={deletion} onClose={() => setModal(null)} onSave={cancelDeletion} />}

    <div className="content-grid">
      <Panel title="Hồ sơ trẻ liên quan" subtitle={canViewChild ? "child.child_members — bấm tên để tra cứu (bắt nhập lý do, có ghi log)" : "child.child_members — chỉ tên và vai trò, không hiển thị dữ liệu sức khỏe"}>
        <DataTable rowKey="id" rows={detail.children} empty="Chưa sở hữu hoặc được chia sẻ hồ sơ nào" columns={[
          { key: "name", label: "HỒ SƠ", render: (child) => canViewChild ? <button className="cell-link" onClick={() => navigate(`/children/${child.id}`)}><b>{child.name}</b></button> : <b>{child.name}</b> },
          { key: "role", label: "VAI TRÒ", render: (child) => child.role === "owner" ? <Badge tone="green">Chủ sở hữu</Badge> : <Badge tone="blue">Thành viên</Badge> },
          { key: "members", label: "SỐ THÀNH VIÊN" },
          { key: "since", label: "TỪ NGÀY" },
        ]} />
      </Panel>
      <Panel title="Thông tin tài khoản" subtitle="account.users">
        <InfoList rows={[
          ["Email", <Verified value={user.email} at={detail.emailVerified} />],
          ["Số điện thoại", <Verified value={user.phone} at={detail.phoneVerified} />],
          ["Quan hệ với trẻ", detail.relationship],
          ["Ngày tham gia", user.joined],
          ["Đăng nhập gần nhất", detail.lastLogin],
        ]} />
      </Panel>
    </div>

    <div className="content-grid">
      <Panel title="Thiết bị đăng nhập" subtitle="account.user_sessions — khóa tài khoản sẽ thu hồi mọi phiên">
        <DataTable rowKey="id" rows={detail.devices} empty="Chưa có phiên đăng nhập" columns={[
          { key: "device", label: "THIẾT BỊ" },
          { key: "lastUsed", label: "DÙNG GẦN NHẤT" },
          { key: "status", label: "TRẠNG THÁI", render: (session) => session.status === "active" ? <Badge tone="green">Hoạt động</Badge> : <Badge tone="gray">Đã thu hồi</Badge> },
        ]} />
      </Panel>
      <Panel title="Cộng đồng" subtitle="community.posts · content_reports">
        <InfoList rows={[
          ["Bài viết", detail.community.posts],
          ["Bình luận", detail.community.comments],
          ["Bị báo cáo", detail.community.reportsAgainst > 0 ? <Badge tone="orange">{detail.community.reportsAgainst} lần</Badge> : 0],
          ["Nội dung bị ẩn", detail.community.hidden > 0 ? <Badge tone="red">{detail.community.hidden}</Badge> : 0],
        ]} />
      </Panel>
    </div>

    <div className="content-grid">
      <Panel title="Lịch sử quản trị" subtitle="admin.admin_audit_logs với entity_type = user">
        <DataTable rowKey="id" rows={history} empty="Chưa có thao tác nào" columns={[
          { key: "action", label: "THAO TÁC", wrap: true },
          { key: "by", label: "NGƯỜI THỰC HIỆN" },
          { key: "at", label: "THỜI GIAN" },
        ]} />
      </Panel>
      <Panel title="Đồng ý điều khoản" subtitle="account.user_consents">
        <DataTable rowKey="id" rows={detail.consents} empty="Chưa có" columns={[
          { key: "document", label: "VĂN BẢN", render: (consent) => <div className="stack"><span>{consent.document}</span><small>{consent.version} · {consent.acceptedAt}</small></div> },
          { key: "current", label: "", render: (consent) => consent.current ? <Badge tone="green">Hiện hành</Badge> : <Badge tone="orange">Cần đồng ý lại</Badge> },
        ]} />
      </Panel>
    </div>
  </div>;
}
