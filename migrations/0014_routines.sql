-- Routine activities ("bath every 2 days") and how often they are done, kept on the child (a
-- JSON list, see src/schedule.rs).
ALTER TABLE children ADD COLUMN routines TEXT NOT NULL DEFAULT '[]';
