create table public.af_bootstrap(id boolean primary key default true check(id),token_hash text not null,claimed boolean not null default false);
create table public.af_invitations(id uuid primary key default gen_random_uuid(),token_hash text not null unique,created_by uuid references public.af_profiles(id),expires_at timestamptz not null default now()+interval '48 hours',used boolean not null default false);
alter table public.af_bootstrap enable row level security;
alter table public.af_invitations enable row level security;
revoke all on public.af_bootstrap,public.af_invitations from public,anon,authenticated;
grant all on public.af_bootstrap,public.af_invitations to service_role;
grant all on public.af_profiles,public.af_events,public.af_modules to service_role;
insert into public.af_modules(id,data) values
('manager_invites','{"id":"manager_invites","name":"Invitations par le manager","description":"Autorisez les responsables à partager des liens d’inscription.","enabled":false,"category":"Délégation"}'),
('manager_access','{"id":"manager_access","name":"Gestion des accès par le manager","description":"Déléguez la création, l’activation et la réinitialisation des comptes collaborateurs.","enabled":false,"category":"Délégation"}');
