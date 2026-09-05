# The server side

Accounts and leaderboards, on Supabase. There is no server to run: the whole
back end is the two tables in `schema.sql`, and the game talks to them
directly over HTTPS.

Everything in the game works without any of this. A build with no
`backend.cfg` has no Account button, no boards, and the same local best times
it always had.

## What you have to do

These are the steps I cannot do for you — they need an account made in your
name, and a key that belongs to you.

1. Make a project at [supabase.com](https://supabase.com). The free tier is
   more than enough for this: the whole leaderboard is one small row per
   player per track.
2. In the dashboard, open **SQL Editor**, paste in all of `schema.sql`, and
   run it. It is safe to run twice.
3. In **Authentication → Sign In / Providers**, make sure Email is enabled.
   Decide there whether you want **Confirm email** on:
   - **On** is the safer default. A new player has to click a link in their
     inbox before they can sign in, which is what stops one person making
     forty accounts to fill a board.
   - **Off** signs players in the moment they sign up, which is a much
     smoother first five minutes. The game handles both — with confirmation
     on, the account screen tells the player to go and check their email.
4. In **Project Settings → API**, copy the **Project URL** and the **anon
   public** key.
5. In the root of the repo, copy `backend.example.cfg` to `backend.cfg` and
   paste both in.

That is the whole setup. Run the game and the Account button appears.

## About that key

The anon key is meant to ship inside the game. It says which project this is,
not who the player is, and every copy of the game contains it. What stops one
player writing over another's time is the row level security in `schema.sql`,
where the database checks the racer id on a write against the account the
request is actually signed in as.

The key is kept out of git anyway, because which project your game talks to is
yours to decide rather than something baked into the source. `backend.cfg` is
in `.gitignore`.

The one key you must never put in `backend.cfg` is the **service role** key
from the same dashboard page. That one bypasses every policy here, and it
would be inside every copy of the game you shipped.

## When you export the game

`backend.cfg` is not a Godot resource, so it is not exported by default. In
the export preset, under **Resources**, add `*.cfg` to
*Filters to export non-resource files*. Without it the exported build silently
has no server, which looks exactly like a bug and is not one.

## What this does and does not defend against

The database will not let a player write a time under someone else's name,
delete anyone's record, or replace their own time with a slower one. Those are
policies and a trigger, enforced where the player cannot reach.

It cannot tell whether a time was actually driven. The game runs on the
player's machine, so a determined person can send whatever number they like
under their own name, and there is a floor here only against the absurd.
Proving a lap really happened means sending the inputs and replaying them on
the server, which is a much larger piece of work than this and is not what
this is.

For a board among people who know each other, that is usually fine. For an
open board, expect to eventually want either replay verification or the
ability to remove a row by hand.
