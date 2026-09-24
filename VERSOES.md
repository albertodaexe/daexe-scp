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
