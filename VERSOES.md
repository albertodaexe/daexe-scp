# Histórico de versões — Sistema de Planejamento Estratégico DAEXE

## Como funciona
A cada mudança relevante, o Claude salva uma **cópia datada** do app na pasta `versoes/`.
Para voltar a um ponto anterior, basta usar a cópia desejada (o Claude faz isso a pedido).

## Arquivos principais (raiz da pasta)
- **DAEXE - Planejamento Estrategico (online).html** — APP LIVE (multiusuário, conectado ao Supabase). É este que a equipe usa.
- **DAEXE - Planejamento Estrategico.html** — versão offline (arquivo único, dados no navegador).
- **daexe-scp/** — versão antiga em Node/Express (não usada na nuvem; mantida só por histórico).

## Pasta versoes/
Cópias com data/hora, ex.: online_2026-06-02_1201_v1.html — cada uma é um ponto de recuperação completo.

## Backend (Supabase)
- Projeto: daexe-scp · ref qgkelrlftxqpoyspxmsf · região São Paulo · https://qgkelrlftxqpoyspxmsf.supabase.co
- Mudanças de ESTRUTURA do banco ficam registradas como "migrações" nomeadas no Supabase.
- IMPORTANTE: o plano gratuito do Supabase NÃO faz backup automático dos dados. Para backup, exporte o Excel
  periodicamente (menu "Relatórios e Gestão") ou ative um plano pago (backup diário + recuperação ponto-a-ponto).

## Linha do tempo
- 2026-06-02 — v1: app online (Supabase): login com mostrar/ocultar senha, Meu Perfil com foto,
  exportação só admin, Desempenho Semanal por popup (meta/resultado/causa/ação) com metas atribuídas e
  visão por trimestre, Metas por Ano+Trimestre e responsáveis por meta.
- 2026-09-24 — v25: (1) "Esqueci minha senha" corrigido — o e-mail agora volta para o sistema on-line e abre a tela
  "Nova senha" (exige Site URL/Redirect URL do Supabase apontando para https://sisplanoestrategico.organiza.workers.dev);
  (2) nova página "Como usar (Tutorial)" + botão "❔ Ajuda" no topo de todas as telas;
  (3) Relatórios e Gestão → "Relatório trimestral de metas": gera Word (papel timbrado) e PowerPoint (Modelo Daexe)
  no padrão aprovado do T3 2026, com revisão editável e rascunho salvo (tabela goal_reports). Modelos em public/modelos/.
- 2026-09-24 — v26: "Macroprocessos" viram SETORES. Cada setor tem Responsáveis e Funcionários (usuários do sistema,
  link "pessoas" em Departamentos; tabela sector_people). Organograma mostra setores com responsáveis e equipe.
  Metas podem ser ligadas a vários departamentos e setores (botão "Deptos/Setores"; tabela goal_sectors).
  Painel de Metas ganhou filtro por Setor. SWOT por setor (coluna swot_items.sector_id); a visão do departamento
  é consolidada (itens do departamento + de todos os seus setores).
- 2026-09-30 — v27: Objetivos & Metas ganhou filtros (busca por texto, ano, trimestre, perspectiva, departamento,
  setor e responsável), com contador de resultados e botão "Limpar filtros". Os filtros ficam guardados ao editar metas.
- 2026-09-30 — v28: uma meta pode valer para mais de um trimestre do mesmo ano (checkboxes T1–T4 no cadastro;
  coluna goals.quarters). Período exibido como "T3–T4 2026"; filtro de trimestre e relatório trimestral consideram
  todos os trimestres da meta (no relatório, o resultado é só das semanas do trimestre escolhido).
- 2026-10-01 — v29: novo módulo ORÇAMENTO (menu "Orçamento"), baseado na planilha Orcamento_DAEXE_Modelo.xlsx.
  Página "Orçamento": uma página com as 3 etapas — 1. Planejamento (departamento lança orçado T1–T4 por categoria),
  2. Acompanhamento (Financeiro lança o realizado; saldo e % automáticos), 3. Revisão trimestral (nova previsão + justificativa).
  Página "Visão Geral do Orçamento": indicadores anuais, tabela departamento × trimestre, gráficos, totais por categoria e Excel.
  Tabelas novas: budget_categories (8 categorias padrão por empresa), budget_lines; organizations.budget_finance_dept_id.
- 2026-10-01 — v30: nova RAS. "Desempenho de Iniciativas" passa a "Desempenho de Iniciativas/Metas", com botão
  "Preenchimento para RAS": assistente em cards — 1) cada ação em aberto do usuário (status, impeditivo, próxima semana);
  2) "Você concluiu alguma meta do trimestre?"; 3) cada meta do trimestre (houve evolução? resultado + causa).
  Salva a cada card. Colunas novas: action_weekly.impeditivo/proximo_passo, goal_weekly.evolucao. O botão de RAS da página
  Preenchimento de Metas abre o mesmo assistente.
- 2026-10-01 — v31: popups só fecham no X (clicar fora não fecha mais). Botão "🖥️ Apresentação da semana" em
  Desempenho de Iniciativas/Metas: tela cheia com indicadores da semana, linha do tempo semanal (bolinhas por semana do
  trimestre) de cada ação por iniciativa com status/impeditivo/próximos passos, e de cada meta (evoluiu / sem evolução /
  não informado) com resultado, causa e % acumulado no trimestre. Navegação ◂ ▸ entre semanas e Minhas/Todas.
- 2026-10-05 — v32: RAS — ação Em andamento ou Atrasada exige impeditivo/motivo do atraso e o que será feito na
  próxima semana; o prazo da ação define o atraso (vencida e não concluída = Atrasada; só permite Atrasado/Concluído).
  Campo "Responsável pelo impeditivo" (usuário, que recebe notificação, ou nome externo). Iniciativas ganharam início e
  prazo de conclusão e vínculo OBRIGATÓRIO com pelo menos uma meta (tabela initiative_goals). Prazos vencidos em vermelho.
- 2026-10-07 — v33: Mapa BSC com filtros de Ano, Trimestre e Departamento (e % de atingimento de cada meta no período).
  Nova página "Plano Estratégico (consolidado)": identidade, estrutura, SWOT, mapa BSC com metas e status, iniciativas
  e orçamento num documento único, com filtro de ano/trimestre e botão Imprimir/PDF.
