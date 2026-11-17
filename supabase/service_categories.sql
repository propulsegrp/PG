alter table public.af_services add column category text not null default 'Autres' check(category in ('Visuels','Vidéos','Couvertures média','Autres'));
update public.af_services set category='Visuels' where name in ('Visuel réseaux sociaux','Visuel print');
update public.af_services set category='Vidéos' where name in ('Vidéo','Motion design','Spot publicitaire');
insert into public.af_services(name,category) values('Couverture média','Couvertures média') on conflict(name) do update set category=excluded.category;
CREATE OR REPLACE FUNCTION public.af_state()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$select jsonb_build_object(
 'people',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'role',role,'active',active,'job',job,'color',color)) from public.af_profiles),'[]'),
 'clients',coalesce((select jsonb_agg(data) from public.af_clients),'[]'),
 'services',coalesce((select jsonb_agg(name order by name) from public.af_services),'[]'),
 'serviceCategories',coalesce((select jsonb_object_agg(name,category) from public.af_services),'{}'::jsonb),
 'tasks',coalesce((select jsonb_agg(data||jsonb_build_object('_version',version)) from public.af_tasks),'[]'),
 'modules',coalesce((select jsonb_agg(data order by id) from public.af_modules),'[]'),
 'declarations',coalesce((select jsonb_agg(data) from public.af_declarations),'[]'),
 'evaluations',coalesce((select jsonb_agg(data||jsonb_build_object('published',published)) from public.af_evaluations),'[]'),
 'events',coalesce((select jsonb_agg(x.obj order by x.at desc) from (select at,jsonb_build_object('id',id,'at',at,'actor',actor,'action',action,'detail',detail,'taskId',task_id,'ip',ip) obj from public.af_events order by at desc limit 500)x),'[]'),
 'transferApproval',coalesce((select transfer_approval from public.af_settings limit 1),true))$function$
;
create function af_private.save_service(p_name text,p_category text,p_create boolean default false) returns void language plpgsql security definer set search_path='' as $fn$
declare u uuid:=auth.uid();r text;begin
 if u is null then raise exception 'Connexion requise';end if;
 select role into r from public.af_profiles where id=u and active;
 if r is null or r not in ('super_admin','manager') then raise exception 'Action réservée au responsable';end if;
 if p_name is null or length(trim(p_name)) not between 1 and 120 or p_category is null or p_category not in ('Visuels','Vidéos','Couvertures média','Autres') then raise exception 'Service ou catégorie invalide';end if;
 if p_create then insert into public.af_services(name,category) values(trim(p_name),p_category);
 else update public.af_services set category=p_category where name=p_name; if not found then raise exception 'Service introuvable';end if;end if;
 insert into public.af_events(actor,action,detail) values(u,case when p_create then 'Service ajouté' else 'Catégorie de service modifiée' end,trim(p_name)||' : '||p_category);
end $fn$;
revoke all on function af_private.save_service(text,text,boolean) from public,anon;
grant execute on function af_private.save_service(text,text,boolean) to authenticated;
create function public.af_save_service(p_name text,p_category text,p_create boolean default false) returns void language sql security invoker set search_path='' as $fn$select af_private.save_service(p_name,p_category,p_create)$fn$;
revoke all on function public.af_save_service(text,text,boolean) from public,anon;
grant execute on function public.af_save_service(text,text,boolean) to authenticated;
