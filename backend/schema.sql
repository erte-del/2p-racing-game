-- The whole server side of the leaderboard, as one file to paste into the
-- Supabase SQL editor.
--
-- There is no server code. Everything the game asks for is a query against
-- these two tables, and everything that stops a player writing something they
-- should not be able to write is a policy or a constraint here rather than a
-- check in the game - the game runs on the player's machine, so nothing it
-- decides can be trusted, and a rule that only exists there is a rule that
-- holds until someone opens the binary.

-- A racer is an account with a name on it.
--
-- Kept apart from Supabase's own auth.users because that table holds the
-- email address, and a leaderboard has to be able to show who set a time
-- without showing the whole world what everyone's email is. This table holds
-- only what is meant to be read by everybody.
create table if not exists public.racers (
  id uuid primary key references auth.users on delete cascade,
  name text not null check (char_length(name) between 2 and 16),
  created_at timestamptz not null default now()
);

-- Names are taken case-insensitively, so nobody can stand next to someone
-- else on a board wearing their name with one letter capitalised.
create unique index if not exists racers_name_unique
  on public.racers (lower(name));

-- One row per racer per version of a track: their best, and nothing else.
--
-- The signature is what makes a board mean something. It is a hash of the
-- track file plus the physics generation, so a time is only ever compared
-- against times set on the same road by the same car. Edit a corner on track
-- seven and the times set on the old seven do not vanish - they simply stop
-- being on the same board as the new ones, which is the truth of it.
create table if not exists public.times (
  racer uuid not null references public.racers on delete cascade,
  track text not null,
  signature text not null,
  seconds double precision not null,
  set_at timestamptz not null default now(),
  primary key (racer, track, signature),

  -- Not anti-cheat, just a floor under the absurd. A real defence against a
  -- forged time needs the inputs replayed on the server, which this is not.
  constraint times_plausible check (seconds > 0.5 and seconds < 3600.0)
);

-- The one query the boards run: everyone's time on one version of one track,
-- quickest first.
create index if not exists times_board
  on public.times (track, signature, seconds);

-- A time may only ever be replaced by a better one.
--
-- The game sends every finish as an upsert, because the game does not know
-- and should not have to know whether the player has been here before. This
-- turns that into the rule the record actually has: returning the old row
-- from a BEFORE UPDATE trigger leaves it exactly as it was, so a slower lap
-- is accepted by the server and quietly changes nothing.
create or replace function public.keep_the_better_time()
returns trigger
language plpgsql
as $$
begin
  if new.seconds >= old.seconds then
    return old;
  end if;
  new.set_at := now();
  return new;
end;
$$;

drop trigger if exists keep_the_better_time on public.times;
create trigger keep_the_better_time
  before update on public.times
  for each row execute function public.keep_the_better_time();

alter table public.racers enable row level security;
alter table public.times enable row level security;

-- Anyone may read the boards, including a player who has not signed in: a
-- leaderboard you have to join to look at is a leaderboard nobody joins.
drop policy if exists racers_readable on public.racers;
create policy racers_readable on public.racers
  for select using (true);

drop policy if exists times_readable on public.times;
create policy times_readable on public.times
  for select using (true);

-- Writing is only ever writing your own row. This is the line that matters:
-- the racer column is checked against the signed-in user by the database, so
-- a modified game cannot post a time under somebody else's name however it
-- asks.
drop policy if exists racers_claim_own on public.racers;
create policy racers_claim_own on public.racers
  for insert with check (auth.uid() = id);

drop policy if exists racers_rename_own on public.racers;
create policy racers_rename_own on public.racers
  for update using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists times_write_own on public.times;
create policy times_write_own on public.times
  for insert with check (auth.uid() = racer);

drop policy if exists times_improve_own on public.times;
create policy times_improve_own on public.times
  for update using (auth.uid() = racer) with check (auth.uid() = racer);

-- Deliberately no delete policy on times. A record is something that
-- happened; the only thing that may touch one is a better one.

-- And the privileges the policies sit on top of.
--
-- These are two different gates and both have to be open. A policy says which
-- rows of a table a role may touch; a grant says whether that role may touch
-- the table at all. A table with careful policies and no grant is a table
-- nobody can read, which arrives as "permission denied for table times"
-- rather than as an empty board.
--
-- `anon` is a player who has not signed in, and may only ever read: that is
-- what lets somebody look at a board before deciding an account is worth
-- making. `authenticated` may also write, but which rows it may write are
-- still decided by the policies above.
grant select on public.racers to anon, authenticated;
grant select on public.times to anon, authenticated;

-- Insert and update, because a time is sent as an upsert and an upsert is
-- both. No delete, matching the missing delete policy: taking that privilege
-- away entirely means a record cannot be removed even by a mistake here.
grant insert, update on public.racers to authenticated;
grant insert, update on public.times to authenticated;
