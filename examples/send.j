#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

/**
 * Post to a Discord channel: DISCORD_WEBHOOK_URL=... jennifer run examples/send.j
 *
 * Prints the payload it would send. Without the variable it prints a hint and
 * posts nothing; when the webhook cannot be reached it prints the error.
 */

use io;
use os;

import "http.j" as http;
import "../src/discord.j" as discord;

def url as string init os.getEnv("DISCORD_WEBHOOK_URL");

def m as discord.Message init discord.content(discord.message(), "Deploy finished");
$m = discord.embed($m, "Deploy", "build 1234 is live in production", 3066993);
$m = discord.embedField($m, "Duration", "4m 12s", true);
$m = discord.embedFooter($m, "ci");
io.printf("payload: %s\n", discord.render($m));

if (len($url) == 0) {
    io.printf("set DISCORD_WEBHOOK_URL to post it\n");
} else {
    try {
        def r as http.Response init discord.sendMessage($url, $m);
        io.printf("sendMessage -> %d %s\n", $r.status, $r.statusText);
    } catch (e) {
        io.printf("no webhook at that URL (%s)\n", $e.message);
    }
}
