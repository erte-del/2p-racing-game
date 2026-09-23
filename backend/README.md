# The server side

Accounts and leaderboards, on Supabase. There is no server to run: the whole
back end is the four tables in `schema.sql`, and the game talks to them
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

4. In **Authentication → URL Configuration**, set the **Site URL** to a page
   that actually exists.

   This is the step that is easy to miss and looks like a broken account when
   it is missed. A confirmation link does not go to your site: it goes to
   Supabase, which checks the token and *then* redirects the player to the
   Site URL. That setting ships as `http://localhost:3000`, because Supabase
   assumes you are building a web app and running a dev server. This game is
   a desktop binary, nothing is listening on that port, and the player is
   left looking at `ERR_CONNECTION_REFUSED` - having been confirmed
   perfectly well on the way past. Clicking again then reports an expired
   link, because these tokens are good for exactly one use.

   Point it at any page that says the account is confirmed. There is one
   written for this game, live at

       https://erte-del.github.io/2p-racing-confirm/

   and kept in `confirmation-page.html` here. It is served out of a separate
   public repository holding nothing but that one file, so the game's own
   source stays private - GitHub Pages will not serve a private repository on
   a free plan, and opening this repository up to publish one landing page
   would be a steep price for it.

   The alternative is to turn **Confirm email** off, which makes signing up
   hand back a session immediately and skips all of this. That costs you
   little - accounts still have passwords, and an unconfirmed email only
   means somebody could sign up under an address that is not theirs - but it
   also removes the one thing standing between an open leaderboard and one
   person holding forty accounts.

5. In **Project Settings → API**, copy the **Project URL** and the **anon
   public** key.
6. In the root of the repo, copy `backend.example.cfg` to `backend.cfg` and
   paste both in.

That is the whole setup. Run the game and the Account button appears.

## What the schema builds

`schema.sql` is written to be pasted in and run again whenever it changes.
Tables and indexes are made only if they are not there, every policy is
dropped before it is made, and the bucket is updated in place if it already
exists - so running the whole file on a project that has an older version of
it brings that project up to this one rather than failing halfway.

**`racers`** is an account with a name on it. It is kept apart from Supabase's
own `auth.users`, because that table holds the email address, and a board has
to be able to show who set a time without showing everyone's email. Names are
unique regardless of case.

**`times`** is one row per racer per version of a track: their best. A trigger
keeps the better of an old and a new time, so the game can send every finish
as an upsert without knowing whether it is an improvement. Nobody may delete a
time.

**`cars`** is the cars players have shared. There is no "shared" column - being
in the table is being shared, and a car nobody shared has no row, no model and
no presence on the server at all. The id is the first sixteen hex characters of
the sha256 of the model, and a constraint holds the model's path to
`<owner>/<id>.glb`, so a row can only ever point at its owner's own file.
Anybody may read the table, signed in or not, so a player can browse before
making an account. Only the owner may insert or delete a row, and the only
column anybody may update is the name: the id is the hash of what was shared,
and nothing may drift away from it.

**`liveries`** is the designs players have shared - stripes, stickers and
handwriting drawn in the garage. It works like `cars` with one difference that
removes most of the complication: **there is no bucket.** A car has to be a
file of a few megabytes, so `cars` keeps the model in storage and the row
points at it, and the path constraint and the storage policies below all exist
to keep those two honest. A livery is one line of text a few hundred characters
long, so the design is a column and the row *is* the livery. Sharing is one
insert, unsharing is one delete, and there is no half-shared state for anything
to go wrong in.

The id is the first sixteen hex characters of the sha256 of that very text.
Nothing here can enforce that - the hash is the game's - so the game refuses
any row whose marks do not come back out as its own id, and what the database
promises is only that a design is not empty and not enormous. As with cars,
anybody may read, only the owner may insert or delete, and the name is the one
column anybody may update.

One thing falls out of the design being a column rather than a file: the
request that lists what has been shared also carries every design, so the
browse page draws all of them at once off a single request. A page of shared
cars can only show names, because showing a car would mean downloading every
model on the list.

**The `cars` bucket** holds the models: private, 8 MB a file, and nothing but
`model/gltf-binary`. It is private because in a public bucket an object is
readable by anyone with its path - before its row exists and after it has gone
- and what makes sharing safe is that a model is readable exactly while a row
points at it. Uploads go only into the uploader's own folder, under a name that
is a car's id. There is no update policy, because overwriting a model in place
would leave its id describing something else.

Two things about the storage policies are easy to get wrong, and both fail
quietly:

- **The read policy spells out `storage.objects.name`.** Inside the subquery a
  bare `name` binds to `cars.name`, the car's display name, which never equals
  a path - so every read is denied. Storage reports a denied read as "Object not
  found", which sends you looking for a missing file instead of a policy.
- **An owner can always read their own folder.** Storage will not delete an
  object its caller cannot see. Without this, the model of a car whose row has
  been deleted could never be cleared away, and a player who unshared a car
  could never share it again: the upload would find the old model still at the
  path and be unable to remove it. Nobody else can read anything more than
  before.

If a project already has a `cars` table from an earlier version of this game's
schema, running the file adds the constraint on the model path to it. That
fails if any existing row points somewhere other than `<owner>/<id>.glb`;
delete those rows first.

**A project set up before liveries existed needs `schema.sql` running again.**
Everything in it is `create ... if not exists` and `drop policy ... / create
policy`, so running the whole file over a live project adds the `liveries`
table and leaves the rest as it was. Until it has been run, sharing a livery
fails and the LIVERIES half of the browse page comes up empty - the rest of the
game, including sharing cars, carries on exactly as before.

## Sending your own email

Everything above works on Supabase's built-in email sender, and that sender is
for trying things out rather than for players. It is shared, heavily rate
limited to a few messages an hour, and Supabase say plainly it is not for
production. With a leaderboard open to more than a couple of friends, most
confirmation emails simply will not arrive. It is also why the email templates
are locked: the dashboard will not let you edit an email you are not paying to
send.

Setting up your own sender fixes both at once.

1. Make an account with an email provider. **Resend** is the least work -
   a free tier of 3,000 messages a month, and a sandbox sender you can use
   immediately without owning a domain. Brevo and Mailgun are equivalent.
2. Verify a domain if you have one. Without it you can still send, but from
   the provider's address rather than yours, and more of it lands in spam.
3. In Supabase, **Project Settings -> Authentication -> SMTP Settings**, turn
   on custom SMTP and fill in the host, port, username and password your
   provider gives you. The password is an API key; treat it the way you would
   treat the service role key, and note it lives only in the dashboard - it
   never goes near `backend.cfg` or the game.
4. The template editor unlocks. Paste `confirm-email.html` from this folder
   into **Authentication -> Emails -> Confirm sign up**, and set the subject
   to something a player will recognise in a crowded inbox.

The template is written for email rather than for the web - tables, inlined
styles, no web fonts - because that is the only thing that renders the same in
Gmail, Outlook and Mail. It uses the same colours as the landing page, so the
email and the page it leads to read as one thing.

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
