'use strict';
const path = require('path');
const fs = require('fs');
const { DatabaseSync } = require('node:sqlite'); // SQLite nativo do Node (nao precisa compilar)
const bcrypt = require('bcryptjs');

const DATA_DIR = path.join(__dirname, '..', 'data');
if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
const DB_PATH = path.join(DATA_DIR, 'daexe.db');

// Wrapper fino para manter a mesma interface usada no projeto (.prepare/.exec/.pragma)
class DB {
  constructor(p) { this._db = new DatabaseSync(p); }
  exec(sql) { return this._db.exec(sql); }
  prepare(sql) { return this._db.prepare(sql); }
  pragma(p) { try { this._db.exec('PRAGMA ' + p + ';'); } catch (e) { /* noop */ } }
}

const db = new DB(DB_PATH);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

function init() {
  db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'viewer',
    department_id INTEGER,
    active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS company (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    name TEXT,
    plan_start TEXT,
    plan_end TEXT,
    vigencia_meses INTEGER,
    mission TEXT,
    vision TEXT,
    positioning TEXT
  );

  CREATE TABLE IF NOT EXISTS company_values (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    description TEXT,
    ord INTEGER DEFAULT 0
  );

  CREATE TABLE IF NOT EXISTS departments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    num TEXT,
    name TEXT NOT NULL,
    atuacao TEXT
  );

  CREATE TABLE IF NOT EXISTS swot_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    classification TEXT NOT NULL,
    item TEXT NOT NULL,
    department_id INTEGER,
    gravidade INTEGER DEFAULT 1,
    urgencia INTEGER DEFAULT 1,
    tendencia INTEGER DEFAULT 1,
    insights TEXT,
    FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS value_curve (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    attribute TEXT NOT NULL,
    daexe_score REAL DEFAULT 0,
    competitor_score REAL DEFAULT 0,
    ord INTEGER DEFAULT 0
  );

  CREATE TABLE IF NOT EXISTS bsc_perspectives (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    ord INTEGER DEFAULT 0
  );

  CREATE TABLE IF NOT EXISTS objectives (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT,
    title TEXT NOT NULL,
    perspective_id INTEGER,
    department_id INTEGER,
    FOREIGN KEY (perspective_id) REFERENCES bsc_perspectives(id) ON DELETE SET NULL,
    FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS goals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    objective_id INTEGER NOT NULL,
    smart_text TEXT NOT NULL,
    target_value REAL,
    unit TEXT,
    period TEXT,
    FOREIGN KEY (objective_id) REFERENCES objectives(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS initiatives (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT,
    objective_id INTEGER,
    name TEXT NOT NULL,
    who TEXT,
    date_start TEXT,
    date_end TEXT,
    how TEXT,
    how_much TEXT,
    where_ TEXT,
    why TEXT,
    status TEXT DEFAULT 'Nao iniciado',
    progress INTEGER DEFAULT 0,
    notes TEXT,
    FOREIGN KEY (objective_id) REFERENCES objectives(id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS goal_performance (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    goal_id INTEGER NOT NULL,
    period_type TEXT NOT NULL DEFAULT 'mensal',
    period_label TEXT NOT NULL,
    target_value REAL DEFAULT 0,
    actual_value REAL DEFAULT 0,
    updated_by INTEGER,
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (goal_id) REFERENCES goals(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS evaluations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    competency TEXT NOT NULL,
    month TEXT NOT NULL,
    self_score REAL DEFAULT 0,
    manager_score REAL DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    title TEXT NOT NULL,
    body TEXT,
    read INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    action TEXT,
    entity TEXT,
    detail TEXT,
    created_at TEXT DEFAULT (datetime('now'))
  );
  `);
}

function seed() {
  const count = db.prepare('SELECT COUNT(*) c FROM users').get().c;
  if (count > 0) { console.log('Seed ignorado: ja existem dados.'); return; }
  console.log('Populando banco com dados iniciais da planilha DAEXE...');

  db.prepare(`INSERT INTO company (id,name,plan_start,plan_end,vigencia_meses,mission,vision,positioning)
    VALUES (1,?,?,?,?,?,?,?)`).run(
    'Daexe', '2026-01-15', '2027-01-15', 12,
    'Organizar o mundo e materializar os objetivos dos empresarios.',
    'Estar entre as melhores empresas de consultoria do mundo, sendo referencia em resultados corporativos.',
    'Posicionamento Estrategico 2026'
  );

  const values = [
    ['Tempestividade', 'Cumprir prazos acordados com eficiencia e eficacia nos servicos prestados de forma antecipada.'],
    ['Qualidade', 'Exagero na qualidade em tudo que fazemos.'],
    ['Autodesenvolvimento e Alta Performance', 'Aperfeicoamento continuo.'],
    ['Simplicidade', 'Busca incessante pela excelencia e simplicidade nas solucoes.'],
    ['Confianca', 'Sinceridade acima de tudo.'],
    ['Resultados Consistentes', 'Pessoas + Competencia (CHAVE: Conhecimento, Habilidade, Atitude, Valores, Entrega) + Processos.'],
    ['Liberdade com Responsabilidade', 'Ter mente empreendedora, autorresponsabilidade e consolidar metas e resultados.']
  ];
  const insVal = db.prepare('INSERT INTO company_values (title,description,ord) VALUES (?,?,?)');
  values.forEach((v, i) => insVal.run(v[0], v[1], i));

  const depts = [
    ['1.0', 'Sucesso do Cliente e Projetos', 'Operacao'],
    ['2.0', 'Comercial', 'Vendas'],
    ['3.0', 'Financeiro', 'Administrativo'],
    ['4.0', 'Gente e Gestao', 'Pessoas'],
    ['5.0', 'Inovacao e Tecnologia', 'Estrategico']
  ];
  const insDep = db.prepare('INSERT INTO departments (num,name,atuacao) VALUES (?,?,?)');
  const deptIds = depts.map(d => insDep.run(d[0], d[1], d[2]).lastInsertRowid);

  const persp = ['Financeira', 'Clientes', 'Processos internos', 'Inovacao e Pessoas'];
  const insP = db.prepare('INSERT INTO bsc_perspectives (name,ord) VALUES (?,?)');
  const perspIds = persp.map((p, i) => insP.run(p, i).lastInsertRowid);

  const insObj = db.prepare('INSERT INTO objectives (code,title,perspective_id,department_id) VALUES (?,?,?,?)');
  const insGoal = db.prepare('INSERT INTO goals (objective_id,smart_text,period) VALUES (?,?,?)');
  const insIni = db.prepare(`INSERT INTO initiatives (code,objective_id,name,who,date_start,date_end,how,status,progress,why)
    VALUES (?,?,?,?,?,?,?,?,?,?)`);

  const o1 = insObj.run('1', 'Aumentar a Receita independente e recorrente', perspIds[0], deptIds[0]).lastInsertRowid;
  insGoal.run(o1, 'Faturar R$ 2.100.000,00 ate o final do Trimestre.', 'T1 2026');
  insGoal.run(o1, 'Gerar, ate o final do semestre, no minimo X de receita recorrente.', 'S1 2026');
  insIni.run('1', o1, 'Projeto Operacao Caixa Forte', 'CEO', '2026-01-15', '2026-04-15', 'Estruturacao de fluxo de caixa e cobranca.', 'Em andamento', 25, 'Garantir saude financeira e previsibilidade.');
  insIni.run('2', o1, 'Projeto Mais Sucesso do Cliente', 'GPC', '2026-01-15', '2026-04-15', 'Programa de retencao e expansao de contas.', 'Nao iniciado', 0, 'Aumentar receita recorrente.');

  const o2 = insObj.run('2', 'Aumentar o Prestigio da Marca', perspIds[1], deptIds[1]).lastInsertRowid;
  insGoal.run(o2, 'Alcancar 75% de NPS nos Projetos Sebrae.', 'T1 2026');
  insGoal.run(o2, 'Garantir que, ate o final do trimestre, X% dos clientes recomendem a Daexe.', 'T1 2026');
  insIni.run('3', o2, 'Programa Cliente Feliz', 'GPC', '2026-01-15', '2026-04-15', 'Pesquisa NPS e plano de melhoria continua.', 'Em andamento', 40, 'Fortalecer marca e indicacao.');
  insIni.run('4', o2, 'Programa Just in Time', 'GPP', '2026-01-15', '2026-04-15', 'Antecipacao de entregas e prazos.', 'Nao iniciado', 0, 'Reduzir atrasos e elevar satisfacao.');

  const o3 = insObj.run('3', 'Alcancar Excelencia Operacional', perspIds[2], deptIds[0]).lastInsertRowid;
  insGoal.run(o3, 'Entregar as demandas do Departamento com 100% de conformidade.', 'T1 2026');
  insGoal.run(o3, 'Alcancar 90% das tarefas concluidas no prazo.', 'T1 2026');
  insGoal.run(o3, 'Garantir a entrega de no minimo 90% dos projetos no prazo.', 'T1 2026');
  insIni.run('5', o3, 'Programa Excelencia Daexe', 'GPP', '2026-01-15', '2026-04-15', 'Padronizacao de POPs e checklists.', 'Em andamento', 30, 'Reduzir retrabalho e elevar qualidade.');

  const o4 = insObj.run('4', 'Garantir a Perenidade da Daexe', perspIds[3], deptIds[3]).lastInsertRowid;
  insGoal.run(o4, 'Obter 85% na Avaliacao de Desempenho no trimestre.', 'T1 2026');
  insGoal.run(o4, 'Ter 2 especialistas dentro do Departamento.', 'T1 2026');
  insGoal.run(o4, 'No trimestre, 100% dos assessores iniciarem o plano de desenvolvimento.', 'T1 2026');
  insGoal.run(o4, 'Implementar e/ou testar 01 projeto de Inovacao.', 'T1 2026');
  insIni.run('6', o4, 'Programa Desenvolve Daexe (Gestao de Pessoas)', 'Gente e Gestao', '2026-01-15', '2026-04-15', 'Plano de desenvolvimento individual e avaliacao.', 'Nao iniciado', 0, 'Reter e desenvolver talentos.');
  insIni.run('7', o4, 'Desenvolver SCP', 'Inovacao e Tecnologia', '2026-01-15', '2026-04-15', 'Sistema de Controle de Planejamento.', 'Em andamento', 15, 'Profissionalizar a gestao estrategica.');
  insIni.run('8', o4, 'Projetar Inova Daexe - SCP', 'Inovacao e Tecnologia', '2026-01-15', '2026-04-15', 'Testes de IA e automacoes.', 'Nao iniciado', 0, 'Inovacao continua.');

  const swot = [
    ['Forca', 'Consolidacao da Metodologia de Mentoria', 5, 5, 5],
    ['Forca', 'Metodologia de Gestao e Execucao', 1, 1, 1],
    ['Forca', 'Relacionamento com os Clientes', 3, 3, 3],
    ['Forca', 'Recrutamento e Selecao do projeto', 3, 3, 3],
    ['Fraqueza', 'Conformidade de Processos com a metodologia', 5, 4, 3],
    ['Fraqueza', 'Mensuracao e Feedback de Impacto', 5, 4, 5],
    ['Fraqueza', 'Antecipar o Cumprimento de Prazos', 5, 5, 5],
    ['Fraqueza', 'Delegar tarefas', 5, 4, 5],
    ['Fraqueza', 'Poucos Consultores habilitados', 5, 5, 5],
    ['Fraqueza', 'Capacidade de Elaborar Plano de Acao', 5, 5, 5],
    ['Oportunidade', 'Identificar empresas em processo de expansao', 5, 5, 5],
    ['Oportunidade', 'Capacitar Agentes de IA no Bitrix', 5, 5, 5],
    ['Ameaca', 'Imprevisibilidade de agenda dos clientes', 5, 5, 5],
    ['Ameaca', 'Crises Economicas', 5, 5, 5],
    ['Ameaca', 'Mudancas de Mercado e Tecnologia', 5, 5, 5],
    ['Ameaca', 'Riscos juridicos', 5, 5, 5],
    ['Ameaca', 'Saturacao operacional', 5, 4, 5]
  ];
  const insSwot = db.prepare('INSERT INTO swot_items (classification,item,department_id,gravidade,urgencia,tendencia) VALUES (?,?,?,?,?,?)');
  swot.forEach(s => insSwot.run(s[0], s[1], deptIds[0], s[2], s[3], s[4]));

  const curve = [
    ['Qualidade da entrega', 9, 6], ['Preco', 5, 7], ['Atendimento/Relacionamento', 9, 5],
    ['Tempestividade (prazo)', 8, 5], ['Inovacao/IA', 8, 4], ['Metodologia propria', 9, 4]
  ];
  const insCurve = db.prepare('INSERT INTO value_curve (attribute,daexe_score,competitor_score,ord) VALUES (?,?,?,?)');
  curve.forEach((c, i) => insCurve.run(c[0], c[1], c[2], i));

  const competencies = ['Organizacao', 'Resultados Consistentes', 'Qualidade', 'Sagaz e Agil', 'Inovador', 'Autodesenvolvimento', 'Comunicacao'];

  const hash = (p) => bcrypt.hashSync(p, 10);
  const insUser = db.prepare('INSERT INTO users (name,email,password_hash,role,department_id) VALUES (?,?,?,?,?)');
  insUser.run('Administrador DAEXE', 'admin@daexe.com.br', hash('daexe123'), 'admin', null);
  const mgrId = insUser.run('Gestor de Projetos', 'gestor@daexe.com.br', hash('daexe123'), 'manager', deptIds[0]).lastInsertRowid;
  insUser.run('Colaborador', 'colaborador@daexe.com.br', hash('daexe123'), 'contributor', deptIds[0]);
  insUser.run('Visualizador', 'visual@daexe.com.br', hash('daexe123'), 'viewer', null);

  const insEval = db.prepare('INSERT INTO evaluations (user_id,competency,month,self_score,manager_score) VALUES (?,?,?,?,?)');
  const months = ['Janeiro', 'Fevereiro', 'Marco'];
  competencies.forEach(c => months.forEach(m => insEval.run(mgrId, c, m, Math.round(Math.random() * 4 + 4), Math.round(Math.random() * 3 + 6))));

  const firstGoal = db.prepare('SELECT id FROM goals LIMIT 1').get().id;
  const insGP = db.prepare('INSERT INTO goal_performance (goal_id,period_type,period_label,target_value,actual_value) VALUES (?,?,?,?,?)');
  const gp = [['Jan', 700000, 350000], ['Fev', 700000, 480000], ['Mar', 700000, 610000]];
  gp.forEach(p => insGP.run(firstGoal, 'mensal', p[0], p[1], p[2]));

  console.log('Seed concluido. Usuarios: admin@daexe.com.br / gestor@daexe.com.br / colaborador@daexe.com.br / visual@daexe.com.br (senha: daexe123)');
}

init();
if (require.main === module && process.argv.includes('--seed')) seed();

module.exports = { db, init, seed };
