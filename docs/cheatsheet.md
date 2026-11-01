<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# discord cheatsheet

Every export of `@jennifer/discord`. Background is in
[the introduction](index.md).

```jennifer
import "@jennifer/discord/" as discord;
import "http.j" as http;
```

Both sends POST JSON to the webhook URL and return the `http.Response`
unchecked: `204` on success, `404` for a deleted webhook. A URL that is not
`https://` (or `http://` to a loopback host) throws `discord`; transport
failures throw from `http`.

## Types

### `Message`

| Field | Meaning |
|---|---|
| `content as string` | message text; `""` to omit |
| `embeds as list of Embed` | the embeds, in order |
| `username as string` | display name override; `""` for none |
| `avatar as string` | avatar image URL override; `""` for none |
| `allowedMentions as string` | rendered `allowed_mentions` object; `""` for Discord's default |

### `Embed`

| Field | Meaning |
|---|---|
| `title as string` | embed title |
| `description as string` | embed body |
| `color as int` | left-bar colour, decimal RGB |
| `fields as list of string` | rendered field objects |
| `footer as string` | rendered footer object; `""` for none |
| `author as string` | rendered author object; `""` for none |

## Sending

| Function | Returns | Sends |
|---|---|---|
| `discord.send(webhookUrl, content)` | `http.Response` | `{"content": ...}` |
| `discord.sendMessage(webhookUrl, m)` | `http.Response` | `render(m)` |

## Building

| Function | Returns | Does |
|---|---|---|
| `discord.message()` | `Message` | an empty message |
| `discord.content(m, content)` | `Message` | sets the text |
| `discord.username(m, name)` | `Message` | sets the display name override |
| `discord.avatar(m, url)` | `Message` | sets the avatar override |
| `discord.noMentions(m)` | `Message` | sets `allowed_mentions` so nobody is notified |
| `discord.embed(m, title, description, color)` | `Message` | appends an embed; throws `discord` for a colour outside 0 to 16777215 |
| `discord.embedField(m, name, value, inline)` | `Message` | adds a field to the latest embed; throws `discord` without one |
| `discord.embedFooter(m, text)` | `Message` | sets the latest embed's footer; throws `discord` without one |
| `discord.embedAuthor(m, name)` | `Message` | sets the latest embed's author; throws `discord` without one |
| `discord.render(m)` | `string` | the JSON payload |
