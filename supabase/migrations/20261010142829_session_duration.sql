-- Actual playing time is entered by players; administration timestamps are not play time.
alter table public.arkham_sessions add column duration_minutes integer
 check (duration_minutes between 1 and 59999);

-- Matches the existing RPC-only write model. All permissions are checked here.
create function public.arkham_save_duration(
 p_campaign uuid, p_session uuid, p_revision integer, p_minutes integer,
 p_close boolean default false
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
 uid uuid:=auth.uid(); c public.arkham_campaigns; s public.arkham_sessions;
 previous_minutes integer;
begin
 if uid is null then raise exception 'Jelentkezz be a folytatáshoz.' using errcode='42501';end if;
 select * into c from public.arkham_campaigns where id=p_campaign for update;
 if not found or not public.arkham_is_member(p_campaign) then
  raise exception 'Nincs hozzáférésed ehhez a kampányhoz.' using errcode='42501';
 end if;
 select * into s from public.arkham_sessions where id=p_session and campaign_id=p_campaign for update;
 if not found then raise exception 'Az alkalom nem található.';end if;
 if uid<>s.gm_id and uid<>c.owner_id then
  raise exception 'A játékidőt az alkalom játékmestere vagy a kampánygazda javíthatja.' using errcode='42501';
 end if;
 if s.revision is distinct from p_revision then
  raise exception 'Az alkalom időközben változott. Frissítsd az adatokat.' using errcode='40001';
 end if;
 if p_close is null or (p_minutes is not null and p_minutes not between 1 and 59999) then
  raise exception 'A játékidő 1 és 59999 perc közötti egész szám lehet, vagy üres.';
 end if;
 previous_minutes:=s.duration_minutes;
 if s.duration_minutes is distinct from p_minutes then
  update public.arkham_sessions set duration_minutes=p_minutes,revision=revision+1 where id=s.id;
  insert into public.arkham_events(campaign_id,actor_id,action,detail)
   values(p_campaign,uid,'save_duration',jsonb_build_object(
    'session_id',s.id,'title',s.title,'before_minutes',previous_minutes,'duration_minutes',p_minutes));
 end if;
 -- Existing closure checks enforce GM, open campaign, open session and complete results.
 -- Any failure also rolls back the duration update and its history event.
 if p_close then
  perform public.arkham_action('close_session',p_campaign,jsonb_build_object('session_id',s.id));
 end if;
 select * into s from public.arkham_sessions where id=p_session;
 return to_jsonb(s);
end;
$$;
revoke all on function public.arkham_save_duration(uuid,uuid,integer,integer,boolean) from public,anon;
grant execute on function public.arkham_save_duration(uuid,uuid,integer,integer,boolean) to authenticated;
