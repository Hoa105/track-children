import { test, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';

let api;
let calls;
let responses;
let events;
const ok = data => new Response(JSON.stringify(data), { status: 200 });
const fail = (status, code) => new Response(JSON.stringify({ error: { code } }), { status });
const session = token => ({ accessToken: token, admin: { id: 'admin-1', permissions: ['health.write'] } });
beforeEach(async () => {
  api = await import(`../src/core/adminAuth.js?test=${Math.random()}`);
  calls = []; responses = []; events = [];
  globalThis.window = { dispatchEvent: event => events.push(event.type) };
  globalThis.fetch = async (url, options) => {
    calls.push({ url, options });
    const response = responses.shift();
    if (response instanceof Error) throw response;
    if (!response) throw new Error('Unexpected fetch');
    return response;
  };
});
afterEach(() => { delete globalThis.window; delete globalThis.fetch; });

test('login sends backend JSON, CSRF header and same-origin cookie mode', async () => {
  responses.push(ok(session('real-jwt')));
  await api.login('admin@example.com', 'password123');
  assert.equal(calls[0].url, '/api/backend/admin/auth/login');
  assert.equal(calls[0].options.credentials, 'same-origin');
  assert.equal(calls[0].options.headers['X-Requested-With'], 'TrackChildrenAdmin');
  assert.deepEqual(JSON.parse(calls[0].options.body), { email: 'admin@example.com', password: 'password123' });
  responses.push(ok([]));
  await api.authorizedFetch('/protected');
  assert.equal(calls[1].options.headers.Authorization, 'Bearer real-jwt');
});
test('login handles generic credentials error', async () => {
  responses.push(fail(401, 'INVALID_CREDENTIALS'));
  await assert.rejects(api.login('missing@example.com', 'wrong'), api.AuthError);
});
test('network error becomes readable auth error', async () => {
  responses.push(new Error('offline'));
  await assert.rejects(api.login('admin@example.com', 'pass'), api.AuthError);
});
test('refresh requests are shared during concurrent calls', async () => {
  responses.push(ok(session('refreshed')));
  const results = await Promise.all([api.refreshSession(), api.refreshSession()]);
  assert.equal(calls.length, 1);
  assert.equal(results[0].accessToken, results[1].accessToken);
});
test('expired access token refreshes and retries protected request once', async () => {
  responses.push(fail(401, 'ACCESS_TOKEN_EXPIRED'), ok(session('new-jwt')), ok({ result: true }));
  assert.equal((await api.authorizedFetch('/protected')).status, 200);
  assert.equal(calls.length, 3);
  assert.equal(calls[2].options.headers.Authorization, 'Bearer new-jwt');
});
test('invalid refresh clears client session', async () => {
  responses.push(fail(401, 'ACCESS_TOKEN_EXPIRED'), fail(401, 'SESSION_EXPIRED'));
  await assert.rejects(api.authorizedFetch('/protected'), api.AuthError);
  assert.deepEqual(events, ['admin-session-expired']);
});
test('retry still unauthorized clears session without refresh loop', async () => {
  responses.push(fail(401, 'ACCESS_TOKEN_EXPIRED'), ok(session('new-jwt')), fail(401, 'SESSION_REVOKED'));
  assert.equal((await api.authorizedFetch('/protected')).status, 401);
  assert.equal(calls.length, 3);
  assert.deepEqual(events, ['admin-session-expired']);
});
test('permission denied does not refresh', async () => {
  responses.push(fail(403, 'FORBIDDEN'));
  assert.equal((await api.authorizedFetch('/protected')).status, 403);
  assert.equal(calls.length, 1);
});
test('logout calls backend and forgets access token', async () => {
  responses.push(ok(session('jwt')), new Response(null, { status: 204 }), ok([]));
  await api.login('admin@example.com', 'pass');
  await api.logout();
  assert.equal(calls[1].url, '/api/backend/admin/auth/logout');
  await api.authorizedFetch('/protected');
  assert.equal(calls[2].options.headers.Authorization, 'Bearer null');
});
test('password change forces login after success', async () => {
  responses.push(new Response(null, { status: 204 }));
  await api.changePassword('admin-1', 'current123', 'NextPassword123');
  assert.deepEqual(JSON.parse(calls[0].options.body), { currentPassword: 'current123', newPassword: 'NextPassword123' });
  assert.deepEqual(events, ['admin-password-changed']);
});
test('password change renews expired JWT then retries', async () => {
  responses.push(fail(401, 'ACCESS_TOKEN_EXPIRED'), ok(session('new-jwt')), new Response(null, { status: 204 }));
  await api.changePassword('admin-1', 'current123', 'NextPassword123');
  assert.equal(calls.length, 3);
  assert.deepEqual(events, ['admin-password-changed']);
});
test('password validation covers minimum, maximum, letters, digits and confirmation', () => {
  for (const value of ['short', 'a'.repeat(12), '1'.repeat(12), 'A1'.repeat(65)]) assert.ok(api.passwordProblem(value));
  assert.ok(api.passwordProblem('Password123', 'different'));
  assert.equal(api.passwordProblem('Password123', 'Password123'), null);
});

test('profile update sends PATCH and returns saved server profile', async () => {
  const saved = { id: 'admin-1', fullName: 'Saved Name', permissions: ['health.write'] };
  responses.push(ok(saved));
  assert.deepEqual(await api.updateProfile({ fullName: '  Saved Name ' }), saved);
  assert.equal(calls[0].url, '/api/backend/admin/auth/me');
  assert.equal(calls[0].options.method, 'PATCH');
  assert.equal(calls[0].options.headers['X-Requested-With'], 'TrackChildrenAdmin');
  assert.deepEqual(JSON.parse(calls[0].options.body), { fullName: '  Saved Name ' });
});
test('profile validation error preserves fields and leaves session active', async () => {
  responses.push(new Response(JSON.stringify({ error: { code: 'VALIDATION_ERROR', fields: { fullName: 'Invalid name' } } }), { status: 422 }));
  await assert.rejects(api.updateProfile({ fullName: 'a' }), error => {
    assert.equal(error.status, 422);
    assert.equal(error.code, 'VALIDATION_ERROR');
    assert.equal(error.fields.fullName, 'Invalid name');
    return true;
  });
  assert.deepEqual(events, []);
});
test('profile update refreshes expired JWT then retries with new token', async () => {
  responses.push(fail(401, 'ACCESS_TOKEN_EXPIRED'), ok(session('refreshed')), ok({ fullName: 'Saved Name' }));
  assert.deepEqual(await api.updateProfile({ fullName: 'Saved Name' }), { fullName: 'Saved Name' });
  assert.equal(calls.length, 3);
  assert.equal(calls[2].options.method, 'PATCH');
  assert.equal(calls[2].options.headers.Authorization, 'Bearer refreshed');
});
test('failed profile refresh redirects to login', async () => {
  responses.push(fail(401, 'ACCESS_TOKEN_EXPIRED'), fail(401, 'SESSION_REVOKED'));
  await assert.rejects(api.updateProfile({ fullName: 'Saved Name' }), api.AuthError);
  assert.deepEqual(events, ['admin-session-expired']);
});
test('expired profile retry cannot loop', async () => {
  responses.push(fail(401, 'ACCESS_TOKEN_EXPIRED'), ok(session('refreshed')), fail(401, 'ACCESS_TOKEN_EXPIRED'));
  await assert.rejects(api.updateProfile({ fullName: 'Saved Name' }), api.AuthError);
  assert.equal(calls.length, 3);
  assert.deepEqual(events, ['admin-session-expired']);
});
test('profile network failure is reported without success or logout', async () => {
  responses.push(new Error('network unavailable'));
  await assert.rejects(api.updateProfile({ fullName: 'Saved Name' }), api.AuthError);
  assert.deepEqual(events, []);
});
test('wrong current password produces a specific message without logging out', async () => {
  responses.push(fail(401, 'INVALID_CREDENTIALS'));
  await assert.rejects(api.changePassword('admin-1', 'wrong', 'NextPassword123'), error => {
    assert.equal(error.code, 'INVALID_CREDENTIALS');
    assert.match(error.message, /hiện tại/);
    return true;
  });
  assert.deepEqual(events, []);
  assert.equal(calls.length, 1);
});
test('password quota failure does not signal success or logout', async () => {
  responses.push(fail(429, 'RATE_LIMITED'));
  await assert.rejects(api.changePassword('admin-1', 'wrong', 'NextPassword123'), api.AuthError);
  assert.deepEqual(events, []);
});
test('revoked session is cleared on profile or password mutation', async () => {
  for (const mutate of [() => api.updateProfile({ fullName: 'Saved Name' }), () => api.changePassword('admin-1', 'old123', 'NewPassword123')]) {
    responses.push(fail(401, 'SESSION_REVOKED'));
    await assert.rejects(mutate(), api.AuthError);
  }
  assert.deepEqual(events, ['admin-session-expired', 'admin-session-expired']);
});
test('disabled account is cleared on profile mutation', async () => {
  responses.push(fail(403, 'ACCOUNT_UNAVAILABLE'));
  await assert.rejects(api.updateProfile({ fullName: 'Saved Name' }), api.AuthError);
  assert.deepEqual(events, ['admin-session-expired']);
});
test('profile validation handles whitespace, Unicode, boundaries and controls', () => {
  for (const name of ['', ' ', ' a ', 'x'.repeat(151), 'A\nB', 'A\tB', 'A\x00B', 'A\u200bB']) assert.ok(api.profileProblem(name), JSON.stringify(name));
  for (const name of ['  Nguyễn   Ánh ', 'Ab', 'x'.repeat(150), 'A\u00a0B']) assert.equal(api.profileProblem(name), null);
});
