import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import mysql from "mysql2/promise";

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 3306,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10
});

app.get("/api/health", async (_, res) => {
  try {
    const [rows] = await pool.query("SELECT 1 as ok");
    res.json({ ok: rows[0].ok === 1 });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});

app.get("/api/tasks", async (_, res) => {
  const [rows] = await pool.query("SELECT id, title, completed, created_at FROM tasks ORDER BY id DESC");
  res.json(rows.map(r => ({ id: r.id, title: r.title, completed: !!r.completed, created_at: r.created_at })));
});

app.post("/api/tasks", async (req, res) => {
  const { title } = req.body;
  if (!title) return res.status(400).json({ error: "title required" });
  const [result] = await pool.query("INSERT INTO tasks (title, completed) VALUES (?, ?)", [title, 0]);
  res.status(201).json({ id: result.insertId, title, completed: false });
});

app.put("/api/tasks/:id", async (req, res) => {
  const { id } = req.params;
  const { completed } = req.body;
  await pool.query("UPDATE tasks SET completed=? WHERE id=?", [completed ? 1 : 0, id]);
  res.json({ id: Number(id), completed: !!completed });
});

app.delete("/api/tasks/:id", async (req, res) => {
  const { id } = req.params;
  await pool.query("DELETE FROM tasks WHERE id=?", [id]);
  res.status(204).end();
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`API listening on ${port}`));
