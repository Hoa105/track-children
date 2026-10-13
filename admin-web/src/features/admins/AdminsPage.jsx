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

// Không tự khóa / tự đổi vai trò, và không bỏ super admin đang hoạt động cuối cùng
// (DB cũng chặn bằng trigger trg_admin_users_keep_super_admin)
export function isProtectedAdmin(item, me, admins) {
  const activeSuperAdmins = admins.filter((other) => other.role === "super_admin" && other.status === "active").length;
  return item.id === me.id || (item.role === "super_admin" && item.status === "active" && activeSuperAdmins === 1);
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

  function togglePermission(role, code) {
    setDraft((current) => {
      const codes = current.matrix[role];
      return { ...current, matrix: { ...current.matrix, [role]: codes.includes(code) ? codes.filter((item) => item !== code) : [...codes, code] } };
    });
  }

  function save() {
    draft.admins.forEach((item) => {
      const stored = mockAdmins.find((other) => other.id === item.id);
      if (stored) Object.assign(stored, { role: item.role, status: item.status });  // để đăng nhập mock thấy thay đổi
    });
    Object.entries(draft.matrix).forEach(([role, codes]) => { ROLE_PERMISSIONS[role].splice(0, ROLE_PERMISSIONS[role].length, ...codes); });
    setAdmins(draft.admins);
    setDraft(null);
    onNotify("Đã lưu thay đổi — vai trò & quyền áp dụng từ lần đăng nhập kế tiếp");
  }

  function addMember({ fullName, email, role, password }) {
    const member = { id: `a${Date.now()}`, email, fullName, role, status: "active", lastLogin: null, createdAt: new Date().toLocaleDateString("vi-VN"), password, failed: 0, mustChangePassword: true };
    mockAdmins.push(member);
    setAdmins((current) => [...current, { ...member }]);
    setModalOpen(false);
    onNotify(`Đã thêm ${fullName} — gửi email và mật khẩu tạm cho thành viên để đăng nhập lần đầu`);
  }

  return <div>
    <PageHeading eyebrow="HỆ THỐNG" title="Quản trị viên & vai trò" subtitle="Tài khoản web admin và phân quyền theo vai trò.">
      {!editing && <>
        <button className="button secondary" onClick={startEditing}><Icon name="edit" size={16} /> Chỉnh sửa</button>
        <button className="button primary" onClick={() => setModalOpen(true)}><Icon name="user-plus" size={16} /> Thêm thành viên</button>
      </>}
    </PageHeading>
    <MockNotice />
    <Tabs active={tab} onChange={setTab} tabs={[
      { id: "admins", label: "Quản trị viên", count: admins.length },
      { id: "roles", label: "Vai trò & quyền" },
    ]} />
    {editing && <div className="matrix-edit-bar edit-mode-bar"><span>Đang chỉnh sửa vai trò, trạng thái tài khoản và phân quyền. Thay đổi chỉ áp dụng khi bấm Lưu.</span><div><button className="button secondary" onClick={() => setDraft(null)}>Hủy</button><button className="button primary" onClick={save}>Lưu thay đổi</button></div></div>}

    {tab === "admins" && <Panel title="Tài khoản quản trị" subtitle={editing ? "admin.admin_users · đang chỉnh sửa" : "admin.admin_users · bấm một dòng để xem chi tiết"}>
      <DataTable rowKey="id" rows={shownAdmins} paginate onRowClick={editing ? undefined : (item) => navigate(`/admins/${item.id}`)} columns={[
        { key: "name", label: "QUẢN TRỊ VIÊN", render: (item) => <div className="user-cell"><div className="avatar avatar-blue">{initialsOf(item.fullName)}</div><div><b>{item.fullName}{item.id === me.id && " (bạn)"}</b><span>{item.email}</span></div></div> },
        { key: "role", label: "VAI TRÒ", render: (item) => !editing || isProtected(item)
          ? roleLabel(item.role)
          : <select className="inline-select" value={item.role} onClick={stopRowClick} onChange={(event) => editAdmin(item.id, { role: event.target.value })}>{ADMIN_ROLES.map((role) => <option key={role.code} value={role.code}>{role.label}</option>)}</select> },
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

    {tab === "roles" && <Panel title="Ma trận vai trò × quyền" subtitle={editing ? "admin.role_permissions · đang chỉnh sửa — Super Admin luôn có toàn bộ quyền" : "admin.role_permissions — menu tự ẩn mục admin không có quyền"}>
      <div className="table-wrap"><table className="matrix"><thead><tr><th>QUYỀN</th>{ADMIN_ROLES.map((role) => <th key={role.code}>{role.label.toUpperCase()}</th>)}</tr></thead>
        <tbody>{PERMISSIONS.map((permission) => <tr key={permission.code}><td><div className="stack"><span>{permission.label}</span><small><code>{permission.code}</code></small></div></td>{ADMIN_ROLES.map((role) => {
          const has = matrix[role.code].includes(permission.code);
          return <td key={role.code} className="matrix-cell">{editing
            ? <input type="checkbox" aria-label={`${role.label} — ${permission.label}`} checked={has} disabled={role.code === "super_admin"} onChange={() => togglePermission(role.code, permission.code)} />
            : has ? <span className="matrix-yes"><Icon name="check" size={14} /></span> : <span className="matrix-no">—</span>}</td>;
        })}</tr>)}</tbody>
      </table></div>
    </Panel>}

    {modalOpen && <AddAdminModal existingEmails={admins.map((item) => item.email)} onClose={() => setModalOpen(false)} onSave={addMember} />}
  </div>;
}
