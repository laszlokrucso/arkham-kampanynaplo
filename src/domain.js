export const esc = value => String(value ?? '').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export function numberValue(value,min,max){if(value===null||String(value).trim()==='')throw Error('Minden számmezőt tölts ki.');const n=Number(value);if(!Number.isInteger(n)||n<min||n>max)throw Error(`Egész számot adj meg ${min} és ${max} között.`);return n;}
export function safeUrl(value){try{return ['http:','https:'].includes(new URL(value).protocol);}catch{return false;}}
export function durationMinutes(hours,minutes){
 if(String(hours??'').trim()===''&&String(minutes??'').trim()==='')return null;
 const total=numberValue(hours||'0',0,999)*60+numberValue(minutes||'0',0,59);
 if(total<1)throw Error('Legalább 1 perc játékidőt adj meg, vagy hagyd üresen mindkét mezőt.');
 return total;
}
export function formatDuration(minutes){
 if(!Number.isInteger(minutes)||minutes<1)return 'Nincs megadva';
 const h=Math.floor(minutes/60),m=minutes%60;
 return [h?`${h} óra`:'',m?`${m} perc`:''].filter(Boolean).join(' ');
}
export function errorText(error){const m=error?.message||String(error);if(error?.code==='40001')return m;if(/Invalid login credentials/i.test(m))return 'Hibás e-mail-cím vagy jelszó.';if(/Email not confirmed/i.test(m))return 'Előbb erősítsd meg az e-mail-címedet a kapott levélben.';if(/rate limit|too many requests/i.test(m))return 'Túl sok próbálkozás. Várj egy kicsit, majd próbáld újra.';if(/email address not authorized|Email address.*invalid|Error sending/i.test(m))return 'A levélküldés nem sikerült. Ellenőrizd az e-mail-címedet; a levélküldő szolgáltatás beállítása is szükséges lehet.';if(/Failed to fetch|NetworkError|fetch failed/i.test(m))return 'Nem sikerült elérni a szervert. Ellenőrizd a kapcsolatot, majd próbáld újra; a mezők tartalma megmaradt.';if(/check constraint/i.test(m))return 'Az értékek nem érvényesek. A traumák nem lehetnek negatívak, és az elköltött XP nem haladhatja meg a megszerzett XP-t.';if(/duplicate key/i.test(m))return 'Ez az adat időközben már létrejött. Frissítsd az oldalt.';return m;}
