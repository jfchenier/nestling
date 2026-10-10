-- The baby book's own pages (the day they were born, their name, the world they were born
-- into): a JSON object of short texts, kept on the child. See src/routes/children.rs `check_book`.
ALTER TABLE children ADD COLUMN book TEXT NOT NULL DEFAULT '{}';
