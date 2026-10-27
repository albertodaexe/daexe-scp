-- gpp_08: CRUD completo do módulo Cultura & Desempenho (ciclos, convites, organizadores, cenários, histórico, e-mails)
begin;

-- ---------- e-mails ligados ao ciclo (excluir o ciclo apaga a fila dele) ----------
alter table gpp.email_fila add column if not exists ciclo_id uuid references gpp.ciclos(id) on delete cascade;

create or replace function gpp.email_fila_ciclo() returns trigger
language plpgsql security definer set search_path to '' as $$
begin
  if new.ciclo_id is null then
    select c.ciclo_id into new.ciclo_id from gpp.convites c where strpos(new.html, '?t=' || c.token) > 0 limit 1;
    if new.ciclo_id is null then
      select ci.id into new.ciclo_id from gpp.ciclos ci
      where ci.modulo = 'ocai' and strpos(new.assunto, ' ' || ci.trimestre) > 0 order by ci.abertura desc limit 1;
    end if;
  end if;
  return new;
end $$;
drop trigger if exists trg_email_fila_ciclo on gpp.email_fila;
create trigger trg_email_fila_ciclo before insert on gpp.email_fila for each row execute function gpp.email_fila_ciclo();

update gpp.email_fila f set ciclo_id = c.ciclo_id from gpp.convites c
 where f.ciclo_id is null and strpos(f.html, '?t=' || c.token) > 0;
update gpp.email_fila f set ciclo_id = ci.id from gpp.ciclos ci
 where f.ciclo_id is null and ci.modulo = 'ocai' and strpos(f.assunto, ' ' || ci.trimestre) > 0;

-- ---------- utilitário: apaga cenário criado automaticamente se o trimestre não for mais usado ----------
create or replace function gpp.limpar_cenario_auto(p_tri text) returns boolean
language plpgsql security definer set search_path to '' as $$
begin
  if exists (select 1 from gpp.ciclos where trimestre = p_tri) or exists (select 1 from gpp.ocai_historico where trimestre = p_tri) then
    return false; end if;
  delete from gpp.ocai_cenario_desejado where trimestre = p_tri and observacao like 'Copiado de % automaticamente';
  return found;
end $$;

-- ---------- CICLOS: editar (trimestre, prazo, reabrir) ----------
create or replace function public.gpp_admin_editar_ciclo(p jsonb) returns jsonb
language plpgsql security definer set search_path to '' as $$
declare c record; v_tri text; v_prazo timestamptz; v_status text; v_reaberto boolean := false;
begin
  perform gpp.exigir_admin();
  select * into c from gpp.ciclos where id = nullif(p ->> 'id', '')::uuid for update;
  if not found then raise exception 'Ciclo não encontrado.'; end if;

  v_tri := upper(trim(coalesce(nullif(p ->> 'trimestre', ''), c.trimestre)));
  if v_tri !~ '^[1-4]T/[0-9]{2}$' then raise exception 'Trimestre inválido. Use o formato 4T/26.'; end if;
  if v_tri <> c.trimestre then
    if exists (select 1 from gpp.ciclos where modulo = c.modulo and trimestre = v_tri and id <> c.id) then
      raise exception 'Já existe um ciclo para %.', v_tri; end if;
    if exists (select 1 from gpp.ocai_historico where trimestre = v_tri) then
      raise exception 'O trimestre % já está no histórico das planilhas.', v_tri; end if;
  end if;

  v_prazo := case when nullif(p ->> 'prazo', '') is null then c.prazo
                  else ((p ->> 'prazo')::date + time '23:59') at time zone 'America/Sao_Paulo' end;
  v_status := coalesce(nullif(p ->> 'status', ''), c.status);
  if v_status not in ('aberto', 'encerrado') then raise exception 'Situação inválida.'; end if;
  if c.status = 'aberto' and v_status = 'encerrado' then
    raise exception 'Para encerrar, use o botão "Encerrar e apurar agora" (ele apura e envia o resultado).'; end if;
  if v_status = 'aberto' then
    if exists (select 1 from gpp.ciclos where modulo = c.modulo and status = 'aberto' and id <> c.id) then
      raise exception 'Já existe outro ciclo aberto. Encerre-o antes de reabrir este.'; end if;
    if v_prazo <= now() then raise exception 'O prazo de um ciclo aberto precisa ser uma data futura.'; end if;
    v_reaberto := c.status = 'encerrado';
  end if;

  update gpp.ciclos set trimestre = v_tri, prazo = v_prazo, status = v_status,
    respondentes_final = case when v_status = 'aberto' then null else respondentes_final end
  where id = c.id;

  if v_tri <> c.trimestre then
    if not exists (select 1 from gpp.ocai_cenario_desejado where trimestre = v_tri) then
      insert into gpp.ocai_cenario_desejado (trimestre, cla, adocracia, mercado, hierarquia, observacao)
      select v_tri, cla, adocracia, mercado, hierarquia, 'Copiado de ' || trimestre || ' automaticamente'
      from gpp.ocai_cenario_desejado where trimestre = c.trimestre;
    end if;
    perform gpp.limpar_cenario_auto(c.trimestre);
  end if;
  return jsonb_build_object('trimestre', v_tri, 'reaberto', v_reaberto);
end $$;

-- ---------- CICLOS: excluir (convites, respostas, e-mails e cenário automático do ciclo) ----------
create or replace function public.gpp_admin_excluir_ciclo(p_id uuid) returns jsonb
language plpgsql security definer set search_path to '' as $$
declare c record; v_conv int; v_resp int; v_mail int; v_cen boolean;
begin
  perform gpp.exigir_admin();
  select * into c from gpp.ciclos where id = p_id for update;
  if not found then raise exception 'Ciclo não encontrado.'; end if;
  select count(*) into v_conv from gpp.convites where ciclo_id = c.id;
  select count(*) into v_resp from gpp.ocai_respostas where ciclo_id = c.id;
  select count(*) into v_mail from gpp.email_fila where ciclo_id = c.id;
  delete from gpp.ciclos where id = c.id;          -- cascata: convites, respostas, buffer e e-mails do ciclo
  v_cen := gpp.limpar_cenario_auto(c.trimestre);
  return jsonb_build_object('trimestre', c.trimestre, 'convites', v_conv, 'respostas', v_resp, 'emails', v_mail, 'cenario_removido', v_cen);
end $$;

-- ---------- CONVITES: adicionar Organizadores a um ciclo aberto ----------
create or replace function public.gpp_admin_adicionar_convites(p_ciclo uuid, p_organizadores uuid[]) returns integer
language plpgsql security definer set search_path to '' as $$
declare c record; v_url text; r record; v_n int := 0;
begin
  perform gpp.exigir_admin();
  select * into c from gpp.ciclos where id = p_ciclo;
  if not found then raise exception 'Ciclo não encontrado.'; end if;
  if c.status <> 'aberto' or now() > c.prazo then
    raise exception 'Só é possível incluir pessoas em um ciclo aberto e dentro do prazo. Se precisar, reabra ou prorrogue o ciclo antes.'; end if;
  v_url := nullif(trim(gpp.cfg('url_app')), '');
  if v_url is null then raise exception 'Endereço do site ainda não configurado (url_app).'; end if;
  if coalesce(array_length(p_organizadores, 1), 0) = 0 then raise exception 'Selecione pelo menos um Organizador.'; end if;
  if exists (select 1 from unnest(p_organizadores) x left join gpp.organizadores o on o.id = x
             where o.id is null or coalesce(trim(o.email), '') = '') then
    raise exception 'Todos os selecionados precisam ter e-mail cadastrado.'; end if;

  for r in insert into gpp.convites (ciclo_id, organizador_id)
           select c.id, x from unnest(p_organizadores) x
           on conflict (ciclo_id, organizador_id) do nothing
           returning token, organizador_id loop
    insert into gpp.email_fila (para, assunto, html, ciclo_id)
    select o.email, 'Pesquisa de Cultura DAEXE ' || c.trimestre || ' — sua participação',
           gpp.html_convite(o.nome, c.trimestre, v_url || '?t=' || r.token, c.prazo, false), c.id
    from gpp.organizadores o where o.id = r.organizador_id;
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;

-- ---------- CONVITES: reenviar o convite (mesmo link) ----------
create or replace function public.gpp_admin_reenviar_convite(p_convite uuid) returns void
language plpgsql security definer set search_path to '' as $$
declare v record; v_url text := nullif(trim(gpp.cfg('url_app')), '');
begin
  perform gpp.exigir_admin();
  select cv.token, cv.respondeu, ci.id ciclo_id, ci.trimestre, ci.prazo, ci.status, o.nome, o.email into v
  from gpp.convites cv join gpp.ciclos ci on ci.id = cv.ciclo_id join gpp.organizadores o on o.id = cv.organizador_id
  where cv.id = p_convite;
  if not found then raise exception 'Convite não encontrado.'; end if;
  if v.respondeu then raise exception 'Esta pessoa já respondeu.'; end if;
  if v.status <> 'aberto' or now() > v.prazo then raise exception 'O ciclo não está aberto.'; end if;
  if coalesce(trim(v.email), '') = '' then raise exception 'O Organizador não tem e-mail cadastrado.'; end if;
  if v_url is null then raise exception 'Endereço do site ainda não configurado (url_app).'; end if;
  insert into gpp.email_fila (para, assunto, html, ciclo_id) values (v.email,
    'Pesquisa de Cultura DAEXE ' || v.trimestre || ' — sua participação',
    gpp.html_convite(v.nome, v.trimestre, v_url || '?t=' || v.token, v.prazo, false), v.ciclo_id);
end $$;

-- ---------- CONVITES: remover (só quem ainda não respondeu) ----------
create or replace function public.gpp_admin_remover_convite(p_convite uuid) returns void
language plpgsql security definer set search_path to '' as $$
declare v record;
begin
  perform gpp.exigir_admin();
  select * into v from gpp.convites where id = p_convite for update;
  if not found then raise exception 'Convite não encontrado.'; end if;
  if v.respondeu then raise exception 'Esta pessoa já respondeu; o convite fica registrado para preservar a participação do ciclo.'; end if;
  delete from gpp.email_fila where enviado_em is null and strpos(html, '?t=' || v.token) > 0;
  delete from gpp.convites where id = v.id;
end $$;

-- ---------- ORGANIZADORES: salvar (mensagens claras) e excluir ----------
create or replace function public.gpp_admin_salvar_organizador(p jsonb) returns uuid
language plpgsql security definer set search_path to '' as $$
declare v_id uuid; v_email text := nullif(lower(trim(p ->> 'email')), ''); v_gestor uuid := nullif(p ->> 'gestor_id', '')::uuid; v_self uuid := nullif(p ->> 'id', '')::uuid;
begin
  perform gpp.exigir_admin();
  if coalesce(trim(p ->> 'nome'), '') = '' then raise exception 'Informe o nome.'; end if;
  if v_email is not null and v_email !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'E-mail inválido.'; end if;
  if v_email is not null and exists (select 1 from gpp.organizadores where email = v_email and id is distinct from v_self) then
    raise exception 'Já existe um Organizador com o e-mail %.', v_email; end if;
  if v_gestor is not null and v_gestor = v_self then raise exception 'O Organizador não pode ser gestor de si mesmo.'; end if;
  if v_gestor is not null and v_self is not null and exists (
      with recursive acima(id) as (select gestor_id from gpp.organizadores where id = v_gestor
                                   union select o.gestor_id from gpp.organizadores o join acima a on o.id = a.id where o.gestor_id is not null)
      select 1 from acima where id = v_self) then
    raise exception 'Esse gestor criaria uma hierarquia circular.'; end if;
  if v_self is null then
    insert into gpp.organizadores (nome, email, area, gestor_id, e_lider, ativo)
    values (trim(p ->> 'nome'), v_email, nullif(trim(p ->> 'area'), ''), v_gestor,
            coalesce((p ->> 'e_lider')::boolean, false), coalesce((p ->> 'ativo')::boolean, true))
    returning id into v_id;
  else
    update gpp.organizadores set nome = trim(p ->> 'nome'), email = v_email, area = nullif(trim(p ->> 'area'), ''),
      gestor_id = v_gestor, e_lider = coalesce((p ->> 'e_lider')::boolean, false), ativo = coalesce((p ->> 'ativo')::boolean, true)
    where id = v_self returning id into v_id;
    if v_id is null then raise exception 'Organizador não encontrado.'; end if;
  end if;
  return v_id;
end $$;

create or replace function public.gpp_admin_excluir_organizador(p_id uuid) returns void
language plpgsql security definer set search_path to '' as $$
begin
  perform gpp.exigir_admin();
  if not exists (select 1 from gpp.organizadores where id = p_id) then raise exception 'Organizador não encontrado.'; end if;
  if exists (select 1 from gpp.convites where organizador_id = p_id) then
    raise exception 'Este Organizador já foi convidado em ciclos. Para preservar o histórico de participação, inative-o (desmarque "Ativo") em vez de excluir — ou exclua antes os ciclos de teste.'; end if;
  update gpp.organizadores set gestor_id = null where gestor_id = p_id;
  delete from gpp.organizadores where id = p_id;
end $$;

-- ---------- CENÁRIO DESEJADO: salvar (congela apurados, inclusive histórico) e excluir ----------
create or replace function public.gpp_admin_salvar_cenario(p jsonb) returns void
language plpgsql security definer set search_path to '' as $$
declare v_tri text := upper(trim(p ->> 'trimestre')); v_soma numeric;
begin
  perform gpp.exigir_admin();
  if v_tri is null or v_tri !~ '^[1-4]T/[0-9]{2}$' then raise exception 'Trimestre inválido. Use o formato 1T/27.'; end if;
  if exists (select 1 from gpp.ciclos where modulo = 'ocai' and trimestre = v_tri and status = 'encerrado')
     or exists (select 1 from gpp.ocai_historico where trimestre = v_tri) then
    raise exception 'O trimestre % já foi apurado; os pesos dele ficam congelados para preservar o histórico.', v_tri; end if;
  v_soma := coalesce((p ->> 'cla')::numeric, 0) + coalesce((p ->> 'adocracia')::numeric, 0) + coalesce((p ->> 'mercado')::numeric, 0) + coalesce((p ->> 'hierarquia')::numeric, 0);
  if v_soma <> 100 then raise exception 'Os quatro pesos precisam somar 100 (hoje somam %).', v_soma; end if;
  insert into gpp.ocai_cenario_desejado (trimestre, cla, adocracia, mercado, hierarquia, observacao)
  values (v_tri, (p ->> 'cla')::numeric, (p ->> 'adocracia')::numeric, (p ->> 'mercado')::numeric, (p ->> 'hierarquia')::numeric, nullif(trim(p ->> 'observacao'), ''))
  on conflict (trimestre) do update set cla = excluded.cla, adocracia = excluded.adocracia,
    mercado = excluded.mercado, hierarquia = excluded.hierarquia, observacao = excluded.observacao;
end $$;

create or replace function public.gpp_admin_excluir_cenario(p_trimestre text) returns void
language plpgsql security definer set search_path to '' as $$
begin
  perform gpp.exigir_admin();
  if exists (select 1 from gpp.ciclos where trimestre = p_trimestre) or exists (select 1 from gpp.ocai_historico where trimestre = p_trimestre) then
    raise exception 'O trimestre % é usado por um ciclo ou pelo histórico; o cenário não pode ser excluído.', p_trimestre; end if;
  delete from gpp.ocai_cenario_desejado where trimestre = p_trimestre;
  if not found then raise exception 'Cenário não encontrado.'; end if;
end $$;

-- ---------- HISTÓRICO (planilhas): salvar e excluir ----------
create or replace function public.gpp_admin_salvar_historico(p jsonb) returns void
language plpgsql security definer set search_path to '' as $$
declare v_tri text := upper(trim(p ->> 'trimestre')); v_orig text := nullif(upper(trim(p ->> 'original')), '');
  v_c numeric := (p ->> 'cla')::numeric; v_a numeric := (p ->> 'adocracia')::numeric; v_m numeric := (p ->> 'mercado')::numeric; v_h numeric := (p ->> 'hierarquia')::numeric;
begin
  perform gpp.exigir_admin();
  if v_tri is null or v_tri !~ '^[1-4]T/[0-9]{2}$' then raise exception 'Trimestre inválido. Use o formato 2T/26.'; end if;
  if v_c is null or v_a is null or v_m is null or v_h is null or least(v_c, v_a, v_m, v_h) < 0 or greatest(v_c, v_a, v_m, v_h) > 100 then
    raise exception 'Informe os quatro quadrantes com valores de 0 a 100.'; end if;
  if abs(v_c + v_a + v_m + v_h - 100) > 1 then raise exception 'Os quatro quadrantes precisam somar 100 (hoje somam %).', v_c + v_a + v_m + v_h; end if;
  if exists (select 1 from gpp.ciclos where modulo = 'ocai' and trimestre = v_tri) then
    raise exception 'O trimestre % já tem um ciclo aplicado pelo sistema.', v_tri; end if;
  if v_tri is distinct from v_orig and exists (select 1 from gpp.ocai_historico where trimestre = v_tri) then
    raise exception 'O trimestre % já está no histórico.', v_tri; end if;
  if v_orig is not null and v_orig <> v_tri then delete from gpp.ocai_historico where trimestre = v_orig; end if;
  insert into gpp.ocai_historico (trimestre, respondentes, cla, adocracia, mercado, hierarquia, origem)
  values (v_tri, nullif(p ->> 'respondentes', '')::int, v_c, v_a, v_m, v_h, coalesce(nullif(trim(p ->> 'origem'), ''), 'Histórico (planilhas)'))
  on conflict (trimestre) do update set respondentes = excluded.respondentes, cla = excluded.cla, adocracia = excluded.adocracia,
    mercado = excluded.mercado, hierarquia = excluded.hierarquia, origem = excluded.origem;
end $$;

create or replace function public.gpp_admin_excluir_historico(p_trimestre text) returns void
language plpgsql security definer set search_path to '' as $$
begin
  perform gpp.exigir_admin();
  delete from gpp.ocai_historico where trimestre = p_trimestre;
  if not found then raise exception 'Trimestre não encontrado no histórico.'; end if;
end $$;

-- ---------- CONFIGURAÇÕES: validações ----------
create or replace function public.gpp_admin_salvar_config(p_chave text, p_valor text) returns void
language plpgsql security definer set search_path to '' as $$
declare v text := trim(coalesce(p_valor, ''));
begin
  perform gpp.exigir_admin();
  if p_chave in ('dias_resposta', 'lembrete_dias', 'minimo_respostas') and (v !~ '^[0-9]+$' or v::int < 1) then
    raise exception 'Use um número inteiro maior que zero.'; end if;
  if p_chave = 'abertura_automatica' then
    v := lower(v); if v = 'nao' then v := 'não'; end if;
    if v not in ('sim', 'não') then raise exception 'Use "sim" ou "não".'; end if; end if;
  if p_chave = 'url_app' and v !~* '^https?://[^\s]+$' then raise exception 'Informe um endereço completo, começando com https://'; end if;
  if p_chave = 'emails_resultado' and v <> '' and exists (
      select 1 from unnest(string_to_array(v, ',')) e where trim(e) <> '' and trim(e) !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$') then
    raise exception 'Há e-mail inválido na lista (separe por vírgula).'; end if;
  update gpp.config set valor = v where chave = p_chave;
  if not found then raise exception 'Parâmetro desconhecido.'; end if;
end $$;

-- ---------- E-MAILS: reenviar ou excluir item da fila ----------
create or replace function public.gpp_admin_email_acao(p_id bigint, p_acao text) returns void
language plpgsql security definer set search_path to '' as $$
begin
  perform gpp.exigir_admin();
  if p_acao = 'reenviar' then
    update gpp.email_fila set enviado_em = null, tentativas = 0, erro = null where id = p_id;
  elsif p_acao = 'excluir' then
    delete from gpp.email_fila where id = p_id;
  else raise exception 'Ação inválida.'; end if;
  if not found then raise exception 'E-mail não encontrado.'; end if;
end $$;

-- ---------- PAINEL: inclui convites de todos os ciclos, histórico e últimos e-mails ----------
create or replace function public.gpp_admin_painel() returns jsonb
language plpgsql security definer set search_path to '' as $$
declare v_aberto uuid;
begin
  perform gpp.exigir_admin();
  select id into v_aberto from gpp.ciclos where modulo = 'ocai' and status = 'aberto';
  return jsonb_build_object(
    'eu', (select coalesce(p.name, p.email) from public.profiles p where p.id = auth.uid()),
    'config', (select coalesce(jsonb_agg(to_jsonb(c) order by c.chave), '[]') from gpp.config c),
    'organizadores', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', o.id, 'nome', o.nome, 'email', o.email, 'area', o.area, 'gestor_id', o.gestor_id,
        'gestor', g.nome, 'e_lider', o.e_lider, 'ativo', o.ativo,
        'convites', (select count(*) from gpp.convites x where x.organizador_id = o.id)) order by o.nome), '[]')
      from gpp.organizadores o left join gpp.organizadores g on g.id = o.gestor_id),
    'cenarios', (select coalesce(jsonb_agg(to_jsonb(d) order by gpp.ordem_trimestre(d.trimestre)), '[]') from gpp.ocai_cenario_desejado d),
    'historico', (select coalesce(jsonb_agg(to_jsonb(h) order by gpp.ordem_trimestre(h.trimestre)), '[]') from gpp.ocai_historico h),
    'ciclos', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', c.id, 'modulo', c.modulo, 'trimestre', c.trimestre, 'status', c.status,
        'abertura', to_char(c.abertura at time zone 'America/Sao_Paulo', 'DD/MM/YYYY'),
        'prazo', to_char(c.prazo at time zone 'America/Sao_Paulo', 'DD/MM/YYYY'),
        'prazo_iso', to_char(c.prazo at time zone 'America/Sao_Paulo', 'YYYY-MM-DD'),
        'vencido', now() > c.prazo,
        'lembrete_enviado', c.lembrete_enviado,
        'respostas', (select count(*) from gpp.ocai_respostas r where r.ciclo_id = c.id),
        'convidados', (select count(*) from gpp.convites x where x.ciclo_id = c.id),
        'responderam', (select count(*) from gpp.convites x where x.ciclo_id = c.id and x.respondeu),
        'convites', (select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'organizador_id', o.id, 'nome', o.nome, 'email', o.email, 'respondeu', x.respondeu) order by o.nome), '[]')
                     from gpp.convites x join gpp.organizadores o on o.id = x.organizador_id where x.ciclo_id = c.id))
        order by c.abertura desc), '[]') from gpp.ciclos c),
    'pendentes', (select coalesce(jsonb_agg(jsonb_build_object('nome', o.nome, 'respondeu', x.respondeu) order by o.nome), '[]')
      from gpp.convites x join gpp.organizadores o on o.id = x.organizador_id where x.ciclo_id = v_aberto),
    'resultados', (select coalesce(jsonb_agg(to_jsonb(r) order by r.ordem), '[]') from gpp.v_ocai_resultados r),
    'emails', (select coalesce(jsonb_agg(e order by e.id desc), '[]') from (
        select f.id, f.para, f.assunto, f.tentativas, f.erro,
               to_char(f.criado_em at time zone 'America/Sao_Paulo', 'DD/MM HH24:MI') criado,
               to_char(f.enviado_em at time zone 'America/Sao_Paulo', 'DD/MM HH24:MI') enviado,
               (select trimestre from gpp.ciclos c where c.id = f.ciclo_id) trimestre
        from gpp.email_fila f order by f.id desc limit 60) e),
    'proxima_abertura', to_char(gpp.ultimo_dia_util_trimestre(gpp.hoje()), 'DD/MM/YYYY'),
    'proximo_trimestre', gpp.rotulo_trimestre(gpp.hoje()),
    'emails_pendentes', (select count(*) from gpp.email_fila where enviado_em is null),
    'emails_com_erro', (select count(*) from gpp.email_fila where enviado_em is null and erro is not null)
  );
end $$;

-- ---------- permissões: só usuários logados (cada função ainda exige admin da DAEXE) ----------
do $$ declare f text; begin
  foreach f in array array[
    'gpp_admin_editar_ciclo(jsonb)', 'gpp_admin_excluir_ciclo(uuid)', 'gpp_admin_adicionar_convites(uuid,uuid[])',
    'gpp_admin_reenviar_convite(uuid)', 'gpp_admin_remover_convite(uuid)', 'gpp_admin_salvar_organizador(jsonb)',
    'gpp_admin_excluir_organizador(uuid)', 'gpp_admin_salvar_cenario(jsonb)', 'gpp_admin_excluir_cenario(text)',
    'gpp_admin_salvar_historico(jsonb)', 'gpp_admin_excluir_historico(text)', 'gpp_admin_salvar_config(text,text)',
    'gpp_admin_email_acao(bigint,text)', 'gpp_admin_painel()'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
revoke all on function gpp.email_fila_ciclo() from public, anon, authenticated;
revoke all on function gpp.limpar_cenario_auto(text) from public, anon, authenticated;

commit;
