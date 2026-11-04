import React, { useState } from "react";
import { useAuth } from "../../core/auth.jsx";
import { mockAdmins } from "../../core/authApi.js";
import { ADMIN_ROLES, PERMISSIONS, ROLE_PERMISSIONS, initialsOf, roleLabel } from "../../core/session.js";
import { navigate } from "../../core/useHashRoute.js";
import Icon from "../../shared/Icon.jsx";
import { Badge, DataTable, MockNotice, PageHeading, Panel, Tabs, stopRowClick } from "../../shared/ui.jsx";
import AddAdminModal from "./AddAdminModal.jsx";

// Tài khoản mới (mustChangePassword) hiện "Chưa đổi mật khẩu" tới khi thành viên đăng nhập lần đầu
export function AdminStatus({ admin }) {
  if (admin.status === "locked") return <Badge tone="red">Đã khóa</Badge>;
  if (admin.mustChangePassword) return <Badge tone="orange">Chưa đổi mật khẩu</Badge>;
  return <Badge tone="green">Đang hoạt động</Badge>;
}

// Không cho quản trị viên tự khóa tài khoản đang đăng nhập.
export function isProtectedAdmin(item, me, admins) {
  return item.id === me.id;
}

const copyMatrix = () => Object.fromEntries(Object.entries(ROLE_PERMISSIONS).map(([role, codes]) => [role, [...codes]]));

export default function AdminsPage({ onNotify }) {
  const { admin: me } = useAuth();
  const [tab, setTab] = useState("admins");
  const [admins, setAdmins] = useState(() => mockAdmins.map((item) => ({ ...item })));
  const [modalOpen, setModalOpen] = useState(false);
  // null = đang khóa; bấm nút Chỉnh sửa mới mở bản nháp cho cả 2 tab, Lưu mới áp dụng
  const [draft, setDraft] = useState(null);

  const editing = draft !== null;
  const shownAdmins = editing ? draft.admins : admins;
  const matrix = editing ? draft.matrix : ROLE_PERMISSIONS;
  const isProtected = (item) => isProtectedAdmin(item, me, shownAdmins);

  function startEditing() {
    setDraft({ admins: admins.map((item) => ({ ...item })), matrix: copyMatrix() });
  }

  function editAdmin(id, changes) {
    setDraft((current) => ({ ...current, admins: current.admins.map((item) => item.id === id ? { ...item, ...changes } : item) }));
  }

  function save() {
    draft.admins.forEach((item) => {
      const stored = mockAdmins.find((other) => other.id === item.id);
      if (stored) Object.assign(stored, { status: item.status });
    });
    Object.entries(draft.matrix).forEach(([role, codes]) => { ROLE_PERMISSIONS[role].splice(0, ROLE_PERMISSIONS[role].length, ...codes); });
    setAdmins(draft.admins);
    setDraft(null);
    onNotify("Đã lưu thay đổi trạng thái tài khoản");
  }

  function addMember({ fullName, email, role, password }) {
    const member = { id: `a${Date.now()}`, email, fullName, role, status: "active", lastLogin: null, createdAt: new Date().toLocaleDateString("vi-VN"), password, failed: 0, mustChangePassword: true };
    mockAdmins.push(member);
    setAdmins((current) => [...current, { ...member }]);
    setModalOpen(false);
    onNotify(`Đã thêm ${fullName} — gửi email và mật khẩu tạm cho thành viên để đăng nhập lần đầu`);
  }

  return <div>
    <PageHeading eyebrow="HỆ THỐNG" title="Quản trị viên" subtitle="Mọi tài khoản quản trị dùng chung vai trò admin và bộ quyền từ backend.">
      {!editing && <>
        <button className="button secondary" onClick={startEditing}><Icon name="edit" size={16} /> Chỉnh sửa</button>
        <button className="button primary" onClick={() => setModalOpen(true)}><Icon name="user-plus" size={16} /> Thêm thành viên</button>
      </>}
    </PageHeading>
    <MockNotice />
    <Tabs active={tab} onChange={setTab} tabs={[
      { id: "admins", label: "Quản trị viên", count: admins.length },
      { id: "roles", label: "Quyền quản trị" },
    ]} />
    {editing && <div className="matrix-edit-bar edit-mode-bar"><span>Đang chỉnh sửa trạng thái tài khoản. Vai trò và quyền được backend áp dụng thống nhất cho mọi admin.</span><div><button className="button secondary" onClick={() => setDraft(null)}>Hủy</button><button className="button primary" onClick={save}>Lưu thay đổi</button></div></div>}

    {tab === "admins" && <Panel title="Tài khoản quản trị" subtitle={editing ? "admin.admin_users · đang chỉnh sửa" : "admin.admin_users · bấm một dòng để xem chi tiết"}>
      <DataTable rowKey="id" rows={shownAdmins} paginate onRowClick={editing ? undefined : (item) => navigate(`/admins/${item.id}`)} columns={[
        { key: "name", label: "QUẢN TRỊ VIÊN", render: (item) => <div className="user-cell"><div className="avatar avatar-blue">{initialsOf(item.fullName)}</div><div><b>{item.fullName}{item.id === me.id && " (bạn)"}</b><span>{item.email}</span></div></div> },
        { key: "role", label: "VAI TRÒ", render: (item) => roleLabel(item.role) },
        { key: "status", label: "TRẠNG THÁI", render: (item) => <AdminStatus admin={item} /> },
        { key: "lastLogin", label: "ĐĂNG NHẬP GẦN NHẤT", render: (item) => item.lastLogin ?? "—" },
        { key: "createdAt", label: "NGÀY TẠO" },
        { key: "actions", label: "", render: (item) => !editing || isProtected(item) ? null : <div className="row-actions" onClick={stopRowClick}>
          {item.status === "active"
            ? <button className="link-button danger" onClick={() => editAdmin(item.id, { status: "locked" })}>Khóa</button>
            : <button className="link-button" onClick={() => editAdmin(item.id, { status: "active" })}>Mở khóa</button>}
        </div> },
      ]} />
    </Panel>}

    {tab === "roles" && <Panel title="Quyền của quản trị viên" subtitle="Backend áp dụng cùng một bộ quyền cho mọi tài khoản admin đang hoạt động.">
      <div className="table-wrap"><table className="matrix"><thead><tr><th>QUYỀN</th>{ADMIN_ROLES.map((role) => <th key={role.code}>{role.label.toUpperCase()}</th>)}</tr></thead>
        <tbody>{PERMISSIONS.map((permission) => <tr key={permission.code}><td><div className="stack"><span>{permission.label}</span><small><code>{permission.code}</code></small></div></td>{ADMIN_ROLES.map((role) => {
          const has = matrix[role.code].includes(permission.code);
          return <td key={role.code} className="matrix-cell">{has ? <span className="matrix-yes"><Icon name="check" size={14} /></span> : <span className="matrix-no">—</span>}</td>;
        })}</tr>)}</tbody>
      </table></div>
    </Panel>}

    {modalOpen && <AddAdminModal existingEmails={admins.map((item) => item.email)} onClose={() => setModalOpen(false)} onSave={addMember} />}
  </div>;
}
