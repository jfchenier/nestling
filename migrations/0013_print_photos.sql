-- A full-size copy of a memory's photo, kept for printing the baby book (the photo itself is
-- scaled down so it stays light to sync). Only on the server: phones never download it. Cleared
-- when the photo is replaced, removed with it.
ALTER TABLE event_photos ADD COLUMN print_type TEXT;
ALTER TABLE event_photos ADD COLUMN print_data BLOB;
