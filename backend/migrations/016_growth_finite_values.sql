-- Keep the two growth tables; numeric(p,s) still permits PostgreSQL NaN.
-- API/engine checks also reject non-finite values, including external writers.
ALTER TABLE growth.measurements
    ADD CONSTRAINT growth_measurements_finite_ck
    CHECK (value <> 'NaN'::numeric);
ALTER TABLE growth.evaluations
    ADD CONSTRAINT growth_evaluations_finite_ck
    CHECK (z_score <> 'NaN'::numeric);
