-- When "daytime" starts and ends for the family's stats (minutes after local midnight).
ALTER TABLE families ADD COLUMN day_start INTEGER NOT NULL DEFAULT 360;
ALTER TABLE families ADD COLUMN day_end INTEGER NOT NULL DEFAULT 1080;
