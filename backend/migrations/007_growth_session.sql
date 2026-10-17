-- Minimal session login throttle for existing accounts. No registration/demo credentials.
CREATE TABLE account.mobile_login_limits (
    key text PRIMARY KEY,
    attempts integer NOT NULL DEFAULT 0,
    blocked_until timestamptz
);
