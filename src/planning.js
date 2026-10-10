import {esc,campaignStats,formatDuration} from './domain.js';

export const prepLabels={
 deck:'Pakli ellenőrizve és előkészítve',
 xp:'Elköltetlen XP átnézve',
 scenario:'Következő forgatókönyv előkészítve',
 tokens:'Káoszzsák és közös kellékek ellenőrizve'
};

export function statsView(sessions,results){
 const s=campaignStats(sessions,results);
 return `<section aria-label="Kampánystatisztika" class="campaign-stats"><h2>Kampánystatisztika</h2>
 <div class="stats"><div class="stat"><strong>${formatDuration(s.totalMinutes)}</strong><span>összes rögzített játékidő</span></div>
 <div class="stat"><strong>${formatDuration(s.averageMinutes)}</strong><span>átlagos alkalomhossz</span></div>
 <div class="stat"><strong>${s.totalXp} XP</strong><span>csapat által megszerzett XP</span></div></div>
 <p class="muted stats-explanation">${s.completed?s.timed+' / '+s.completed+' lezárt alkalom játékideje van megadva.' :'Még nincs lezárt alkalom.'} ${s.missing?'A hiányzó idők nem számítanak bele az átlagba.':''} Az XP a lezárt alkalmak összes játékosának jutalma, a korábbi nyomozókéval együtt.</p></section>`;
}

export function planningView({campaign,sessions,members,investigators,preparation,userId}){
 const latest=sessions[0],next=(latest?.number||0)+1;
 const manager=campaign.owner_id===userId||latest?.gm_id===userId;
 const canEdit=!campaign.closed;
 const row=(scope,task)=>preparation.find(p=>p.target_number===next&&p.scope===scope&&p.task===task);
 const check=(scope,task,editable)=>{
  const p=row(scope,task);
  return `<label class="prep-check"><input type="checkbox" data-prep-task="${task}" data-prep-scope="${scope==='shared'?'shared':'self'}" data-prep-revision="${p?.revision||0}" data-prep-target="${next}" ${p?.done?'checked':''} ${editable?'':'disabled'}><span>${prepLabels[task]}</span></label>`;
 };
 const me=investigators.find(i=>i.active&&i.user_id===userId);
 return `<div class="columns planning-columns">
 <section class="panel"><div class="section-title"><h2>Legközelebb innen folytatjuk</h2>${manager&&canEdit?'<button type="button" class="ghost" data-action="edit-reminder">Szerkesztés</button>':''}</div>
 <p class="note reminder-text">${esc(campaign.next_reminder||'Még nincs emlékeztető. Ide kerülhet, hol tart a történet, mely döntések várnak rátok, és mire figyeljetek legközelebb.')}</p>
 <small class="muted">A kampánygazda vagy a legutóbbi alkalom játékmestere szerkesztheti. Az emlékeztető új alkalom indításakor is megmarad.</small></section>
 <section class="panel"><h2>Felkészülés a következő alkalomra</h2>
 ${campaign.closed?'<p class="muted">A kampány lezárult. A lista már nem módosítható.</p>':`<p class="muted">A ${next}. alkalomra · Új alkalom indításakor új lista kezdődik. A pipák nem feltételei az indításnak.</p>`}
 <h3>Saját felkészülésem</h3>
 <p class="muted">${me?`${me.earned-me.spent} elkölthető XP. Az XP későbbre is megtartható.`:'Még nincs aktív nyomozód. Saját nyomozó nélkül is felkészülhetsz a játékvezetésre.'}</p>
 ${check(userId,'deck',canEdit)}${check(userId,'xp',canEdit)}
 <h3 class="prep-heading">Közös előkészületek</h3>
 ${check('shared','scenario',manager&&canEdit)}${check('shared','tokens',manager&&canEdit)}
 <h3 class="prep-heading">A csapat készültsége</h3><ul class="checklist">
 ${members.map(m=>`<li><span>${esc(m.name)}</span><span>${['deck','xp'].filter(t=>row(m.user_id,t)?.done).length}/2 kész</span></li>`).join('')}
 </ul></section></div>`;
}
