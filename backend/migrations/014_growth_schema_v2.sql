-- Growth v2. Run atomically with psql -1 (scripts/migrate.ps1).
-- Only growth tables are changed; account/child are referenced, never altered.
-- Keep a row-level snapshot before removing legacy fields/cache/WHO data.
LOCK TABLE growth.growth_measurements, growth.growth_evaluations,
    growth.who_growth_standards IN ACCESS EXCLUSIVE MODE;

DO $$
DECLARE invalid_positions bigint;
BEGIN
    SELECT count(*) INTO invalid_positions FROM growth.growth_measurements
    WHERE (metric = 'height' AND (measure_position IS NULL
                                 OR measure_position NOT IN ('lying', 'standing')))
       OR (metric <> 'height' AND measure_position IS NOT NULL);
    RAISE NOTICE 'Growth inventory: measurements=%, evaluations=%, WHO rows=%',
        (SELECT count(*) FROM growth.growth_measurements),
        (SELECT count(*) FROM growth.growth_evaluations),
        (SELECT count(*) FROM growth.who_growth_standards);
    IF invalid_positions > 0 THEN
        RAISE EXCEPTION '% measurements have invalid/missing position; resolve from source records before migrating', invalid_positions;
    END IF;
    IF EXISTS (SELECT 1 FROM growth.growth_measurements
               WHERE deleted_at IS NULL GROUP BY child_id, metric, measured_at
               HAVING count(*) > 1) THEN
        RAISE EXCEPTION 'Duplicate active daily measurements; resolve before migrating';
    END IF;
END $$;

CREATE SCHEMA IF NOT EXISTS growth_archive;
CREATE TABLE growth_archive.measurements_before_014 AS TABLE growth.growth_measurements;
CREATE TABLE growth_archive.evaluations_before_014 AS TABLE growth.growth_evaluations;
CREATE TABLE growth_archive.who_standards_before_014 AS TABLE growth.who_growth_standards;

-- Cache is reproducible, but old results cannot be assumed valid anthro outputs.
-- Archive all rows; the WHO/anthro service must recalculate after deployment.
DROP TABLE growth.growth_evaluations;
DROP TABLE growth.who_growth_standards;

ALTER TABLE growth.growth_measurements
    ADD COLUMN measured_on date;
-- Legacy measured_at is DATE. Preserve its calendar day; midnight is a
-- conversion convention, not a recovered original measurement time.
UPDATE growth.growth_measurements SET measured_on = measured_at;
ALTER TABLE growth.growth_measurements
    ALTER COLUMN measured_on SET NOT NULL,
    ALTER COLUMN measured_at TYPE timestamptz
        USING (measured_at::timestamp AT TIME ZONE 'Asia/Ho_Chi_Minh'),
    ALTER COLUMN value TYPE numeric(7,2),
    DROP COLUMN age_in_days,
    DROP COLUMN updated_by,
    DROP COLUMN deleted_by;

-- Replace the old DATE-based unique index with business-calendar uniqueness.
DROP INDEX growth.uq_growth_measurement_day;
CREATE UNIQUE INDEX growth_measurements_one_per_day_uq
    ON growth.growth_measurements(child_id, metric, measured_on)
    WHERE deleted_at IS NULL;

-- SQL CHECK accepts NULL, so the explicit IS NOT NULL is essential here.
ALTER TABLE growth.growth_measurements
    ADD CONSTRAINT growth_measurements_position_ck CHECK (
        (metric = 'height' AND measure_position IS NOT NULL
            AND measure_position IN ('lying', 'standing'))
        OR (metric <> 'height' AND measure_position IS NULL)
    ),
    ADD CONSTRAINT growth_measurements_business_day_ck CHECK (
        measured_on = (measured_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
    ),
    DROP CONSTRAINT growth_measurements_created_by_fkey,
    ADD CONSTRAINT growth_measurements_created_by_fkey FOREIGN KEY (created_by)
        REFERENCES account.users(id) ON DELETE SET NULL;

-- Existing history index and UNIQUE(id, child_id) remain in place.
-- Migration 002 already attached common.set_updated_at() to measurements.
CREATE TABLE growth.growth_evaluations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id uuid NOT NULL REFERENCES child.children(id) ON DELETE CASCADE,
    measurement_id uuid NOT NULL,
    paired_measurement_id uuid,
    indicator varchar(10) NOT NULL
        CHECK (indicator IN ('wfa','lhfa','hcfa','bmifa','wfl','wfh')),
    z_score numeric(6,3) NOT NULL,
    classification varchar(40) NOT NULL,
    standard_version varchar(30) NOT NULL DEFAULT 'WHO-2006',
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT growth_evaluations_primary_fk FOREIGN KEY (measurement_id, child_id)
        REFERENCES growth.growth_measurements(id, child_id) ON DELETE CASCADE,
    CONSTRAINT growth_evaluations_paired_fk FOREIGN KEY (paired_measurement_id, child_id)
        REFERENCES growth.growth_measurements(id, child_id) ON DELETE CASCADE,
    CONSTRAINT growth_evaluations_pair_ck CHECK (
        (indicator IN ('bmifa','wfl','wfh') AND paired_measurement_id IS NOT NULL
            AND paired_measurement_id <> measurement_id)
        OR (indicator NOT IN ('bmifa','wfl','wfh') AND paired_measurement_id IS NULL)
    ),
    CONSTRAINT growth_evaluations_measurement_indicator_uq UNIQUE(measurement_id, indicator)
);
CREATE INDEX growth_evaluations_child_indicator_idx
    ON growth.growth_evaluations(child_id, indicator);
