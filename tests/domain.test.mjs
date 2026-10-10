import {test} from 'node:test';
import assert from 'node:assert/strict';
import {esc,numberValue,safeUrl,durationMinutes,formatDuration} from '../src/domain.js';

test('duration distinguishes missing time from a real duration',()=>{
 assert.equal(durationMinutes('',''),null);
 assert.equal(durationMinutes('2','35'),155);
 assert.equal(durationMinutes('','45'),45);
 assert.equal(durationMinutes('3',''),180);
 for(const pair of [['0','0'],['-1','30'],['2','60'],['1.5','0'],['1000','0'],['x','1']])assert.throws(()=>durationMinutes(...pair));
 assert.equal(formatDuration(null),'Nincs megadva');
 assert.equal(formatDuration(undefined),'Nincs megadva');
 assert.equal(formatDuration(155),'2 óra 35 perc');
 assert.equal(formatDuration(60),'1 óra');
 assert.equal(formatDuration(45),'45 perc');
});
test('user text cannot create HTML attributes or tags',()=>{assert.equal(esc('<img src=x onerror="bad">'), '&lt;img src=x onerror=&quot;bad&quot;&gt;');});
test('XP and trauma accept only bounded whole numbers',()=>{assert.equal(numberValue('0',0,99),0);assert.equal(numberValue('12',0,99),12);for(const v of ['',null,'1.5','-1','100','NaN'])assert.throws(()=>numberValue(v,0,99));});
test('deck links never execute script URLs',()=>{assert.equal(safeUrl('javascript:alert(1)'),false);assert.equal(safeUrl('data:text/html,test'),false);assert.equal(safeUrl('https://arkhamdb.com/deck/view/1'),true);});
