-- =====================================================================
-- GPP · Gestão do Desempenho (v45) — parte A: tabelas, visões, biblioteca
-- =====================================================================

create table if not exists gpp.des_competencias (
  id serial primary key,
  nome text not null unique,
  tipo text not null default 'comportamental' check (tipo in ('comportamental', 'estrategica', 'tecnica')),
  valor text,
  descricao text,
  comportamentos text[] not null default '{}',
  so_lideres boolean not null default false,
  ordem int not null default 0,
  ativo boolean not null default true
);

-- Matriz aplicada em cada trimestre (cópia congelada do texto do comportamento)
create table if not exists gpp.des_itens (
  id serial primary key,
  trimestre text not null check (trimestre ~ '^[1-4]T/[0-9]{2}$'),
  ordem int not null,
  competencia_id int not null references gpp.des_competencias(id),
  texto text not null check (length(trim(texto)) > 0),
  so_lideres boolean not null default false
);
create index if not exists des_itens_tri on gpp.des_itens (trimestre, ordem);

create table if not exists gpp.des_avaliacoes (
  id uuid primary key default gen_random_uuid(),
  trimestre text not null check (trimestre ~ '^[1-4]T/[0-9]{2}$'),
  ciclo_id uuid references gpp.ciclos(id) on delete cascade,
  avaliado_id uuid not null references gpp.organizadores(id),
  avaliador_id uuid references gpp.organizadores(id),
  tipo text not null check (tipo in ('auto', 'gestor')),
  e_lider boolean not null default false,
  area text,
  respondida_em timestamptz,
  prioridades int[] not null default '{}',
  comentario text,
  origem text not null default 'sistema' check (origem in ('sistema', 'importado', 'manual')),
  unique (trimestre, avaliado_id, tipo)
);
create index if not exists des_avaliacoes_ciclo on gpp.des_avaliacoes (ciclo_id);

create table if not exists gpp.des_notas (
  avaliacao_id uuid not null references gpp.des_avaliacoes(id) on delete cascade,
  item_id int not null references gpp.des_itens(id) on delete cascade,
  nota smallint not null check (nota between 1 and 4),
  primary key (avaliacao_id, item_id)
);

-- Um link por pessoa por ciclo: serve para a autoavaliação e para avaliar os liderados
create table if not exists gpp.des_links (
  id uuid primary key default gen_random_uuid(),
  ciclo_id uuid not null references gpp.ciclos(id) on delete cascade,
  organizador_id uuid not null references gpp.organizadores(id),
  token text not null unique default encode(extensions.gen_random_bytes(24), 'hex'),
  unique (ciclo_id, organizador_id)
);

-- NPS de Liderança: sem ligação com quem respondeu, sem horário
create table if not exists gpp.des_nps (
  id uuid primary key default gen_random_uuid(),
  trimestre text not null check (trimestre ~ '^[1-4]T/[0-9]{2}$'),
  ciclo_id uuid references gpp.ciclos(id) on delete cascade,
  gestor_id uuid references gpp.organizadores(id),
  nota smallint not null check (nota between 0 and 10),
  origem text not null default 'sistema'
);
create index if not exists des_nps_tri on gpp.des_nps (trimestre, gestor_id);

create table if not exists gpp.des_pdi (
  id uuid primary key default gen_random_uuid(),
  trimestre text not null check (trimestre ~ '^[1-4]T/[0-9]{2}$'),
  organizador_id uuid not null references gpp.organizadores(id),
  competencia_id int references gpp.des_competencias(id),
  acao text,
  responsavel text,
  prazo date,
  status text not null default 'a definir' check (status in ('a definir', 'planejada', 'em andamento', 'concluida', 'cancelada')),
  origem text not null default 'manual' check (origem in ('gestor', 'manual')),
  observacao text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index if not exists des_pdi_org on gpp.des_pdi (organizador_id, trimestre);

alter table gpp.des_competencias enable row level security;
alter table gpp.des_itens enable row level security;
alter table gpp.des_avaliacoes enable row level security;
alter table gpp.des_notas enable row level security;
alter table gpp.des_links enable row level security;
alter table gpp.des_nps enable row level security;
alter table gpp.des_pdi enable row level security;

-- ---------------- Visões de apuração (mesma lógica das planilhas) ----------------
-- Média por competência em cada avaliação. Competências "só líderes" contam apenas para líderes.
create or replace view gpp.v_des_comp as
select a.id as avaliacao_id, a.trimestre, a.avaliado_id, a.tipo, a.e_lider, i.competencia_id,
       avg(n.nota)::numeric as media, count(*)::int as itens
from gpp.des_avaliacoes a
join gpp.des_notas n on n.avaliacao_id = a.id
join gpp.des_itens i on i.id = n.item_id
where a.respondida_em is not null and (not i.so_lideres or a.e_lider)
group by a.id, a.trimestre, a.avaliado_id, a.tipo, a.e_lider, i.competencia_id;

-- Por pessoa: Nota Geral = média das competências; Índice % = nota ÷ 3 × 100; Gap = auto − gestor
create or replace view gpp.v_des_pessoa as
select trimestre, avaliado_id, bool_or(e_lider) as e_lider,
       avg(media) filter (where tipo = 'auto') as nota_auto,
       avg(media) filter (where tipo = 'gestor') as nota_gestor,
       avg(media) filter (where tipo = 'auto') / 3 * 100 as indice_auto,
       avg(media) filter (where tipo = 'gestor') / 3 * 100 as indice_gestor,
       avg(media) filter (where tipo = 'auto') - avg(media) filter (where tipo = 'gestor') as gap
from gpp.v_des_comp
group by trimestre, avaliado_id;

-- Por competência (avaliação do gestor): Maturidade = (média − 1) ÷ 2 × 100
create or replace view gpp.v_des_org_comp as
select trimestre, competencia_id, count(*)::int as n, avg(media) as media,
       (avg(media) - 1) / 2 * 100 as maturidade,
       100.0 * count(*) filter (where media >= 3) / count(*) as pct_3,
       100.0 * count(*) filter (where media = 4) / count(*) as pct_4
from gpp.v_des_comp
where tipo = 'gestor'
group by trimestre, competencia_id;

create or replace view gpp.v_des_org as
select trimestre, avg(maturidade) as maturidade, count(*)::int as competencias
from gpp.v_des_org_comp
group by trimestre;

-- NPS de Liderança: geral do trimestre (gestor_id nulo) e por gestor
create or replace view gpp.v_des_nps as
select trimestre, gestor_id, count(*)::int as n,
       count(*) filter (where nota >= 9)::int as promotores,
       count(*) filter (where nota between 7 and 8)::int as neutros,
       count(*) filter (where nota <= 6)::int as detratores,
       round(100.0 * (count(*) filter (where nota >= 9) - count(*) filter (where nota <= 6)) / count(*), 1) as nps,
       grouping(gestor_id) = 1 as geral
from gpp.des_nps
group by grouping sets ((trimestre), (trimestre, gestor_id));

revoke all on gpp.v_des_comp, gpp.v_des_pessoa, gpp.v_des_org_comp, gpp.v_des_org, gpp.v_des_nps from anon, authenticated;

-- ---------------- Configurações do Desempenho ----------------
insert into gpp.config (chave, valor, descricao) values
  ('des_abertura_automatica', 'sim', 'sim = a Avaliação de Desempenho abre sozinha no último dia útil de mar/jun/set/dez'),
  ('des_dias_resposta', '10', 'Desempenho: prazo em dias corridos a partir da abertura'),
  ('des_lembrete_dias', '5', 'Desempenho: dias após a abertura para lembrar quem tem avaliação pendente')
on conflict (chave) do nothing;

-- ---------------- Biblioteca: Mapa de competências DAEXE V0_2026 ----------------
insert into gpp.des_competencias (nome, tipo, valor, descricao, comportamentos, so_lideres, ordem) values
 ('Aprendizado Contínuo', 'comportamental', 'Autodesenvolvimento',
  'Busca constante por evolução pessoal e profissional, desenvolvendo habilidades, métodos e soluções que gerem melhoria contínua.',
  array['Busco aprender novas ferramentas e métodos', 'Solicito feedback e aplico melhorias', 'Compartilho aprendizados com a equipe'], false, 10),
 ('Integridade', 'comportamental', 'Confiança',
  'Age com honestidade, coerência e respeito nas relações profissionais, construindo relações baseadas em credibilidade.',
  array['Comunico informações de forma clara e verdadeira', 'Assumo erros com transparência', 'Cumpro acordos estabelecidos'], false, 20),
 ('Orientação para Pessoas e Cliente', 'comportamental', 'Engajar e Encantar',
  'Constrói relações positivas e busca gerar experiências que fortaleçam o engajamento das pessoas e a satisfação dos clientes.',
  array['Demonstro empatia nas relações com colegas e clientes', 'Busco entender necessidades de clientes e colegas', 'Contribuo para um ambiente positivo'], false, 30),
 ('Pensamento Prático e Solução de Problemas', 'comportamental', 'Simplicidade',
  'Resolve desafios de forma objetiva, eficiente e inteligente, priorizando soluções simples e funcionais.',
  array['Simplifico processos e rotinas', 'Foco no que gera resultado', 'Proponho melhorias práticas'], false, 40),
 ('Qualidade e Alto Desempenho', 'comportamental', 'Excelência',
  'Busca continuamente padrões elevados de qualidade e entrega resultados com alto nível de cuidado e profissionalismo.',
  array['Entrego trabalhos bem executados', 'Demonstro atenção aos detalhes', 'Assumo responsabilidade pelo resultado final'], false, 50),
 ('Gestão de Prioridades e Cumprimento de Prazos', 'comportamental', 'Tempestividade',
  'Organiza atividades de forma eficiente, antecipando necessidades e garantindo entregas dentro dos prazos acordados.',
  array['Planejo tarefas com antecedência', 'Comunico riscos de atraso rapidamente', 'Cumpro prazos acordados'], false, 60),
 ('Autonomia e Accountability', 'comportamental', 'Liberdade com Responsabilidade',
  'Age com iniciativa e autonomia, tomando decisões responsáveis e baseadas em dados, assumindo os resultados das próprias ações.',
  array['Tomo iniciativa para resolver problemas', 'Assumo responsabilidade pelas decisões', 'Uso dados para apoiar decisões'], false, 70),
 ('Orientação para Resultados', 'comportamental', 'Resultados Consistentes',
  'Mobiliza recursos, processos e pessoas para gerar resultados consistentes e garantir o sucesso do cliente.',
  array['Monitoro resultados continuamente', 'Ajusto estratégias quando necessário', 'Mantenho consistência nas entregas'], false, 80),
 ('Pensamento Estratégico', 'estrategica', 'Missão, Visão e Propósito',
  'Capacidade de compreender o negócio do cliente de forma sistêmica, identificando oportunidades, riscos e caminhos para alcançar resultados sustentáveis.',
  array['Analiso cenários e identifico causas estruturais dos problemas', 'Conecto ações do dia a dia com objetivos estratégicos', 'Proponho soluções alinhadas ao crescimento do negócio'], true, 110),
 ('Geração de Valor para o Cliente', 'estrategica', 'Missão, Visão e Propósito',
  'Atua com foco em gerar impacto real no negócio do cliente, traduzindo conhecimento em resultados práticos e mensuráveis.',
  array['Entendo profundamente os objetivos do negócio do cliente', 'Proponho soluções com impacto no desempenho do negócio', 'Acompanho se as ações geram resultados concretos'], true, 120),
 ('Execução Estratégica', 'estrategica', 'Missão, Visão e Propósito',
  'Capacidade de transformar planos e estratégias em implementação consistente e resultados concretos.',
  array['Converto estratégias em planos de ação executáveis', 'Acompanho indicadores estratégicos', 'Garanto que decisões se traduzam em implementação real'], true, 130),
 ('Liderança de Equipe', 'estrategica', 'Missão, Visão e Propósito',
  'Capacidade de conduzir a equipe para alcançar resultados de forma consistente, organizando o trabalho, influenciando positivamente as pessoas e promovendo um ambiente de escuta, respeito e responsabilidade.',
  array['Sei coordenar pessoas, definir prioridades e distribuir tarefas', 'Influencio positivamente a equipe, fornecendo feedbacks construtivos e liderando pelo exemplo', 'Escuto sem criticar, julgar ou condenar'], true, 140)
on conflict (nome) do nothing;
