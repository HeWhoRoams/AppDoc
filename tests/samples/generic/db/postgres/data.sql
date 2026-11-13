-- create table notes in a comment must not count
INSERT INTO accounts (name) VALUES ('CREATE TABLE fake (id INT)');
INSERT INTO projects (title, account_id) VALUES ('first', 1);
