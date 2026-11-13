CREATE TABLE accounts (
  id INT(4) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(30)
) engine=InnoDB;

CREATE TABLE projects (
  id INT(4) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(80),
  account_id INT(4) UNSIGNED,
  FOREIGN KEY (account_id) REFERENCES accounts(id)
) engine=InnoDB;

CREATE TABLE tasks (
  id INT PRIMARY KEY,
  project_id INT
);
ALTER TABLE tasks ADD CONSTRAINT fk_tasks_projects FOREIGN KEY (project_id) REFERENCES projects (id);
