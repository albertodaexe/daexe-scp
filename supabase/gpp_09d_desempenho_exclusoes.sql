-- =====================================================================
-- GPP · Gestão do Desempenho (v45) — exclusões
-- Rode este arquivo no SQL Editor do Supabase (as exclusões pedem confirmação
-- que o conector do Claude não consegue exibir).
-- =====================================================================

-- Remove um item da matriz (só se o trimestre ainda não tem respostas)
create or replace function public.gpp_admin_des_excluir_item(p_id int)
returns void language plpgsql security definer set search_path = '' as $$
declare v_tri text;
begin
  perform gpp.exigir_admin();
  select trimestre into v_tri from gpp.des_itens where id = p_id;
  if not found then raise exception 'Item não encontrado.'; end if;
  if exists (select 1 from gpp.des_avaliacoes where trimestre = v_tri and respondida_em is not null) then
    raise exception 'Já há respostas em %: o item não pode ser removido.', v_tri; end if;
  delete from gpp.des_itens where id = p_id;
end $$;

-- Remove uma competência da biblioteca (só se nunca foi usada)
create or replace function public.gpp_admin_des_excluir_competencia(p_id int)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform gpp.exigir_admin();
  if exists (select 1 from gpp.des_itens where competencia_id = p_id) or exists (select 1 from gpp.des_pdi where competencia_id = p_id) then
    raise exception 'Esta competência já foi usada em matrizes ou PDI. Desative-a em vez de excluir.'; end if;
  delete from gpp.des_competencias where id = p_id;
  if not found then raise exception 'Competência não encontrada.'; end if;
end $$;

create or replace function public.gpp_admin_des_excluir_pdi(p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform gpp.exigir_admin();
  delete from gpp.des_pdi where id = p_id;
  if not found then raise exception 'Item de PDI não encontrado.'; end if;
end $$;

-- Exclui uma avaliação (e suas notas). Não mexe no NPS, que é anônimo.
create or replace function public.gpp_admin_des_excluir_avaliacao(p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform gpp.exigir_admin();
  delete from gpp.des_avaliacoes where id = p_id;
  if not found then raise exception 'Avaliação não encontrada.'; end if;
end $$;

-- Tira uma pessoa de um ciclo aberto (as duas avaliações dela; o link do gestor fica se ele tiver outros liderados)
create or replace function public.gpp_admin_des_remover_participante(p_ciclo uuid, p_avaliado uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform gpp.exigir_admin();
  if not exists (select 1 from gpp.ciclos where id = p_ciclo and modulo = 'desempenho' and status = 'aberto') then
    raise exception 'Só é possível remover pessoas de um ciclo aberto.'; end if;
  delete from gpp.des_avaliacoes where ciclo_id = p_ciclo and avaliado_id = p_avaliado;
  delete from gpp.des_links dl where dl.ciclo_id = p_ciclo
    and not exists (select 1 from gpp.des_avaliacoes a where a.ciclo_id = p_ciclo
                    and ((a.tipo = 'auto' and a.avaliado_id = dl.organizador_id) or (a.tipo = 'gestor' and a.avaliador_id = dl.organizador_id)));
end $$;

-- Exclui um ciclo inteiro: avaliações, notas, links, NPS e e-mails (a matriz do trimestre fica, para reaproveitar)
create or replace function public.gpp_admin_des_excluir_ciclo(p_id uuid, p_confirmacao text)
returns void language plpgsql security definer set search_path = '' as $$
declare c record;
begin
  perform gpp.exigir_admin();
  select * into c from gpp.ciclos where id = p_id and modulo = 'desempenho';
  if not found then raise exception 'Ciclo não encontrado.'; end if;
  if upper(trim(coalesce(p_confirmacao, ''))) <> c.trimestre then raise exception 'Digite % para confirmar.', c.trimestre; end if;
  delete from gpp.des_pdi where trimestre = c.trimestre and origem = 'gestor' and status = 'a definir';
  delete from gpp.ciclos where id = c.id;
end $$;

revoke execute on function public.gpp_admin_des_excluir_item(int), public.gpp_admin_des_excluir_competencia(int),
  public.gpp_admin_des_excluir_pdi(uuid), public.gpp_admin_des_excluir_avaliacao(uuid),
  public.gpp_admin_des_remover_participante(uuid, uuid), public.gpp_admin_des_excluir_ciclo(uuid, text) from public, anon;
grant execute on function public.gpp_admin_des_excluir_item(int), public.gpp_admin_des_excluir_competencia(int),
  public.gpp_admin_des_excluir_pdi(uuid), public.gpp_admin_des_excluir_avaliacao(uuid),
  public.gpp_admin_des_remover_participante(uuid, uuid), public.gpp_admin_des_excluir_ciclo(uuid, text) to authenticated;
