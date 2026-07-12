'use strict';
const path = require('path');
const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { db, seed } = require('./db');
const { exportExcel, exportPdf } = require('./exports');
const { notifyEmail } = require('./notify');

const app = express();
const PORT = process.env.PORT || 3000;
const SECRET = process.env.JWT_SECRET || 'daexe-scp-secret-change-me';

app.use(express.json({ limit: '2mb' }));
app.use(express.static(path.join(__dirname, '..', 'public')));

// Garante seed na primeira execução
try { seed(); } catch (e) { /* já populado */ }

// ---------- Helpers ----------
function log(userId, action, entity, detail) {
  try { db.prepare('INSERT INTO audit_log (user_id,action,entity,detail) VALUES (?,?,?,?)').run(userId, action, entity, detail || ''); } catch (e) {}
}
function sign(user) {
  return jwt.sign({ id: user.id, role: user.role, name: user.name, email: user.email, department_id: user.department_id }, SECRET, { expiresIn: '12h' });
}
function auth(req, res, next) {
  const h = req.headers.authorization || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Não autenticado' });
  try { req.user = jwt.verify(token, SECRET); next(); }
  catch (e) { return res.status(401).json({ error: 'Sessão expirada' }); }
}
// RBAC: ordem de poder
const RANK = { viewer: 0, contributor: 1, manager: 2, admin: 3 };
function require_(minRole) {
  return (req, res, next) => {
    if (RANK[req.user.role] >= RANK[minRole]) return next();
    return res.status(403).json({ error: 'Permissão insuficiente' });
  };
}
const canWrite = require_('contributor');
const canManage = require_('manager');
const adminOnly = require_('admin');

// ---------- Auth ----------
app.post('/api/login', (req, res) => {
  const { email, password } = req.body || {};
  const user = db.prepare('SELECT * FROM users WHERE email = ? AND active = 1').get((email || '').trim().toLowerCase());
  if (!user || !bcrypt.compareSync(password || '', user.password_hash))
    return res.status(401).json({ error: 'E-mail ou senha inválidos' });
  log(user.id, 'login', 'auth');
  res.json({ token: sign(user), user: { id: user.id, name: user.name, email: user.email, role: user.role, department_id: user.department_id } });
});

app.get('/api/me', auth, (req, res) => res.json({ user: req.user }));

// ---------- Usuários (admin) ----------
app.get('/api/users', auth, canManage, (req, res) => {
  const rows = db.prepare(`SELECT u.id,u.name,u.email,u.role,u.department_id,u.active,d.name dept
    FROM users u LEFT JOIN departments d ON d.id=u.department_id ORDER BY u.name`).all();
  res.json(rows);
});
app.post('/api/users', auth, adminOnly, (req, res) => {
  const { name, email, password, role, department_id } = req.body || {};
  if (!name || !email || !password) return res.status(400).json({ error: 'Nome, e-mail e senha são obrigatórios' });
  try {
    const r = db.prepare('INSERT INTO users (name,email,password_hash,role,department_id) VALUES (?,?,?,?,?)')
      .run(name, email.toLowerCase(), bcrypt.hashSync(password, 10), role || 'viewer', department_id || null);
    log(req.user.id, 'create', 'user', email);
    res.json({ id: r.lastInsertRowid });
  } catch (e) { res.status(400).json({ error: 'E-mail já cadastrado' }); }
});
app.put('/api/users/:id', auth, adminOnly, (req, res) => {
  const { name, role, department_id, active, password } = req.body || {};
  const u = db.prepare('SELECT * FROM users WHERE id=?').get(req.params.id);
  if (!u) return res.status(404).json({ error: 'Usuário não encontrado' });
  db.prepare('UPDATE users SET name=?,role=?,department_id=?,active=? WHERE id=?')
    .run(name ?? u.name, role ?? u.role, department_id ?? u.department_id, active ?? u.active, u.id);
  if (password) db.prepare('UPDATE users SET password_hash=? WHERE id=?').run(bcrypt.hashSync(password, 10), u.id);
  log(req.user.id, 'update', 'user', u.email);
  res.json({ ok: true });
});
app.delete('/api/users/:id', auth, adminOnly, (req, res) => {
  db.prepare('DELETE FROM users WHERE id=?').run(req.params.id);
  log(req.user.id, 'delete', 'user', req.params.id);
  res.json({ ok: true });
});

// ---------- Empresa / Filosofia ----------
app.get('/api/company', auth, (req, res) => {
  const company = db.prepare('SELECT * FROM company WHERE id=1').get();
  const values = db.prepare('SELECT * FROM company_values ORDER BY ord').all();
  res.json({ company, values });
});
app.put('/api/company', auth, canManage, (req, res) => {
  const c = req.body || {};
  db.prepare(`UPDATE company SET name=?,plan_start=?,plan_end=?,vigencia_meses=?,mission=?,vision=?,positioning=? WHERE id=1`)
    .run(c.name, c.plan_start, c.plan_end, c.vigencia_meses, c.mission, c.vision, c.positioning);
  log(req.user.id, 'update', 'company');
  res.json({ ok: true });
});
app.post('/api/values', auth, canManage, (req, res) => {
  const { title, description } = req.body || {};
  const ord = db.prepare('SELECT COALESCE(MAX(ord),0)+1 n FROM company_values').get().n;
  const r = db.prepare('INSERT INTO company_values (title,description,ord) VALUES (?,?,?)').run(title, description, ord);
  res.json({ id: r.lastInsertRowid });
});
app.put('/api/values/:id', auth, canManage, (req, res) => {
  const { title, description } = req.body || {};
  db.prepare('UPDATE company_values SET title=?,description=? WHERE id=?').run(title, description, req.params.id);
  res.json({ ok: true });
});
app.delete('/api/values/:id', auth, canManage, (req, res) => {
  db.prepare('DELETE FROM company_values WHERE id=?').run(req.params.id); res.json({ ok: true });
});

// ---------- Departamentos ----------
app.get('/api/departments', auth, (req, res) => res.json(db.prepare('SELECT * FROM departments ORDER BY id').all()));
app.post('/api/departments', auth, canManage, (req, res) => {
  const { num, name, atuacao } = req.body || {};
  const r = db.prepare('INSERT INTO departments (num,name,atuacao) VALUES (?,?,?)').run(num, name, atuacao);
  res.json({ id: r.lastInsertRowid });
});
app.put('/api/departments/:id', auth, canManage, (req, res) => {
  const { num, name, atuacao } = req.body || {};
  db.prepare('UPDATE departments SET num=?,name=?,atuacao=? WHERE id=?').run(num, name, atuacao, req.params.id);
  res.json({ ok: true });
});
app.delete('/api/departments/:id', auth, canManage, (req, res) => {
  db.prepare('DELETE FROM departments WHERE id=?').run(req.params.id); res.json({ ok: true });
});

// ---------- SWOT / GUT ----------
app.get('/api/swot', auth, (req, res) => {
  const rows = db.prepare(`SELECT s.*, (s.gravidade*s.urgencia*s.tendencia) AS gut, d.name dept
    FROM swot_items s LEFT JOIN departments d ON d.id=s.department_id ORDER BY gut DESC`).all();
  res.json(rows);
});
app.post('/api/swot', auth, canWrite, (req, res) => {
  const b = req.body || {};
  const r = db.prepare('INSERT INTO swot_items (classification,item,department_id,gravidade,urgencia,tendencia,insights) VALUES (?,?,?,?,?,?,?)')
    .run(b.classification, b.item, b.department_id || null, b.gravidade || 1, b.urgencia || 1, b.tendencia || 1, b.insights || '');
  log(req.user.id, 'create', 'swot', b.item);
  res.json({ id: r.lastInsertRowid });
});
app.put('/api/swot/:id', auth, canWrite, (req, res) => {
  const b = req.body || {};
  db.prepare('UPDATE swot_items SET classification=?,item=?,department_id=?,gravidade=?,urgencia=?,tendencia=?,insights=? WHERE id=?')
    .run(b.classification, b.item, b.department_id || null, b.gravidade, b.urgencia, b.tendencia, b.insights || '', req.params.id);
  res.json({ ok: true });
});
app.delete('/api/swot/:id', auth, canWrite, (req, res) => {
  db.prepare('DELETE FROM swot_items WHERE id=?').run(req.params.id); res.json({ ok: true });
});

// ---------- Curva de Valor ----------
app.get('/api/value-curve', auth, (req, res) => res.json(db.prepare('SELECT * FROM value_curve ORDER BY ord,id').all()));
app.post('/api/value-curve', auth, canManage, (req, res) => {
  const b = req.body || {};
  const ord = db.prepare('SELECT COALESCE(MAX(ord),0)+1 n FROM value_curve').get().n;
  const r = db.prepare('INSERT INTO value_curve (attribute,daexe_score,competitor_score,ord) VALUES (?,?,?,?)')
    .run(b.attribute, b.daexe_score || 0, b.competitor_score || 0, ord);
  res.json({ id: r.lastInsertRowid });
});
app.put('/api/value-curve/:id', auth, canManage, (req, res) => {
  const b = req.body || {};
  db.prepare('UPDATE value_curve SET attribute=?,daexe_score=?,competitor_score=? WHERE id=?')
    .run(b.attribute, b.daexe_score, b.competitor_score, req.params.id);
  res.json({ ok: true });
});
app.delete('/api/value-curve/:id', auth, canManage, (req, res) => {
  db.prepare('DELETE FROM value_curve WHERE id=?').run(req.params.id); res.json({ ok: true });
});

// ---------- BSC / Objetivos / Metas ----------
app.get('/api/bsc', auth, (req, res) => {
  const perspectives = db.prepare('SELECT * FROM bsc_perspectives ORDER BY ord').all();
  const objectives = db.prepare('SELECT * FROM objectives ORDER BY code').all();
  const goals = db.prepare('SELECT * FROM goals ORDER BY id').all();
  res.json({ perspectives, objectives, goals });
});
app.post('/api/objectives', auth, canManage, (req, res) => {
  const b = req.body || {};
  const r = db.prepare('INSERT INTO objectives (code,title,perspective_id,department_id) VALUES (?,?,?,?)')
    .run(b.code, b.title, b.perspective_id || null, b.department_id || null);
  res.json({ id: r.lastInsertRowid });
});
app.put('/api/objectives/:id', auth, canManage, (req, res) => {
  const b = req.body || {};
  db.prepare('UPDATE objectives SET code=?,title=?,perspective_id=?,department_id=? WHERE id=?')
    .run(b.code, b.title, b.perspective_id || null, b.department_id || null, req.params.id);
  res.json({ ok: true });
});
app.delete('/api/objectives/:id', auth, canManage, (req, res) => {
  db.prepare('DELETE FROM objectives WHERE id=?').run(req.params.id); res.json({ ok: true });
});
app.post('/api/goals', auth, canManage, (req, res) => {
  const b = req.body || {};
  const r = db.prepare('INSERT INTO goals (objective_id,smart_text,target_value,unit,period) VALUES (?,?,?,?,?)')
    .run(b.objective_id, b.smart_text, b.target_value || null, b.unit || '', b.period || '');
  res.json({ id: r.lastInsertRowid });
});
app.put('/api/goals/:id', auth, canManage, (req, res) => {
  const b = req.body || {};
  db.prepare('UPDATE goals SET smart_text=?,target_value=?,unit=?,period=? WHERE id=?')
    .run(b.smart_text, b.target_value || null, b.unit || '', b.period || '', req.params.id);
  res.json({ ok: true });
});
app.delete('/api/goals/:id', auth, canManage, (req, res) => {
  db.prepare('DELETE FROM goals WHERE id=?').run(req.params.id); res.json({ ok: true });
});

// ---------- Iniciativas (5W2H) ----------
app.get('/api/initiatives', auth, (req, res) => {
  const rows = db.prepare(`SELECT i.*, o.title objective_title, o.code objective_code
    FROM initiatives i LEFT JOIN objectives o ON o.id=i.objective_id ORDER BY i.code,i.id`).all();
  res.json(rows);
});
app.post('/api/initiatives', auth, canWrite, (req, res) => {
  const b = req.body || {};
  const r = db.prepare(`INSERT INTO initiatives (code,objective_id,name,who,date_start,date_end,how,how_much,where_,why,status,progress,notes)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)`).run(
    b.code || '', b.objective_id || null, b.name, b.who || '', b.date_start || '', b.date_end || '',
    b.how || '', b.how_much || '', b.where_ || '', b.why || '', b.status || 'Não iniciado', b.progress || 0, b.notes || '');
  log(req.user.id, 'create', 'initiative', b.name);
  res.json({ id: r.lastInsertRowid });
});
app.put('/api/initiatives/:id', auth, canWrite, (req, res) => {
  const b = req.body || {};
  db.prepare(`UPDATE initiatives SET code=?,objective_id=?,name=?,who=?,date_start=?,date_end=?,how=?,how_much=?,where_=?,why=?,status=?,progress=?,notes=? WHERE id=?`)
    .run(b.code || '', b.objective_id || null, b.name, b.who || '', b.date_start || '', b.date_end || '',
      b.how || '', b.how_much || '', b.where_ || '', b.why || '', b.status, b.progress, b.notes || '', req.params.id);
  log(req.user.id, 'update', 'initiative', b.name);
  res.json({ ok: true });
});
app.delete('/api/initiatives/:id', auth, canWrite, (req, res) => {
  db.prepare('DELETE FROM initiatives WHERE id=?').run(req.params.id); res.json({ ok: true });
});

// ---------- Desempenho de Metas ----------
app.get('/api/performance', auth, (req, res) => {
  const rows = db.prepare(`SELECT gp.*, g.smart_text, o.title objective_title
    FROM goal_performance gp JOIN goals g ON g.id=gp.goal_id LEFT JOIN objectives o ON o.id=g.objective_id
    ORDER BY gp.goal_id, gp.id`).all();
  res.json(rows);
});
app.post('/api/performance', auth, canWrite, (req, res) => {
  const b = req.body || {};
  const r = db.prepare('INSERT INTO goal_performance (goal_id,period_type,period_label,target_value,actual_value,updated_by) VALUES (?,?,?,?,?,?)')
    .run(b.goal_id, b.period_type || 'mensal', b.period_label, b.target_value || 0, b.actual_value || 0, req.user.id);
  res.json({ id: r.lastInsertRowid });
});
app.put('/api/performance/:id', auth, canWrite, (req, res) => {
  const b = req.body || {};
  db.prepare('UPDATE goal_performance SET period_type=?,period_label=?,target_value=?,actual_value=?,updated_by=?,updated_at=datetime(\'now\') WHERE id=?')
    .run(b.period_type, b.period_label, b.target_value, b.actual_value, req.user.id, req.params.id);
  res.json({ ok: true });
});
app.delete('/api/performance/:id', auth, canWrite, (req, res) => {
  db.prepare('DELETE FROM goal_performance WHERE id=?').run(req.params.id); res.json({ ok: true });
});

// ---------- Avaliação de Desempenho ----------
app.get('/api/evaluations', auth, (req, res) => {
  let rows;
  if (RANK[req.user.role] >= RANK.manager) {
    rows = db.prepare(`SELECT e.*, u.name user_name FROM evaluations e JOIN users u ON u.id=e.user_id ORDER BY u.name,e.month`).all();
  } else {
    rows = db.prepare(`SELECT e.*, u.name user_name FROM evaluations e JOIN users u ON u.id=e.user_id WHERE e.user_id=? ORDER BY e.month`).all(req.user.id);
  }
  res.json(rows);
});
app.post('/api/evaluations', auth, canWrite, (req, res) => {
  const b = req.body || {};
  const uid = (RANK[req.user.role] >= RANK.manager && b.user_id) ? b.user_id : req.user.id;
  const r = db.prepare('INSERT INTO evaluations (user_id,competency,month,self_score,manager_score) VALUES (?,?,?,?,?)')
    .run(uid, b.competency, b.month, b.self_score || 0, b.manager_score || 0);
  res.json({ id: r.lastInsertRowid });
});
app.put('/api/evaluations/:id', auth, canWrite, (req, res) => {
  const b = req.body || {};
  const e = db.prepare('SELECT * FROM evaluations WHERE id=?').get(req.params.id);
  if (!e) return res.status(404).json({ error: 'Não encontrado' });
  // colaborador só edita auto avaliação própria; gestor edita nota do gestor
  const isManager = RANK[req.user.role] >= RANK.manager;
  if (!isManager && e.user_id !== req.user.id) return res.status(403).json({ error: 'Permissão insuficiente' });
  const self_score = b.self_score ?? e.self_score;
  const manager_score = isManager ? (b.manager_score ?? e.manager_score) : e.manager_score;
  db.prepare('UPDATE evaluations SET self_score=?,manager_score=? WHERE id=?').run(self_score, manager_score, req.params.id);
  res.json({ ok: true });
});

// ---------- Notificações ----------
app.get('/api/notifications', auth, (req, res) => {
  res.json(db.prepare('SELECT * FROM notifications WHERE user_id IS NULL OR user_id=? ORDER BY created_at DESC LIMIT 50').all(req.user.id));
});
app.post('/api/notifications/remind', auth, canManage, (req, res) => {
  const { user_id, title, body } = req.body || {};
  db.prepare('INSERT INTO notifications (user_id,title,body) VALUES (?,?,?)').run(user_id || null, title || 'Lembrete', body || '');
  const target = user_id ? db.prepare('SELECT email FROM users WHERE id=?').get(user_id) : null;
  notifyEmail(target ? target.email : 'todos', title || 'Lembrete', body || '');
  res.json({ ok: true });
});

// ---------- Dashboard agregado ----------
app.get('/api/dashboard', auth, (req, res) => {
  const objectives = db.prepare('SELECT COUNT(*) c FROM objectives').get().c;
  const goals = db.prepare('SELECT COUNT(*) c FROM goals').get().c;
  const inis = db.prepare('SELECT status, COUNT(*) c, AVG(progress) p FROM initiatives GROUP BY status').all();
  const totalIni = db.prepare('SELECT COUNT(*) c, AVG(progress) p FROM initiatives').get();
  const swotByClass = db.prepare('SELECT classification, COUNT(*) c FROM swot_items GROUP BY classification').all();
  const topGut = db.prepare('SELECT item, (gravidade*urgencia*tendencia) gut, classification FROM swot_items ORDER BY gut DESC LIMIT 5').all();
  const perf = db.prepare(`SELECT g.smart_text, SUM(gp.target_value) t, SUM(gp.actual_value) a
    FROM goal_performance gp JOIN goals g ON g.id=gp.goal_id GROUP BY gp.goal_id`).all();
  res.json({ objectives, goals, initiatives: { total: totalIni.c, avgProgress: Math.round(totalIni.p || 0), byStatus: inis }, swotByClass, topGut, perf });
});

// ---------- Exportações ----------
app.get('/api/export/excel', auth, async (req, res) => {
  try {
    const buf = await exportExcel(db);
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', 'attachment; filename="Planejamento_DAEXE.xlsx"');
    res.send(buf);
  } catch (e) { res.status(500).json({ error: e.message }); }
});
app.get('/api/export/pdf', auth, (req, res) => {
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', 'attachment; filename="Planejamento_DAEXE.pdf"');
  exportPdf(db, res);
});

app.get('*', (req, res) => res.sendFile(path.join(__dirname, '..', 'public', 'index.html')));

app.listen(PORT, () => console.log(`\n✅ DAEXE SCP rodando em http://localhost:${PORT}\n   Login admin: admin@daexe.com.br / daexe123\n`));
