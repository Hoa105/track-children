import React, { useEffect, useState } from "react";
import { navGroups, allNavItems, accountItem } from "./navigation.js";
import { navigate, useHashRoute } from "../core/useHashRoute.js";
import { AuthProvider, useAuth } from "../core/auth.jsx";
import { can, initialsOf, roleLabel } from "../core/session.js";
import Icon from "../shared/Icon.jsx";
import { FirstLoginPasswordPage, ForgotPasswordPage, LoginPage, SetPasswordPage } from "../features/auth/AuthPages.jsx";
import DashboardPage from "../features/dashboard/DashboardPage.jsx";
import UsersPage from "../features/users/UsersPage.jsx";
import UserDetailPage from "../features/users/UserDetailPage.jsx";
import ChildrenStatsPage from "../features/children/ChildrenStatsPage.jsx";
import ChildDetailPage from "../features/children/ChildDetailPage.jsx";
import KnowledgeBasePage from "../features/ai/KnowledgeBasePage.jsx";
import CandidateCriteriaPage from "../features/ai/CandidateCriteriaPage.jsx";
import ChatbotMonitorPage from "../features/ai/ChatbotMonitorPage.jsx";
import ReportsPage from "../features/community/ReportsPage.jsx";
import AdminsPage from "../features/admins/AdminsPage.jsx";
import AdminDetailPage from "../features/admins/AdminDetailPage.jsx";
import AccountPage from "../features/account/AccountPage.jsx";
import VaccinationPage from "../features/health/VaccinationPage.jsx";
import ModulePage from "../features/modules/ModulePage.jsx";

const pages = {
  "/": DashboardPage,
  "/users": UsersPage,
  "/children": ChildrenStatsPage,
  "/ai/knowledge-base": KnowledgeBasePage,
  "/ai/candidates": CandidateCriteriaPage,
  "/ai/chatbot": ChatbotMonitorPage,
  "/community/reports": ReportsPage,
  "/health": VaccinationPage,
  "/admins": AdminsPage,
  "/account": AccountPage,
};

// Trang chi tiết: #/users/:id … — cần quyền của mục cha, cộng thêm permission riêng nếu có
const detailPages = {
  "/users": { Page: UserDetailPage },
  "/admins": { Page: AdminDetailPage },
  "/children": { Page: ChildDetailPage, permission: "child.support_view" },
};

// Trang không cần đăng nhập
const publicPaths = ["/login", "/forgot-password", "/invite", "/reset-password"];

export default function App() {
  return <AuthProvider><Router /></AuthProvider>;
}

function Router() {
  const { path, params } = useHashRoute();
  const { admin } = useAuth();
  const isPublic = publicPaths.includes(path);

  useEffect(() => {
    if (!admin && !isPublic) navigate("/login");
    if (admin && (path === "/login" || path === "/forgot-password")) navigate("/");
  }, [admin, isPublic, path]);

  if (path === "/invite") return <SetPasswordPage key={params.get("token")} mode="invite" token={params.get("token") ?? ""} />;
  if (path === "/reset-password") return <SetPasswordPage key={params.get("token")} mode="reset" token={params.get("token") ?? ""} />;
  if (!admin) return path === "/forgot-password" ? <ForgotPasswordPage /> : <LoginPage />;
  if (admin.mustChangePassword) return <FirstLoginPasswordPage />;
  return <Shell path={path} />;
}

function Shell({ path }) {
  const { admin, logout } = useAuth();
  const [query, setQuery] = useState("");
  const [toast, setToast] = useState("");
  const [menuOpen, setMenuOpen] = useState(false);

  const exact = [...allNavItems, accountItem].find((navItem) => navItem.path === path);
  const parent = exact ? null : allNavItems.find((navItem) => navItem.path !== "/" && path.startsWith(`${navItem.path}/`));
  const item = exact ?? parent ?? allNavItems[0];
  const detailId = parent && detailPages[parent.path] ? decodeURIComponent(path.slice(parent.path.length + 1)) : null;
  const detail = detailId ? detailPages[item.path] : null;
  const missingPermission = [item.permission, detail?.permission].find((permission) => !can(admin, permission));
  const Page = detail ? detail.Page : pages[item.path] ?? ModulePage;

  function notify(message) {
    setToast(message);
    window.setTimeout(() => setToast(""), 2800);
  }

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-mark"><span>+</span></div>
          <div><strong>track<span>children</span></strong><small>ADMIN CONSOLE</small></div>
        </div>
        <nav>
          {navGroups.map((group) => {
            const items = group.items.filter((navItem) => can(admin, navItem.permission));
            if (items.length === 0) return null;
            return <div className="nav-group" key={group.label}><p>{group.label}</p>{items.map((navItem) => <button className={`nav-item ${item.path === navItem.path ? "active" : ""}`} key={navItem.path} onClick={() => navigate(navItem.path)}><Icon name={navItem.icon} /><span>{navItem.label}</span></button>)}</div>;
          })}
        </nav>
        <div className="sidebar-footer">
          {menuOpen && <div className="account-menu" onMouseLeave={() => setMenuOpen(false)}>
            <button onClick={() => { setMenuOpen(false); navigate("/account"); }}><Icon name="settings" size={15} />Tài khoản của tôi</button>
            <button className="danger" onClick={logout}><Icon name="arrow" size={15} />Đăng xuất</button>
          </div>}
          <div className="admin-mini"><div className="avatar avatar-blue">{initialsOf(admin.fullName)}</div><div><b>{admin.fullName}</b><span>{roleLabel(admin.role)}</span></div><button aria-label="Tùy chọn tài khoản" aria-expanded={menuOpen} onClick={() => setMenuOpen((open) => !open)}><Icon name="more" size={17} /></button></div>
        </div>
      </aside>
      <main className="main-content">
        <header className="topbar"><div className="breadcrumb"><span>Quản trị</span><i>/</i>{detailId ? <><button className="breadcrumb-link" onClick={() => navigate(item.path)}>{item.label}</button><i>/</i><b>Chi tiết</b></> : <b>{item.label}</b>}</div><div className="top-actions">{can(admin, "user.read") && <div className="global-search"><Icon name="search" size={17} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Tìm người dùng..." onKeyDown={(event) => event.key === "Enter" && navigate("/users")} /></div>}<button className="top-avatar avatar-blue" title="Tài khoản của tôi" onClick={() => navigate("/account")}>{initialsOf(admin.fullName)}</button></div></header>
        <div className="page">
          {!missingPermission
            ? <Page key={detailId ?? item.path} item={item} id={detailId} query={query} onNotify={notify} />
            : <div className="panel empty-state"><h2>Không có quyền truy cập</h2><p>Vai trò của bạn chưa được cấp quyền <code>{missingPermission}</code>.</p></div>}
        </div>
      </main>
      {toast && <div className="toast"><span>✓</span>{toast}</div>}
    </div>
  );
}
