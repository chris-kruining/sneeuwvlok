# hatrix (design sketch)

Nothing here is built yet. This folder only holds the design until there is a
`default.nix`, which is why snowfall doesn't pick it up as a module.

A generic bridge between Matrix and Home Assistant. It gives HA access to the
chats I have with friends, and lets HA talk back to me on Matrix. HA decides
what to do with it, hatrix only carries messages. The name follows arrtrix.

The first use case is the **calendar**: turning the plans we make ("zaterdag
bowlen?" "ja, 8 uur bij Sam") into events, after asking me first. Others can
follow (notifications, commands) without changing the bot, only its
configuration and HA.

## Context

- My friends are on Signal and WhatsApp, which reach Matrix through the
  mautrix bridges on ulmo (see `../matrix`). Their messages arrive in normal
  Matrix rooms.
- HA's LLM is llama.cpp through llama-swap, which wakes manwe on demand (see
  `../../development/llama-swap/README.md`). **Every hand-off that reaches the
  LLM can wake manwe**, so the bot must not pass on every message.

## Why not Home Assistant's own `matrix` integration

That integration fires an event for each message, so it has no idea of a
conversation. Plans tend to come together over several messages and people.
If HA reacts to every message, it wakes manwe all day. The bot does the
buffering and filtering that HA can't do well, and hands over the whole
conversation at once.

## Responsibilities

| hatrix                                                | Home Assistant                                       |
| ----------------------------------------------------- | ---------------------------------------------------- |
| Log in to Matrix, join rooms I invite it to           | Decide what a conversation means (LLM)               |
| Keep a rolling window of messages per room            | Act on it (calendar, notifications, …)               |
| Apply each watcher's rules, decide when to hand off   | Ask me for confirmation, through hatrix              |
| POST conversations to the watcher's HA webhook        | Remember what was proposed, accepted, dismissed      |
| Send messages for HA, pass reactions/replies back     |                                                      |

hatrix knows nothing about calendars. Everything use-case specific is either a
watcher's configuration or lives in HA.

## Watchers

A watcher is one use case: which conversations it wants, when they are ready,
and which webhook gets them. They are declared in nix, and every room the bot
is in is checked against every watcher.

```nix
watchers.calendar = {
  webhook = "hatrix/webhook/calendar";  # sops secret holding the HA webhook id
  rooms = "all";                        # or a list of room ids
  requireOwner = true;                  # only conversations I took part in
  quietFor = "10m";                     # debounce: hand off once the room is quiet
  quietHours = { from = "23:00"; to = "08:00"; };
  window = { messages = 50; age = "24h"; };
};
```

- **`requireOwner`**: the messages since the last hand-off must include at
  least one of mine. Chats I'm only reading along in are never handed off,
  however much they talk about plans.
- **`quietFor`**: hand off once a room has been quiet that long, so a plan
  that comes together over several messages arrives as one conversation.
- **`quietHours`**: rooms that become due then wait until the morning.
- Due rooms of the same watcher are sent in **one** webhook call, so HA can
  handle them in one wake of manwe.

There is no keyword or pattern matching in hatrix. Whether a conversation is
about something (an event, for the calendar) is decided by the LLM in HA,
which handles any language and phrasing. hatrix only decides *when* a
conversation is ready, and the rules above keep that to a few hand-offs a
day: only chats I took part in, only once they have gone quiet, batched.

## Flow (calendar)

```
bridged room ──messages──▶ hatrix: buffer per room
                              │  watcher "calendar": I took part, quiet for 10m
                              ▼
                 POST /api/webhook/<calendar id>  { conversations[] }   (hatrix → HA)
                              │
                              ▼
          HA automation: LLM report → about an event? which? (JSON)
                              │  nothing found → stop
                              │
                              ▼
     rest_command → hatrix: DM @chris "Add Bowling with Sam, Sat 21 Nov 20:00? 👍 / ❌"
                              │  reaction or reply
                              ▼
                 POST /api/webhook/<calendar id>  { response }          (hatrix → HA)
                              │
                              ▼
          HA: ha_caldav.create_event / update_event / delete_event
```

## Listening

- A plain Matrix client (bot user `@hatrix:kruining.eu`), not an
  appservice. It joins the rooms I invite it to, so I decide which chats HA
  can see. The bridges only relay messages from users they puppet, so friends
  don't see the bot.
  - Alternative: an appservice with a `namespaces.rooms` regex for the bridge
    portals, so it doesn't need invites. More setup, and it can read
    everything. Start with invites.
- The bot user is created once with `register_new_matrix_user` and the
  existing `synapse/shared_secret`. Its password is `hatrix/matrix_password`.
- Encryption: the bridged portals are not end-to-end encrypted right now. If
  they become encrypted, the bot needs crypto (mautrix-go's cryptohelper, as
  arrtrix already depends on olm).
- The message window per room is kept in memory, with sender display names
  and timestamps. After a restart, it is refilled from `/messages`.

## Interface with HA

hatrix → HA, over HA's webhook trigger (`POST http://[::1]:6010/api/webhook/<id>`,
local only). Every watcher has its own webhook id, kept as a secret.

```json
{
  "type": "conversation",
  "watcher": "calendar",
  "conversations": [
    {
      "room_id": "!abc:kruining.eu",
      "room_name": "Sam (WhatsApp)",
      "messages": [
        { "id": "$ev1", "sender": "Sam", "own": false, "ts": "2026-11-18T14:02:11+01:00", "body": "zaterdag bowlen?" },
        { "id": "$ev2", "sender": "Chris", "own": true, "ts": "2026-11-18T14:05:40+01:00", "body": "ja, 8 uur?" }
      ]
    }
  ]
}
```

Reactions and replies to a message hatrix sent for a watcher go back to that
watcher's webhook:

```json
{ "type": "response", "watcher": "calendar", "in_reply_to": "$dm1", "reaction": "👍" }
{ "type": "response", "watcher": "calendar", "in_reply_to": "$dm1", "text": "make it 19:30" }
```

HA → hatrix, over a small HTTP API on `[::1]` that HA calls with `rest_command`:

- `POST /send` `{ "watcher": "calendar", "to": "owner", "body": "...", "html": "..." }`
  → `{ "event_id": "$dm1" }`

  hatrix remembers which watcher sent the message, so it knows where the
  reactions go. HA keeps the event id with its own state, so it knows what
  the reaction is about. For now hatrix only sends to the owner, never to the
  friends' rooms.

Authentication: the API only listens on `[::1]` and requires a bearer token,
which HA passes from its `secrets.yaml`.

## Calendar in HA (sketch, built there)

- **LLM report**: the LLM both decides whether a conversation is about an
  event and extracts it, in one call per hand-off. The llama.cpp integration
  in HA 2026.10.4 only provides a conversation agent, no `ai_task` entity, so
  HA can't ask it for structured output. Instead, the automation calls
  llama-swap directly with a `rest_command` that sets `response_format` to a
  JSON schema. llama.cpp enforces the schema, so the reply always parses. The
  model is the `:assist` variant.

  ```json
  {
    "conversations": [
      {
        "room_id": "!abc:kruining.eu",
        "about_event": true,
        "language": "nl",
        "events": [
          {
            "action": "create",
            "uid": null,
            "title": "Bowlen met Sam",
            "start": "2026-11-21T20:00:00+01:00",
            "end": null,
            "all_day": false,
            "location": null,
            "status": "agreed",
            "confidence": 0.85,
            "evidence": ["$ev1", "$ev2"]
          }
        ]
      }
    ]
  }
  ```

  - `about_event: false` (with no events) is the normal outcome for most
    conversations, and ends the automation.
  - `action` is `create`, `update` or `delete`. For the last two, `uid` is the
    existing event's uid.
  - `status` is `agreed` or `tentative`. Only `agreed` plans are proposed.
  - `language` is the conversation's language (`nl` or `en` for now). The
    title is in that language.
- **Prompt**: the current date and time (Europe/Amsterdam), my name, that
  conversations can be Dutch or English, the events already in that period
  (from `ha_caldav.search_events`) so it can recognise changes to them, and
  the messages. Relative dates ("zaterdag", "next Friday") are resolved
  against the time of the message, not the hand-off.
- **Filtering**: drop events with low confidence, in the past, or the same as
  an existing event.
- **Pending proposals**: a `local_todo` list ("hatrix calendar") in HA, one
  item per proposal, holding the candidate as JSON in its description and the
  DM's event id in its summary. It is visible and easy to clean up by hand,
  and survives restarts. (A `text` helper holds 255 characters at most, too
  little.)
- **Confirmation**: one DM per candidate through `rest_command.hatrix_send`.
  On a `response`: 👍 runs the candidate's action, ❌ marks it done without
  acting, a text reply goes through the LLM again as a correction.
- **Changed plans**: when a later conversation changes or cancels a plan
  already in the calendar ("let's do 9 instead", "Sam can't make it"), the
  candidate is an `update` or `delete` of that event instead of a new one.
- **Calendar**: the friend's Nextcloud, through the
  [`ivenos/ha_caldav`](https://github.com/ivenos/ha_caldav) custom integration
  (CalDAV Complete), packaged like `home-assistant-stellantis-vehicles`. It
  has `create_event`, `update_event` and `delete_event` (and `search_events`).
  It needs HA 2026.3+, and Python `caldav>=2.1.0`, `icalendar>=6.3.1` and
  `vobject>=0.9.9`. Setup in the UI with a Nextcloud app password. HA's
  built-in `caldav` integration can create events but not edit or delete
  them (in 2026.10.4 its calendar entity only declares
  `CalendarEntityFeature.CREATE_EVENT`), which is why it isn't used. Don't
  add it for this account as well, or the calendar shows up twice.

## State

SQLite in `/var/lib/hatrix`: Matrix sync token, the Matrix access token, the
last hand-off per room and watcher, and which watcher sent which message.
What a message or reaction means is HA's state, not hatrix's.

## Module shape (once it exists)

Follows the pattern of `../matrix` (which sets up arrtrix) and `packages/arrtrix`:

- `packages/hatrix`: Go, using mautrix-go (same as arrtrix).
- `modules/nixos/services/communication/hatrix/default.nix`:
  `${namespace}.services.communication.hatrix` with `enable` and `watchers`, a
  hardened systemd service with `DynamicUser` and `StateDirectory`, and its
  settings rendered with a sops template.
- Secrets (in ulmo's `secrets.yml`):
  - `hatrix/matrix_password` for the bot user
  - `hatrix/api_token`, which HA uses to call hatrix
  - `hatrix/webhook/<watcher>`, e.g. `hatrix/webhook/calendar`, shared with
    HA's config
- Observability: OTLP to alloy like arrtrix (`http://[::1]:9071`), with
  metrics per watcher for hand-offs, rooms skipped by each rule, and HA
  response times. The number of hand-offs per day shows how often the
  calendar watcher wakes manwe. If that turns out to be too often, raise
  `quietFor` before considering anything else.

## Build order

1. Package `ha_caldav` and add it to HA's `customComponents`, connect the
   friend's Nextcloud.
2. hatrix: package, module, bot user, secrets.
3. HA: the calendar automations, `rest_command`s and the to-do list.

## Open questions

- Privacy: chat content only goes to HA and the local model on manwe, never to
  an external API. Keep it that way.
