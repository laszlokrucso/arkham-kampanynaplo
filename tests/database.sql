-- Integration checks execute against the actual schema, then roll back all test users and data.
begin;
create temporary table arkham_test_context(a uuid,b uuid,stranger uuid,cid uuid,sid uuid,inv uuid,invite uuid);
insert into arkham_test_context(a,b,stranger) values(gen_random_uuid(),gen_random_uuid(),gen_random_uuid());
insert into auth.users(id,aud,role,email) select a,'authenticated','authenticated',a::text||'@example.invalid' from arkham_test_context
 union all select b,'authenticated','authenticated',b::text||'@example.invalid' from arkham_test_context
 union all select stranger,'authenticated','authenticated',stranger::text||'@example.invalid' from arkham_test_context;
grant select,update on arkham_test_context to authenticated;
set local role authenticated;
do $$
declare t record; d jsonb; token uuid; failed boolean; rev integer;
begin
 select * into t from arkham_test_context;
 if (select count(*) from public.arkham_characters) < 64 then raise exception 'FAIL: Hall of Arkham investigator roster incomplete';end if;
 perform set_config('request.jwt.claim.sub',t.a::text,true);
 d:=public.arkham_action('create_campaign',null,'{"name":"Automated integration check","player_name":"Test owner"}');
 update arkham_test_context set cid=(d->>'campaign_id')::uuid;select * into t from arkham_test_context;
 d:=public.arkham_action('create_invite',t.cid,'{}');token:=(d->>'token')::uuid;
 perform public.arkham_action('choose_character',t.cid,'{"character_code":"daisy"}');
 select id into t.inv from public.arkham_investigators where campaign_id=t.cid;
 update arkham_test_context set inv=t.inv,invite=token;
 perform set_config('request.jwt.claim.sub',t.stranger::text,true);
 if exists(select 1 from public.arkham_campaigns where id=t.cid) or exists(select 1 from public.arkham_investigators where campaign_id=t.cid) then raise exception 'FAIL: outsider can read campaign';end if;
 failed:=false;begin perform public.arkham_action('create_invite',t.cid,'{}');exception when insufficient_privilege then failed:=true;end;if not failed then raise exception 'FAIL: outsider can mutate campaign';end if;
 perform set_config('request.jwt.claim.sub',t.b::text,true);
 perform public.arkham_action('join_campaign',null,jsonb_build_object('token',token,'player_name','Test player'));
 if (select count(*) from public.arkham_members where campaign_id=t.cid)<>2 then raise exception 'FAIL: membership';end if;
 if exists(select 1 from public.arkham_invites where campaign_id=t.cid) then raise exception 'FAIL: non-owner can read invitations';end if;
 failed:=false;begin perform public.arkham_action('choose_character',t.cid,'{"character_code":"daisy"}');exception when raise_exception then failed:=true;end;if not failed then raise exception 'FAIL: duplicate character allowed';end if;
 perform public.arkham_action('choose_character',t.cid,'{"character_code":"roland"}');
 failed:=false;begin perform public.arkham_action('save_investigator',t.cid,jsonb_build_object('id',t.inv,'revision',1,'spent',0,'physical',0,'mental',0));exception when insufficient_privilege then failed:=true;end;if not failed then raise exception 'FAIL: other investigator editable';end if;
 failed:=false;begin update public.arkham_campaigns set owner_id=t.b where id=t.cid;exception when insufficient_privilege then failed:=true;end;if not failed then raise exception 'FAIL: direct writes allowed';end if;
 perform set_config('request.jwt.claim.sub',t.a::text,true);
 d:=public.arkham_action('start_session',t.cid,jsonb_build_object('title','Test scenario','gm_id',t.a));t.sid:=(d->>'id')::uuid;update arkham_test_context set sid=t.sid;
 failed:=false;begin perform public.arkham_action('close_session',t.cid,jsonb_build_object('session_id',t.sid));exception when raise_exception then failed:=true;end;if not failed then raise exception 'FAIL: incomplete session closed';end if;
 perform public.arkham_action('save_result',t.cid,jsonb_build_object('session_id',t.sid,'revision',1,'xp',5,'physical',1,'mental',0));
 failed:=false;begin perform public.arkham_action('save_result',t.cid,jsonb_build_object('session_id',t.sid,'revision',1,'xp',5,'physical',1,'mental',0));exception when serialization_failure then failed:=true;end;if not failed then raise exception 'FAIL: duplicate result accepted';end if;
 perform public.arkham_action('save_result',t.cid,jsonb_build_object('session_id',t.sid,'revision',2,'xp',3,'physical',0,'mental',1));
 if not exists(select 1 from public.arkham_investigators where id=t.inv and earned=3 and physical=0 and mental=1) then raise exception 'FAIL: result delta incorrect';end if;
 perform public.arkham_action('transfer_gm',t.cid,jsonb_build_object('session_id',t.sid,'revision',1,'gm_id',t.b));
 failed:=false;begin perform public.arkham_action('save_common',t.cid,jsonb_build_object('session_id',t.sid,'revision',2,'resolution','R1'));exception when insufficient_privilege then failed:=true;end;if not failed then raise exception 'FAIL: former GM retains access';end if;
 perform set_config('request.jwt.claim.sub',t.b::text,true);
 perform public.arkham_action('save_common',t.cid,jsonb_build_object('session_id',t.sid,'revision',2,'resolution','R1','note','Integration note'));
 perform public.arkham_action('save_result',t.cid,jsonb_build_object('session_id',t.sid,'revision',1,'xp',4,'physical',0,'mental',0));
 perform public.arkham_action('close_session',t.cid,jsonb_build_object('session_id',t.sid));
 if not exists(select 1 from public.arkham_sessions where id=t.sid and closed) then raise exception 'FAIL: session not closed';end if;
 failed:=false;begin perform public.arkham_action('save_result',t.cid,jsonb_build_object('session_id',t.sid,'revision',2,'xp',9,'physical',0,'mental',0));exception when raise_exception then failed:=true;end;if not failed then raise exception 'FAIL: closed result editable';end if;
 perform set_config('request.jwt.claim.sub',t.a::text,true);
 perform public.arkham_action('choose_character',t.cid,'{"character_code":"wendy"}');
 if not exists(select 1 from public.arkham_investigators where id=t.inv and not active and earned=3) then raise exception 'FAIL: archived investigator lost';end if;
 perform public.arkham_action('transfer_owner',t.cid,jsonb_build_object('user_id',t.b));
 failed:=false;begin perform public.arkham_action('create_invite',t.cid,'{}');exception when insufficient_privilege then failed:=true;end;if not failed then raise exception 'FAIL: previous owner retains invitation rights';end if;
 failed:=false;begin perform public.arkham_delete_campaign(t.cid,'Automated integration check');exception when insufficient_privilege then failed:=true;end;if not failed then raise exception 'FAIL: previous owner can delete campaign';end if;
 perform set_config('request.jwt.claim.sub',t.b::text,true);
 failed:=false;begin perform public.arkham_delete_campaign(t.cid,'wrong name');exception when raise_exception then failed:=true;end;if not failed then raise exception 'FAIL: campaign deletion accepted wrong confirmation';end if;
 perform public.arkham_delete_campaign(t.cid,'Automated integration check');
 if exists(select 1 from public.arkham_campaigns where id=t.cid)
  or exists(select 1 from public.arkham_members where campaign_id=t.cid)
  or exists(select 1 from public.arkham_investigators where campaign_id=t.cid)
  or exists(select 1 from public.arkham_sessions where campaign_id=t.cid)
  or exists(select 1 from public.arkham_results where campaign_id=t.cid)
  or exists(select 1 from public.arkham_journal where campaign_id=t.cid)
  or exists(select 1 from public.arkham_events where campaign_id=t.cid)
  or exists(select 1 from public.arkham_invites where campaign_id=t.cid)
 then raise exception 'FAIL: campaign deletion left dependent data';end if;
end $$;
select 'PASS: RLS isolation, invite-only join, own-only writes, character uniqueness, transactional XP delta, stale-write protection, GM transfer, session completeness, closed-session protection, archival, owner transfer, checked campaign deletion' as result;
rollback;
