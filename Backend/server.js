import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import mysql from "mysql2/promise";
import cookieParser from "cookie-parser";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import path from "path";
import { fileURLToPath } from "url";

dotenv.config();

const app = express();

// --- Paths / static serving ---
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
// If your HTML lives elsewhere, point to that folder instead:
const PUBLIC_DIR = path.join(__dirname, "../Frontend");

// --- Security / cookies / CORS ---
const JWT_SECRET = process.env.JWT_SECRET || "dev-secret-change-me";

// CORS (must be before routes)
app.use(cors({
  origin: true,          // reflect origin
  credentials: true,
  methods: ["GET","POST","PUT","DELETE","OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization"],
}));

// Make sure OPTIONS never 501s
app.options("*", cors());


app.use(express.json());
app.use(cookieParser());
app.use(
  cors({
    origin: true,           // reflect request origin (e.g., http://localhost:3000)
    credentials: true,      // allow cookies
  })
);

const COOKIE_OPTS = {
  httpOnly: true,
  sameSite: "lax",          // use "none" + secure:true for cross-site HTTPS
  secure: false,            // set true in prod behind HTTPS
  path: "/",
};

// --- DB pool ---
const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 3306,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
});

// --- Auth helpers ---
function signToken(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: "1d" });
}

function authRequired(req, res, next) {
  const token = req.cookies?.auth;
  if (!token) return res.status(401).json({ error: "Not authenticated" });
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    return res.status(401).json({ error: "Invalid/expired" });
  }
}

// --- Static files ---
// Disable the automatic "index.html" at '/':
app.use(express.static(PUBLIC_DIR, { index: false }));

// Serve landing page at '/'
app.get("/", (_req, res) => {
  res.sendFile(path.join(PUBLIC_DIR, "home.html"));
});

// Protect index.html behind auth
app.get("/index.html", authRequired, (_req, res) => {
  res.sendFile(path.join(PUBLIC_DIR, "index.html"));
});

// --- Health ---
app.get("/api/health", async (_req, res) => {
  try {
    const [rows] = await pool.query("SELECT 1 as ok");
    res.json({ ok: rows[0].ok === 1 });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});

// --- Auth routes ---
// POST /api/auth/signup
app.post("/api/auth/signup", async (req, res) => {
  const { email, password } = req.body || {};
  if (!email || !password) {
    return res.status(400).json({ error: "email and password required" });
  }
  try {
    const [rows] = await pool.query("SELECT id FROM users WHERE email=?", [email]);
    if (rows.length) return res.status(409).json({ error: "Email already registered" });

    const hash = await bcrypt.hash(password, 10);
    const [ins] = await pool.query(
      "INSERT INTO users (email, password_hash) VALUES (?, ?)",
      [email, hash]
    );

    const token = signToken({ id: ins.insertId, email });
    res.cookie("auth", token, COOKIE_OPTS);
    return res.status(201).json({ message: "Account created", email });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: "Server error" });
  }
});

// POST /api/auth/login
app.post("/api/auth/login", async (req, res) => {
  const { email, password } = req.body || {};
  if (!email || !password) {
    return res.status(400).json({ error: "email and password required" });
  }
  try {
    const [rows] = await pool.query(
      "SELECT id, email, password_hash FROM users WHERE email=?",
      [email]
    );
    if (!rows.length) return res.status(401).json({ error: "Invalid credentials" });

    const ok = await bcrypt.compare(password, rows[0].password_hash);
    if (!ok) return res.status(401).json({ error: "Invalid credentials" });

    const token = signToken({ id: rows[0].id, email: rows[0].email });
    res.cookie("auth", token, COOKIE_OPTS);
    return res.json({ message: "Login successful", email: rows[0].email });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: "Server error" });
  }
});

// GET /api/auth/me
app.get("/api/auth/me", authRequired, (req, res) => {
  res.json({ id: req.user.id, email: req.user.email });
});

// POST /api/auth/logout
app.post("/api/auth/logout", (req, res) => {
  res.clearCookie("auth", { ...COOKIE_OPTS, maxAge: 0 });
  res.json({ message: "Logged out" });
});

// --- Tasks API (ALL protected) ---
app.get("/api/tasks", authRequired, async (_req, res) => {
  const [rows] = await pool.query(
    "SELECT id, title, completed, created_at FROM tasks ORDER BY id DESC"
  );
  res.json(
    rows.map((r) => ({
      id: r.id,
      title: r.title,
      completed: !!r.completed,
      created_at: r.created_at,
    }))
  );
});

app.post("/api/tasks", authRequired, async (req, res) => {
  const { title } = req.body || {};
  if (!title) return res.status(400).json({ error: "title required" });

  const [result] = await pool.query(
    "INSERT INTO tasks (title, completed) VALUES (?, 0)",
    [title]
  );
  res.status(201).json({ id: result.insertId, title, completed: false });
});

app.put("/api/tasks/:id", authRequired, async (req, res) => {
  const { id } = req.params;
  const { title, completed } = req.body || {};

  const fields = [];
  const vals = [];
  if (typeof title === "string") {
    fields.push("title=?");
    vals.push(title);
  }
  if (typeof completed !== "undefined") {
    fields.push("completed=?");
    vals.push(completed ? 1 : 0);
  }
  if (!fields.length) return res.status(400).json({ error: "No fields to update" });

  vals.push(id);
  await pool.query(`UPDATE tasks SET ${fields.join(", ")} WHERE id=?`, vals);

  res.json({
    id: Number(id),
    ...(title !== undefined ? { title } : {}),
    ...(completed !== undefined ? { completed: !!completed } : {}),
  });
});

app.delete("/api/tasks/:id", authRequired, async (req, res) => {
  const { id } = req.params;
  await pool.query("DELETE FROM tasks WHERE id=?", [id]);
  res.status(204).end();
});

// --- Start server ---
const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`Server listening on ${port}`));
