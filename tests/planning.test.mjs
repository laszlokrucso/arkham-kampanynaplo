import {test} from 'node:test';
import assert from 'node:assert/strict';
import {campaignStats} from '../src/domain.js';
import {statsView,planningView} from '../src/planning.js';

test('statistics exclude open sessions and missing duration without losing awarded XP',()=>{
 const sessions=[{id:'a',closed:true,duration_minutes:120},{id:'b',closed:true,duration_minutes:null},{id:'c',closed:true,duration_minutes:181},{id:'open',closed:false,duration_minutes:999}];
 const results=[{session_id:'a',submitted:true,xp:4},{session_id:'a',submitted:true,xp:5},{session_id:'b',submitted:true,xp:2},{session_id:'open',submitted:true,xp:90},{session_id:'c',submitted:false,xp:99}];
 assert.deepEqual(campaignStats(sessions,results),{completed:3,timed:2,missing:1,totalMinutes:301,averageMinutes:151,totalXp:11});
 assert.equal(campaignStats([],[]).averageMinutes,null);
 assert.equal(campaignStats([{id:'a',closed:true}],[]).totalMinutes,null);
 assert.match(statsView(sessions,results),/2 \/ 3 lezárt/);
});

const fixture={campaign:{owner_id:'owner',next_reminder:'<img onerror=bad>'},sessions:[{number:2,gm_id:'gm'}],members:[{user_id:'player',name:'<script>'}],investigators:[],preparation:[{target_number:2,scope:'player',task:'deck',done:true,revision:1}],userId:'player'};
test('planning safely renders reminders and scopes completion to the upcoming session',()=>{
 const html=planningView(fixture);
 assert.ok(html.includes('&lt;img onerror=bad&gt;'));
 assert.ok(!html.includes('<script>'));
 assert.ok(!html.includes('checked'));
 assert.match(html,/0\/2 kész/);
 assert.match(html,/A 3\. alkalomra/);
 assert.ok(!html.includes('data-action="edit-reminder"'));
 assert.match(html,/data-prep-task="scenario"[^>]*disabled/);
 assert.ok(!/data-prep-task="deck"[^>]*disabled/.test(html));
});
test('only managers see reminder editing and closed campaigns disable all checklist fields',()=>{
 assert.ok(planningView({...fixture,userId:'gm'}).includes('data-action="edit-reminder"'));
 assert.ok(planningView({...fixture,userId:'owner'}).includes('data-action="edit-reminder"'));
 const html=planningView({...fixture,campaign:{...fixture.campaign,closed:true}});
 assert.equal((html.match(/disabled/g)||[]).length,4);
 assert.ok(!html.includes('data-action="edit-reminder"'));
});
