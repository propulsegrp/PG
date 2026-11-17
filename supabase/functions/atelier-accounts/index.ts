import {createClient} from 'npm:@supabase/supabase-js@2.110.0';
import {canManageAccount,canAssignRole} from './permissions.ts';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
const reply=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers:{...cors,'Content-Type':'application/json','Cache-Control':'no-store'}});
const hash=async(s:string)=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(s)))).map(v=>v.toString(16).padStart(2,'0')).join('');
const random=()=>Array.from(crypto.getRandomValues(new Uint8Array(24))).map(v=>v.toString(16).padStart(2,'0')).join('');
const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
Deno.serve(async req=>{if(req.method==='OPTIONS')return new Response('ok',{headers:cors});if(req.method!=='POST')return reply({error:'Méthode refusée'},405);try{
 if(Number(req.headers.get('content-length')||0)>20000)return reply({error:'Requête trop volumineuse'},413);
 const body=await req.json();const action=body.action;let actor:string|null=null;const ip=req.headers.get('x-forwarded-for')?.split(',')[0]||null;
 if(action==='setup'){
  if(typeof body.token!=='string'||body.token.length<40||typeof body.password!=='string'||body.password.length<12||typeof body.email!=='string'||!body.email.includes('@')||typeof body.name!=='string'||!body.name.trim())return reply({error:'Données de configuration invalides'},400);
  const {data:claim,error}=await admin.from('af_bootstrap').update({claimed:true}).eq('id',true).eq('claimed',false).eq('token_hash',await hash(body.token)).select('id');if(error||!claim?.length)return reply({error:'Lien de configuration invalide ou déjà utilisé'},403);
  const {data,error:authError}=await admin.auth.admin.createUser({email:body.email,password:body.password,email_confirm:true,user_metadata:{name:body.name.trim().slice(0,120)}});
  if(authError){await admin.from('af_bootstrap').update({claimed:false}).eq('id',true);return reply({error:'Création impossible. Vérifiez l’adresse et réessayez.'},400)}
  const {error:profileError}=await admin.from('af_profiles').update({role:'super_admin',active:true}).eq('id',data.user.id);if(profileError){await admin.auth.admin.deleteUser(data.user.id);await admin.from('af_bootstrap').update({claimed:false}).eq('id',true);return reply({error:'Configuration non terminée. Réessayez.'},500)}
  await admin.from('af_events').insert({actor:data.user.id,action:'Super administrateur créé',detail:'Configuration initiale de l’espace',ip});return reply({ok:true});
 }
 if(action==='register'){
  if(typeof body.token!=='string'||body.token.length<40||typeof body.name!=='string'||!body.name.trim()||typeof body.email!=='string'||!body.email.includes('@'))return reply({error:'Inscription invalide'},400);
  const {data:claim,error}=await admin.from('af_invitations').update({used:true}).eq('token_hash',await hash(body.token)).eq('used',false).gt('expires_at',new Date().toISOString()).select('id');if(error||!claim?.length)return reply({error:'Lien expiré ou déjà utilisé'},403);
  const {data,error:authError}=await admin.auth.admin.createUser({email:body.email,password:random(),email_confirm:true,user_metadata:{name:body.name.trim().slice(0,120)}});
  if(authError){await admin.from('af_invitations').update({used:false}).eq('id',claim[0].id);return reply({error:'Inscription impossible. Contactez votre responsable.'},400)}
  await admin.from('af_events').insert({actor:data.user.id,action:'Inscription en attente',detail:'Activation et code requis',ip});return reply({ok:true});
 }
 const bearer=req.headers.get('Authorization')||'';const {data:{user},error:authError}=await admin.auth.getUser(bearer.replace(/^Bearer\s+/i,''));if(authError||!user)return reply({error:'Connexion requise'},401);
 const {data:profile}=await admin.from('af_profiles').select('role,active').eq('id',user.id).single();if(!profile?.active||!['super_admin','manager'].includes(profile.role))return reply({error:'Accès refusé'},403);actor=user.id;
 const module=action==='invite'?'manager_invites':'manager_access';if(profile.role==='manager'){const {data:m}=await admin.from('af_modules').select('data').eq('id',module).single();if(!m?.data?.enabled)return reply({error:'Cette délégation n’est pas activée.'},403)}
 if(action==='invite'){const token=random();const {error}=await admin.from('af_invitations').insert({token_hash:await hash(token),created_by:actor});if(error)throw error;await admin.from('af_events').insert({actor,action:'Lien d’inscription créé',detail:'Lien individuel valable 48 heures',ip});return reply({token})}
 if(action==='create'){
  if(typeof body.email!=='string'||!body.email.includes('@')||typeof body.name!=='string'||!body.name.trim())return reply({error:'Nom et e-mail requis'},400);
  const role=profile.role==='super_admin'&&body.role==='manager'?'manager':'collaborator';const password=random();const {data,error}=await admin.auth.admin.createUser({email:body.email,password,email_confirm:true,user_metadata:{name:body.name.trim().slice(0,120)}});if(error)return reply({error:'Compte non créé. Vérifiez l’adresse ou contactez l’administrateur.'},400);
  const {error:pe}=await admin.from('af_profiles').update({role,active:true}).eq('id',data.user.id);if(pe){await admin.auth.admin.deleteUser(data.user.id);throw pe}await admin.from('af_events').insert({actor,action:'Compte créé et activé',detail:body.name.trim().slice(0,120),ip});return reply({password});
 }
 if(action==='permissions'){
  const {data:target}=await admin.from('af_profiles').select('id,role,name,active').eq('id',body.userId).single();
  if(!target||!canManageAccount(profile.role,target.role,target.id===actor)||!canAssignRole(profile.role,body.role)||typeof body.active!=='boolean')return reply({error:'Modification de rôle ou d’accès non autorisée'},403);
  if(!body.active){const {error}=await admin.from('af_profiles').update({active:false}).eq('id',target.id);if(error)throw error;}
  const {error:banError}=await admin.auth.admin.updateUserById(target.id,{ban_duration:body.active?'none':'876000h'});if(banError)throw banError;
  const {error}=await admin.from('af_profiles').update({role:body.role,active:body.active}).eq('id',target.id);if(error)throw error;
  await admin.from('af_events').insert({actor,action:'Rôle et accès modifiés',detail:target.name+' : '+target.role+' → '+body.role+' · '+(body.active?'Accès actif':'Accès suspendu'),ip});return reply({ok:true});
 }
 if(action==='activate'){
  const {data:target}=await admin.from('af_profiles').select('id,role,name').eq('id',body.userId).single();if(!target||!canManageAccount(profile.role,target.role,target.id===actor))return reply({error:'Action non autorisée sur ce compte'},403);
  const password=random();const {error}=await admin.auth.admin.updateUserById(target.id,{password,ban_duration:'none'});if(error)throw error;const {error:pe}=await admin.from('af_profiles').update({active:true}).eq('id',target.id);if(pe)throw pe;await admin.from('af_events').insert({actor,action:'Accès généré',detail:target.name,ip});return reply({password});
 }
 return reply({error:'Action inconnue'},400);
}catch{return reply({error:'L’opération a échoué. Réessayez ou contactez l’administrateur.'},500)}});
