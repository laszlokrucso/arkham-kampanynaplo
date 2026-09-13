import {test} from 'node:test';
import assert from 'node:assert/strict';
import {esc,numberValue,safeUrl} from '../src/domain.js';
test('user text cannot create HTML attributes or tags',()=>{assert.equal(esc('<img src=x onerror="bad">'), '&lt;img src=x onerror=&quot;bad&quot;&gt;');});
test('XP and trauma accept only bounded whole numbers',()=>{assert.equal(numberValue('0',0,99),0);assert.equal(numberValue('12',0,99),12);for(const v of ['',null,'1.5','-1','100','NaN'])assert.throws(()=>numberValue(v,0,99));});
test('deck links never execute script URLs',()=>{assert.equal(safeUrl('javascript:alert(1)'),false);assert.equal(safeUrl('data:text/html,test'),false);assert.equal(safeUrl('https://arkhamdb.com/deck/view/1'),true);});
