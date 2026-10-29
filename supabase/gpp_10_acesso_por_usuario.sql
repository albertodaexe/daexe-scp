-- v46 (já aplicado no Supabase): acesso ao módulo Cultura & Desempenho por usuário
alter table public.profiles add column if not exists gpp_acesso boolean not null default false;
comment on column public.profiles.gpp_acesso is 'Acesso ao módulo Cultura & Desempenho (GPP). Administradores da DAEXE têm acesso sempre.';

-- quem não é administrador não consegue se dar acesso pelo Meu Perfil
create or replace function public.protect_profile_fields()
 returns trigger language plpgsql security definer set search_path to 'public' as $function$
begin
  if auth.uid() = new.id and coalesce(public.user_role(),'') <> 'admin' then
    new.role := old.role; new.department_id := old.department_id; new.active := old.active;
    new.gpp_acesso := old.gpp_acesso;
  end if;
  return new;
end $function$;

-- regra de acesso usada por todas as funções gpp_admin_*
create or replace function gpp.e_admin()
 returns boolean language sql stable security definer set search_path to '' as $$
  select exists (select 1 from public.profiles p
                 where p.id = auth.uid() and p.org_id = 1 and coalesce(p.active, true)
                   and (p.role = 'admin' or p.gpp_acesso))
$$;
