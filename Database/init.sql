-- Create schema & table
CREATE DATABASE IF NOT EXISTS ttmdb;
USE ttmdb;

CREATE TABLE IF NOT EXISTS tasks (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  completed TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create least-privilege app user (use modern auth plugin)
CREATE USER IF NOT EXISTS 'todo_user'@'%' IDENTIFIED WITH caching_sha2_password BY 'StrongDevPwd!123';

GRANT SELECT, INSERT, UPDATE, DELETE ON ttmdb.* TO 'todo_user'@'%';
FLUSH PRIVILEGES;

-- Optional seed
INSERT INTO tasks (title, completed) VALUES ('First task from SQL', 0);
