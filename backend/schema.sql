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

-- Cars players have shared.
--
-- There is no "shared" column. Being in this table is being shared, and a car
-- nobody shared has no row, no model in storage and no presence here at all -
-- so there is no flag that can be flipped the wrong way, and nothing about a
-- private car for anyone to find.
--
-- The id is the first sixteen hex characters of the sha256 of the model, which
-- is what the game checks a downloaded model against. The model always lives
-- in its owner's own folder under that id, and the constraint says so: a row
-- cannot point at somebody else's file, which is the only thing that would
-- make that file readable.
create table if not exists public.cars (
  id text primary key check (id ~ '^[0-9a-f]{16}$'),
  owner uuid not null references public.racers on delete cascade,
  name text not null check (char_length(name) between 1 and 24),
  model text not null,
  vertices integer not null check (vertices > 0),
  shared_at timestamptz not null default now()
);

-- Added apart from the table so that running this again puts it on a table
-- an earlier version of this file made without it.
alter table public.cars drop constraint if exists cars_model_is_its_own;
alter table public.cars add constraint cars_model_is_its_own
  check (model = owner::text || '/' || id || '.glb');

-- The one query the browse page runs: the newest first.
create index if not exists cars_newest on public.cars (shared_at desc);

alter table public.cars enable row level security;

-- Anyone may look, including somebody who has not made an account: browsing
-- is how a player finds out whether there is anything worth signing up for.
drop policy if exists cars_readable on public.cars;
create policy cars_readable on public.cars
  for select using (true);

drop policy if exists cars_share_own on public.cars;
create policy cars_share_own on public.cars
  for insert with check (auth.uid() = owner);

drop policy if exists cars_rename_own on public.cars;
create policy cars_rename_own on public.cars
  for update using (auth.uid() = owner) with check (auth.uid() = owner);

drop policy if exists cars_unshare_own on public.cars;
create policy cars_unshare_own on public.cars
  for delete using (auth.uid() = owner);

grant select on public.cars to anon, authenticated;
grant insert, delete on public.cars to authenticated;
-- The name, and only the name. The id is the hash of the bytes and the model
-- is where those bytes are, so neither may drift from what was shared. Taken
-- away first, so a table an earlier run granted whole updates on ends up here.
revoke update on public.cars from anon, authenticated;
grant update (name) on public.cars to authenticated;

-- A livery somebody has shared: a design, and nothing else.
--
-- No bucket and no second table. A car has to be a file, so `cars` keeps the
-- model in storage and points at it, and every awkward thing about that table
-- follows from the row and the file being able to disagree. A livery is one
-- line of text a few hundred characters long, so it is a column - the row *is*
-- the livery, a share is one insert, an unshare is one delete, and there is no
-- state in between for anything to go wrong in.
--
-- The id is the first sixteen hex characters of the sha256 of that very text,
-- which is what the game checks a downloaded design against. Nothing here can
-- enforce that - the hash is the game's - so the game refuses a row whose
-- marks do not come out as its own id, and what the database guarantees is
-- only that a design is not empty and not enormous.
create table if not exists public.liveries (
  id text primary key check (id ~ '^[0-9a-f]{16}$'),
  owner uuid not null references public.racers on delete cascade,
  name text not null check (char_length(name) between 1 and 24),
  marks text not null check (char_length(marks) between 1 and 8192),
  shared_at timestamptz not null default now()
);

-- The one query the browse page runs: the newest first.
create index if not exists liveries_newest on public.liveries (shared_at desc);

alter table public.liveries enable row level security;

-- Anyone may look, signed in or not, for the reason the cars are readable.
drop policy if exists liveries_readable on public.liveries;
create policy liveries_readable on public.liveries
  for select using (true);

drop policy if exists liveries_share_own on public.liveries;
create policy liveries_share_own on public.liveries
  for insert with check (auth.uid() = owner);

drop policy if exists liveries_rename_own on public.liveries;
create policy liveries_rename_own on public.liveries
  for update using (auth.uid() = owner) with check (auth.uid() = owner);

drop policy if exists liveries_unshare_own on public.liveries;
create policy liveries_unshare_own on public.liveries
  for delete using (auth.uid() = owner);

grant select on public.liveries to anon, authenticated;
grant insert, delete on public.liveries to authenticated;
-- The name, and only the name. The id is the hash of the marks, so a design
-- may never drift from the one that was shared under it.
revoke update on public.liveries from anon, authenticated;
grant update (name) on public.liveries to authenticated;

-- Where the models are.
--
-- Private. In a public bucket an object can be read by anyone who knows its
-- path, which means before its row exists and after its row has gone, and the
-- whole of what makes sharing safe is that a model is readable exactly while a
-- row points at it.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('cars', 'cars', false, 8388608, array['model/gltf-binary'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- A model can be read while a row points at it, by anyone.
--
-- `storage.objects.name` is spelled out in full on purpose. A bare `name`
-- inside the subquery binds to `cars.name` - the car's display name - which
-- never equals a path, so every read is quietly denied. Storage reports a
-- denied read as "Object not found", which sends you looking in the wrong place.
--
-- And its owner can always read their own folder. Storage will not delete an
-- object its caller cannot see, so without this an unshared car's model - its
-- row already gone - could never be cleared away, and a player who unshared a
-- car could never share it again: the upload would find the old model in the
-- way and be unable to remove it. Nobody but the owner gains anything.
drop policy if exists cars_models_readable on storage.objects;
create policy cars_models_readable on storage.objects
  for select using (
    bucket_id = 'cars' and (
      exists (select 1 from public.cars c where c.model = storage.objects.name)
      or (storage.foldername(storage.objects.name))[1] = auth.uid()::text
    )
  );

-- Only into your own folder, and only under a name that is a car's id. Nothing
-- else can be put in the bucket, so it cannot be used to keep anything else.
drop policy if exists cars_models_upload_own on storage.objects;
create policy cars_models_upload_own on storage.objects
  for insert to authenticated with check (
    bucket_id = 'cars'
    and (storage.foldername(storage.objects.name))[1] = auth.uid()::text
    and storage.objects.name ~ ('^' || auth.uid()::text || '/[0-9a-f]{16}\.glb$')
  );

drop policy if exists cars_models_erase_own on storage.objects;
create policy cars_models_erase_own on storage.objects
  for delete to authenticated using (
    bucket_id = 'cars'
    and (storage.foldername(storage.objects.name))[1] = auth.uid()::text
  );

-- Deliberately no update policy. Overwriting a model in place would leave its
-- id, which is the hash of what was shared, describing something else.
