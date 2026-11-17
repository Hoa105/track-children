-- An opaque token changes on every write, including delete/recreate cycles.
ALTER TABLE health.child_teeth
    ADD COLUMN version uuid NOT NULL DEFAULT gen_random_uuid();
