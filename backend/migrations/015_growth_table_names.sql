-- Keep existing measurements, constraints, indexes and foreign keys intact.
-- Apply atomically through scripts/migrate.ps1.
ALTER TABLE growth.growth_measurements RENAME TO measurements;
ALTER TABLE growth.growth_evaluations RENAME TO evaluations;

-- Legacy snapshots from 014 are explicitly retired. No CASCADE: unexpected
-- dependencies must stop the migration rather than remove unrelated objects.
DROP TABLE growth_archive.evaluations_before_014;
DROP TABLE growth_archive.measurements_before_014;
DROP TABLE growth_archive.who_standards_before_014;
DROP SCHEMA growth_archive;
