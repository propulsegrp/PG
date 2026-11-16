-- Test transactionnel : aucune donnée ou identité de test n'est conservée.
begin;
insert into auth.users(id,raw_user_meta_data) values
('00000000-0000-4000-a000-000000000021','{"name":"Test Admin"}'),
('00000000-0000-4000-a000-000000000022','{"name":"Test Designer"}'),
('00000000-0000-4000-a000-000000000023','{"name":"Test Recipient"}');
update public.af_profiles set active=true,role=case when id='00000000-0000-4000-a000-000000000021' then 'super_admin' else 'collaborator' end where id in ('00000000-0000-4000-a000-000000000021','00000000-0000-4000-a000-000000000022','00000000-0000-4000-a000-000000000023');
select set_config('request.jwt.claim.sub','00000000-0000-4000-a000-000000000021',true);
select public.af_apply('Client ajouté','{"client":{"id":"TEST-CLIENT","name":"Client de test","type":"Test"}}');
select public.af_apply('Tâche créée',jsonb_build_object('task',jsonb_build_object('id','TEST-TASK','title','Test de bout en bout','brief','Test','clientId','TEST-CLIENT','assigneeId','00000000-0000-4000-a000-000000000022','service','Visuel print','quantity',3,'priority','Haute','start',current_date,'due',current_date,'estimate',2)));
select set_config('request.jwt.claim.sub','00000000-0000-4000-a000-000000000022',true);
select public.af_apply('Intervention ajoutée',jsonb_build_object('taskId','TEST-TASK','version',1,'intervention',jsonb_build_object('date',current_date,'kind','Création','description','Création de 2 affiches','quantity',2)));
select public.af_apply('Transfert demandé','{"taskId":"TEST-TASK","version":2,"transfer":{"to":"00000000-0000-4000-a000-000000000023","reason":"Nouvelle priorité","handoff":"Deux affiches prêtes, une à terminer"}}');
select set_config('request.jwt.claim.sub','00000000-0000-4000-a000-000000000021',true);
select public.af_apply('Transfert autorisé','{"taskId":"TEST-TASK","version":3}');
select set_config('request.jwt.claim.sub','00000000-0000-4000-a000-000000000023',true);
select public.af_apply('Prise en charge confirmée','{"taskId":"TEST-TASK","version":4}');
select public.af_apply('Intervention ajoutée',jsonb_build_object('taskId','TEST-TASK','version',5,'intervention',jsonb_build_object('date',current_date,'kind','Modification','description','Retouche de la typographie','reason','Retour client','quantity',8)));
select public.af_apply('Journée déclarée','{"empty":false,"note":"Travail de test"}');
do $$declare d jsonb;begin select data into d from public.af_tasks where id='TEST-TASK';
if d->>'assigneeId'<>'00000000-0000-4000-a000-000000000023' then raise exception 'Mauvais destinataire';end if;
if d->'interventions'->0->>'author'<>'00000000-0000-4000-a000-000000000022' then raise exception 'Auteur initial perdu';end if;
if (d->'interventions'->1->>'quantity')::integer<>0 then raise exception 'Retouche comptée comme création';end if;
begin perform public.af_apply('Module modifié','{"moduleId":"evaluation","enabled":true}');raise exception 'Privilège illégal accordé';exception when others then if sqlerrm='Privilège illégal accordé' then raise;end if;end;
begin perform public.af_apply('Statut modifié','{"taskId":"TEST-TASK","version":1,"status":"Terminé"}');raise exception 'Conflit non détecté';exception when others then if sqlerrm='Conflit non détecté' then raise;end if;end;
end$$;
select 'Création, intervention, autorisation, transfert, retouche, déclaration et conflits : OK' as verification;
rollback;
