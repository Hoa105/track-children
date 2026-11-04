-- Give teething its own caregiver permission scope again. Existing deployments
-- merged it into vaccination in migration 002, so copy the current level as a
-- safe backwards-compatible default before the two scopes diverge.
ALTER TABLE child.child_member_permissions
    DROP CONSTRAINT IF EXISTS child_member_permissions_data_scope_check;

ALTER TABLE child.child_member_permissions
    ADD CONSTRAINT child_member_permissions_data_scope_check
    CHECK (data_scope IN (
        'growth', 'assessment', 'vaccination', 'teething', 'diary', 'activities'
    ));

INSERT INTO child.child_member_permissions (member_id, data_scope, access_level)
SELECT member_id, 'teething', access_level
FROM child.child_member_permissions
WHERE data_scope = 'vaccination'
ON CONFLICT (member_id, data_scope) DO NOTHING;

ALTER TABLE child.child_invitations
    DROP CONSTRAINT IF EXISTS child_invitations_permission_keys_check;

ALTER TABLE child.child_invitations
    ADD CONSTRAINT child_invitations_permission_keys_check
    CHECK ((proposed_permissions - ARRAY[
        'growth', 'assessment', 'vaccination', 'teething', 'diary', 'activities'
    ]) = '{}'::jsonb);

