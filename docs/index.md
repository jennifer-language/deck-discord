<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# @jennifer/discord

Posts messages to a [Discord](https://discord.com) channel through a channel
[webhook](https://discord.com/developers/docs/resources/webhook), using
Jennifer's `http` module. The full API is on the
[cheatsheet](cheatsheet.md).

## Conventions

Snippets assume these imports:

```jennifer
import "@jennifer/discord/" as discord;
import "http.j" as http;
```

The trailing slash resolves to the entry module.

## Sending

```jennifer
def url as string init os.getEnv("DISCORD_WEBHOOK_URL");
def r as http.Response init discord.send($url, "deploy finished");
if ($r.status != 204) {
    io.printf("discord: %d %s\n", $r.status, $r.body);
}
```

`send` POSTs `{"content": ...}` as JSON to the webhook URL. The content is
Discord markdown. The webhook URL carries its own token, so treat it as a
secret: read it from the environment or a config file. A URL that does not
start with `https://` throws an error of kind `discord` before anything is
sent, so a missing or mistyped scheme cannot send the token in the clear;
`http://` is allowed only to `127.0.0.1`, `localhost` and `[::1]`, for a local
test server.

## Rich messages

The builder starts from `message()`; every step returns a new `Message`:

```jennifer
def m as discord.Message init discord.content(discord.message(), "Deploy finished");
$m = discord.embed($m, "Deploy", "build 1234 is live", 3066993);
$m = discord.embedField($m, "Duration", "4m 12s", true);
$m = discord.embedFooter($m, "ci");
$m = discord.username($m, "releaser");
def r as http.Response init discord.sendMessage($url, $m);
```

| Step | Sets |
|---|---|
| `content` | the message text |
| `username`, `avatar` | the name and avatar image shown instead of the webhook's own |
| `embed` | appends a card: title, description, left-bar colour as a decimal RGB int (`3066993` is green) |
| `embedField`, `embedFooter`, `embedAuthor` | a field, the footer or the author of the **latest** embed |
| `noMentions` | turns mention parsing off, so the message notifies nobody |

The embed steps throw an error of kind `discord` when the message has no
embed yet, and `embed` throws one for a colour outside 0 to 16777215
(`0xFFFFFF`). `render` returns the JSON payload without sending it, which is
handy for logging and tests. Empty parts are left out of the payload; a
message needs content or at least one embed for Discord to accept it.

## Mentions

Discord acts on `@everyone`, `@here`, `<@id>` and `<@&role>` in the content,
wherever the text came from. When it carries text from elsewhere (a commit
message, a user name), send it with `noMentions`, which adds
`"allowed_mentions": {"parse": []}` so the text shows but notifies nobody:

```jennifer
def m as discord.Message init discord.content(discord.message(), "deployed: " + $commitMessage);
def r as http.Response init discord.sendMessage($url, discord.noMentions($m));
```

`send` has no such option; use `sendMessage` for untrusted text.

## Errors

`send` and `sendMessage` return the `http.Response` and do not inspect it.
Discord answers `204` on success; a deleted webhook is a `404` response and a
malformed payload a `400`, not errors. A webhook URL that is not `https://`
throws an error of kind `discord`; a transport failure (no network, refused
connection, TLS) throws from `http`.

## Runtime

Needs `net`, so it runs on the default `jennifer` binary. The stock
`jennifer-tiny` has no network driver and every send throws; building and
rendering messages works on both.

## Moving from the standard library module

Jennifer has shipped `discord` as a standard library module
(`modules/discord.j`) since 0.18.0; `username`, `avatar`, `embedField`,
`embedFooter` and `embedAuthor` came in 0.23.0. The module is deprecated from
Jennifer 0.26.0 and removed in 0.28.0. This deck replaces it with the same
types and functions; only the import changes:

```jennifer
import "discord.j" as discord;             # before
import "@jennifer/discord/" as discord;    # after: jvc add @jennifer/discord
```

Three things differ from the module: the deck adds `noMentions` and the
`Message.allowedMentions` field behind it (so a `Message{...}` literal needs
the extra field), `embed` refuses an out-of-range colour, and a webhook URL
that is not `https://`, which the module would have sent, throws.
