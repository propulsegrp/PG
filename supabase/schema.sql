-- Atelier Flow v1. Tables de production distinctes des données de démonstration.
create schema if not exists af_private;
revoke all on schema af_private from public, anon;
grant usage on schema af_private to authenticated;

create table public.af_profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 name text not null check(length(name) between 1 and 120),
 role text not null default 'collaborator' check(role in ('super_admin','manager','collaborator')),
 active boolean not null default false,
 job text not null default '', color text not null default '#dfe8d5',
 created_at timestamptz not null default now()
);
create table public.af_clients(id text primary key,data jsonb not null);
create table public.af_services(name text primary key check(length(name) between 1 and 120));
create table public.af_tasks(id text primary key,data jsonb not null,version integer not null default 1);
create table public.af_modules(id text primary key,data jsonb not null);
create table public.af_settings(id boolean primary key default true check(id),transfer_approval boolean not null default true);
create table public.af_declarations(author uuid references public.af_profiles(id),day date not null,data jsonb not null,primary key(author,day));
create table public.af_evaluations(id text primary key,person_id uuid not null references public.af_profiles(id),published boolean not null default false,data jsonb not null);
create table public.af_events(id uuid primary key default gen_random_uuid(),at timestamptz not null default now(),actor uuid references public.af_profiles(id),action text not null,detail text not null,task_id text,ip text);
create index af_tasks_assignee on public.af_tasks((data->>'assigneeId'));
create index af_evaluations_person on public.af_evaluations(person_id);
create index af_events_actor on public.af_events(actor,at desc);
create index af_events_task on public.af_events(task_id);

create function af_private.role() returns text language sql stable security definer set search_path='' as $$select role from public.af_profiles where id=auth.uid() and active$$;
revoke all on function af_private.role() from public,anon;
grant execute on function af_private.role() to authenticated;
create function af_private.task_visible(d jsonb) returns boolean language sql stable security invoker set search_path='' as $$select af_private.role() is not null and (af_private.role() in ('manager','super_admin') or d->>'assigneeId'=auth.uid()::text or d->'transfer'->>'to'=auth.uid()::text or exists(select 1 from jsonb_array_elements(coalesce(d->'interventions','[]')) i where i->>'author'=auth.uid()::text))$$;
revoke all on function af_private.task_visible(jsonb) from public,anon;
grant execute on function af_private.task_visible(jsonb) to authenticated;

alter table public.af_profiles enable row level security;
alter table public.af_clients enable row level security;
alter table public.af_services enable row level security;
alter table public.af_tasks enable row level security;
alter table public.af_modules enable row level security;
alter table public.af_settings enable row level security;
alter table public.af_declarations enable row level security;
alter table public.af_evaluations enable row level security;
alter table public.af_events enable row level security;
revoke all on public.af_profiles,public.af_clients,public.af_services,public.af_tasks,public.af_modules,public.af_settings,public.af_declarations,public.af_evaluations,public.af_events from anon,authenticated;
grant select on public.af_profiles,public.af_clients,public.af_services,public.af_tasks,public.af_modules,public.af_settings,public.af_declarations,public.af_evaluations,public.af_events to authenticated;
create policy profiles_read on public.af_profiles for select to authenticated using (id=auth.uid() or af_private.role() is not null);
create policy clients_read on public.af_clients for select to authenticated using (af_private.role() is not null);
create policy services_read on public.af_services for select to authenticated using (af_private.role() is not null);
create policy tasks_read on public.af_tasks for select to authenticated using (af_private.task_visible(data));
create policy modules_read on public.af_modules for select to authenticated using (af_private.role() is not null);
create policy settings_read on public.af_settings for select to authenticated using (af_private.role() is not null);
create policy declarations_read on public.af_declarations for select to authenticated using (af_private.role() is not null and (author=auth.uid() or af_private.role() in ('manager','super_admin')));
create policy evaluations_read on public.af_evaluations for select to authenticated using (af_private.role() is not null and (af_private.role() in ('manager','super_admin') or (person_id=auth.uid() and published)));
create policy events_read on public.af_events for select to authenticated using (af_private.role() is not null and (actor=auth.uid() or af_private.role() in ('manager','super_admin') or exists(select 1 from public.af_tasks t where t.id=task_id)));

-- Aucun profil ne reçoit de privilège à partir de métadonnées modifiables par le client.
create function af_private.new_user() returns trigger language plpgsql security definer set search_path='' as $$begin insert into public.af_profiles(id,name) values(new.id,coalesce(nullif(left(new.raw_user_meta_data->>'name',120),''),'Nouveau collaborateur'));return new;end$$;
revoke all on function af_private.new_user() from public,anon,authenticated;
create trigger af_new_user after insert on auth.users for each row execute function af_private.new_user();

create function public.af_state() returns jsonb language sql stable security invoker set search_path='' as $$select jsonb_build_object(
 'people',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'role',role,'active',active,'job',job,'color',color)) from public.af_profiles),'[]'),
 'clients',coalesce((select jsonb_agg(data) from public.af_clients),'[]'),
 'services',coalesce((select jsonb_agg(name order by name) from public.af_services),'[]'),
 'tasks',coalesce((select jsonb_agg(data||jsonb_build_object('_version',version)) from public.af_tasks),'[]'),
 'modules',coalesce((select jsonb_agg(data order by id) from public.af_modules),'[]'),
 'declarations',coalesce((select jsonb_agg(data) from public.af_declarations),'[]'),
 'evaluations',coalesce((select jsonb_agg(data||jsonb_build_object('published',published)) from public.af_evaluations),'[]'),
 'events',coalesce((select jsonb_agg(x.obj order by x.at desc) from (select at,jsonb_build_object('id',id,'at',at,'actor',actor,'action',action,'detail',detail,'taskId',task_id,'ip',ip) obj from public.af_events order by at desc limit 500)x),'[]'),
 'transferApproval',coalesce((select transfer_approval from public.af_settings limit 1),true))$$;
revoke all on function public.af_state() from public,anon;
grant execute on function public.af_state() to authenticated;

-- Seul point d'écriture métier. Les vérifications sont faites sur l'état serveur verrouillé.
create function af_private.apply(p_action text,p jsonb) returns void language plpgsql security definer set search_path='' as $$
declare
 u uuid:=auth.uid(); r text; managing boolean; d jsonb; n jsonb; i jsonb; tr jsonb; tid text; target text; idx integer; ver integer; day date; enabled boolean; require_approval boolean; e jsonb; ip text;
begin
 if u is null then raise exception 'Connexion requise';end if;
 select role into r from public.af_profiles where id=u and active;
 if r is null then raise exception 'Compte en attente ou suspendu';end if;
 managing:=r in ('manager','super_admin');
 tid:=p->>'taskId';
 if tid is not null then
  select data,version into d,ver from public.af_tasks where id=tid for update;
  if d is null or not af_private.task_visible(d) then raise exception 'Tâche inaccessible';end if;
  if coalesce((p->>'version')::integer,0)<>ver then raise exception 'Cette tâche a changé. Actualisez avant de réessayer.';end if;
 end if;
 if p_action='Tâche créée' then
  n:=p->'task';tid:=n->>'id';
  if not managing and n->>'assigneeId'<>u::text then raise exception 'Attribution non autorisée';end if;
  if not exists(select 1 from public.af_profiles where id=(n->>'assigneeId')::uuid and active) then raise exception 'Responsable invalide';end if;
  if not exists(select 1 from public.af_clients where id=n->>'clientId') or not exists(select 1 from public.af_services where name=n->>'service') then raise exception 'Client ou service invalide';end if;
  if length(trim(n->>'title')) not between 1 and 160 or coalesce((n->>'quantity')::integer,0) not between 1 and 100000 or (n->>'due')::date<(n->>'start')::date or coalesce((n->>'estimate')::numeric,0)<0 or not (n->>'priority'=any(array['Basse','Normale','Haute','Urgente'])) then raise exception 'Données de tâche invalides';end if;
  n:=n-'transfer'-'_version'||jsonb_build_object('status','À faire','interventions','[]'::jsonb);
  insert into public.af_tasks(id,data) values(tid,n);
 elsif p_action='Intervention ajoutée' then
  if not managing and d->>'assigneeId'<>u::text then raise exception 'Intervention non autorisée';end if;
  i:=p->'intervention';day:=(i->>'date')::date;
  if day>(now() at time zone 'Africa/Abidjan')::date or length(trim(i->>'description'))<1 or not(i->>'kind'=any(array['Création','Modification','Avancement'])) or coalesce((i->>'quantity')::integer,-1) not between 0 and 100000 then raise exception 'Intervention invalide';end if;
  if i->>'kind'='Modification' and length(trim(coalesce(i->>'reason','')))=0 then raise exception 'Motif requis';end if;
  i:=jsonb_build_object('id',gen_random_uuid(),'author',u,'date',day,'createdAt',now(),'kind',i->>'kind','description',left(i->>'description',10000),'reason',left(coalesce(i->>'reason',''),2000),'quantity',case when i->>'kind'='Création' then (i->>'quantity')::integer else 0 end);
  n:=jsonb_set(d,'{interventions}',(d->'interventions')||jsonb_build_array(i));
  if d->>'status' in ('À faire','Terminé') then n:=jsonb_set(n,'{status}','"En cours"');end if;
  update public.af_tasks set data=n,version=version+1 where id=tid;
 elsif p_action in ('Statut modifié','Blocage signalé') then
  if not managing and d->>'assigneeId'<>u::text then raise exception 'Changement non autorisé';end if;
  target:=p->>'status';if not(target=any(array['À faire','En cours','En revue','Terminé','Bloqué'])) then raise exception 'Statut invalide';end if;
  if target='Bloqué' and length(trim(coalesce(p->>'reason','')))=0 then raise exception 'Motif requis';end if;
  n:=jsonb_set(d-'blockedReason','{status}',to_jsonb(target));if target='Bloqué' then n:=n||jsonb_build_object('blockedReason',left(p->>'reason',2000));end if;
  update public.af_tasks set data=n,version=version+1 where id=tid;
 elsif p_action='Visa du responsable' then
  if not managing then raise exception 'Visa réservé au responsable';end if;
  target:=p->>'visa';if not(target=any(array['Vu','Validé','Correction demandée'])) then raise exception 'Visa invalide';end if;
  select ordinality::integer-1 into idx from jsonb_array_elements(d->'interventions') with ordinality x(item,ordinality) where item->>'id'=p->>'interventionId';
  if idx is null then raise exception 'Intervention introuvable';end if;
  i:=d->'interventions'->idx||jsonb_build_object('visa',target,'reviewer',u,'reviewedAt',now());
  update public.af_tasks set data=jsonb_set(d,array['interventions',idx::text],i),version=version+1 where id=tid;
 elsif p_action in ('Transfert demandé','Transfert autorisé','Transfert refusé','Prise en charge confirmée') then
  select coalesce((data->>'enabled')::boolean,false) into enabled from public.af_modules where id='transfer';
  if not coalesce(enabled,false) then raise exception 'Module de transfert désactivé';end if;
  tr:=d->'transfer';
  if p_action='Transfert demandé' then
   if not managing and d->>'assigneeId'<>u::text then raise exception 'Transfert non autorisé';end if;
   if tr->>'state' in ('En attente','À réceptionner') then raise exception 'Transfert déjà en cours';end if;
   target:=p->'transfer'->>'to';
   if target=d->>'assigneeId' or not exists(select 1 from public.af_profiles where id=target::uuid and active) then raise exception 'Destinataire invalide';end if;
   if length(trim(p->'transfer'->>'reason'))<1 or length(trim(p->'transfer'->>'handoff'))<1 then raise exception 'Motif et point de reprise requis';end if;
   select transfer_approval into require_approval from public.af_settings;
   tr:=jsonb_build_object('to',target,'reason',left(p->'transfer'->>'reason',2000),'handoff',left(p->'transfer'->>'handoff',5000),'requestedBy',u,'at',now(),'state',case when managing or not require_approval then 'À réceptionner' else 'En attente' end);
  elsif p_action in ('Transfert autorisé','Transfert refusé') then
   if not managing or tr->>'state'<>'En attente' then raise exception 'Décision non autorisée';end if;
   tr:=tr||jsonb_build_object('state',case when p_action='Transfert autorisé' then 'À réceptionner' else 'Refusé' end,'approvedBy',u);
  else
   if tr->>'state'<>'À réceptionner' or tr->>'to'<>u::text then raise exception 'Réception non autorisée';end if;
   d:=jsonb_set(d,'{assigneeId}',to_jsonb(u::text));tr:=tr||jsonb_build_object('state','Accepté');
  end if;
  update public.af_tasks set data=jsonb_set(d,'{transfer}',tr),version=version+1 where id=tid;
 elsif p_action='Client ajouté' then
  if not managing then raise exception 'Action réservée au responsable';end if;
  n:=p->'client';if length(trim(n->>'name')) not between 1 and 120 then raise exception 'Nom invalide';end if;
  insert into public.af_clients(id,data) values(n->>'id',jsonb_build_object('id',n->>'id','name',n->>'name','type',n->>'type','color','#6d8b59'));
 elsif p_action='Service ajouté' then
  if not managing then raise exception 'Action réservée au responsable';end if;
  insert into public.af_services(name) values(trim(p->>'service'));
 elsif p_action='Module modifié' then
  if r<>'super_admin' then raise exception 'Action réservée au super administrateur';end if;
  if p->>'moduleId'='attachments' then raise exception 'Stockage à configurer avant activation';end if;
  if p->>'moduleId'='transfer' and not (p->>'enabled')::boolean and exists(select 1 from public.af_tasks where data->'transfer'->>'state' in ('En attente','À réceptionner')) then raise exception 'Des transferts sont encore en attente';end if;
  update public.af_modules set data=jsonb_set(data,'{enabled}',p->'enabled') where id=p->>'moduleId';
 elsif p_action='Règle modifiée' then
  if r<>'super_admin' then raise exception 'Action réservée au super administrateur';end if;
  update public.af_settings set transfer_approval=(p->>'transferApproval')::boolean;
 elsif p_action='Journée déclarée' then
  day:=(now() at time zone 'Africa/Abidjan')::date;
  enabled:=(p->>'empty')::boolean;
  if enabled and exists(select 1 from public.af_tasks t,jsonb_array_elements(t.data->'interventions') as entry(value) where entry.value->>'author'=u::text and (entry.value->>'date')::date=day) then raise exception 'Du travail a déjà été déclaré';end if;
  if not enabled and not exists(select 1 from public.af_tasks t,jsonb_array_elements(t.data->'interventions') as entry(value) where entry.value->>'author'=u::text and (entry.value->>'date')::date=day) then raise exception 'Ajoutez une intervention avant de confirmer votre journée';end if;
  n:=jsonb_build_object('author',u,'date',day,'empty',enabled,'note',left(p->>'note',5000),'createdAt',now());
  insert into public.af_declarations(author,day,data) values(u,day,n) on conflict on constraint af_declarations_pkey do update set data=excluded.data;
 elsif p_action in ('Évaluation préparée','Évaluation publiée') then
  if not managing or not exists(select 1 from public.af_modules where id='evaluation' and (data->>'enabled')::boolean) then raise exception 'Évaluation non autorisée';end if;
  if p_action='Évaluation préparée' then
   e:=p->'evaluation';if jsonb_array_length(e->'scores')<>4 or exists(select 1 from jsonb_array_elements_text(e->'scores') score where score::numeric<0 or score::numeric>5) then raise exception 'Barème invalide';end if;
   if not exists(select 1 from public.af_profiles where id=(e->>'personId')::uuid and role='collaborator') then raise exception 'Collaborateur invalide';end if;
   e:=e||jsonb_build_object('published',false);insert into public.af_evaluations(id,person_id,data) values(e->>'id',(e->>'personId')::uuid,e);
  else update public.af_evaluations set published=true,data=data||'{"published":true}'::jsonb where id=p->>'evaluationId';end if;
 else raise exception 'Action inconnue';end if;
 -- IP transmise par la passerelle. Ne jamais accepter une IP fournie dans le corps métier.
 ip:=split_part(coalesce(nullif(current_setting('request.headers',true),'')::jsonb->>'x-forwarded-for',''),',',1);
 insert into public.af_events(actor,action,detail,task_id,ip) values(u,p_action,left(coalesce(p->>'detail',p_action),2000),tid,nullif(ip,''));
end$$;
revoke all on function af_private.apply(text,jsonb) from public,anon;
grant execute on function af_private.apply(text,jsonb) to authenticated;
create function public.af_apply(p_action text,p jsonb) returns void language sql security invoker set search_path='' as $$select af_private.apply(p_action,p)$$;
revoke all on function public.af_apply(text,jsonb) from public,anon;
grant execute on function public.af_apply(text,jsonb) to authenticated;

insert into public.af_settings(id) values(true);
insert into public.af_services(name) values('Visuel réseaux sociaux'),('Visuel print'),('Vidéo'),('Motion design'),('Spot publicitaire');
insert into public.af_modules(id,data) values
('workload','{"id":"workload","name":"Charge de travail & priorités","description":"Disponibilités, échéances et blocages de votre équipe.","enabled":true,"category":"Organisation"}'),
('transfer','{"id":"transfer","name":"Transfert de tâches","description":"Passage de relais avec autorisation et historique.","enabled":true,"category":"Organisation"}'),
('evaluation','{"id":"evaluation","name":"Évaluations","description":"Fiches de notation et publication individuelle.","enabled":false,"category":"Équipe"}'),
('attachments','{"id":"attachments","name":"Pièces jointes","description":"Stockage à connecter ultérieurement.","enabled":false,"category":"Production"}'),
('reminders','{"id":"reminders","name":"Rappels quotidiens","description":"Rappels dans l’application après 18 h en semaine.","enabled":true,"category":"Équipe"}');
