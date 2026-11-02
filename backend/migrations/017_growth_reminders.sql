CREATE TABLE growth.reminder_settings (
    child_id uuid NOT NULL REFERENCES child.children(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES account.users(id) ON DELETE CASCADE,
    metric text NOT NULL CHECK(metric IN ('weight','height','head_circumference')),
    enabled boolean NOT NULL DEFAULT true,
    snoozed_until date,
    appointment_on date,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY(child_id,user_id,metric)
);
CREATE TABLE growth.reminder_notices (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id uuid NOT NULL REFERENCES child.children(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES account.users(id) ON DELETE CASCADE,
    metric text NOT NULL,
    due_on date NOT NULL,
    stage smallint NOT NULL CHECK(stage IN (0,1)),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(child_id,user_id,metric,due_on,stage)
);
