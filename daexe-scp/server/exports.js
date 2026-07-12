'use strict';
const ExcelJS = require('exceljs');
const PDFDocument = require('pdfkit');

async function exportExcel(db) {
  const wb = new ExcelJS.Workbook();
  wb.creator = 'DAEXE SCP';

  const header = (ws, cols) => {
    ws.columns = cols;
    ws.getRow(1).font = { bold: true, color: { argb: 'FFFFFFFF' } };
    ws.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1F3A5F' } };
  };

  const filo = wb.addWorksheet('Filosofia');
  const company = db.prepare('SELECT * FROM company WHERE id=1').get() || {};
  filo.addRow(['Empresa', company.name]);
  filo.addRow(['Missão', company.mission]);
  filo.addRow(['Visão', company.vision]);
  filo.addRow([]);
  filo.addRow(['Valores']);
  db.prepare('SELECT * FROM company_values ORDER BY ord').all().forEach(v => filo.addRow([v.title, v.description]));
  filo.getColumn(1).width = 30; filo.getColumn(2).width = 80;

  const sw = wb.addWorksheet('SWOT-GUT');
  header(sw, [
    { header: 'Classificação', key: 'c', width: 16 }, { header: 'Item', key: 'i', width: 50 },
    { header: 'Gravidade', key: 'g', width: 11 }, { header: 'Urgência', key: 'u', width: 11 },
    { header: 'Tendência', key: 't', width: 11 }, { header: 'GUT', key: 'gut', width: 8 }]);
  db.prepare('SELECT *, gravidade*urgencia*tendencia gut FROM swot_items ORDER BY gut DESC').all()
    .forEach(s => sw.addRow({ c: s.classification, i: s.item, g: s.gravidade, u: s.urgencia, t: s.tendencia, gut: s.gut }));

  const bsc = wb.addWorksheet('OKR-BSC');
  header(bsc, [
    { header: 'Objetivo', key: 'o', width: 45 }, { header: 'Perspectiva', key: 'p', width: 20 },
    { header: 'Meta SMART', key: 'm', width: 60 }, { header: 'Período', key: 'per', width: 12 }]);
  const goals = db.prepare(`SELECT g.*, o.title ot, p.name pn FROM goals g JOIN objectives o ON o.id=g.objective_id
    LEFT JOIN bsc_perspectives p ON p.id=o.perspective_id ORDER BY o.code`).all();
  goals.forEach(g => bsc.addRow({ o: g.ot, p: g.pn, m: g.smart_text, per: g.period }));

  const ini = wb.addWorksheet('Iniciativas-5W2H');
  header(ini, [
    { header: 'Cód', key: 'c', width: 6 }, { header: 'Quê (Iniciativa)', key: 'n', width: 40 },
    { header: 'Quem', key: 'w', width: 18 }, { header: 'Início', key: 'ds', width: 12 },
    { header: 'Fim', key: 'de', width: 12 }, { header: 'Status', key: 's', width: 16 },
    { header: 'Progresso %', key: 'p', width: 12 }]);
  db.prepare('SELECT * FROM initiatives ORDER BY code,id').all()
    .forEach(i => ini.addRow({ c: i.code, n: i.name, w: i.who, ds: i.date_start, de: i.date_end, s: i.status, p: i.progress }));

  const perf = wb.addWorksheet('Desempenho');
  header(perf, [
    { header: 'Meta', key: 'm', width: 55 }, { header: 'Período', key: 'p', width: 12 },
    { header: 'Tipo', key: 't', width: 12 }, { header: 'Alvo', key: 'al', width: 14 },
    { header: 'Realizado', key: 'r', width: 14 }, { header: '% Atingido', key: 'pct', width: 12 }]);
  db.prepare(`SELECT gp.*, g.smart_text FROM goal_performance gp JOIN goals g ON g.id=gp.goal_id ORDER BY gp.goal_id`).all()
    .forEach(p => perf.addRow({ m: p.smart_text, p: p.period_label, t: p.period_type, al: p.target_value, r: p.actual_value, pct: p.target_value ? Math.round(p.actual_value / p.target_value * 100) : 0 }));

  return await wb.xlsx.writeBuffer();
}

function exportPdf(db, stream) {
  const doc = new PDFDocument({ margin: 50, size: 'A4' });
  doc.pipe(stream);
  const C = '#1F3A5F';
  const company = db.prepare('SELECT * FROM company WHERE id=1').get() || {};

  doc.fillColor(C).fontSize(22).text('Planejamento Estratégico', { align: 'center' });
  doc.fontSize(16).fillColor('#333').text(company.name || 'DAEXE', { align: 'center' });
  doc.moveDown(0.3).fontSize(10).fillColor('#777')
    .text(`Vigência: ${company.plan_start || ''} a ${company.plan_end || ''}`, { align: 'center' });
  doc.moveDown(1.5);

  const h = (t) => { doc.moveDown(0.6).fillColor(C).fontSize(14).text(t); doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor(C).stroke(); doc.moveDown(0.4); doc.fillColor('#333').fontSize(10); };

  h('Filosofia');
  doc.font('Helvetica-Bold').text('Missão: ', { continued: true }).font('Helvetica').text(company.mission || '-');
  doc.font('Helvetica-Bold').text('Visão: ', { continued: true }).font('Helvetica').text(company.vision || '-');
  doc.moveDown(0.3).font('Helvetica-Bold').text('Valores:').font('Helvetica');
  db.prepare('SELECT * FROM company_values ORDER BY ord').all().forEach(v => doc.text(`• ${v.title}: ${v.description || ''}`));

  h('Objetivos Estratégicos e Metas (OKR/BSC)');
  const goals = db.prepare(`SELECT g.*, o.title ot, o.code oc FROM goals g JOIN objectives o ON o.id=g.objective_id ORDER BY o.code`).all();
  let lastObj = null;
  goals.forEach(g => {
    if (g.ot !== lastObj) { doc.moveDown(0.3).font('Helvetica-Bold').fillColor(C).text(`${g.oc}. ${g.ot}`).fillColor('#333').font('Helvetica'); lastObj = g.ot; }
    doc.text(`   → ${g.smart_text}`);
  });

  h('Iniciativas (5W2H)');
  db.prepare('SELECT * FROM initiatives ORDER BY code,id').all().forEach(i => {
    doc.font('Helvetica-Bold').text(`${i.code}. ${i.name} `, { continued: true }).font('Helvetica').fillColor('#777').text(`[${i.status} - ${i.progress}%]`).fillColor('#333');
    doc.fontSize(9).fillColor('#555').text(`   Quem: ${i.who || '-'} | Quando: ${i.date_start || '-'} a ${i.date_end || '-'}`).fontSize(10).fillColor('#333');
  });

  h('Prioridades SWOT (Matriz GUT)');
  db.prepare('SELECT *, gravidade*urgencia*tendencia gut FROM swot_items ORDER BY gut DESC LIMIT 10').all()
    .forEach(s => doc.text(`• [${s.classification}] ${s.item} — GUT ${s.gut}`));

  doc.moveDown(2).fontSize(8).fillColor('#999').text(`Gerado pelo Sistema de Planejamento Estratégico DAEXE em ${new Date().toLocaleDateString('pt-BR')}`, { align: 'center' });
  doc.end();
}

module.exports = { exportExcel, exportPdf };
