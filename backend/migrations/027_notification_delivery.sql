ALTER TABLE notification.notifications
    ADD COLUMN child_id uuid REFERENCES child.children(id) ON DELETE CASCADE,
    ADD COLUMN scope text,
    ADD COLUMN event_key text UNIQUE,
    ADD COLUMN resolved_at timestamptz;
CREATE TABLE notification.preferences (
    user_id uuid PRIMARY KEY REFERENCES account.users(id) ON DELETE CASCADE,
    push_enabled boolean NOT NULL DEFAULT true,
    timezone_offset integer NOT NULL DEFAULT 420 CHECK(timezone_offset BETWEEN -720 AND 840),
    send_hour integer NOT NULL DEFAULT 8 CHECK(send_hour BETWEEN 0 AND 23),
    send_minute integer NOT NULL DEFAULT 0 CHECK(send_minute BETWEEN 0 AND 59),
    growth_interval_days integer NOT NULL DEFAULT 30 CHECK(growth_interval_days BETWEEN 7 AND 365)
);
CREATE TABLE notification.push_outbox (
    notification_id uuid NOT NULL REFERENCES notification.notifications(id) ON DELETE CASCADE,
    device_token_id uuid NOT NULL REFERENCES account.device_tokens(id) ON DELETE CASCADE,
    attempts integer NOT NULL DEFAULT 0,
    status text NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','sent','cancelled','failed')),
    next_attempt_at timestamptz NOT NULL DEFAULT now(),
    last_error text,
    PRIMARY KEY(notification_id,device_token_id)
);
INSERT INTO notification.notification_types(code,name,default_channel)
VALUES ('assessment_reminder','Nhắc đánh giá','push'),('growth_reminder','Nhắc cập nhật tăng trưởng','push')
ON CONFLICT(code) DO NOTHING;
