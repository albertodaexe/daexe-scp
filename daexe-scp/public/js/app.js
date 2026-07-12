// SPA DAEXE — Planejamento Estratégico
const App = (() => {
  let token = null, me = null, charts = {};
  const RANK = { viewer: 0, contributor: 1, manager: 2, admin: 3 };
  const ROLE_LABEL = { admin: 'Administrador', manager: 'Gestor', contributor: 'Colaborador', viewer: 'Visualizador' };
  const can = (r) => me && RANK[me.role] >= RANK[r];

  // ---------- API ----------
  async function api(path, opts = {}) {
    const res = await fetch('/api' + path, {
      ...opts,
      headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}), ...(opts.headers || {}) }
    });
    if (res.status === 401) { logout(); throw new Error('Sessão expirada'); }
    if (!res.ok) { const e = await res.json().catch(() => ({})); throw new Error(e.error || 'Erro'); }
    const ct = res.headers.get('content-type') || '';
    return ct.includes('json') ? res.json() : res;
  }

  // ---------- Auth ----------
  async function login(email, password) {
    const data = await api('/login', { method: 'POST', body: JSON.stringify({ email, password }) });
    token = data.token; me = data.user;
    sessionStorage.setItem('daexe_t', token); sessionStorage.setItem('daexe_u', JSON.stringify(me));
    boot();
  }
  function logout() {
    token = null; me = null; sessionStorage.clear();
    document.getElementById('app').classList.add('hidden');
    document.getElementById('login-screen').classList.remove('hidden');
  }
  function boot() {
    document.getElementById('login-screen').classList.add('hidden');
    document.getElementById('app').classList.remove('hidden');
    document.getElementById('user-chip').innerHTML = `<strong>${me.name}</strong><span>${me.email}</span>`;
    document.getElementById('role-badge').textContent = ROLE_LABEL[me.role];
    renderNav();
    go('dashboard');
  }

  // ---------- Navegação ----------
  const NAV = [
    { sec: 'Estratégia' },
    { id: 'dashboard', label: 'Painel', ico: '📊' },
    { id: 'filosofia', label: 'Filosofia', ico: '🎯' },
    { id: 'departamentos', label: 'Departamentos', ico: '🏢' },
    { id: 'swot', label: 'SWOT / GUT', ico: '⚖️' },
    { id: 'curva', label: 'Curva de Valor', ico: '📈' },
    { sec: 'Execução' },
    { id: 'bsc', label: 'Mapa BSC', ico: '🗺️' },
    { id: 'okr', label: 'Objetivos & Metas', ico: '✅' },
    { id: 'iniciativas', label: 'Iniciativas (5W2H)', ico: '🚀' },
    { id: 'desempenho', label: 'Desempenho de Metas', ico: '📉' },
    { id: 'avaliacao', label: 'Avaliação', ico: '⭐' },
    { sec: 'Gestão', role: 'manager' },
    { id: 'usuarios', label: 'Usuários & Acessos', ico: '👥', role: 'manager' },
    { id: 'notificacoes', label: 'Notificações', ico: '🔔' }
  ];
  function renderNav() {
    const nav = document.getElementById('nav'); nav.innerHTML = '';
    NAV.forEach(n => {
      if (n.role && !can(n.role)) return;
      if (n.sec) { const s = document.createElement('div'); s.className = 'nav-section'; s.textContent = n.sec; nav.appendChild(s); return; }
      const d = document.createElement('div'); d.className = 'nav-item'; d.dataset.id = n.id;
      d.innerHTML = `<span class="ico">${n.ico}</span><span>${n.label}</span>`;
      d.onclick = () => go(n.id);
      nav.appendChild(d);
    });
  }
  let current = null;
  function go(id) {
    current = id;
    document.querySelectorAll('.nav-item').forEach(e => e.classList.toggle('active', e.dataset.id === id));
    const v = document.getElementById('view'); v.innerHTML = '<div class="empty">Carregando…</div>';
    const def = NAV.find(n => n.id === id);
    document.getElementById('page-title').textContent = def ? def.label : 'Painel';
    (VIEWS[id] || VIEWS.dashboard)(v);
  }

  // ---------- Helpers UI ----------
  const esc = (s) => (s == null ? '' : String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c])));
  function toast(msg) { const t = document.getElementById('toast'); t.textContent = msg; t.classList.remove('hidden'); setTimeout(() => t.classList.add('hidden'), 2600); }
  function modal(title, bodyHtml) {
    document.getElementById('modal-title').textContent = title;
    document.getElementById('modal-body').innerHTML = bodyHtml;
    document.getElementById('modal-backdrop').classList.remove('hidden');
  }
  function closeModal() { document.getElementById('modal-backdrop').classList.add('hidden'); }
  function form(fields) { return fields.map(f => f).join(''); }
  const f = {
    text: (id, label, val = '', extra = '') => `<div class="field"><label>${label}</label><input id="${id}" value="${esc(val)}" ${extra}></div>`,
    num: (id, label, val = '', extra = '') => `<div class="field"><label>${label}</label><input type="number" id="${id}" value="${val ?? ''}" ${extra}></div>`,
    date: (id, label, val = '') => `<div class="field"><label>${label}</label><input type="date" id="${id}" value="${val ? String(val).slice(0, 10) : ''}"></div>`,
    area: (id, label, val = '') => `<div class="field"><label>${label}</label><textarea id="${id}">${esc(val)}</textarea></div>`,
    sel: (id, label, opts, val) => `<div class="field"><label>${label}</label><select id="${id}">${opts.map(o => `<option value="${o.v}" ${o.v == val ? 'selected' : ''}>${esc(o.t)}</option>`).join('')}</select></div>`
  };
  const val = (id) => { const e = document.getElementById(id); return e ? e.value : ''; };
  const pct = (a, t) => t ? Math.round(a / t * 100) : 0;
  const money = (n) => (n || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
  function statusPill(s) {
    const m = { 'Concluído': 'pill-green', 'Em andamento': 'pill-blue', 'Não iniciado': 'pill-gray', 'Atrasado': 'pill-red' };
    return `<span class="pill ${m[s] || 'pill-gray'}">${esc(s)}</span>`;
  }
  function bar(p) { const c = p >= 80 ? 'var(--green)' : p >= 40 ? 'var(--accent)' : 'var(--amber)'; return `<div class="progress"><i style="width:${Math.min(p, 100)}%;background:${c}"></i></div>`; }
  function actionsCol(editFn, delFn, role = 'contributor') {
    if (!can(role)) return '';
    return `<div class="inline-actions">
      <button class="btn btn-light btn-sm" onclick="${editFn}">Editar</button>
      ${delFn ? `<button class="btn btn-danger btn-sm" onclick="${delFn}">Excluir</button>` : ''}</div>`;
  }
  async function del(path, msg) { if (!confirm(msg || 'Confirmar exclusão?')) return false; await api(path, { method: 'DELETE' }); toast('Excluído'); return true; }

  // ---------- VIEWS ----------
  const VIEWS = {};

  // Dashboard
  VIEWS.dashboard = async (v) => {
    const d = await api('/dashboard');
    const conc = (d.initiatives.byStatus.find(s => s.status === 'Concluído') || {}).c || 0;
    v.innerHTML = `
      <div class="cards">
        <div class="stat"><div class="label">Objetivos Estratégicos</div><div class="value">${d.objectives}</div><div class="sub">${d.goals} metas SMART</div></div>
        <div class="stat"><div class="label">Iniciativas</div><div class="value">${d.initiatives.total}</div><div class="sub">${conc} concluídas</div></div>
        <div class="stat" style="border-color:var(--green)"><div class="label">Progresso médio</div><div class="value">${d.initiatives.avgProgress}%</div><div class="sub">do plano de ação</div></div>
        <div class="stat" style="border-color:var(--gold)"><div class="label">Itens SWOT</div><div class="value">${d.swotByClass.reduce((a, b) => a + b.c, 0)}</div><div class="sub">mapeados</div></div>
      </div>
      <div class="grid-2">
        <div class="card"><h3>Desempenho das metas</h3><p class="desc">Realizado vs. alvo acumulado</p><canvas id="ch-perf" height="200"></canvas></div>
        <div class="card"><h3>SWOT por classificação</h3><p class="desc">Distribuição do diagnóstico</p><canvas id="ch-swot" height="200"></canvas></div>
      </div>
      <div class="card"><h3>Top 5 prioridades (Matriz GUT)</h3>
        <table><thead><tr><th>Item</th><th>Classificação</th><th>GUT</th></tr></thead><tbody>
        ${d.topGut.map(t => `<tr><td>${esc(t.item)}</td><td>${esc(t.classification)}</td><td class="gut-num">${t.gut}</td></tr>`).join('')}
        </tbody></table></div>`;
    const labels = d.perf.map(p => p.smart_text.slice(0, 22) + '…');
    mkChart('ch-perf', 'bar', { labels, datasets: [
      { label: 'Alvo', data: d.perf.map(p => p.t), backgroundColor: '#cdd8e6' },
      { label: 'Realizado', data: d.perf.map(p => p.a), backgroundColor: '#2E8BC0' }] });
    const colorMap = { 'Força': '#2e9e6b', 'Fraqueza': '#d9534f', 'Oportunidade': '#2E8BC0', 'Ameaça': '#E6A817' };
    mkChart('ch-swot', 'doughnut', { labels: d.swotByClass.map(s => s.classification),
      datasets: [{ data: d.swotByClass.map(s => s.c), backgroundColor: d.swotByClass.map(s => colorMap[s.classification] || '#999') }] });
  };
  function mkChart(id, type, data, opts = {}) {
    const el = document.getElementById(id); if (!el) return;
    if (charts[id]) charts[id].destroy();
    charts[id] = new Chart(el, { type, data, options: { responsive: true, plugins: { legend: { position: 'bottom' } }, ...opts } });
  }

  // Filosofia
  VIEWS.filosofia = async (v) => {
    const { company, values } = await api('/company');
    v.innerHTML = `
      <div class="philo-box">
        <h4>Missão</h4><p>${esc(company.mission)}</p>
        <h4 style="margin-top:18px">Visão</h4><p>${esc(company.vision)}</p>
      </div>
      <div class="card">
        <div class="section-head"><h3>Valores</h3>
          ${can('manager') ? `<button class="btn btn-accent btn-sm" onclick="App.editValue()">+ Novo valor</button>` : ''}</div>
        <div class="value-list">${values.map(val => `<div class="value-item"><b>${esc(val.title)}</b><p>${esc(val.description)}</p>
          ${can('manager') ? `<div class="inline-actions" style="margin-top:8px"><button class="btn btn-light btn-sm" onclick='App.editValue(${JSON.stringify(val)})'>Editar</button><button class="btn btn-danger btn-sm" onclick="App.delValue(${val.id})">Excluir</button></div>` : ''}</div>`).join('')}</div>
      </div>
      ${can('manager') ? `<div class="card"><div class="section-head"><h3>Dados da empresa</h3>
        <button class="btn btn-accent btn-sm" onclick='App.editCompany(${JSON.stringify(company)})'>Editar</button></div>
        <table><tr><th>Empresa</th><td>${esc(company.name)}</td></tr>
        <tr><th>Vigência</th><td>${esc(company.plan_start)} a ${esc(company.plan_end)} (${company.vigencia_meses} meses)</td></tr>
        <tr><th>Posicionamento</th><td>${esc(company.positioning)}</td></tr></table></div>` : ''}`;
  };
  App_editValue = async (v = {}) => {
    modal(v.id ? 'Editar valor' : 'Novo valor', form([
      f.text('val-title', 'Título', v.title), f.area('val-desc', 'Descrição', v.description),
      `<button class="btn btn-primary btn-block" onclick="App.saveValue(${v.id || 0})">Salvar</button>`]));
  };
  App_saveValue = async (id) => {
    const body = JSON.stringify({ title: val('val-title'), description: val('val-desc') });
    await api('/values' + (id ? '/' + id : ''), { method: id ? 'PUT' : 'POST', body });
    closeModal(); toast('Salvo'); go('filosofia');
  };
  App_delValue = async (id) => { if (await del('/values/' + id)) go('filosofia'); };
  App_editCompany = (c) => {
    modal('Editar empresa', form([
      f.text('co-name', 'Nome', c.name), f.area('co-mission', 'Missão', c.mission), f.area('co-vision', 'Visão', c.vision),
      `<div class="field-row">${f.date('co-start', 'Início', c.plan_start)}${f.date('co-end', 'Fim', c.plan_end)}</div>`,
      f.num('co-vig', 'Vigência (meses)', c.vigencia_meses), f.text('co-pos', 'Posicionamento', c.positioning),
      `<button class="btn btn-primary btn-block" onclick="App.saveCompany()">Salvar</button>`]));
  };
  App_saveCompany = async () => {
    await api('/company', { method: 'PUT', body: JSON.stringify({
      name: val('co-name'), mission: val('co-mission'), vision: val('co-vision'),
      plan_start: val('co-start'), plan_end: val('co-end'), vigencia_meses: +val('co-vig'), positioning: val('co-pos') }) });
    closeModal(); toast('Salvo'); go('filosofia');
  };

  // Departamentos
  VIEWS.departamentos = async (v) => {
    const rows = await api('/departments');
    v.innerHTML = card('Departamentos', 'Áreas e níveis de atuação da empresa', can('manager') ? `App.editDept()` : null,
      `<table><thead><tr><th>Nº</th><th>Departamento</th><th>Atuação</th>${can('manager') ? '<th></th>' : ''}</tr></thead><tbody>
      ${rows.map(d => `<tr><td>${esc(d.num)}</td><td><b>${esc(d.name)}</b></td><td>${esc(d.atuacao)}</td>
        ${can('manager') ? `<td>${actionsCol(`App.editDept(${JSON.stringify(d).replace(/"/g, '&quot;')})`, `App.delDept(${d.id})`, 'manager')}</td>` : ''}</tr>`).join('')}
      </tbody></table>`);
  };
  App_editDept = (d = {}) => modal(d.id ? 'Editar departamento' : 'Novo departamento', form([
    f.text('dp-num', 'Número', d.num), f.text('dp-name', 'Nome', d.name), f.text('dp-at', 'Atuação', d.atuacao),
    `<button class="btn btn-primary btn-block" onclick="App.saveDept(${d.id || 0})">Salvar</button>`]));
  App_saveDept = async (id) => {
    await api('/departments' + (id ? '/' + id : ''), { method: id ? 'PUT' : 'POST',
      body: JSON.stringify({ num: val('dp-num'), name: val('dp-name'), atuacao: val('dp-at') }) });
    closeModal(); toast('Salvo'); go('departamentos');
  };
  App_delDept = async (id) => { if (await del('/departments/' + id)) go('departamentos'); };

  // SWOT / GUT
  VIEWS.swot = async (v) => {
    const [rows, depts] = await Promise.all([api('/swot'), api('/departments')]);
    window.__depts = depts;
    const group = (cls) => rows.filter(r => r.classification === cls);
    const tbl = (cls) => `<div class="card swot-${cls}"><div class="section-head"><h3>${cls}s</h3></div>
      <table><thead><tr><th>Item</th><th>G</th><th>U</th><th>T</th><th>GUT</th>${can('contributor') ? '<th></th>' : ''}</tr></thead><tbody>
      ${group(cls).length ? group(cls).map(r => `<tr><td>${esc(r.item)}</td><td>${r.gravidade}</td><td>${r.urgencia}</td><td>${r.tendencia}</td>
        <td class="gut-num">${r.gut}</td>${can('contributor') ? `<td>${actionsCol(`App.editSwot(${JSON.stringify(r).replace(/"/g, '&quot;')})`, `App.delSwot(${r.id})`)}</td>` : ''}</tr>`).join('') : `<tr><td colspan="6" class="empty">Nenhum item</td></tr>`}
      </tbody></table></div>`;
    v.innerHTML = `<div class="section-head"><h3>Análise SWOT com priorização GUT (Gravidade × Urgência × Tendência)</h3>
      ${can('contributor') ? `<button class="btn btn-accent" onclick="App.editSwot()">+ Novo item</button>` : ''}</div>
      <div class="grid-2">${tbl('Força')}${tbl('Fraqueza')}${tbl('Oportunidade')}${tbl('Ameaça')}</div>`;
  };
  App_editSwot = (s = {}) => {
    const scale = [1, 2, 3, 4, 5].map(n => ({ v: n, t: n }));
    const deptOpts = [{ v: '', t: '—' }].concat((window.__depts || []).map(d => ({ v: d.id, t: d.name })));
    modal(s.id ? 'Editar item SWOT' : 'Novo item SWOT', form([
      f.sel('sw-c', 'Classificação', ['Força', 'Fraqueza', 'Oportunidade', 'Ameaça'].map(x => ({ v: x, t: x })), s.classification),
      f.text('sw-item', 'Item', s.item),
      f.sel('sw-dep', 'Departamento', deptOpts, s.department_id),
      `<div class="field-row-3">${f.sel('sw-g', 'Gravidade', scale, s.gravidade || 1)}${f.sel('sw-u', 'Urgência', scale, s.urgencia || 1)}${f.sel('sw-t', 'Tendência', scale, s.tendencia || 1)}</div>`,
      f.area('sw-ins', 'Insights', s.insights),
      `<button class="btn btn-primary btn-block" onclick="App.saveSwot(${s.id || 0})">Salvar</button>`]));
  };
  App_saveSwot = async (id) => {
    await api('/swot' + (id ? '/' + id : ''), { method: id ? 'PUT' : 'POST', body: JSON.stringify({
      classification: val('sw-c'), item: val('sw-item'), department_id: +val('sw-dep') || null,
      gravidade: +val('sw-g'), urgencia: +val('sw-u'), tendencia: +val('sw-t'), insights: val('sw-ins') }) });
    closeModal(); toast('Salvo'); go('swot');
  };
  App_delSwot = async (id) => { if (await del('/swot/' + id)) go('swot'); };

  // Curva de Valor
  VIEWS.curva = async (v) => {
    const rows = await api('/value-curve');
    v.innerHTML = `<div class="card"><div class="section-head"><h3>Curva de Valor</h3>
      ${can('manager') ? `<button class="btn btn-accent btn-sm" onclick="App.editCurve()">+ Atributo</button>` : ''}</div>
      <p class="desc">Comparação DAEXE × concorrência (0 a 10)</p><canvas id="ch-curve" height="120"></canvas></div>
      <div class="card"><table><thead><tr><th>Atributo</th><th>DAEXE</th><th>Concorrência</th>${can('manager') ? '<th></th>' : ''}</tr></thead><tbody>
      ${rows.map(r => `<tr><td>${esc(r.attribute)}</td><td><b>${r.daexe_score}</b></td><td>${r.competitor_score}</td>
        ${can('manager') ? `<td>${actionsCol(`App.editCurve(${JSON.stringify(r).replace(/"/g, '&quot;')})`, `App.delCurve(${r.id})`, 'manager')}</td>` : ''}</tr>`).join('')}</tbody></table></div>`;
    mkChart('ch-curve', 'line', { labels: rows.map(r => r.attribute), datasets: [
      { label: 'DAEXE', data: rows.map(r => r.daexe_score), borderColor: '#2E8BC0', backgroundColor: 'rgba(46,139,192,.1)', tension: .3, fill: true },
      { label: 'Concorrência', data: rows.map(r => r.competitor_score), borderColor: '#E6A817', tension: .3 }] },
      { scales: { y: { min: 0, max: 10 } } });
  };
  App_editCurve = (r = {}) => modal(r.id ? 'Editar atributo' : 'Novo atributo', form([
    f.text('cv-at', 'Atributo', r.attribute),
    `<div class="field-row">${f.num('cv-d', 'DAEXE (0-10)', r.daexe_score)}${f.num('cv-c', 'Concorrência (0-10)', r.competitor_score)}</div>`,
    `<button class="btn btn-primary btn-block" onclick="App.saveCurve(${r.id || 0})">Salvar</button>`]));
  App_saveCurve = async (id) => {
    await api('/value-curve' + (id ? '/' + id : ''), { method: id ? 'PUT' : 'POST',
      body: JSON.stringify({ attribute: val('cv-at'), daexe_score: +val('cv-d'), competitor_score: +val('cv-c') }) });
    closeModal(); toast('Salvo'); go('curva');
  };
  App_delCurve = async (id) => { if (await del('/value-curve/' + id)) go('curva'); };

  // Mapa BSC
  VIEWS.bsc = async (v) => {
    const { perspectives, objectives, goals } = await api('/bsc');
    window.__bsc = { perspectives, objectives };
    v.innerHTML = `<div class="section-head"><h3>Mapa Estratégico (Balanced Scorecard)</h3>
      ${can('manager') ? `<button class="btn btn-accent" onclick="App.editObj()">+ Objetivo</button>` : ''}</div>
      ${perspectives.map(p => {
        const objs = objectives.filter(o => o.perspective_id === p.id);
        return `<div class="bsc-row"><div class="bsc-persp">${esc(p.name)}</div><div class="bsc-objs">
          ${objs.length ? objs.map(o => `<div class="bsc-obj"><b>${esc(o.code ? o.code + '. ' : '')}${esc(o.title)}</b>
            <ul>${goals.filter(g => g.objective_id === o.id).map(g => `<li>${esc(g.smart_text)}</li>`).join('')}</ul></div>`).join('') : '<span class="empty">—</span>'}
        </div></div>`;
      }).join('')}`;
  };
  App_editObj = (o = {}) => {
    const ps = (window.__bsc.perspectives || []).map(p => ({ v: p.id, t: p.name }));
    modal(o.id ? 'Editar objetivo' : 'Novo objetivo', form([
      f.text('ob-code', 'Código', o.code), f.text('ob-title', 'Objetivo estratégico', o.title),
      f.sel('ob-persp', 'Perspectiva BSC', ps, o.perspective_id),
      `<button class="btn btn-primary btn-block" onclick="App.saveObj(${o.id || 0})">Salvar</button>`]));
  };
  App_saveObj = async (id) => {
    await api('/objectives' + (id ? '/' + id : ''), { method: id ? 'PUT' : 'POST',
      body: JSON.stringify({ code: val('ob-code'), title: val('ob-title'), perspective_id: +val('ob-persp') }) });
    closeModal(); toast('Salvo'); go('bsc');
  };

  // OKR - Objetivos & Metas
  VIEWS.okr = async (v) => {
    const { objectives, goals, perspectives } = await api('/bsc');
    window.__bsc = { perspectives, objectives };
    v.innerHTML = `<div class="section-head"><h3>Detalhamento OKR / BSC</h3>
      ${can('manager') ? `<button class="btn btn-accent" onclick="App.editGoal()">+ Meta SMART</button>` : ''}</div>
      ${objectives.map(o => `<div class="card"><div class="section-head"><h3>${esc(o.code ? o.code + '. ' : '')}${esc(o.title)}</h3>
        ${can('manager') ? `<button class="btn btn-light btn-sm" onclick='App.editObj(${JSON.stringify(o)})'>Editar objetivo</button>` : ''}</div>
        <table><thead><tr><th>Meta SMART</th><th>Período</th>${can('manager') ? '<th></th>' : ''}</tr></thead><tbody>
        ${goals.filter(g => g.objective_id === o.id).map(g => `<tr><td>${esc(g.smart_text)}</td><td>${esc(g.period)}</td>
          ${can('manager') ? `<td>${actionsCol(`App.editGoal(${JSON.stringify(g).replace(/"/g, '&quot;')})`, `App.delGoal(${g.id})`, 'manager')}</td>` : ''}</tr>`).join('') || '<tr><td colspan="3" class="empty">Sem metas</td></tr>'}
        </tbody></table></div>`).join('')}`;
  };
  App_editGoal = (g = {}) => {
    const objs = (window.__bsc.objectives || []).map(o => ({ v: o.id, t: (o.code ? o.code + '. ' : '') + o.title }));
    modal(g.id ? 'Editar meta' : 'Nova meta SMART', form([
      f.sel('gl-obj', 'Objetivo', objs, g.objective_id),
      f.area('gl-smart', 'Meta SMART', g.smart_text), f.text('gl-per', 'Período', g.period),
      `<button class="btn btn-primary btn-block" onclick="App.saveGoal(${g.id || 0})">Salvar</button>`]));
  };
  App_saveGoal = async (id) => {
    await api('/goals' + (id ? '/' + id : ''), { method: id ? 'PUT' : 'POST',
      body: JSON.stringify({ objective_id: +val('gl-obj'), smart_text: val('gl-smart'), period: val('gl-per') }) });
    closeModal(); toast('Salvo'); go('okr');
  };
  App_delGoal = async (id) => { if (await del('/goals/' + id)) go('okr'); };

  // Iniciativas 5W2H
  VIEWS.iniciativas = async (v) => {
    const [rows, bsc] = await Promise.all([api('/initiatives'), api('/bsc')]);
    window.__bsc = bsc;
    v.innerHTML = `<div class="section-head"><h3>Plano de Ação — Iniciativas (5W2H)</h3>
      ${can('contributor') ? `<button class="btn btn-accent" onclick="App.editIni()">+ Nova iniciativa</button>` : ''}</div>
      <div class="card"><table><thead><tr><th>Cód</th><th>Quê / Iniciativa</th><th>Quem</th><th>Quando</th><th>Status</th><th>Progresso</th>${can('contributor') ? '<th></th>' : ''}</tr></thead><tbody>
      ${rows.map(i => `<tr><td>${esc(i.code)}</td>
        <td><b>${esc(i.name)}</b>${i.objective_title ? `<br><span style="color:var(--muted);font-size:11.5px">↳ ${esc(i.objective_title)}</span>` : ''}</td>
        <td>${esc(i.who)}</td><td style="font-size:12px">${esc((i.date_start || '').slice(0, 10))}<br>${esc((i.date_end || '').slice(0, 10))}</td>
        <td>${statusPill(i.status)}</td><td>${bar(i.progress)} <small>${i.progress}%</small></td>
        ${can('contributor') ? `<td>${actionsCol(`App.editIni(${JSON.stringify(i).replace(/"/g, '&quot;')})`, `App.delIni(${i.id})`)}</td>` : ''}</tr>`).join('')}
      </tbody></table></div>`;
  };
  App_editIni = (i = {}) => {
    const objs = [{ v: '', t: '—' }].concat((window.__bsc.objectives || []).map(o => ({ v: o.id, t: (o.code ? o.code + '. ' : '') + o.title })));
    const st = ['Não iniciado', 'Em andamento', 'Concluído', 'Atrasado'].map(x => ({ v: x, t: x }));
    modal(i.id ? 'Editar iniciativa' : 'Nova iniciativa', form([
      `<div class="field-row">${f.text('in-code', 'Código', i.code)}${f.sel('in-obj', 'Objetivo vinculado', objs, i.objective_id)}</div>`,
      f.text('in-name', 'QUÊ — Iniciativa/Projeto', i.name),
      `<div class="field-row">${f.text('in-who', 'QUEM — Responsável', i.who)}${f.text('in-where', 'ONDE', i.where_)}</div>`,
      `<div class="field-row">${f.date('in-ds', 'QUANDO — Início', i.date_start)}${f.date('in-de', 'QUANDO — Fim', i.date_end)}</div>`,
      f.area('in-how', 'COMO', i.how), f.text('in-much', 'QUANTO (custo/recurso)', i.how_much), f.area('in-why', 'PORQUÊ', i.why),
      `<div class="field-row">${f.sel('in-st', 'Status', st, i.status)}${f.num('in-prog', 'Progresso %', i.progress, 'min=0 max=100')}</div>`,
      `<button class="btn btn-primary btn-block" onclick="App.saveIni(${i.id || 0})">Salvar</button>`]));
  };
  App_saveIni = async (id) => {
    await api('/initiatives' + (id ? '/' + id : ''), { method: id ? 'PUT' : 'POST', body: JSON.stringify({
      code: val('in-code'), objective_id: +val('in-obj') || null, name: val('in-name'), who: val('in-who'),
      where_: val('in-where'), date_start: val('in-ds'), date_end: val('in-de'), how: val('in-how'),
      how_much: val('in-much'), why: val('in-why'), status: val('in-st'), progress: +val('in-prog') }) });
    closeModal(); toast('Salvo'); go('iniciativas');
  };
  App_delIni = async (id) => { if (await del('/initiatives/' + id)) go('iniciativas'); };

  // Desempenho de metas
  VIEWS.desempenho = async (v) => {
    const [rows, bsc] = await Promise.all([api('/performance'), api('/bsc')]);
    window.__goals = bsc.goals;
    v.innerHTML = `<div class="section-head"><h3>Desempenho de Metas</h3>
      ${can('contributor') ? `<button class="btn btn-accent" onclick="App.editPerf()">+ Registrar resultado</button>` : ''}</div>
      <div class="card"><table><thead><tr><th>Meta</th><th>Período</th><th>Tipo</th><th>Alvo</th><th>Realizado</th><th>% Atingido</th>${can('contributor') ? '<th></th>' : ''}</tr></thead><tbody>
      ${rows.map(r => { const p = pct(r.actual_value, r.target_value); return `<tr><td>${esc(r.smart_text)}</td><td>${esc(r.period_label)}</td>
        <td><span class="pill pill-gray">${esc(r.period_type)}</span></td><td>${r.target_value.toLocaleString('pt-BR')}</td>
        <td><b>${r.actual_value.toLocaleString('pt-BR')}</b></td><td>${bar(p)} <small>${p}%</small></td>
        ${can('contributor') ? `<td>${actionsCol(`App.editPerf(${JSON.stringify(r).replace(/"/g, '&quot;')})`, `App.delPerf(${r.id})`)}</td>` : ''}</tr>`; }).join('') || '<tr><td colspan="7" class="empty">Sem registros</td></tr>'}
      </tbody></table></div>`;
  };
  App_editPerf = (r = {}) => {
    const goals = (window.__goals || []).map(g => ({ v: g.id, t: g.smart_text.slice(0, 50) }));
    const types = ['semanal', 'mensal', 'trimestral'].map(x => ({ v: x, t: x }));
    modal(r.id ? 'Editar resultado' : 'Registrar resultado', form([
      f.sel('pf-goal', 'Meta', goals, r.goal_id),
      `<div class="field-row">${f.sel('pf-type', 'Tipo', types, r.period_type || 'mensal')}${f.text('pf-label', 'Período (ex: Jan, S1, T1)', r.period_label)}</div>`,
      `<div class="field-row">${f.num('pf-target', 'Alvo', r.target_value)}${f.num('pf-actual', 'Realizado', r.actual_value)}</div>`,
      `<button class="btn btn-primary btn-block" onclick="App.savePerf(${r.id || 0})">Salvar</button>`]));
  };
  App_savePerf = async (id) => {
    await api('/performance' + (id ? '/' + id : ''), { method: id ? 'PUT' : 'POST', body: JSON.stringify({
      goal_id: +val('pf-goal'), period_type: val('pf-type'), period_label: val('pf-label'),
      target_value: +val('pf-target'), actual_value: +val('pf-actual') }) });
    closeModal(); toast('Salvo'); go('desempenho');
  };
  App_delPerf = async (id) => { if (await del('/performance/' + id)) go('desempenho'); };

  // Avaliação
  VIEWS.avaliacao = async (v) => {
    const rows = await api('/evaluations');
    const users = {};
    rows.forEach(r => { (users[r.user_name] = users[r.user_name] || []).push(r); });
    v.innerHTML = `<div class="section-head"><h3>Avaliação de Desempenho</h3>
      ${can('contributor') ? `<button class="btn btn-accent" onclick="App.editEval()">+ Registrar</button>` : ''}</div>
      ${Object.keys(users).length ? Object.entries(users).map(([name, evs]) => `<div class="card"><h3>${esc(name)}</h3>
        <table><thead><tr><th>Competência</th><th>Mês</th><th>Auto avaliação</th><th>Avaliação do gestor</th>${can('contributor') ? '<th></th>' : ''}</tr></thead><tbody>
        ${evs.map(e => `<tr><td>${esc(e.competency)}</td><td>${esc(e.month)}</td><td>${e.self_score}</td><td>${e.manager_score}</td>
          ${can('contributor') ? `<td>${actionsCol(`App.editEval(${JSON.stringify(e).replace(/"/g, '&quot;')})`, null)}</td>` : ''}</tr>`).join('')}
        </tbody></table></div>`).join('') : '<div class="empty">Nenhuma avaliação registrada</div>'}`;
  };
  App_editEval = (e = {}) => {
    const comps = ['Organização', 'Resultados Consistentes', 'Qualidade', 'Sagaz e Ágil', 'Inovador', 'Autodesenvolvimento', 'Comunicação'].map(x => ({ v: x, t: x }));
    const months = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'].map(x => ({ v: x, t: x }));
    modal(e.id ? 'Editar avaliação' : 'Nova avaliação', form([
      `<div class="field-row">${f.sel('ev-comp', 'Competência', comps, e.competency)}${f.sel('ev-month', 'Mês', months, e.month)}</div>`,
      `<div class="field-row">${f.num('ev-self', 'Auto avaliação (0-10)', e.self_score)}${can('manager') ? f.num('ev-mgr', 'Nota do gestor (0-10)', e.manager_score) : ''}</div>`,
      `<button class="btn btn-primary btn-block" onclick="App.saveEval(${e.id || 0})">Salvar</button>`]));
  };
  App_saveEval = async (id) => {
    const body = { competency: val('ev-comp'), month: val('ev-month'), self_score: +val('ev-self') };
    if (can('manager')) body.manager_score = +val('ev-mgr');
    await api('/evaluations' + (id ? '/' + id : ''), { method: id ? 'PUT' : 'POST', body: JSON.stringify(body) });
    closeModal(); toast('Salvo'); go('avaliacao');
  };

  // Usuários
  VIEWS.usuarios = async (v) => {
    const [users, depts] = await Promise.all([api('/users'), api('/departments')]);
    window.__depts = depts;
    v.innerHTML = `<div class="section-head"><h3>Usuários & Controle de Acesso</h3>
      ${can('admin') ? `<button class="btn btn-accent" onclick="App.editUser()">+ Novo usuário</button>` : ''}</div>
      <div class="card"><table><thead><tr><th>Nome</th><th>E-mail</th><th>Papel</th><th>Departamento</th><th>Status</th>${can('admin') ? '<th></th>' : ''}</tr></thead><tbody>
      ${users.map(u => `<tr><td><b>${esc(u.name)}</b></td><td>${esc(u.email)}</td>
        <td><span class="pill pill-blue">${ROLE_LABEL[u.role]}</span></td><td>${esc(u.dept || '—')}</td>
        <td>${u.active ? '<span class="pill pill-green">Ativo</span>' : '<span class="pill pill-gray">Inativo</span>'}</td>
        ${can('admin') ? `<td><div class="inline-actions"><button class="btn btn-light btn-sm" onclick='App.editUser(${JSON.stringify(u)})'>Editar</button>
          <button class="btn btn-light btn-sm" onclick="App.remind(${u.id},'${esc(u.name)}')">🔔</button>
          <button class="btn btn-danger btn-sm" onclick="App.delUser(${u.id})">Excluir</button></div></td>` : ''}</tr>`).join('')}
      </tbody></table></div>
      <div class="card"><h3>Papéis e permissões</h3><table><thead><tr><th>Papel</th><th>Permissões</th></tr></thead><tbody>
        <tr><td><b>Administrador</b></td><td>Gerencia usuários, acessos, toda a estrutura e configurações</td></tr>
        <tr><td><b>Gestor</b></td><td>Cria/edita objetivos, metas, departamentos, valores; acompanha indicadores; envia lembretes</td></tr>
        <tr><td><b>Colaborador</b></td><td>Insere e atualiza SWOT, iniciativas, desempenho e auto avaliação</td></tr>
        <tr><td><b>Visualizador</b></td><td>Apenas consulta painéis e relatórios</td></tr>
      </tbody></table></div>`;
  };
  App_editUser = (u = {}) => {
    const roles = [['admin', 'Administrador'], ['manager', 'Gestor'], ['contributor', 'Colaborador'], ['viewer', 'Visualizador']].map(r => ({ v: r[0], t: r[1] }));
    const depts = [{ v: '', t: '—' }].concat((window.__depts || []).map(d => ({ v: d.id, t: d.name })));
    modal(u.id ? 'Editar usuário' : 'Novo usuário', form([
      f.text('us-name', 'Nome', u.name), f.text('us-email', 'E-mail', u.email, u.id ? 'disabled' : ''),
      f.text('us-pass', u.id ? 'Nova senha (deixe vazio p/ manter)' : 'Senha', '', 'type=password'),
      `<div class="field-row">${f.sel('us-role', 'Papel', roles, u.role || 'viewer')}${f.sel('us-dep', 'Departamento', depts, u.department_id)}</div>`,
      u.id ? f.sel('us-active', 'Status', [{ v: 1, t: 'Ativo' }, { v: 0, t: 'Inativo' }], u.active) : '',
      `<button class="btn btn-primary btn-block" onclick="App.saveUser(${u.id || 0})">Salvar</button>`]));
  };
  App_saveUser = async (id) => {
    const body = { name: val('us-name'), role: val('us-role'), department_id: +val('us-dep') || null };
    if (val('us-pass')) body.password = val('us-pass');
    if (id) body.active = +val('us-active');
    else { body.email = val('us-email'); }
    await api('/users' + (id ? '/' + id : ''), { method: id ? 'PUT' : 'POST', body: JSON.stringify(body) });
    closeModal(); toast('Salvo'); go('usuarios');
  };
  App_delUser = async (id) => { if (await del('/users/' + id, 'Excluir este usuário?')) go('usuarios'); };
  App_remind = (id, name) => modal('Enviar lembrete', form([
    `<p class="desc">Notificar <b>${esc(name)}</b> sobre atualização de metas/iniciativas.</p>`,
    f.text('rm-title', 'Título', 'Atualize seus indicadores'),
    f.area('rm-body', 'Mensagem', 'Por favor, atualize o progresso das suas iniciativas e metas no sistema.'),
    `<button class="btn btn-primary btn-block" onclick="App.sendRemind(${id})">Enviar</button>`]));
  App_sendRemind = async (id) => {
    await api('/notifications/remind', { method: 'POST', body: JSON.stringify({ user_id: id, title: val('rm-title'), body: val('rm-body') }) });
    closeModal(); toast('Lembrete enviado');
  };

  // Notificações
  VIEWS.notificacoes = async (v) => {
    const rows = await api('/notifications');
    v.innerHTML = card('Notificações', 'Lembretes e alertas recebidos', null,
      rows.length ? `<table><thead><tr><th>Título</th><th>Mensagem</th><th>Data</th></tr></thead><tbody>
      ${rows.map(n => `<tr><td><b>${esc(n.title)}</b></td><td>${esc(n.body)}</td><td style="font-size:12px;color:var(--muted)">${esc(n.created_at)}</td></tr>`).join('')}</tbody></table>`
      : '<div class="empty">Nenhuma notificação</div>');
  };

  function card(title, desc, addFn, body) {
    return `<div class="card"><div class="section-head"><div><h3>${title}</h3><p class="desc">${desc || ''}</p></div>
      ${addFn ? `<button class="btn btn-accent btn-sm" onclick="${addFn}">+ Adicionar</button>` : ''}</div>${body}</div>`;
  }

  async function exportFile(type) {
    toast('Gerando arquivo…');
    const res = await api('/export/' + type);
    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a'); a.href = url;
    a.download = type === 'pdf' ? 'Planejamento_DAEXE.pdf' : 'Planejamento_DAEXE.xlsx';
    a.click(); URL.revokeObjectURL(url);
  }

  // ---------- Init / expose ----------
  function init() {
    document.getElementById('login-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      try { await login(val('login-email'), val('login-password')); }
      catch (err) { document.getElementById('login-error').textContent = err.message; }
    });
    document.getElementById('logout-btn').onclick = logout;
    document.getElementById('modal-backdrop').addEventListener('click', (e) => { if (e.target.id === 'modal-backdrop') closeModal(); });
    const t = sessionStorage.getItem('daexe_t');
    if (t) { token = t; me = JSON.parse(sessionStorage.getItem('daexe_u')); boot(); }
  }

  // Expor handlers globais usados no HTML inline
  const pub = { go, closeModal, exportFile, logout };
  ['editValue', 'saveValue', 'delValue', 'editCompany', 'saveCompany', 'editDept', 'saveDept', 'delDept',
    'editSwot', 'saveSwot', 'delSwot', 'editCurve', 'saveCurve', 'delCurve', 'editObj', 'saveObj',
    'editGoal', 'saveGoal', 'delGoal', 'editIni', 'saveIni', 'delIni', 'editPerf', 'savePerf', 'delPerf',
    'editEval', 'saveEval', 'editUser', 'saveUser', 'delUser', 'remind', 'sendRemind']
    .forEach(name => { pub[name] = (...a) => eval('App_' + name)(...a); });

  return Object.assign(pub, { init });
})();
// Bind dos handlers nomeados (declarados como globais acima via App_*)
window.addEventListener('DOMContentLoaded', App.init);
