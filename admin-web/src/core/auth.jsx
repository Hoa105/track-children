import React, { createContext, useContext, useEffect, useState } from "react";
import * as authApi from "./adminAuth.js";
const AuthContext = createContext(null);
export function AuthProvider({ children }) {
  const [admin, setAdmin] = useState(null);
  const [loading, setLoading] = useState(true);
  const [sessionNotice, setSessionNotice] = useState("");
  useEffect(() => {
    let active = true;
    // Remove sessions created by the former demo implementation.
    try { window.sessionStorage.removeItem("tc-admin-session"); } catch {}
    const expired = () => setAdmin(null);
    const passwordChanged = () => {
      setAdmin(null);
      setSessionNotice("Đã đổi mật khẩu thành công. Vui lòng đăng nhập lại bằng mật khẩu mới.");
    };
    window.addEventListener("admin-session-expired", expired);
    window.addEventListener("admin-password-changed", passwordChanged);
    authApi.refreshSession().then(result => { if (active) setAdmin(result.admin); })
      .catch(() => {}).finally(() => { if (active) setLoading(false); });
    return () => {
      active = false;
      window.removeEventListener("admin-session-expired", expired);
      window.removeEventListener("admin-password-changed", passwordChanged);
    };
  }, []);
  return <AuthContext.Provider value={{ admin, loading, sessionNotice,
    async login(email, password) {
      const result = await authApi.login(email, password);
      setAdmin(result.admin);
      setSessionNotice("");
    },
    async logout() { await authApi.logout(); setAdmin(null); },
    async completeFirstLogin(current, next) { await authApi.changePassword(admin.id, current, next); setAdmin(null); },
    async updateProfile(changes) {
      const saved = await authApi.updateProfile(changes);
      setAdmin(previous => previous ? saved : null);
      return saved;
    },
  }}>{children}</AuthContext.Provider>;
}
export function useAuth() { return useContext(AuthContext); }
