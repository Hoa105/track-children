import { BACKEND } from './api.js';

let accessToken = null;
let refreshPromise = null;
export class AuthError extends Error {
  constructor(message, status = 0, code = null, fields = {}) {
    super(message);
    this.status = status;
    this.code = code;
    this.fields = fields;
  }
}
const messages = {
  INVALID_CREDENTIALS: 'Email hoặc mật khẩu không đúng.',
  ACCOUNT_UNAVAILABLE: 'Tài khoản đã bị khóa. Liên hệ Super Admin.',
  RATE_LIMITED: 'Thử đăng nhập quá nhiều lần. Vui lòng thử lại sau.',
  AUTH_NOT_CONFIGURED: 'Máy chủ chưa cấu hình xác thực.',
  DATABASE_UNAVAILABLE: 'Không kết nối được cơ sở dữ liệu.',
  RATE_LIMIT_UNAVAILABLE: 'Bộ giới hạn đăng nhập tạm thời không hoạt động. Vui lòng thử lại sau.',
  VALIDATION_ERROR: 'Dữ liệu không hợp lệ. Vui lòng kiểm tra lại.',
};

async function request(path, body, method = 'POST', retry = true) {
  let response;
  try {
    response = await fetch(`${BACKEND}/admin/auth${path}`, {
      method, credentials: 'same-origin',
      headers: { 'X-Requested-With': 'TrackChildrenAdmin',
        ...(body !== undefined && { 'Content-Type': 'application/json' }),
        ...(accessToken && { Authorization: `Bearer ${accessToken}` }) },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch { throw new AuthError('Không kết nối được backend.'); }
  const data = await response.json().catch(() => null);
  if (!response.ok) {
    const code = data?.error?.code ?? data?.code;
    if ((path === '/change-password' || path === '/me') && code === 'ACCESS_TOKEN_EXPIRED' && retry) {
      try { await refreshSession(); }
      catch (error) { window.dispatchEvent(new Event('admin-session-expired')); throw error; }
      return request(path, body, method, false);
    }
    if (['ACCESS_TOKEN_INVALID', 'ACCESS_TOKEN_EXPIRED', 'SESSION_REVOKED', 'SESSION_EXPIRED', 'ACCOUNT_UNAVAILABLE'].includes(code)
        && (path === '/me' || path === '/change-password')) {
      accessToken = null;
      window.dispatchEvent(new Event('admin-session-expired'));
    }
    const message = path === '/change-password' && code === 'INVALID_CREDENTIALS'
      ? 'Mật khẩu hiện tại không đúng.'
      : messages[code] ?? (response.status === 401 ? 'Phiên đăng nhập đã hết hạn.' : `Không thực hiện được yêu cầu (HTTP ${response.status}).`);
    throw new AuthError(message, response.status, code, data?.error?.fields ?? {});
  }
  return data;
}

export async function login(email, password) {
  const result = await request('/login', { email, password });
  accessToken = result.accessToken;
  return result;
}
export function refreshSession() {
  if (!refreshPromise) refreshPromise = request('/refresh').then(result => {
    accessToken = result.accessToken;
    return result;
  }).catch(error => { accessToken = null; throw error; }).finally(() => { refreshPromise = null; });
  return refreshPromise;
}
export async function logout() {
  await request('/logout');
  accessToken = null;
}
export async function authorizedFetch(url, options = {}) {
  const send = () => fetch(url, { ...options, headers: { ...options.headers, Authorization: `Bearer ${accessToken}` } });
  let response = await send();
  if (response.status === 401) {
    try { await refreshSession(); }
    catch (error) { window.dispatchEvent(new Event('admin-session-expired')); throw error; }
    response = await send();
    if (response.status === 401) {
      accessToken = null;
      window.dispatchEvent(new Event('admin-session-expired'));
    }
  }
  return response;
}
export async function changePassword(adminId, currentPassword, newPassword) {
  await request('/change-password', { currentPassword, newPassword });
  accessToken = null;
  window.dispatchEvent(new Event('admin-password-changed'));
}
export function updateProfile(changes) { return request('/me', changes, 'PATCH'); }
export function profileProblem(fullName) {
  const length = Array.from(fullName.trim().replace(/\s+/gu, ' ')).length;
  if (length < 2 || length > 150) return 'Họ tên cần từ 2 đến 150 ký tự.';
  if (/\p{C}/u.test(fullName)) return 'Họ tên không được chứa ký tự điều khiển.';
  return null;
}
export const completeFirstLogin = changePassword;
export function passwordProblem(password, confirm) {
  if (password.length < 10) return 'Mật khẩu cần tối thiểu 10 ký tự.';
  if (password.length > 128) return 'Mật khẩu tối đa 128 ký tự.';
  if (!/[A-Za-z]/.test(password) || !/\d/.test(password)) return 'Mật khẩu cần có cả chữ và số.';
  if (confirm !== undefined && password !== confirm) return 'Mật khẩu xác nhận không khớp.';
  return null;
}
