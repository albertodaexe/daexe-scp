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
