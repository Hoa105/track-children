import { test } from 'node:test';
import assert from 'node:assert/strict';

import { ADMIN_ROLES, PERMISSIONS, ROLE_PERMISSIONS, can, roleLabel } from '../src/core/session.js';

test('the current admin authorization class exposes every navigation permission', () => {
  const admin = {
    role: 'admin',
    roles: ['admin'],
    permissions: [...ROLE_PERMISSIONS.admin],
  };

  assert.equal(roleLabel(admin.role), 'Quản trị viên');
  assert.equal(ADMIN_ROLES.some((role) => role.code === 'admin'), true);
  assert.deepEqual(new Set(admin.permissions), new Set(PERMISSIONS.map(({ code }) => code)));
  for (const permission of PERMISSIONS) assert.equal(can(admin, permission.code), true);
});
