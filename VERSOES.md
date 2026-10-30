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

## v41 — 19/10/2026
- Apresentação v2 (testes): nos blocos de departamento, ações das iniciativas passam para a esquerda e metas para a direita.

## v42 — 20/10/2026
- Apresentação v2 (testes): votação ao vivo e Ranking gamificado no final.
  - Abertura: botão "🗳️ Abrir votação (1 min)" (gestor/admin). Todos os usuários logados recebem um popup com cronômetro para votar em 1 departamento destaque e 1 organizador destaque (sem voto em si mesmo nem no próprio departamento; dá para mudar o voto até acabar o tempo).
  - Novo bloco final "🏆 Ranking" (pódio + tabela), por semana ou acumulado do trimestre:
    - Organizador: meta batida ×3, ação concluída no prazo ×3, voto recebido ×3, RAS completa até sábado às 10h ×1.
    - Departamento: meta do departamento batida ×3, ação do departamento concluída no prazo ×3, voto recebido ×3.
  - Roteiro: abertura 1', departamentos 18', diretor 7', encaminhamentos 2', ranking 2'.
- Supabase: tabelas ras_vote_sessions e ras_votes (RLS: votação só dentro do prazo); goal_weekly/action_weekly.first_filled_at (data do 1º preenchimento, usada no prazo de sábado 10h).

## v43 — 26/10/2026
- Novo módulo **Cultura & Desempenho** (Gestão para Pessoas), seção "Pessoas" do menu — visível só para **administradores da DAEXE**. Abre em nova aba a página própria `public/gpp/index.html` (endereço `/gpp/`), que usa o mesmo login do SisPlano.
  - Pesquisa de Cultura (OCAI): ciclo trimestral automático (abre no último dia útil do trimestre às 8h, lembrete no 5º dia, encerra no 10º), formulário anônimo com trava de 100 pontos (`/gpp/?t=<token>`), painel com mapa dos quadrantes, radar atual x desejado e evolução do Índice de Aderência; cenário desejado por trimestre; histórico 1T e 2T/26.
  - Cadastro de Organizadores próprio do módulo (independente de Usuários & Acessos). Gestão do Desempenho: em construção (o "Desempenho" antigo do SisPlano continua como está).
- Supabase: schema `gpp` (não exposto na API; acesso só pelas funções `gpp_*`), migrações `gpp_01` a `gpp_07`; agendamentos pg_cron `gpp-rotina-diaria` e `gpp-envio-emails`; Edge Function `gpp-email` (envio pelo organiza@ via SMTP — segredos SMTP_USER/SMTP_PASS).

## v44 — 27/10/2026
- Cultura & Desempenho (`/gpp/`): revisão geral de CRUD.
  - Ciclos: editar (trimestre, prazo, reabrir ciclo encerrado), excluir (com convites, respostas, e-mails e cenário copiado automaticamente; confirmação digitando o trimestre), ver convidados de qualquer ciclo.
  - Convites: incluir Organizadores que ficaram de fora de um ciclo aberto (convite enviado na hora), reenviar convite e remover quem ainda não respondeu.
  - Organizadores: excluir (só quem nunca foi convidado; os demais são inativados), validação de e-mail repetido e de gestor circular.
  - Cenário desejado: excluir trimestres sem ciclo/histórico; trimestres do histórico também ficam congelados.
  - Resultados históricos (planilhas): adicionar, editar e excluir.
  - Configurações: validação dos parâmetros e fila/histórico de e-mails (tentar de novo, reenviar, excluir).
  - E-mail do convite: corrigido "a a" e "perguntas" → "afirmativas".
- Supabase: email_fila.ciclo_id (+ trigger), funções gpp_admin_* novas/atualizadas (supabase/gpp_08b_exclusoes.sql precisa ser executado no SQL Editor).

## v45 — 28/10/2026
- Cultura & Desempenho (`/gpp/`): **Gestão do Desempenho** dentro do sistema (aba Desempenho).
  - Visão geral: Maturidade Organizacional, Índice de Desempenho médio, NPS de Liderança, evolução por trimestre, maturidade por competência, gaps auto × gestor e NPS por gestor (oculto abaixo do mínimo de respostas).
  - Por Organizador: índices auto e gestor, gap, comparação por competência, evolução, notas, prioridades e comentário do gestor, PDI; lançamento/edição manual de avaliações.
  - Ciclos: abertura com escolha dos participantes e validação do cadastro, link pessoal por e-mail (`/gpp/?d=<token>`) com autoavaliação + avaliação dos liderados, incluir/remover pessoas, reenviar link, lembrete, editar prazo, reabrir, encerrar, excluir.
  - Matriz de competências por trimestre (texto congelado; travada após a 1ª resposta) e biblioteca do Mapa de Competências DAEXE V0_2026.
  - PDI: prioridades indicadas pelo gestor viram itens "a definir" no encerramento; CRUD com responsável, prazo e situação.
  - Relatórios para PDF (trimestre e individual).
  - Cálculo igual às planilhas: índice = nota ÷ 3; maturidade = (média − 1) ÷ 2; competências estratégicas só para líderes; NPS anônimo.
- Automação: abertura no último dia útil do trimestre, lembrete, encerramento com apuração, PDI e e-mail de resultado; rotina diária isolada por módulo, com e-mail de aviso se algo falhar.
- Histórico 1T, 2T e 3T/26 importado das planilhas (conferido: maturidade 73,6% / 83,8% / 90,3%; NPS 3T 80).
- Supabase: `gpp_09a` a `gpp_09c` aplicados; **`supabase/gpp_09d_desempenho_exclusoes.sql` precisa ser executado no SQL Editor** (exclusões).

## v46 — 29/10/2026
- Usuários & Acessos (Daexe): nova coluna e campo "Acesso ao módulo Cultura & Desempenho" (Sim/Não) para qualquer papel. Administradores continuam com acesso sempre. O item do menu aparece para quem tem acesso.
- O próprio usuário não consegue se dar esse acesso (trigger protect_profile_fields).
- Módulo `/gpp/`: mensagens de acesso e textos atualizados (Cangolo no lugar de SisPlano).
- Supabase: profiles.gpp_acesso e gpp.e_admin() considerando o novo campo (supabase/gpp_10_acesso_por_usuario.sql, já aplicado).

## v47 — 29/10/2026
- Revisão dos filtros de período, departamento e responsável:
  - **Painel de Metas:** o filtro de trimestre agora vale em todos os modos (antes só filtrava as colunas no modo semanal e mostrava metas de outros trimestres). Mostra o período de cada meta; células fora do período ficam hachuradas e não contam no total; ⚠️ indica lançamentos fora do período da meta. Total = período da meta dentro do trimestre. Inclui metas sem objetivo. Botão "Limpar filtros". Carrega todos os lançamentos (antes havia limite de 1000 linhas).
  - **Preenchimento de Metas:** filtros de ano e trimestre na lista de metas, período da meta na lista, só as semanas do período aparecem e podem ser preenchidas; acumulado do período da meta; aviso de lançamentos fora do período.
  - **Iniciativas:** novos filtros (busca, ano, trimestre, departamento, responsável e situação: em aberto, prazo vencido, concluídas).
  - **Departamento** (Painel de Metas, Objetivos & Metas, Mapa BSC, Plano Estratégico consolidado): inclui as metas ligadas a setores do departamento.
  - **Mapa BSC / Plano consolidado:** com trimestre "Todos", o % considera só o período da meta.
  - **Painel inicial:** lista só metas do ano, com o período; Excel exporta todos os lançamentos semanais.

## v48 — 30/10/2026
- Apresentação v2 (página de testes da RAS):
  - Sem slide de abertura: começa direto pelos setores.
  - Ordem fixa na Daexe: Sucesso do Cliente e Projetos → Gestão para Pessoas → Gestão para Clientes → Administrativo e Financeiro → Licitação e Contratos. TIQ e Diretoria não entram. Os 5 setores aparecem mesmo sem metas/ações na semana. Outras empresas seguem a ordem do cadastro.
  - Tempos: 5 min por setor, Diretor 2 min, Encaminhamentos 2 min, Votação 1 min, Ranking 2 min. Relógio total = soma dos blocos (32 min).
  - Votação passou para um bloco próprio no final, antes do Ranking (com o resumo da semana).

## v49 — 30/10/2026
- Apresentação v2 (testes da RAS):
  - Diretor e Encaminhamentos viraram um só bloco (3 min). Votação 1 min e Ranking 1 min. Total da reunião: 30 min (5 setores × 5 min + 3 + 1 + 1).
  - Alertas em cada setor: 1 bip no último minuto, 2 bips aos 30 segundos e 3 bips longos no fim, com faixa de aviso na tela; no fim aparece o aviso "Tempo esgotado" com os botões "Continuar neste bloco" e "Ir para o próximo". Cada alerta toca uma vez por setor; "zerar" o relógio rearma os alertas. Botão 🔔 Som / 🔕 Sem som no topo.
