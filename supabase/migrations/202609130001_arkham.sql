-- Campaign data is readable through RLS; every write is a checked, atomic RPC.
create table public.arkham_characters (
 code text primary key, name text not null, class text not null, subtitle text not null
);
insert into public.arkham_characters values
 ('roland','Roland Banks','Őrző','A szövetségi ügynök'),('daisy','Daisy Walker','Kutató','A könyvtáros'),
 ('skids','“Skids” O’Toole','Zsivány','A volt fegyenc'),('agnes','Agnes Baker','Misztikus','A pincérnő'),('wendy','Wendy Adams','Túlélő','Az utcagyerek');
create table public.arkham_campaigns (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id),
 name text not null check(length(name) between 1 and 120), campaign_type text not null default 'Egyéni kampány',
 difficulty text not null default 'Normál', closed boolean not null default false, created_at timestamptz not null default now()
);
create table public.arkham_members (
 campaign_id uuid not null references public.arkham_campaigns(id), user_id uuid not null references auth.users(id),
 name text not null check(length(name) between 1 and 80), joined_at timestamptz not null default now(), primary key(campaign_id,user_id)
);
create table public.arkham_investigators (
 id uuid primary key default gen_random_uuid(),campaign_id uuid not null references public.arkham_campaigns(id),
 user_id uuid not null, character_code text not null references public.arkham_characters(code), active boolean not null default true,
 earned integer not null default 0 check(earned>=0), spent integer not null default 0 check(spent between 0 and earned),
 physical integer not null default 0 check(physical>=0),mental integer not null default 0 check(mental>=0),
 status text not null default '',notes text not null default '',deck text not null default '', revision integer not null default 1,
 foreign key(campaign_id,user_id) references public.arkham_members(campaign_id,user_id)
);
create unique index arkham_one_active_per_user on public.arkham_investigators(campaign_id,user_id) where active;
create unique index arkham_one_active_character on public.arkham_investigators(campaign_id,character_code) where active;
create table public.arkham_sessions (
 id uuid primary key default gen_random_uuid(), campaign_id uuid not null references public.arkham_campaigns(id),
 number integer not null check(number>0),title text not null check(length(title) between 1 and 160),gm_id uuid not null,
 resolution text not null default '',note text not null default '',closed boolean not null default false,
 revision integer not null default 1,created_at timestamptz not null default now(),closed_at timestamptz,
 unique(campaign_id,number), foreign key(campaign_id,gm_id) references public.arkham_members(campaign_id,user_id)
);
create unique index arkham_one_open_session on public.arkham_sessions(campaign_id) where not closed;
create table public.arkham_results (
 session_id uuid not null references public.arkham_sessions(id), investigator_id uuid not null references public.arkham_investigators(id),
 campaign_id uuid not null references public.arkham_campaigns(id),user_id uuid not null,
 xp integer not null default 0 check(xp between 0 and 99),physical integer not null default 0 check(physical between 0 and 99),
 mental integer not null default 0 check(mental between 0 and 99),note text not null default '',submitted boolean not null default false,
 revision integer not null default 1,primary key(session_id,investigator_id),
 foreign key(campaign_id,user_id) references public.arkham_members(campaign_id,user_id)
);
create table public.arkham_journal (
 id uuid primary key default gen_random_uuid(),campaign_id uuid not null references public.arkham_campaigns(id),
 session_id uuid references public.arkham_sessions(id),author_id uuid not null references auth.users(id),
 body text not null check(length(body) between 1 and 10000),created_at timestamptz not null default now()
);
create table public.arkham_events (
 id bigint generated always as identity primary key,campaign_id uuid not null references public.arkham_campaigns(id),
 actor_id uuid not null references auth.users(id),action text not null,detail jsonb not null default '{}',created_at timestamptz not null default now()
);
create table public.arkham_invites (
 token uuid primary key default gen_random_uuid(),campaign_id uuid not null references public.arkham_campaigns(id),
 created_by uuid not null references auth.users(id),expires_at timestamptz not null default now()+interval '7 days',revoked boolean not null default false
);
create index arkham_members_user on public.arkham_members(user_id);
create index arkham_campaign_owner on public.arkham_campaigns(owner_id);
create index arkham_results_campaign on public.arkham_results(campaign_id);
create index arkham_investigators_user on public.arkham_investigators(user_id);
create index arkham_results_user on public.arkham_results(user_id);
create index arkham_results_investigator on public.arkham_results(investigator_id);
create index arkham_journal_campaign on public.arkham_journal(campaign_id,created_at desc);
create index arkham_events_campaign on public.arkham_events(campaign_id,created_at desc);
create index arkham_invites_campaign on public.arkham_invites(campaign_id);
create function public.arkham_is_member(cid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.arkham_members where campaign_id=cid and user_id=(select auth.uid()));
$$;
alter table public.arkham_characters enable row level security;
create policy characters_read on public.arkham_characters for select to authenticated using(true);
alter table public.arkham_campaigns enable row level security;
create policy campaigns_read on public.arkham_campaigns for select to authenticated using(public.arkham_is_member(id));
alter table public.arkham_members enable row level security;
create policy members_read on public.arkham_members for select to authenticated using(public.arkham_is_member(campaign_id));
alter table public.arkham_investigators enable row level security;
create policy investigators_read on public.arkham_investigators for select to authenticated using(public.arkham_is_member(campaign_id));
alter table public.arkham_sessions enable row level security;
create policy sessions_read on public.arkham_sessions for select to authenticated using(public.arkham_is_member(campaign_id));
alter table public.arkham_results enable row level security;
create policy results_read on public.arkham_results for select to authenticated using(public.arkham_is_member(campaign_id));
alter table public.arkham_journal enable row level security;
create policy journal_read on public.arkham_journal for select to authenticated using(public.arkham_is_member(campaign_id));
alter table public.arkham_events enable row level security;
create policy events_read on public.arkham_events for select to authenticated using(public.arkham_is_member(campaign_id));
alter table public.arkham_invites enable row level security;
create policy invites_read on public.arkham_invites for select to authenticated using(exists(select 1 from public.arkham_campaigns where id=campaign_id and owner_id=(select auth.uid())));

create function public.arkham_action(p_action text,p_campaign uuid default null,p_data jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare
 uid uuid:=auth.uid(); c public.arkham_campaigns; s public.arkham_sessions; inv public.arkham_investigators;
 r public.arkham_results; old_data jsonb; out_data jsonb:='{}'; target uuid; cid uuid:=p_campaign;
 val text; nm text; token_id uuid; n integer; new_xp integer; new_ph integer; new_mn integer;
begin
 if uid is null then raise exception 'Jelentkezz be a folytatáshoz.' using errcode='42501'; end if;
 if p_data is null or jsonb_typeof(p_data)<>'object' or length(p_data::text)>40000 then raise exception 'Érvénytelen adatok.'; end if;
 if p_action='create_campaign' then
  nm:=trim(p_data->>'name'); val:=trim(p_data->>'player_name');
  if coalesce(nm,'')='' or coalesce(val,'')='' then raise exception 'Add meg a kampány és a játékos nevét.'; end if;
  insert into public.arkham_campaigns(owner_id,name,campaign_type,difficulty) values(uid,nm,left(coalesce(p_data->>'campaign_type','Egyéni kampány'),120),left(coalesce(p_data->>'difficulty','Normál'),30)) returning * into c;
  insert into public.arkham_members(campaign_id,user_id,name) values(c.id,uid,val);cid:=c.id;
  out_data:=jsonb_build_object('campaign_id',cid);
 elsif p_action='join_campaign' then
  -- Find the campaign first, then take its lock before rechecking the invitation.
  select campaign_id into cid from public.arkham_invites where token=(p_data->>'token')::uuid;
  select * into c from public.arkham_campaigns where id=cid for update;
  if not found or c.closed then raise exception 'A meghívó nem használható.'; end if;
  if not exists(select 1 from public.arkham_invites where token=(p_data->>'token')::uuid and not revoked and expires_at>now()) then raise exception 'A meghívó lejárt vagy visszavonták.';end if;
  if exists(select 1 from public.arkham_members where campaign_id=cid and user_id=uid) then return jsonb_build_object('campaign_id',cid);end if;
  select count(*) into n from public.arkham_members where campaign_id=cid;
  if n>=4 then raise exception 'A kampány megtelt (legfeljebb 4 játékos).';end if;
  nm:=trim(p_data->>'player_name');if coalesce(nm,'')='' then raise exception 'Add meg a játékosneved.';end if;
  insert into public.arkham_members(campaign_id,user_id,name) values(cid,uid,nm);
  out_data:=jsonb_build_object('campaign_id',cid);
 else
  select * into c from public.arkham_campaigns where id=cid for update;
  if not found or not public.arkham_is_member(cid) then raise exception 'Nincs hozzáférésed ehhez a kampányhoz.' using errcode='42501'; end if;
  if c.closed then raise exception 'A kampány már lezárult.';end if;
  if p_action='create_invite' or p_action='revoke_invite' then
   if c.owner_id<>uid then raise exception 'Csak a kampánygazda kezelhet meghívókat.' using errcode='42501';end if;
   if p_action='create_invite' then
    insert into public.arkham_invites(campaign_id,created_by) values(cid,uid) returning token into token_id;
    out_data:=jsonb_build_object('token',token_id);
   else update public.arkham_invites set revoked=true where campaign_id=cid and token=(p_data->>'token')::uuid;
   end if;
  elsif p_action='transfer_owner' then
   target:=(p_data->>'user_id')::uuid;
   if c.owner_id<>uid or not exists(select 1 from public.arkham_members where campaign_id=cid and user_id=target) then raise exception 'A kampánygazda csak egy csapattagnak adhatja át a szerepet.' using errcode='42501';end if;
   update public.arkham_campaigns set owner_id=target where id=cid;
   out_data:=jsonb_build_object('from',uid,'to',target);
  elsif p_action='choose_character' then
   if exists(select 1 from public.arkham_sessions where campaign_id=cid and not closed) then raise exception 'Nyomozót két alkalom között válthatsz.';end if;
   val:=p_data->>'character_code';
   if not exists(select 1 from public.arkham_characters where code=val) then raise exception 'Ismeretlen nyomozó.';end if;
   select * into inv from public.arkham_investigators where campaign_id=cid and user_id=uid and active;
   if inv.character_code=val then return jsonb_build_object('investigator_id',inv.id);end if;
   if exists(select 1 from public.arkham_investigators where campaign_id=cid and active and character_code=val) then raise exception 'Ezt a nyomozót már választotta egy csapattárs.';end if;
   old_data:=to_jsonb(inv);
   update public.arkham_investigators set active=false,revision=revision+1 where campaign_id=cid and user_id=uid and active;
   insert into public.arkham_investigators(campaign_id,user_id,character_code) values(cid,uid,val) returning * into inv;
   out_data:=jsonb_build_object('previous',old_data,'current',to_jsonb(inv));
  elsif p_action='save_investigator' then
   select * into inv from public.arkham_investigators where id=(p_data->>'id')::uuid and campaign_id=cid and user_id=uid and active for update;
   if not found then raise exception 'Csak a saját aktív nyomozódat szerkesztheted.' using errcode='42501';end if;
   if inv.revision is distinct from (p_data->>'revision')::integer then raise exception 'Az adatlap időközben változott. Frissítsd az adatokat, és ellenőrizd újra.' using errcode='40001';end if;
   old_data:=to_jsonb(inv);
   if length(coalesce(p_data->>'notes',''))>10000 or length(coalesce(p_data->>'status',''))>2000 or length(coalesce(p_data->>'deck',''))>2000 then raise exception 'Túl hosszú szöveg.';end if;
   if coalesce(p_data->>'deck','')<>'' and (p_data->>'deck')!~'^https?://' then raise exception 'A paklilink http:// vagy https:// címmel kezdődjön.';end if;
   update public.arkham_investigators set spent=(p_data->>'spent')::integer,physical=(p_data->>'physical')::integer,mental=(p_data->>'mental')::integer,
    status=coalesce(p_data->>'status',''),notes=coalesce(p_data->>'notes',''),deck=coalesce(p_data->>'deck',''),revision=revision+1 where id=inv.id returning * into inv;
   out_data:=jsonb_build_object('before',old_data,'after',to_jsonb(inv));
  elsif p_action='start_session' then
   select * into s from public.arkham_sessions where campaign_id=cid order by number desc limit 1;
   if uid<>c.owner_id and (s.id is null or s.gm_id<>uid) then raise exception 'A kampánygazda vagy az előző játékmester indíthat alkalmat.' using errcode='42501';end if;
   if s.id is not null and not s.closed then raise exception 'Előbb zárjátok le az aktuális alkalmat.';end if;
   target:=(p_data->>'gm_id')::uuid;val:=trim(p_data->>'title');
   if coalesce(val,'')='' then raise exception 'Add meg a forgatókönyv nevét.';end if;
   if not exists(select 1 from public.arkham_members where campaign_id=cid and user_id=target) then raise exception 'A játékmesternek csapattagnak kell lennie.';end if;
   if not exists(select 1 from public.arkham_investigators where campaign_id=cid and active) then raise exception 'Legalább egy nyomozót válasszatok ki.';end if;
   if exists(select 1 from public.arkham_members m where campaign_id=cid and user_id<>target and not exists(select 1 from public.arkham_investigators i where i.campaign_id=cid and i.user_id=m.user_id and i.active)) then raise exception 'Minden résztvevő játékosnak válasszon nyomozót (a játékmesternek nem kötelező).';end if;
   insert into public.arkham_sessions(campaign_id,number,title,gm_id) values(cid,coalesce(s.number,0)+1,val,target) returning * into s;
   insert into public.arkham_results(session_id,investigator_id,campaign_id,user_id) select s.id,id,cid,user_id from public.arkham_investigators where campaign_id=cid and active;
   out_data:=to_jsonb(s);
  elsif p_action='close_campaign' then
   if uid<>c.owner_id then raise exception 'Csak a kampánygazda zárhatja le a kampányt.' using errcode='42501';end if;
   if exists(select 1 from public.arkham_sessions where campaign_id=cid and not closed) then raise exception 'Előbb zárjátok le az aktuális alkalmat.';end if;
   update public.arkham_campaigns set closed=true where id=cid;
  else
   select * into s from public.arkham_sessions where id=(p_data->>'session_id')::uuid and campaign_id=cid for update;
   if not found then raise exception 'Az alkalom nem található.';end if;
   if s.closed then raise exception 'Az alkalom már lezárult.';end if;
   if p_action='save_result' then
    select * into r from public.arkham_results where session_id=s.id and user_id=uid for update;
    if not found then raise exception 'Ehhez az alkalomhoz nincs résztvevő nyomozód.' using errcode='42501';end if;
    if r.revision is distinct from (p_data->>'revision')::integer then raise exception 'Az eredmény már változott. Frissítsd az adatokat.' using errcode='40001';end if;
    new_xp:=(p_data->>'xp')::integer;new_ph:=(p_data->>'physical')::integer;new_mn:=(p_data->>'mental')::integer;
    if new_xp is null or new_ph is null or new_mn is null or new_xp not between 0 and 99 or new_ph not between 0 and 99 or new_mn not between 0 and 99 or length(coalesce(p_data->>'note',''))>10000 then raise exception 'Érvénytelen eredmény.';end if;
    old_data:=to_jsonb(r);
    -- Results remain editable until closing; only their difference is applied.
    update public.arkham_investigators set earned=earned+new_xp-r.xp,physical=physical+new_ph-r.physical,mental=mental+new_mn-r.mental,revision=revision+1 where id=r.investigator_id;
    update public.arkham_results set xp=new_xp,physical=new_ph,mental=new_mn,note=coalesce(p_data->>'note',''),submitted=true,revision=revision+1 where session_id=s.id and investigator_id=r.investigator_id returning * into r;
    out_data:=jsonb_build_object('before',old_data,'after',to_jsonb(r));
   elsif p_action='transfer_gm' then
    if uid<>s.gm_id and uid<>c.owner_id then raise exception 'Csak a játékmester vagy a kampánygazda adhatja át a szerepet.' using errcode='42501';end if;
    if s.revision is distinct from (p_data->>'revision')::integer then raise exception 'Az alkalom időközben változott. Frissítsd az adatokat.' using errcode='40001';end if;
    target:=(p_data->>'gm_id')::uuid;
    if not exists(select 1 from public.arkham_members where campaign_id=cid and user_id=target) then raise exception 'A játékmesternek csapattagnak kell lennie.';end if;
    update public.arkham_sessions set gm_id=target,revision=revision+1 where id=s.id;
    out_data:=jsonb_build_object('from',s.gm_id,'to',target,'session_id',s.id);
   else
    if uid<>s.gm_id then raise exception 'Ezt csak az alkalom játékmestere módosíthatja.' using errcode='42501';end if;
    if p_action='save_common' then
     if s.revision is distinct from (p_data->>'revision')::integer then raise exception 'Az alkalom időközben változott. Frissítsd az adatokat.' using errcode='40001';end if;
     val:=trim(p_data->>'resolution');if coalesce(val,'')='' or length(val)>2000 or length(coalesce(p_data->>'note',''))>10000 then raise exception 'Adj meg érvényes közös eredményt.';end if;
     update public.arkham_sessions set resolution=val,note=coalesce(p_data->>'note',''),revision=revision+1 where id=s.id returning * into s;out_data:=to_jsonb(s);
    elsif p_action='add_note' then
     insert into public.arkham_journal(campaign_id,session_id,author_id,body) values(cid,s.id,uid,trim(p_data->>'body'));
     out_data:=jsonb_build_object('body',p_data->>'body','session_id',s.id);
    elsif p_action='close_session' then
     if trim(s.resolution)='' or exists(select 1 from public.arkham_results where session_id=s.id and not submitted) then raise exception 'Még hiányzik közös vagy személyes eredmény.';end if;
     update public.arkham_sessions set closed=true,closed_at=now(),revision=revision+1 where id=s.id;
     insert into public.arkham_journal(campaign_id,session_id,author_id,body) values(cid,s.id,uid,s.title||E'\n'||s.resolution||E'\n'||s.note);
     out_data:=to_jsonb(s);
    else raise exception 'Ismeretlen művelet.';end if;
   end if;
  end if;
 end if;
 insert into public.arkham_events(campaign_id,actor_id,action,detail) values(cid,uid,p_action,out_data - 'token');
 return out_data;
end;
$$;
revoke all on public.arkham_characters,public.arkham_campaigns,public.arkham_members,public.arkham_investigators,public.arkham_sessions,public.arkham_results,public.arkham_journal,public.arkham_events,public.arkham_invites from anon,authenticated;
grant select on public.arkham_characters,public.arkham_campaigns,public.arkham_members,public.arkham_investigators,public.arkham_sessions,public.arkham_results,public.arkham_journal,public.arkham_events,public.arkham_invites to authenticated;
revoke all on function public.arkham_is_member(uuid) from public,anon;
grant execute on function public.arkham_is_member(uuid) to authenticated;
revoke all on function public.arkham_action(text,uuid,jsonb) from public,anon;
grant execute on function public.arkham_action(text,uuid,jsonb) to authenticated;
