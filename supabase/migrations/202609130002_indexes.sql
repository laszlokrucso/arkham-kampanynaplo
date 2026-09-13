create index arkham_events_actor on public.arkham_events(actor_id);
create index arkham_investigators_character on public.arkham_investigators(character_code);
create index arkham_invites_creator on public.arkham_invites(created_by);
create index arkham_journal_author on public.arkham_journal(author_id);
create index arkham_journal_session on public.arkham_journal(session_id);
create index arkham_results_member on public.arkham_results(campaign_id,user_id);
create index arkham_sessions_gm on public.arkham_sessions(campaign_id,gm_id);
