import {createClient} from '@supabase/supabase-js';
import type {State,Task} from '@atelier/core';
// Clé publiable : elle identifie le projet ; l'accès est protégé par Auth et RLS.
export const supabase=createClient('https://vagwswaaozwvjzipfeuh.supabase.co','sb_publishable_pBAkCkq3nrwwGQShO2EZew_hlXiyXTm');
export async function loadRemote():Promise<State>{const {data,error}=await supabase.rpc('af_state');if(error)throw error;return data as State;}
export async function applyRemote(action:string,detail:string,before:State,after:State,taskId?:string){const p:any={detail};const oldTask=before.tasks.find(t=>t.id===taskId) as (Task&{_version:number})|undefined;const t=after.tasks.find(t=>t.id===taskId);if(taskId&&oldTask){p.taskId=taskId;p.version=oldTask._version;}
 switch(action){
 case 'Tâche créée':p.task=after.tasks.find(t=>!before.tasks.some(x=>x.id===t.id));break;
 case 'Intervention ajoutée':p.intervention=t!.interventions.find(i=>!oldTask!.interventions.some(x=>x.id===i.id));break;
 case 'Statut modifié':case 'Blocage signalé':p.status=t!.status;p.reason=t!.blockedReason||'';break;
 case 'Visa du responsable':{const i=t!.interventions.find(i=>{const old=oldTask!.interventions.find(x=>x.id===i.id);return old?.visa!==i.visa||old?.reviewedAt!==i.reviewedAt});p.interventionId=i!.id;p.visa=i!.visa;break;}
 case 'Transfert demandé':p.transfer=t!.transfer;break;
 case 'Transfert autorisé':case 'Transfert refusé':case 'Prise en charge confirmée':break;
 case 'Client ajouté':p.client=after.clients.find(c=>!before.clients.some(x=>x.id===c.id));break;
 case 'Service ajouté':p.service=after.services.find(v=>!before.services.includes(v));break;
 case 'Module modifié':{const m=after.modules.find(m=>m.enabled!==before.modules.find(x=>x.id===m.id)?.enabled)!;p.moduleId=m.id;p.enabled=m.enabled;break;}
 case 'Règle modifiée':p.transferApproval=after.transferApproval;break;
 case 'Journée déclarée':{const d=after.declarations.find(d=>!before.declarations.some(x=>JSON.stringify(x)===JSON.stringify(d)))!;p.empty=d.empty;p.note=d.note;break;}
 case 'Évaluation préparée':p.evaluation=after.evaluations.find(e=>!before.evaluations.some(x=>x.id===e.id));break;
 case 'Évaluation publiée':p.evaluationId=after.evaluations.find(e=>e.published&&!before.evaluations.find(x=>x.id===e.id)?.published)!.id;break;
 default:throw new Error('Cette action n’est pas encore disponible sur le serveur.');
 }
 const {error}=await supabase.rpc('af_apply',{p_action:action,p});if(error)throw error;
}
export async function accountAction(body:Record<string,unknown>){const {data,error}=await supabase.functions.invoke('atelier-accounts',{body});if(error){const context=error.context;if(context instanceof Response){try{const info=await context.json();throw new Error(info.error||error.message)}catch(e){if(e instanceof Error&&!e.message.includes('JSON'))throw e}}throw error}if(data?.error)throw new Error(data.error);return data;}
