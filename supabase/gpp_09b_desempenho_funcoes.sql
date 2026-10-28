-- =====================================================================
-- GPP · Gestão do Desempenho (v45) — parte B: funções, automações e RPCs
-- =====================================================================

alter table gpp.des_avaliacoes add column if not exists nps_registrado boolean not null default false;
update gpp.des_avaliacoes set nps_registrado = true where origem = 'importado' and tipo = 'auto' and trimestre = '3T/26';

-- ---------------- E-mail do convite / lembrete ----------------
create or replace function gpp.html_des_convite(p_nome text, p_tri text, p_link text, p_prazo timestamptz,
                                                p_lembrete boolean, p_auto boolean, p_liderados text)
returns text language sql stable set search_path = '' as $$
select format(
 '<div style="font-family:Arial,sans-serif;max-width:560px;color:#1f2937;line-height:1.5">'
 '<p>Olá, %s!</p>'
 '<p>%s <b>Avaliação de Desempenho DAEXE (%s)</b>. Fica faltando:</p><ul>%s%s</ul>'
 '<p>Escala: <b>1</b> ainda não pratica · <b>2</b> faz sem consistência · <b>3</b> pratica consistentemente (o esperado) · <b>4</b> acima do esperado.</p>'
 '<p style="margin:28px 0"><a href="%s" style="background:#1F3A5F;color:#fff;padding:12px 22px;border-radius:6px;text-decoration:none;font-weight:bold">Abrir minha avaliação</a></p>'
 '<p>Prazo: <b>%s</b>. O link é pessoal: não encaminhe.</p>'
 '<p style="color:#6b7280;font-size:12px">GPP · Gestão para Pessoas — DAEXE</p></div>',
 gpp.esc(split_part(p_nome, ' ', 1)),
 case when p_lembrete then 'Ainda não recebemos todas as suas respostas da' else 'Está aberta a' end,
 gpp.esc(p_tri),
 case when p_auto then '<li>sua <b>autoavaliação</b> (com a Percepção da Liderança, que é anônima)</li>' else '' end,
 case when coalesce(p_liderados, '') <> '' then '<li>a avaliação de: <b>' || gpp.esc(p_liderados) || '</b></li>' else '' end,
 p_link,
 to_char(p_prazo at time zone 'America/Sao_Paulo', 'DD/MM/YYYY'))
$$;

-- Envia (ou reenvia) o link de uma pessoa, listando apenas o que está pendente.
create or replace function gpp.des_enviar_link(p_link uuid, p_lembrete boolean)
returns boolean language plpgsql security definer set search_path = '' as $$
declare l record; v_auto boolean; v_lid text; v_url text := trim(gpp.cfg('url_app'));
begin
  select dl.id, dl.token, dl.ciclo_id, dl.organizador_id, o.nome, o.email, c.trimestre, c.prazo into l
  from gpp.des_links dl join gpp.organizadores o on o.id = dl.organizador_id join gpp.ciclos c on c.id = dl.ciclo_id
  where dl.id = p_link;
  if not found or coalesce(trim(l.email), '') = '' then return false; end if;
  select exists (select 1 from gpp.des_avaliacoes a where a.ciclo_id = l.ciclo_id and a.tipo = 'auto'
                   and a.avaliado_id = l.organizador_id and a.respondida_em is null) into v_auto;
  select string_agg(o.nome, ', ' order by o.nome) into v_lid
  from gpp.des_avaliacoes a join gpp.organizadores o on o.id = a.avaliado_id
  where a.ciclo_id = l.ciclo_id and a.tipo = 'gestor' and a.avaliador_id = l.organizador_id and a.respondida_em is null;
  if not v_auto and v_lid is null then return false; end if;
  insert into gpp.email_fila (para, assunto, html, ciclo_id) values (
    trim(l.email),
    case when p_lembrete
      then 'Lembrete: Avaliação de Desempenho DAEXE ' || l.trimestre || ' — prazo ' || to_char(l.prazo at time zone 'America/Sao_Paulo', 'DD/MM')
      else 'Avaliação de Desempenho DAEXE ' || l.trimestre || ' — sua participação' end,
    gpp.html_des_convite(l.nome, l.trimestre, v_url || '?d=' || l.token, l.prazo, p_lembrete, v_auto, v_lid),
    l.ciclo_id);
  return true;
end $$;

-- Confere o cadastro dos participantes antes de abrir/incluir
create or replace function gpp.des_validar(p_ids uuid[])
returns void language plpgsql stable security definer set search_path = '' as $$
declare v_prob text;
begin
  if coalesce(cardinality(p_ids), 0) = 0 then raise exception 'Nenhum participante selecionado.'; end if;
  select string_agg(msg, '; ' order by msg) into v_prob from (
    select o.nome || ' está sem e-mail' as msg from gpp.organizadores o
     where o.id = any(p_ids) and coalesce(trim(o.email), '') = ''
    union
    select o.nome || ' está sem gestor' from gpp.organizadores o where o.id = any(p_ids) and o.gestor_id is null
    union
    select 'o gestor ' || g.nome || ' está sem e-mail' from gpp.organizadores o join gpp.organizadores g on g.id = o.gestor_id
     where o.id = any(p_ids) and coalesce(trim(g.email), '') = '') x;
  if v_prob is not null then
    raise exception 'Ajuste o cadastro em Pessoas antes de continuar: %.', v_prob;
  end if;
end $$;

-- Cria as avaliações (auto + gestor), os links e envia os convites
create or replace function gpp.des_incluir(p_ciclo uuid, p_ids uuid[])
returns int language plpgsql security definer set search_path = '' as $$
declare c record; v_n int; r record;
begin
  select * into c from gpp.ciclos where id = p_ciclo and modulo = 'desempenho';
  if not found then raise exception 'Ciclo não encontrado.'; end if;
  perform gpp.des_validar(p_ids);
  insert into gpp.des_avaliacoes (trimestre, ciclo_id, avaliado_id, avaliador_id, tipo, e_lider, area)
  select c.trimestre, c.id, o.id, case when t = 'auto' then o.id else o.gestor_id end, t, o.e_lider, o.area
  from gpp.organizadores o cross join unnest(array['auto', 'gestor']) t
  where o.id = any(p_ids)
  on conflict (trimestre, avaliado_id, tipo) do nothing;
  get diagnostics v_n = row_count;
  insert into gpp.des_links (ciclo_id, organizador_id)
  select distinct c.id, x.id from (
    select o.id from gpp.organizadores o where o.id = any(p_ids)
    union select o.gestor_id from gpp.organizadores o where o.id = any(p_ids) and o.gestor_id is not null) x
  on conflict (ciclo_id, organizador_id) do nothing;
  for r in select dl.id from gpp.des_links dl where dl.ciclo_id = c.id and dl.organizador_id in (
             select o.id from gpp.organizadores o where o.id = any(p_ids)
             union select o.gestor_id from gpp.organizadores o where o.id = any(p_ids)) loop
    perform gpp.des_enviar_link(r.id, false);
  end loop;
  return v_n / 2;
end $$;

create or replace function gpp.abrir_ciclo_desempenho(p_trimestre text, p_prazo date default null, p_participantes uuid[] default null)
returns int language plpgsql security definer set search_path = '' as $$
declare v_tri text := upper(trim(p_trimestre)); v_ciclo uuid; v_prazo timestamptz; v_ids uuid[]; v_de text;
begin
  if v_tri !~ '^[1-4]T/[0-9]{2}$' then raise exception 'Trimestre inválido. Use o formato 4T/26.'; end if;
  if exists (select 1 from gpp.ciclos where modulo = 'desempenho' and status = 'aberto') then
    raise exception 'Já existe uma Avaliação de Desempenho aberta. Encerre-a antes.'; end if;
  if exists (select 1 from gpp.ciclos where modulo = 'desempenho' and trimestre = v_tri)
     or exists (select 1 from gpp.des_avaliacoes where trimestre = v_tri) then
    raise exception 'O trimestre % já tem Avaliação de Desempenho.', v_tri; end if;
  if nullif(trim(gpp.cfg('url_app')), '') is null then raise exception 'Endereço do site ainda não configurado (url_app).'; end if;

  if not exists (select 1 from gpp.des_itens where trimestre = v_tri) then
    select trimestre into v_de from gpp.des_itens order by gpp.ordem_trimestre(trimestre) desc limit 1;
    if v_de is null then raise exception 'Monte a matriz de competências de % antes de abrir.', v_tri; end if;
    insert into gpp.des_itens (trimestre, ordem, competencia_id, texto, so_lideres)
    select v_tri, ordem, competencia_id, texto, so_lideres from gpp.des_itens where trimestre = v_de;
  end if;

  v_ids := coalesce(p_participantes, array(select id from gpp.organizadores where ativo and gestor_id is not null));
  perform gpp.des_validar(v_ids);
  v_prazo := ((coalesce(p_prazo, gpp.hoje() + coalesce(gpp.cfg('des_dias_resposta'), '10')::int))::timestamp + time '23:59')
             at time zone 'America/Sao_Paulo';
  if v_prazo <= now() then raise exception 'O prazo precisa ser uma data futura.'; end if;
  insert into gpp.ciclos (modulo, trimestre, prazo) values ('desempenho', v_tri, v_prazo) returning id into v_ciclo;
  return gpp.des_incluir(v_ciclo, v_ids);
end $$;

create or replace function gpp.lembrar_ciclo_desempenho(p_ciclo uuid)
returns int language plpgsql security definer set search_path = '' as $$
declare r record; v_n int := 0;
begin
  if not exists (select 1 from gpp.ciclos where id = p_ciclo and modulo = 'desempenho' and status = 'aberto') then
    raise exception 'Este ciclo não está aberto.'; end if;
  for r in select id from gpp.des_links where ciclo_id = p_ciclo loop
    if gpp.des_enviar_link(r.id, true) then v_n := v_n + 1; end if;
  end loop;
  update gpp.ciclos set lembrete_enviado = true where id = p_ciclo;
  return v_n;
end $$;

create or replace function gpp.encerrar_ciclo_desempenho(p_ciclo uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare c record; v_tot int; v_resp int; v_pdi int; o record; n record; v_tab text; v_media numeric;
begin
  select * into c from gpp.ciclos where id = p_ciclo and modulo = 'desempenho' for update;
  if not found or c.status <> 'aberto' then raise exception 'Este ciclo não está aberto.'; end if;
  select count(*), count(*) filter (where respondida_em is not null) into v_tot, v_resp
  from gpp.des_avaliacoes where ciclo_id = c.id;
  update gpp.ciclos set status = 'encerrado', respondentes_final = v_resp where id = c.id;

  -- PDI: cada competência prioritária indicada pelo gestor vira um item "a definir"
  insert into gpp.des_pdi (trimestre, organizador_id, competencia_id, origem, responsavel, observacao)
  select a.trimestre, a.avaliado_id, p.cid, 'gestor', g.nome, 'Prioridade indicada pelo gestor na avaliação'
  from gpp.des_avaliacoes a cross join unnest(a.prioridades) p(cid)
  left join gpp.organizadores g on g.id = a.avaliador_id
  where a.ciclo_id = c.id and a.tipo = 'gestor' and a.respondida_em is not null
    and not exists (select 1 from gpp.des_pdi x where x.trimestre = a.trimestre and x.organizador_id = a.avaliado_id and x.competencia_id = p.cid);
  get diagnostics v_pdi = row_count;

  select * into o from gpp.v_des_org where trimestre = c.trimestre;
  select * into n from gpp.v_des_nps where trimestre = c.trimestre and geral;
  select avg(indice_gestor) into v_media from gpp.v_des_pessoa where trimestre = c.trimestre;
  select string_agg(format('<tr><td style="padding:6px 10px">%s</td><td align="center">%s</td><td align="center">%s</td></tr>',
                           gpp.esc(k.nome), x.n, round(x.maturidade) || '%'), '' order by k.ordem) into v_tab
  from gpp.v_des_org_comp x join gpp.des_competencias k on k.id = x.competencia_id where x.trimestre = c.trimestre;

  insert into gpp.email_fila (para, assunto, html, ciclo_id)
  select trim(e), 'Resultado — Avaliação de Desempenho DAEXE ' || c.trimestre,
    format('<div style="font-family:Arial,sans-serif;max-width:600px;color:#1f2937">'
           '<h2 style="color:#1F3A5F">Avaliação de Desempenho DAEXE — %s</h2>'
           '<p>Avaliações respondidas: <b>%s de %s</b></p>'
           '<p>Maturidade Organizacional: <b>%s</b> · Índice médio (gestor): <b>%s</b> · NPS de Liderança: <b>%s</b></p>'
           '%s<p>Itens de PDI criados a partir das prioridades dos gestores: <b>%s</b></p>'
           '<p><a href="%s">Abrir o painel completo</a></p></div>',
           c.trimestre, v_resp, v_tot,
           coalesce(round(o.maturidade, 1) || '%', '—'), coalesce(round(v_media, 1) || '%', '—'), coalesce(n.nps::text, '—'),
           case when v_tab is null then '<p>Nenhuma avaliação de gestor recebida.</p>'
                else '<table style="border-collapse:collapse;border:1px solid #ddd"><tr style="background:#1F3A5F;color:#fff">'
                     '<th style="padding:6px 10px;text-align:left">Competência</th><th style="padding:6px 10px">N</th><th style="padding:6px 10px">Maturidade</th></tr>'
                     || v_tab || '</table>' end,
           v_pdi, trim(gpp.cfg('url_app'))), c.id
  from unnest(string_to_array(coalesce(gpp.cfg('emails_resultado'), ''), ',')) e
  where trim(e) <> '';

  return jsonb_build_object('trimestre', c.trimestre, 'avaliacoes', v_tot, 'respondidas', v_resp,
                            'maturidade', round(o.maturidade, 1), 'nps', n.nps, 'pdi', v_pdi);
end $$;

-- ---------------- Rotina diária: OCAI + Desempenho, cada um isolado ----------------
create or replace function gpp.rotina_ocai()
returns text language plpgsql security definer set search_path = '' as $$
declare v record; v_hoje date := gpp.hoje(); v_tri text;
begin
  select * into v from gpp.ciclos where modulo = 'ocai' and status = 'aberto';
  if found then
    if now() > v.prazo then
      perform gpp.encerrar_ciclo_ocai(); return 'ocai encerrado ' || v.trimestre;
    elsif not v.lembrete_enviado and v_hoje >= (v.abertura at time zone 'America/Sao_Paulo')::date + coalesce(gpp.cfg('lembrete_dias'), '5')::int then
      perform gpp.lembrar_ciclo_ocai(); return 'ocai lembrete ' || v.trimestre;
    end if;
    return 'ocai aberto, sem ação';
  end if;
  v_tri := gpp.rotulo_trimestre(v_hoje);
  if lower(coalesce(gpp.cfg('abertura_automatica'), 'sim')) = 'sim'
     and v_hoje = gpp.ultimo_dia_util_trimestre(v_hoje)
     and not exists (select 1 from gpp.ciclos where modulo = 'ocai' and trimestre = v_tri)
     and not exists (select 1 from gpp.ocai_historico where trimestre = v_tri) then
    perform gpp.abrir_ciclo_ocai(v_tri); return 'ocai aberto ' || v_tri;
  end if;
  return 'ocai: nada a fazer';
end $$;

create or replace function gpp.rotina_desempenho()
returns text language plpgsql security definer set search_path = '' as $$
declare v record; v_hoje date := gpp.hoje(); v_tri text;
begin
  select * into v from gpp.ciclos where modulo = 'desempenho' and status = 'aberto';
  if found then
    if now() > v.prazo then
      perform gpp.encerrar_ciclo_desempenho(v.id); return 'desempenho encerrado ' || v.trimestre;
    elsif not v.lembrete_enviado and v_hoje >= (v.abertura at time zone 'America/Sao_Paulo')::date + coalesce(gpp.cfg('des_lembrete_dias'), '5')::int then
      perform gpp.lembrar_ciclo_desempenho(v.id); return 'desempenho lembrete ' || v.trimestre;
    end if;
    return 'desempenho aberto, sem ação';
  end if;
  v_tri := gpp.rotulo_trimestre(v_hoje);
  if lower(coalesce(gpp.cfg('des_abertura_automatica'), 'sim')) = 'sim'
     and v_hoje = gpp.ultimo_dia_util_trimestre(v_hoje)
     and not exists (select 1 from gpp.ciclos where modulo = 'desempenho' and trimestre = v_tri)
     and not exists (select 1 from gpp.des_avaliacoes where trimestre = v_tri) then
    perform gpp.abrir_ciclo_desempenho(v_tri); return 'desempenho aberto ' || v_tri;
  end if;
  return 'desempenho: nada a fazer';
end $$;

create or replace function gpp.avisar_falha(p_parte text, p_erro text)
returns void language sql security definer set search_path = '' as $$
  insert into gpp.email_fila (para, assunto, html)
  select trim(e), 'Atenção: rotina automática da GPP (' || p_parte || ') não foi concluída',
    format('<div style="font-family:Arial,sans-serif;max-width:560px;color:#1f2937"><p>A rotina diária da GPP tentou executar a etapa <b>%s</b> e parou com a mensagem:</p>'
           '<p style="background:#FFF4CC;padding:10px;border-radius:6px">%s</p><p>Ajuste no painel e, se preferir, execute a ação manualmente.</p>'
           '<p><a href="%s">Abrir o painel</a></p></div>', gpp.esc(p_parte), gpp.esc(p_erro), trim(gpp.cfg('url_app')))
  from unnest(string_to_array(coalesce(gpp.cfg('emails_resultado'), ''), ',')) e where trim(e) <> ''
$$;

create or replace function gpp.rotina_diaria()
returns text language plpgsql security definer set search_path = '' as $$
declare r1 text; r2 text;
begin
  begin r1 := gpp.rotina_ocai();
  exception when others then r1 := 'ocai erro: ' || sqlerrm; perform gpp.avisar_falha('Cultura / OCAI', sqlerrm); end;
  begin r2 := gpp.rotina_desempenho();
  exception when others then r2 := 'desempenho erro: ' || sqlerrm; perform gpp.avisar_falha('Avaliação de Desempenho', sqlerrm); end;
  return r1 || ' | ' || r2;
end $$;

-- ---------------- Formulário público (link pessoal) ----------------
create or replace function public.gpp_des_link(p_token text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare l record;
begin
  if p_token is null or p_token !~ '^[a-f0-9]{48}$' then return jsonb_build_object('estado', 'invalido'); end if;
  select dl.organizador_id, o.nome, c.id as ciclo_id, c.trimestre, c.status, c.prazo into l
  from gpp.des_links dl join gpp.organizadores o on o.id = dl.organizador_id join gpp.ciclos c on c.id = dl.ciclo_id
  where dl.token = p_token;
  if not found then return jsonb_build_object('estado', 'invalido'); end if;
  if l.status <> 'aberto' or now() > l.prazo then return jsonb_build_object('estado', 'encerrado', 'trimestre', l.trimestre); end if;
  return jsonb_build_object('estado', 'ok', 'nome', l.nome, 'trimestre', l.trimestre,
    'prazo', to_char(l.prazo at time zone 'America/Sao_Paulo', 'DD/MM/YYYY'),
    'itens', (select coalesce(jsonb_agg(jsonb_build_object('id', i.id, 'ordem', i.ordem, 'competencia_id', k.id, 'competencia', k.nome,
                'descricao', k.descricao, 'texto', i.texto, 'so_lideres', i.so_lideres) order by i.ordem), '[]')
              from gpp.des_itens i join gpp.des_competencias k on k.id = i.competencia_id where i.trimestre = l.trimestre),
    'tarefas', (select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'tipo', a.tipo, 'avaliado', av.nome, 'area', a.area,
                  'e_lider', a.e_lider, 'respondida', a.respondida_em is not null,
                  'gestor', case when a.tipo = 'auto' then (select g.nome from gpp.des_avaliacoes ag join gpp.organizadores g on g.id = ag.avaliador_id
                                  where ag.ciclo_id = a.ciclo_id and ag.avaliado_id = a.avaliado_id and ag.tipo = 'gestor') end,
                  'pede_nps', a.tipo = 'auto' and not a.nps_registrado
                    and exists (select 1 from gpp.des_avaliacoes ag where ag.ciclo_id = a.ciclo_id and ag.avaliado_id = a.avaliado_id and ag.tipo = 'gestor'))
                  order by a.tipo, av.nome), '[]')
                from gpp.des_avaliacoes a join gpp.organizadores av on av.id = a.avaliado_id
                where a.ciclo_id = l.ciclo_id
                  and ((a.tipo = 'auto' and a.avaliado_id = l.organizador_id) or (a.tipo = 'gestor' and a.avaliador_id = l.organizador_id))));
end $$;

create or replace function public.gpp_des_responder(p_token text, p_avaliacao uuid, p_notas jsonb,
                                                    p_nps int default null, p_prioridades int[] default null, p_comentario text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare l record; a record; v_falta int; v_gestor uuid;
begin
  if p_token is null or p_token !~ '^[a-f0-9]{48}$' then return jsonb_build_object('ok', false, 'msg', 'Link inválido.'); end if;
  select dl.organizador_id, c.id as ciclo_id, c.status, c.prazo into l
  from gpp.des_links dl join gpp.ciclos c on c.id = dl.ciclo_id where dl.token = p_token;
  if not found then return jsonb_build_object('ok', false, 'msg', 'Link inválido.'); end if;
  if l.status <> 'aberto' or now() > l.prazo then return jsonb_build_object('ok', false, 'msg', 'A avaliação deste trimestre já foi encerrada.'); end if;
  select * into a from gpp.des_avaliacoes x
  where x.id = p_avaliacao and x.ciclo_id = l.ciclo_id
    and ((x.tipo = 'auto' and x.avaliado_id = l.organizador_id) or (x.tipo = 'gestor' and x.avaliador_id = l.organizador_id))
  for update;
  if not found then return jsonb_build_object('ok', false, 'msg', 'Avaliação não encontrada neste link.'); end if;
  if a.respondida_em is not null then return jsonb_build_object('ok', false, 'msg', 'Esta avaliação já foi enviada.'); end if;
  if p_notas is null or jsonb_typeof(p_notas) <> 'object' then return jsonb_build_object('ok', false, 'msg', 'Resposta incompleta.'); end if;

  select count(*) into v_falta from gpp.des_itens i
  where i.trimestre = a.trimestre and (not i.so_lideres or a.e_lider) and coalesce(p_notas ->> (i.id::text), '') !~ '^[1-4]$';
  if v_falta > 0 then return jsonb_build_object('ok', false, 'msg', format('Falta nota em %s afirmativa(s).', v_falta)); end if;

  if a.tipo = 'auto' then
    select avaliador_id into v_gestor from gpp.des_avaliacoes where ciclo_id = a.ciclo_id and avaliado_id = a.avaliado_id and tipo = 'gestor';
    if v_gestor is not null and not a.nps_registrado and (p_nps is null or p_nps < 0 or p_nps > 10) then
      return jsonb_build_object('ok', false, 'msg', 'Responda a Percepção da Liderança (nota de 0 a 10).'); end if;
  else
    if coalesce(cardinality(p_prioridades), 0) > 2 then
      return jsonb_build_object('ok', false, 'msg', 'Escolha no máximo 2 competências prioritárias.'); end if;
    if exists (select 1 from unnest(coalesce(p_prioridades, '{}')) p
               where not exists (select 1 from gpp.des_itens i where i.trimestre = a.trimestre and i.competencia_id = p)) then
      return jsonb_build_object('ok', false, 'msg', 'Competência prioritária inválida.'); end if;
  end if;

  insert into gpp.des_notas (avaliacao_id, item_id, nota)
  select a.id, i.id, (p_notas ->> (i.id::text))::smallint from gpp.des_itens i
  where i.trimestre = a.trimestre and (not i.so_lideres or a.e_lider)
  on conflict (avaliacao_id, item_id) do update set nota = excluded.nota;

  update gpp.des_avaliacoes set respondida_em = now(),
    prioridades = case when tipo = 'gestor' then coalesce(p_prioridades, '{}') else prioridades end,
    comentario = case when tipo = 'gestor' then nullif(trim(left(coalesce(p_comentario, ''), 2000)), '') else comentario end,
    nps_registrado = nps_registrado or (tipo = 'auto' and v_gestor is not null)
  where id = a.id;

  -- NPS anônimo: sem nome, sem horário, sem ligação com a avaliação
  if a.tipo = 'auto' and v_gestor is not null and not a.nps_registrado then
    insert into gpp.des_nps (trimestre, ciclo_id, gestor_id, nota) values (a.trimestre, a.ciclo_id, v_gestor, p_nps);
  end if;
  return jsonb_build_object('ok', true);
end $$;

-- ---------------- Administração ----------------
create or replace function public.gpp_admin_des_painel()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_min int := coalesce(gpp.cfg('minimo_respostas'), '3')::int;
begin
  perform gpp.exigir_admin();
  return jsonb_build_object(
    'min_nps', v_min,
    'proxima_abertura', to_char(gpp.ultimo_dia_util_trimestre(gpp.hoje()), 'DD/MM/YYYY'),
    'proximo_trimestre', gpp.rotulo_trimestre(gpp.hoje()),
    'competencias', (select coalesce(jsonb_agg(to_jsonb(k) || jsonb_build_object(
        'em_uso', exists (select 1 from gpp.des_itens i where i.competencia_id = k.id)
               or exists (select 1 from gpp.des_pdi x where x.competencia_id = k.id)) order by k.ordem, k.nome), '[]')
      from gpp.des_competencias k),
    'itens', (select coalesce(jsonb_agg(jsonb_build_object('id', i.id, 'trimestre', i.trimestre, 'ordem', i.ordem,
        'competencia_id', i.competencia_id, 'texto', i.texto, 'so_lideres', i.so_lideres)
        order by gpp.ordem_trimestre(i.trimestre), i.ordem, i.id), '[]') from gpp.des_itens i),
    'avaliacoes', (select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'trimestre', a.trimestre, 'ciclo_id', a.ciclo_id,
        'avaliado_id', a.avaliado_id, 'avaliador_id', a.avaliador_id, 'tipo', a.tipo, 'e_lider', a.e_lider, 'area', a.area,
        'respondida', to_char(a.respondida_em at time zone 'America/Sao_Paulo', 'DD/MM/YYYY'), 'origem', a.origem,
        'prioridades', a.prioridades, 'comentario', a.comentario,
        'notas', (select coalesce(jsonb_object_agg(n.item_id::text, n.nota), '{}') from gpp.des_notas n where n.avaliacao_id = a.id))), '[]')
      from gpp.des_avaliacoes a),
    'comp', (select coalesce(jsonb_agg(jsonb_build_object('trimestre', c.trimestre, 'avaliado_id', c.avaliado_id, 'tipo', c.tipo,
        'competencia_id', c.competencia_id, 'media', round(c.media, 4))), '[]') from gpp.v_des_comp c),
    'pessoas', (select coalesce(jsonb_agg(jsonb_build_object('trimestre', p.trimestre, 'avaliado_id', p.avaliado_id, 'e_lider', p.e_lider,
        'nota_auto', round(p.nota_auto, 4), 'nota_gestor', round(p.nota_gestor, 4),
        'indice_auto', round(p.indice_auto, 2), 'indice_gestor', round(p.indice_gestor, 2), 'gap', round(p.gap, 4))), '[]')
      from gpp.v_des_pessoa p),
    'org_comp', (select coalesce(jsonb_agg(jsonb_build_object('trimestre', x.trimestre, 'competencia_id', x.competencia_id, 'n', x.n,
        'media', round(x.media, 4), 'maturidade', round(x.maturidade, 2), 'pct_3', round(x.pct_3, 1), 'pct_4', round(x.pct_4, 1))), '[]')
      from gpp.v_des_org_comp x),
    'org', (select coalesce(jsonb_agg(jsonb_build_object('trimestre', trimestre, 'maturidade', round(maturidade, 2))
        order by gpp.ordem_trimestre(trimestre)), '[]') from gpp.v_des_org),
    'nps', (select coalesce(jsonb_agg(jsonb_build_object('trimestre', n.trimestre, 'gestor_id', n.gestor_id, 'gestor', g.nome,
        'geral', n.geral, 'n', n.n, 'visivel', n.geral or n.n >= v_min,
        'nps', case when n.geral or n.n >= v_min then n.nps end,
        'promotores', case when n.geral or n.n >= v_min then n.promotores end,
        'neutros', case when n.geral or n.n >= v_min then n.neutros end,
        'detratores', case when n.geral or n.n >= v_min then n.detratores end)), '[]')
      from gpp.v_des_nps n left join gpp.organizadores g on g.id = n.gestor_id),
    'pdi', (select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'trimestre', x.trimestre, 'organizador_id', x.organizador_id,
        'competencia_id', x.competencia_id, 'acao', x.acao, 'responsavel', x.responsavel,
        'prazo', to_char(x.prazo, 'YYYY-MM-DD'), 'status', x.status, 'origem', x.origem, 'observacao', x.observacao,
        'atrasado', x.prazo < gpp.hoje() and x.status in ('a definir', 'planejada', 'em andamento'))
        order by gpp.ordem_trimestre(x.trimestre) desc, x.criado_em), '[]') from gpp.des_pdi x),
    'ciclos', (select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'trimestre', c.trimestre, 'status', c.status,
        'abertura', to_char(c.abertura at time zone 'America/Sao_Paulo', 'DD/MM/YYYY'),
        'prazo', to_char(c.prazo at time zone 'America/Sao_Paulo', 'DD/MM/YYYY'),
        'prazo_iso', to_char(c.prazo at time zone 'America/Sao_Paulo', 'YYYY-MM-DD'),
        'vencido', now() > c.prazo, 'lembrete_enviado', c.lembrete_enviado,
        'links', (select coalesce(jsonb_agg(jsonb_build_object('id', dl.id, 'organizador_id', dl.organizador_id, 'nome', o.nome, 'email', o.email,
            'total', (select count(*) from gpp.des_avaliacoes a where a.ciclo_id = c.id
                       and ((a.tipo = 'auto' and a.avaliado_id = dl.organizador_id) or (a.tipo = 'gestor' and a.avaliador_id = dl.organizador_id))),
            'pendentes', (select count(*) from gpp.des_avaliacoes a where a.ciclo_id = c.id and a.respondida_em is null
                       and ((a.tipo = 'auto' and a.avaliado_id = dl.organizador_id) or (a.tipo = 'gestor' and a.avaliador_id = dl.organizador_id))))
            order by o.nome), '[]')
          from gpp.des_links dl join gpp.organizadores o on o.id = dl.organizador_id where dl.ciclo_id = c.id))
        order by c.abertura desc), '[]') from gpp.ciclos c where c.modulo = 'desempenho')
  );
end $$;

create or replace function public.gpp_admin_des_salvar_competencia(p jsonb)
returns int language plpgsql security definer set search_path = '' as $$
declare v_id int := nullif(p ->> 'id', '')::int; v_nome text := trim(coalesce(p ->> 'nome', '')); v_tipo text := coalesce(nullif(p ->> 'tipo', ''), 'comportamental');
        v_comp text[];
begin
  perform gpp.exigir_admin();
  if v_nome = '' then raise exception 'Informe o nome da competência.'; end if;
  if v_tipo not in ('comportamental', 'estrategica', 'tecnica') then raise exception 'Tipo inválido.'; end if;
  v_comp := array(select trim(x) from jsonb_array_elements_text(coalesce(p -> 'comportamentos', '[]')) x where trim(x) <> '');
  begin
    if v_id is null then
      insert into gpp.des_competencias (nome, tipo, valor, descricao, comportamentos, so_lideres, ordem, ativo)
      values (v_nome, v_tipo, nullif(trim(p ->> 'valor'), ''), nullif(trim(p ->> 'descricao'), ''), v_comp,
              coalesce((p ->> 'so_lideres')::boolean, v_tipo = 'estrategica'),
              coalesce(nullif(p ->> 'ordem', '')::int, (select coalesce(max(ordem), 0) + 10 from gpp.des_competencias)),
              coalesce((p ->> 'ativo')::boolean, true))
      returning id into v_id;
    else
      update gpp.des_competencias set nome = v_nome, tipo = v_tipo, valor = nullif(trim(p ->> 'valor'), ''),
        descricao = nullif(trim(p ->> 'descricao'), ''), comportamentos = v_comp,
        so_lideres = coalesce((p ->> 'so_lideres')::boolean, so_lideres),
        ordem = coalesce(nullif(p ->> 'ordem', '')::int, ordem), ativo = coalesce((p ->> 'ativo')::boolean, ativo)
      where id = v_id;
      if not found then raise exception 'Competência não encontrada.'; end if;
    end if;
  exception when unique_violation then raise exception 'Já existe uma competência com o nome "%".', v_nome;
  end;
  return v_id;
end $$;

create or replace function public.gpp_admin_des_salvar_item(p jsonb)
returns int language plpgsql security definer set search_path = '' as $$
declare v_id int := nullif(p ->> 'id', '')::int; i record; v_tri text; v_comp int := nullif(p ->> 'competencia_id', '')::int;
        v_so boolean; v_texto text := trim(coalesce(p ->> 'texto', '')); v_travado boolean;
begin
  perform gpp.exigir_admin();
  if v_id is not null then
    select * into i from gpp.des_itens where id = v_id;
    if not found then raise exception 'Item não encontrado.'; end if;
    v_tri := i.trimestre;
  else
    v_tri := upper(trim(coalesce(p ->> 'trimestre', '')));
    if v_tri !~ '^[1-4]T/[0-9]{2}$' then raise exception 'Trimestre inválido. Use o formato 4T/26.'; end if;
  end if;
  if v_texto = '' then raise exception 'Escreva o comportamento observável.'; end if;
  if v_comp is null or not exists (select 1 from gpp.des_competencias where id = v_comp) then raise exception 'Escolha a competência.'; end if;
  v_so := coalesce((p ->> 'so_lideres')::boolean, (select so_lideres from gpp.des_competencias where id = v_comp));
  v_travado := exists (select 1 from gpp.des_avaliacoes where trimestre = v_tri and respondida_em is not null);
  if v_id is null then
    if v_travado then raise exception 'Já há respostas em %: a matriz não pode receber itens novos.', v_tri; end if;
    insert into gpp.des_itens (trimestre, ordem, competencia_id, texto, so_lideres)
    values (v_tri, coalesce(nullif(p ->> 'ordem', '')::int, (select coalesce(max(ordem), 0) + 1 from gpp.des_itens where trimestre = v_tri)),
            v_comp, v_texto, v_so)
    returning id into v_id;
  else
    if v_travado and (i.competencia_id <> v_comp or i.so_lideres <> v_so) then
      raise exception 'Já há respostas em %: só é possível corrigir o texto ou a ordem deste item.', v_tri; end if;
    update gpp.des_itens set texto = v_texto, competencia_id = v_comp, so_lideres = v_so,
      ordem = coalesce(nullif(p ->> 'ordem', '')::int, ordem) where id = v_id;
  end if;
  return v_id;
end $$;

create or replace function public.gpp_admin_des_copiar_matriz(p_de text, p_para text)
returns int language plpgsql security definer set search_path = '' as $$
declare v_para text := upper(trim(p_para)); v_n int;
begin
  perform gpp.exigir_admin();
  if v_para !~ '^[1-4]T/[0-9]{2}$' then raise exception 'Trimestre inválido. Use o formato 4T/26.'; end if;
  if exists (select 1 from gpp.des_itens where trimestre = v_para) then raise exception '% já tem matriz.', v_para; end if;
  insert into gpp.des_itens (trimestre, ordem, competencia_id, texto, so_lideres)
  select v_para, ordem, competencia_id, texto, so_lideres from gpp.des_itens where trimestre = p_de;
  get diagnostics v_n = row_count;
  if v_n = 0 then raise exception 'O trimestre % não tem matriz para copiar.', p_de; end if;
  return v_n;
end $$;

create or replace function public.gpp_admin_des_abrir(p jsonb)
returns int language plpgsql security definer set search_path = '' as $$
begin
  perform gpp.exigir_admin();
  return gpp.abrir_ciclo_desempenho(p ->> 'trimestre', nullif(p ->> 'prazo', '')::date,
    case when jsonb_typeof(p -> 'participantes') = 'array'
         then array(select x::uuid from jsonb_array_elements_text(p -> 'participantes') x) end);
end $$;

create or replace function public.gpp_admin_des_adicionar(p_ciclo uuid, p_ids uuid[])
returns int language plpgsql security definer set search_path = '' as $$
begin
  perform gpp.exigir_admin();
  if not exists (select 1 from gpp.ciclos where id = p_ciclo and modulo = 'desempenho' and status = 'aberto') then
    raise exception 'Só é possível incluir pessoas em um ciclo aberto.'; end if;
  return gpp.des_incluir(p_ciclo, p_ids);
end $$;

create or replace function public.gpp_admin_des_lembrar(p_ciclo uuid)
returns int language plpgsql security definer set search_path = '' as $$
begin perform gpp.exigir_admin(); return gpp.lembrar_ciclo_desempenho(p_ciclo); end $$;

create or replace function public.gpp_admin_des_encerrar(p_ciclo uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin perform gpp.exigir_admin(); return gpp.encerrar_ciclo_desempenho(p_ciclo); end $$;

create or replace function public.gpp_admin_des_editar_ciclo(p jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare c record; v_prazo timestamptz; v_reabrir boolean := coalesce((p ->> 'reabrir')::boolean, false);
begin
  perform gpp.exigir_admin();
  select * into c from gpp.ciclos where id = nullif(p ->> 'id', '')::uuid and modulo = 'desempenho' for update;
  if not found then raise exception 'Ciclo não encontrado.'; end if;
  v_prazo := case when nullif(p ->> 'prazo', '') is null then c.prazo
                  else ((p ->> 'prazo')::date + time '23:59') at time zone 'America/Sao_Paulo' end;
  if v_reabrir and c.status = 'encerrado' then
    if exists (select 1 from gpp.ciclos where modulo = 'desempenho' and status = 'aberto') then
      raise exception 'Já existe outro ciclo aberto. Encerre-o antes de reabrir este.'; end if;
    if v_prazo <= now() then raise exception 'Para reabrir, informe um prazo futuro.'; end if;
    update gpp.ciclos set status = 'aberto', prazo = v_prazo, respondentes_final = null where id = c.id;
    return jsonb_build_object('reaberto', true);
  end if;
  if c.status = 'aberto' and v_prazo <= now() then raise exception 'O prazo de um ciclo aberto precisa ser uma data futura.'; end if;
  update gpp.ciclos set prazo = v_prazo where id = c.id;
  return jsonb_build_object('reaberto', false);
end $$;

create or replace function public.gpp_admin_des_reenviar(p_link uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  perform gpp.exigir_admin();
  if not exists (select 1 from gpp.des_links dl join gpp.ciclos c on c.id = dl.ciclo_id where dl.id = p_link and c.status = 'aberto') then
    raise exception 'Este ciclo não está aberto.'; end if;
  if not gpp.des_enviar_link(p_link, false) then
    raise exception 'Nada pendente para essa pessoa, ou ela está sem e-mail.'; end if;
  return true;
end $$;

-- Lançamento/correção manual (ex.: avaliação feita fora do sistema)
create or replace function public.gpp_admin_des_salvar_avaliacao(p jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid := nullif(p ->> 'id', '')::uuid; a record; v_tri text; v_tipo text; v_falta int;
begin
  perform gpp.exigir_admin();
  if v_id is null then
    v_tri := upper(trim(coalesce(p ->> 'trimestre', ''))); v_tipo := p ->> 'tipo';
    if v_tri !~ '^[1-4]T/[0-9]{2}$' then raise exception 'Trimestre inválido.'; end if;
    if v_tipo not in ('auto', 'gestor') then raise exception 'Tipo inválido.'; end if;
    if not exists (select 1 from gpp.des_itens where trimestre = v_tri) then raise exception 'O trimestre % ainda não tem matriz.', v_tri; end if;
    if exists (select 1 from gpp.des_avaliacoes where trimestre = v_tri and avaliado_id = (p ->> 'avaliado_id')::uuid and tipo = v_tipo) then
      raise exception 'Já existe essa avaliação para a pessoa em %. Edite a existente.', v_tri; end if;
    insert into gpp.des_avaliacoes (trimestre, avaliado_id, avaliador_id, tipo, e_lider, area, origem)
    select v_tri, o.id, case when v_tipo = 'auto' then o.id else coalesce(nullif(p ->> 'avaliador_id', '')::uuid, o.gestor_id) end,
           v_tipo, coalesce((p ->> 'e_lider')::boolean, o.e_lider), coalesce(nullif(trim(p ->> 'area'), ''), o.area), 'manual'
    from gpp.organizadores o where o.id = (p ->> 'avaliado_id')::uuid
    returning id into v_id;
    if v_id is null then raise exception 'Pessoa não encontrada.'; end if;
  else
    update gpp.des_avaliacoes set
      e_lider = coalesce((p ->> 'e_lider')::boolean, e_lider),
      area = case when p ? 'area' then nullif(trim(p ->> 'area'), '') else area end,
      avaliador_id = case when tipo = 'gestor' and nullif(p ->> 'avaliador_id', '') is not null then (p ->> 'avaliador_id')::uuid else avaliador_id end
    where id = v_id;
    if not found then raise exception 'Avaliação não encontrada.'; end if;
  end if;
  select * into a from gpp.des_avaliacoes where id = v_id;
  if jsonb_typeof(p -> 'notas') = 'object' then
    insert into gpp.des_notas (avaliacao_id, item_id, nota)
    select a.id, i.id, (p -> 'notas' ->> (i.id::text))::smallint from gpp.des_itens i
    where i.trimestre = a.trimestre and coalesce(p -> 'notas' ->> (i.id::text), '') ~ '^[1-4]$'
    on conflict (avaliacao_id, item_id) do update set nota = excluded.nota;
  end if;
  if a.tipo = 'gestor' and p ? 'prioridades' then
    update gpp.des_avaliacoes set prioridades = array(select x::int from jsonb_array_elements_text(coalesce(p -> 'prioridades', '[]')) x)
    where id = a.id;
  end if;
  if p ? 'comentario' then update gpp.des_avaliacoes set comentario = nullif(trim(p ->> 'comentario'), '') where id = a.id; end if;
  select count(*) into v_falta from gpp.des_itens i
  where i.trimestre = a.trimestre and (not i.so_lideres or a.e_lider)
    and not exists (select 1 from gpp.des_notas n where n.avaliacao_id = a.id and n.item_id = i.id);
  update gpp.des_avaliacoes set respondida_em = case when v_falta = 0 then coalesce(respondida_em, now()) else respondida_em end where id = a.id;
  return v_id;
end $$;

create or replace function public.gpp_admin_des_reabrir_avaliacao(p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform gpp.exigir_admin();
  if not exists (select 1 from gpp.des_avaliacoes a join gpp.ciclos c on c.id = a.ciclo_id where a.id = p_id and c.status = 'aberto') then
    raise exception 'Só é possível liberar novo envio em um ciclo aberto.'; end if;
  update gpp.des_avaliacoes set respondida_em = null where id = p_id;
end $$;

create or replace function public.gpp_admin_des_salvar_pdi(p jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid := nullif(p ->> 'id', '')::uuid; v_status text := coalesce(nullif(p ->> 'status', ''), 'a definir');
        v_tri text := upper(trim(coalesce(p ->> 'trimestre', '')));
begin
  perform gpp.exigir_admin();
  if v_status not in ('a definir', 'planejada', 'em andamento', 'concluida', 'cancelada') then raise exception 'Situação inválida.'; end if;
  if v_id is null then
    if v_tri !~ '^[1-4]T/[0-9]{2}$' then raise exception 'Trimestre inválido.'; end if;
    if nullif(p ->> 'organizador_id', '') is null then raise exception 'Escolha a pessoa.'; end if;
    insert into gpp.des_pdi (trimestre, organizador_id, competencia_id, acao, responsavel, prazo, status, origem, observacao)
    values (v_tri, (p ->> 'organizador_id')::uuid, nullif(p ->> 'competencia_id', '')::int, nullif(trim(p ->> 'acao'), ''),
            nullif(trim(p ->> 'responsavel'), ''), nullif(p ->> 'prazo', '')::date, v_status, 'manual', nullif(trim(p ->> 'observacao'), ''))
    returning id into v_id;
  else
    update gpp.des_pdi set
      competencia_id = nullif(p ->> 'competencia_id', '')::int, acao = nullif(trim(p ->> 'acao'), ''),
      responsavel = nullif(trim(p ->> 'responsavel'), ''), prazo = nullif(p ->> 'prazo', '')::date,
      status = v_status, observacao = nullif(trim(p ->> 'observacao'), ''), atualizado_em = now()
    where id = v_id;
    if not found then raise exception 'Item de PDI não encontrado.'; end if;
  end if;
  return v_id;
end $$;

-- ---------------- Permissões ----------------
revoke execute on function public.gpp_des_link(text), public.gpp_des_responder(text, uuid, jsonb, int, int[], text) from public;
grant execute on function public.gpp_des_link(text), public.gpp_des_responder(text, uuid, jsonb, int, int[], text) to anon, authenticated;

revoke execute on function
  public.gpp_admin_des_painel(), public.gpp_admin_des_salvar_competencia(jsonb), public.gpp_admin_des_salvar_item(jsonb),
  public.gpp_admin_des_copiar_matriz(text, text), public.gpp_admin_des_abrir(jsonb), public.gpp_admin_des_adicionar(uuid, uuid[]),
  public.gpp_admin_des_lembrar(uuid), public.gpp_admin_des_encerrar(uuid), public.gpp_admin_des_editar_ciclo(jsonb),
  public.gpp_admin_des_reenviar(uuid), public.gpp_admin_des_salvar_avaliacao(jsonb), public.gpp_admin_des_reabrir_avaliacao(uuid),
  public.gpp_admin_des_salvar_pdi(jsonb)
from public, anon;
grant execute on function
  public.gpp_admin_des_painel(), public.gpp_admin_des_salvar_competencia(jsonb), public.gpp_admin_des_salvar_item(jsonb),
  public.gpp_admin_des_copiar_matriz(text, text), public.gpp_admin_des_abrir(jsonb), public.gpp_admin_des_adicionar(uuid, uuid[]),
  public.gpp_admin_des_lembrar(uuid), public.gpp_admin_des_encerrar(uuid), public.gpp_admin_des_editar_ciclo(jsonb),
  public.gpp_admin_des_reenviar(uuid), public.gpp_admin_des_salvar_avaliacao(jsonb), public.gpp_admin_des_reabrir_avaliacao(uuid),
  public.gpp_admin_des_salvar_pdi(jsonb)
to authenticated;

-- O painel do OCAI passa a listar só os ciclos do OCAI
do $f$
declare d text;
begin
  select pg_get_functiondef('public.gpp_admin_painel()'::regprocedure) into d;
  if strpos(d, 'from gpp.ciclos c),') > 0 then
    execute replace(d, 'from gpp.ciclos c),', 'from gpp.ciclos c where c.modulo = ''ocai''),');
  end if;
end $f$;

-- Ajustes aplicados depois (vírgula decimal no e-mail de resultado e validação das novas configurações)
do $f$
declare d text;
begin
  select pg_get_functiondef('gpp.encerrar_ciclo_desempenho(uuid)'::regprocedure) into d;
  d := replace(d, 'coalesce(round(o.maturidade, 1) || ''%'', ''—'')', 'coalesce(replace(round(o.maturidade, 1)::text, ''.'', '','') || ''%'', ''—'')');
  d := replace(d, 'coalesce(round(v_media, 1) || ''%'', ''—'')', 'coalesce(replace(round(v_media, 1)::text, ''.'', '','') || ''%'', ''—'')');
  d := replace(d, 'coalesce(n.nps::text, ''—'')', 'coalesce(replace(n.nps::text, ''.'', '',''), ''—'')');
  execute d;
  select pg_get_functiondef('public.gpp_admin_salvar_config(text,text)'::regprocedure) into d;
  d := replace(d, 'p_chave in (''dias_resposta'', ''lembrete_dias'', ''minimo_respostas'')',
                  'p_chave in (''dias_resposta'', ''lembrete_dias'', ''minimo_respostas'', ''des_dias_resposta'', ''des_lembrete_dias'')');
  d := replace(d, 'if p_chave = ''abertura_automatica'' then', 'if p_chave in (''abertura_automatica'', ''des_abertura_automatica'') then');
  execute d;
end $f$;
