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
- 2026-10-07 — v34: SWOT "Geral da organização" passa a ser o consolidado de tudo (itens gerais + todos os departamentos
  e setores), com etiqueta de origem em cada item. "Copiar do trimestre anterior" na visão geral copia só os itens gerais.
  O Plano Estratégico consolidado também usa a SWOT consolidada.
- 2026-10-07 — v35: "Plano Estratégico (consolidado)" virou apresentação interativa em slides 16:9 (capa com agenda,
  visão geral, identidade, estrutura, SWOT com TODOS os itens, PESTEL, BSC e metas, desempenho das metas, iniciativas,
  orçamento), com filtros próprios em cada slide, navegação por setas/teclado/índice, tela cheia e PDF de todos os slides.

## v36 — 08/10/2026
- Ações das iniciativas: data de início prevista, data de conclusão prevista (prazo), data de início efetiva, data de fim efetiva e nível de prioridade (matriz de Eisenhower: N3 Importante e urgente · N2 Importante e não urgente · N1 Não importante e urgente · N0 Não importante e não urgente).
- Tabela de ações mostra prioridade, previsto x efetivo e dias de atraso na conclusão (+Nd).
- RAS (assistente e Atualizar): datas efetivas; ao marcar Concluído, a data de fim efetiva é obrigatória (sugerida com o fim da semana).
- Report semanal: mais de um responsável pelo impeditivo (usuários marcados + externos); cada novo usuário indicado recebe notificação.
- Supabase: initiative_actions (start_planned, start_actual, end_actual, priority 0–3); action_weekly.impeditivo_resps uuid[].

## v37 — 13/10/2026
- RAS com dois modelos, escolhidos pelo administrador no topo da página Desempenho de Iniciativas/Metas (organizations.ras_mode):
  - "Metas" (ativo na Daexe): o assistente mostra só as metas do trimestre, com 1. meta da semana, 2. resultado, 3. causa e 4. ação (causa e ação obrigatórias quando o resultado fica abaixo da meta). A página e a Apresentação da semana mostram meta, resultado, % e causa/ação; os pontos semanais são coloridos pelo % da meta.
  - "Completo": o fluxo da v30–v36 (ações das iniciativas + evolução das metas), preservado sem alterações para ser retomado.
- Cadastro de iniciativas e ações (datas, prioridade, vínculo com metas) continua igual na página Iniciativas.

## v38 — 14/10/2026
- Sistema renomeado para **Cangolo**: tela de login e de nova senha, título da aba, marca na barra lateral, boas-vindas e textos do relatório trimestral.
- Apresentação da semana: seletor 👥 para apresentar Todos, individualmente (uma pessoa), por departamento ou por setor. Metas filtradas por responsável/departamento/setor (no individual, só os lançamentos da pessoa); ações por responsável, departamento da iniciativa/pessoa ou pessoas do setor.
- Nova página **RAS com iniciativas (testes)** no menu Administração (gestor e administrador): sempre no modelo completo (ações das iniciativas + metas). O assistente nessa página atualiza só as ações; as metas aparecem para consulta e não são alteradas (para não sobrescrever a RAS oficial).

## v39 — 19/10/2026
- Correção do cálculo semanal das metas com vários responsáveis: metas com fórmula "Média" (ex.: metas em %) agora tiram a **média** dos lançamentos da semana, e não a soma (antes, 100% + 100% + 83% aparecia como 283%). Linhas em branco (meta 0 e resultado 0) e "sem evolução" da RAS não entram na média. Metas com fórmula "Soma" continuam somando. Vale para Painel, Painel de Metas, Preenchimento de Metas, BSC, Plano consolidado, relatório trimestral, exportação Excel e Apresentação da semana.
- Apresentação da semana (modelo completo / página de testes): dividida em dois blocos — 1. Iniciativas (indicadores e tabela das ações) e 2. Metas (metas com evolução, sem evolução e sem informação + tabela das metas). O resultado mostra também a meta da semana e, nas metas de média, quantos lançamentos entraram.

## v40 — 19/10/2026
- Apresentação da semana (oficial e testes): na parte das metas, cada responsável aparece num mini bloco com meta, valor atingido, % , causa e ação (e o total/média da semana quando há mais de um).
- Página de testes: novo botão "✨ Apresentação v2 (testes)" — roteiro da reunião em blocos: Abertura (indicadores gerais e cartões por departamento), um bloco por departamento (metas e ações lado a lado, modo "Só exceções"), Espaço do diretor (metas < 70%, ações atrasadas, impeditivos que dependem de alguém) e Encaminhamentos (compromissos por pessoa). Cronômetro da reunião (30 min) e tempo por bloco; navegação pelas setas do teclado.
