-- Keep the Revised Core Set investigators available and add a checked campaign deletion endpoint.
insert into public.arkham_characters(code,name,class,subtitle) values
 ('roland','Roland Banks','Őrző','A szövetségi ügynök'),
 ('daisy','Daisy Walker','Kutató','A könyvtáros'),
 ('skids','“Skids” O’Toole','Zsivány','A volt fegyenc'),
 ('agnes','Agnes Baker','Misztikus','A pincérnő'),
 ('wendy','Wendy Adams','Túlélő','Az utcagyerek')
on conflict (code) do update set
 name=excluded.name,class=excluded.class,subtitle=excluded.subtitle;

create function public.arkham_delete_campaign(p_campaign uuid,p_confirmation text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
 uid uuid:=auth.uid();
 c public.arkham_campaigns;
begin
 if uid is null then
  raise exception 'Jelentkezz be a folytatáshoz.' using errcode='42501';
 end if;

 select * into c
 from public.arkham_campaigns
 where id=p_campaign and owner_id=uid
 for update;

 if not found then
  raise exception 'Csak a kampánygazda törölheti a kampányt.' using errcode='42501';
 end if;
 if p_confirmation is distinct from c.name then
  raise exception 'A megerősítéshez pontosan írd be a kampány nevét.';
 end if;

 -- Delete dependants explicitly so the operation is atomic without broad cascade rules.
 delete from public.arkham_results where campaign_id=p_campaign;
 delete from public.arkham_journal where campaign_id=p_campaign;
 delete from public.arkham_events where campaign_id=p_campaign;
 delete from public.arkham_sessions where campaign_id=p_campaign;
 delete from public.arkham_investigators where campaign_id=p_campaign;
 delete from public.arkham_invites where campaign_id=p_campaign;
 delete from public.arkham_members where campaign_id=p_campaign;
 delete from public.arkham_campaigns where id=p_campaign;

 return jsonb_build_object('campaign_id',p_campaign,'name',c.name);
end;
$$;

revoke all on function public.arkham_delete_campaign(uuid,text) from public,anon;
grant execute on function public.arkham_delete_campaign(uuid,text) to authenticated;
