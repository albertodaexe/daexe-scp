-- gpp_08b: funções de exclusão do módulo Cultura & Desempenho + permissões.
-- Rode inteiro no SQL Editor do Supabase (projeto daexe-scp). Não apaga nenhum dado: só cria/atualiza funções.
begin;
create or replace function gpp.limpar_cenario_auto(p_tri text) returns boolean
language plpgsql security definer set search_path to '' as $$
begin
  if exists (select 1 from gpp.ciclos where trimestre = p_tri) or exists (select 1 from gpp.ocai_historico where trimestre = p_tri) then
    return false; end if;
  delete from gpp.ocai_cenario_desejado where trimestre = p_tri and observacao like 'Copiado de % automaticamente';
  return found;
end $$;

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

create or replace function public.gpp_admin_excluir_cenario(p_trimestre text) returns void
language plpgsql security definer set search_path to '' as $$
begin
  perform gpp.exigir_admin();
  if exists (select 1 from gpp.ciclos where trimestre = p_trimestre) or exists (select 1 from gpp.ocai_historico where trimestre = p_trimestre) then
    raise exception 'O trimestre % é usado por um ciclo ou pelo histórico; o cenário não pode ser excluído.', p_trimestre; end if;
  delete from gpp.ocai_cenario_desejado where trimestre = p_trimestre;
  if not found then raise exception 'Cenário não encontrado.'; end if;
end $$;

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
