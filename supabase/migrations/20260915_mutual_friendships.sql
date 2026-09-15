-- 20260915_mutual_friendships.sql
-- Fixes the "Add Friend" feature in the live Prosper Inc. game.
--
-- The live game already has its own account/social schema (profiles,
-- game_saves, friendships, referrals, feedback, live_events) created
-- outside version control. This migration does NOT recreate that schema.
--
-- It adds one RPC: addFriendCode() in index.html previously inserted a
-- friendship row directly from the client in only ONE direction
-- (cloud.from('friendships').upsert({user_id, friend_id})), so the other
-- founder never actually saw the friendship. This function creates both
-- directions atomically, the same pattern as a mutual add-friend RPC.
--
-- Idempotent: safe to run more than once. Run this manually in the
-- Supabase SQL editor for the project (cmgyjuoedbfkxqjuyitj) — it is not
-- applied automatically by this repo.

create or replace function public.add_friend_by_code(target_code text)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  me     uuid := auth.uid();
  target public.profiles;
begin
  if me is null then
    raise exception 'not signed in';
  end if;

  select * into target
  from public.profiles
  where founder_code = upper(trim(target_code));

  if target.id is null then
    raise exception 'no founder with code %', target_code;
  end if;
  if target.id = me then
    raise exception 'that is your own founder code';
  end if;

  insert into public.friendships (user_id, friend_id)
  values (me, target.id) on conflict (user_id, friend_id) do nothing;

  insert into public.friendships (user_id, friend_id)
  values (target.id, me) on conflict (user_id, friend_id) do nothing;

  return target;
end;
$$;

grant execute on function public.add_friend_by_code(text) to authenticated;
