alter table public.arkham_campaigns
 add column next_reminder text not null default '' check (length(next_reminder)<=8000),
 add column reminder_revision integer not null default 1;

-- Completion belongs to a specific upcoming session; starting it exposes a fresh list.
create table public.arkham_preparation (
 campaign_id uuid not null references public.arkham_campaigns(id) on delete cascade,
 target_number integer not null check(target_number>0),
 scope text not null,
 task text not null check(task in ('deck','xp','scenario','tokens')),
 done boolean not null default false,
 revision integer not null default 1,
 primary key(campaign_id,target_number,scope,task),
 check((scope='shared' and task in ('scenario','tokens')) or
       (scope<>'shared' and task in ('deck','xp')))
);
alter table public.arkham_preparation enable row level security;
create policy preparation_read on public.arkham_preparation for select to authenticated
 using(public.arkham_is_member(campaign_id));
revoke all on public.arkham_preparation from public,anon,authenticated;
grant select on public.arkham_preparation to authenticated;

create function public.arkham_plan(p_campaign uuid,p_action text,p_revision integer,p_data jsonb default '{}')
 returns jsonb language plpgsql security definer set search_path='' as $$
declare
 uid uuid:=auth.uid(); c public.arkham_campaigns; s public.arkham_sessions;
 item public.arkham_preparation; scope_key text; task_key text; body text;
 upcoming integer; manager boolean; new_done boolean; out_data jsonb;
begin
 if uid is null then raise exception 'Jelentkezz be a folytatáshoz.' using errcode='42501';end if;
 if p_data is null or jsonb_typeof(p_data)<>'object' or length(p_data::text)>40000 then raise exception 'Érvénytelen adatok.';end if;
 select * into c from public.arkham_campaigns where id=p_campaign for update;
 if not found or not public.arkham_is_member(p_campaign) then raise exception 'Nincs hozzáférésed ehhez a kampányhoz.' using errcode='42501';end if;
 if c.closed then raise exception 'A kampány már lezárult.';end if;
 select * into s from public.arkham_sessions where campaign_id=p_campaign order by number desc limit 1;
 manager:=uid=c.owner_id or coalesce(uid=s.gm_id,false);
 upcoming:=coalesce(s.number,0)+1;
 if p_action='save_reminder' then
  if not manager then raise exception 'Az emlékeztetőt a játékmester vagy a kampánygazda szerkesztheti.' using errcode='42501';end if;
  if c.reminder_revision is distinct from p_revision then raise exception 'Az emlékeztető időközben változott. Frissítsd az adatokat.' using errcode='40001';end if;
  if jsonb_typeof(p_data->'body') is distinct from 'string' then raise exception 'Érvénytelen emlékeztető.';end if;
  body:=trim(p_data->>'body');
  if length(body)>8000 then raise exception 'Az emlékeztető legfeljebb 8000 karakter lehet.';end if;
  update public.arkham_campaigns set next_reminder=body,reminder_revision=reminder_revision+1 where id=p_campaign;
  out_data:=jsonb_build_object('before',c.next_reminder,'body',body);
 elsif p_action='set_preparation' then
  if (p_data->>'target_number')::integer is distinct from upcoming then raise exception 'Időközben új alkalom indult. Frissítsd a felkészülési listát.' using errcode='40001';end if;
  task_key:=p_data->>'task';
  if (p_data->>'scope')='shared' then
   if not manager then raise exception 'A közös teendőket a játékmester vagy a kampánygazda kezelheti.' using errcode='42501';end if;
   scope_key:='shared';
   if task_key is null or task_key not in ('scenario','tokens') then raise exception 'Ismeretlen közös teendő.';end if;
  elsif (p_data->>'scope')='self' then
   scope_key:=uid::text;
   if task_key is null or task_key not in ('deck','xp') then raise exception 'Ismeretlen személyes teendő.';end if;
  else raise exception 'Csak a saját vagy a közös felkészülés módosítható.' using errcode='42501';
  end if;
  if jsonb_typeof(p_data->'done') is distinct from 'boolean' then raise exception 'Érvénytelen készültségi állapot.';end if;
  new_done:=(p_data->>'done')::boolean;
  select * into item from public.arkham_preparation where campaign_id=p_campaign and target_number=upcoming and scope=scope_key and task=task_key;
  if coalesce(item.revision,0) is distinct from p_revision then raise exception 'A teendő időközben változott. Frissítsd az adatokat.' using errcode='40001';end if;
  insert into public.arkham_preparation(campaign_id,target_number,scope,task,done)
   values(p_campaign,upcoming,scope_key,task_key,new_done)
   on conflict(campaign_id,target_number,scope,task) do update set done=excluded.done,revision=arkham_preparation.revision+1;
  out_data:=jsonb_build_object('target_number',upcoming,'scope',scope_key,'task',task_key,'done',new_done);
 else raise exception 'Ismeretlen művelet.';end if;
 insert into public.arkham_events(campaign_id,actor_id,action,detail) values(p_campaign,uid,p_action,out_data);
 return out_data;
end;
$$;
revoke all on function public.arkham_plan(uuid,text,integer,jsonb) from public,anon;
grant execute on function public.arkham_plan(uuid,text,integer,jsonb) to authenticated;
