# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

/**
 * White-box tests for discord: jennifer test src/discord_test.j
 *
 * The payload rendering is tested directly. The sends go to an `httpd` server
 * on a loopback port, which answers one request like a Discord webhook does
 * and hands back what it received.
 */
use convert;
use httpd;
use task;
use testing;

/** One request as the fake webhook saw it. */
def struct Seen {
    method as string,
    path as string,
    contentType as string,
    body as string
};

/**
 * Answer one request: 204 on `/webhook`, like Discord, else 404 with
 * Discord's unknown-webhook error.
 *
 * @param srv {httpd.Server} the listening server
 * @return {Seen} the request
 */
func answerOne(srv as httpd.Server) {
    def req as httpd.Request init httpd.accept($srv);
    def seen as Seen init Seen{
        method: httpd.method($req),
        path: httpd.path($req),
        contentType: httpd.header($req, "Content-Type"),
        body: convert.stringFromBytes("utf-8", httpd.body($req))
    };
    if ($seen.path == "/webhook") {
        httpd.respond($req, 204, "");
    } else {
        httpd.respond($req, 404, '{"message": "Unknown Webhook", "code": 10015}');
    }
    return $seen;
}

func testRenderContentOnly() {
    def m as Message init content(message(), "deploy done");
    testing.assertEqual(render($m), '{"content":"deploy done"}');
}

func testRenderEmpty() {
    testing.assertEqual(render(message()), '{}');
}

func testEmbed() {
    def m as Message init embed(message(), "Deploy", "build 1234 live", 3066993);
    testing.assertEqual(
        render($m),
        '{"embeds":[{"title":"Deploy","description":"build 1234 live","color":3066993}]}');
}

func testContentAndEmbed() {
    def m as Message init embed(content(message(), "heads up"), "T", "D", 255);
    testing.assertEqual(
        render($m),
        '{"content":"heads up","embeds":[{"title":"T","description":"D","color":255}]}');
}

func testEmbedEscaping() {
    def m as Message init embed(message(), "a \"q\"", "line\nnl", 0);
    testing.assertEqual(
        render($m),
        '{"embeds":[{"title":"a \"q\"","description":"line\nnl","color":0}]}');
}

func testMultipleEmbeds() {
    def m as Message init embed(embed(message(), "A", "a", 1), "B", "b", 2);
    testing.assertEqual(
        render($m),
        '{"embeds":[{"title":"A","description":"a","color":1},{"title":"B","description":"b","color":2}]}');
}

func testEmbedField() {
    def m as Message init embedField(embed(message(), "T", "D", 1), "CPU", "80%", true);
    testing.assertEqual(
        render($m),
        '{"embeds":[{"title":"T","description":"D","color":1,"fields":[{"name":"CPU","value":"80%","inline":true}]}]}');
}

func testEmbedFieldMultiple() {
    def m as Message init embedField(
        embedField(embed(message(), "T", "D", 1), "a", "1", true),
        "b",
        "2",
        false);
    testing.assertEqual(
        render($m),
        '{"embeds":[{"title":"T","description":"D","color":1,"fields":[{"name":"a","value":"1","inline":true},{"name":"b","value":"2","inline":false}]}]}');
}

func testEmbedFooter() {
    def m as Message init embedFooter(embed(message(), "T", "D", 1), "ci bot");
    testing.assertEqual(
        render($m),
        '{"embeds":[{"title":"T","description":"D","color":1,"footer":{"text":"ci bot"}}]}');
}

func testEmbedAuthor() {
    def m as Message init embedAuthor(embed(message(), "T", "D", 1), "deploybot");
    testing.assertEqual(
        render($m),
        '{"embeds":[{"title":"T","description":"D","color":1,"author":{"name":"deploybot"}}]}');
}

func testEmbedFieldFooterAuthorOrder() {
    def m as Message init embed(message(), "T", "D", 1);
    $m = embedField($m, "k", "v", false);
    $m = embedFooter($m, "foot");
    $m = embedAuthor($m, "auth");
    testing.assertEqual(
        render($m),
        '{"embeds":[{"title":"T","description":"D","color":1,"fields":[{"name":"k","value":"v","inline":false}],"footer":{"text":"foot"},"author":{"name":"auth"}}]}');
}

func testUsernameAvatar() {
    def m as Message init avatar(username(content(message(), "hi"), "bot"), "https://x/y.png");
    testing.assertEqual(
        render($m),
        '{"username":"bot","avatar_url":"https://x/y.png","content":"hi"}');
}

func testUsernameWithEmbed() {
    def m as Message init username(embed(message(), "T", "D", 1), "releaser");
    testing.assertEqual(
        render($m),
        '{"username":"releaser","embeds":[{"title":"T","description":"D","color":1}]}');
}

func testEmbedFieldEscaping() {
    def m as Message init embedField(embed(message(), "T", "D", 0), "a \"q\"", "line\nnl", true);
    testing.assertEqual(
        render($m),
        '{"embeds":[{"title":"T","description":"D","color":0,"fields":[{"name":"a \"q\"","value":"line\nnl","inline":true}]}]}');
}

# fieldNoEmbed drives embedField on a message with no embed, which must throw.
func fieldNoEmbed() {
    embedField(message(), "k", "v", true);
}

func testEmbedFieldNoEmbedThrows() {
    testing.assertThrows("fieldNoEmbed", "discord");
}

func testSendPostsTheContent() {
    def srv as httpd.Server init httpd.listen("127.0.0.1:0");
    defer httpd.shutdown($srv);
    def t as task of Seen init spawn {
        return answerOne($srv);
    };
    def r as http.Response init send("http://" + httpd.address($srv) + "/webhook", "hello");
    def seen as Seen init task.wait($t);
    testing.assertEqual($r.status, 204);
    testing.assertEqual($seen.method, "POST");
    testing.assertEqual($seen.contentType, "application/json");
    testing.assertEqual($seen.body, '{"content":"hello"}');
}

func testSendMessagePostsTheRenderedPayload() {
    def srv as httpd.Server init httpd.listen("127.0.0.1:0");
    defer httpd.shutdown($srv);
    def t as task of Seen init spawn {
        return answerOne($srv);
    };
    def m as Message init embed(content(message(), "heads up"), "Deploy", "live", 3066993);
    def r as http.Response init sendMessage("http://" + httpd.address($srv) + "/webhook", $m);
    def seen as Seen init task.wait($t);
    testing.assertEqual($r.status, 204);
    testing.assertEqual(
        $seen.body,
        '{"content":"heads up","embeds":[{"title":"Deploy","description":"live","color":3066993}]}');
}

func testUnknownWebhookIsAResponse() {
    def srv as httpd.Server init httpd.listen("127.0.0.1:0");
    defer httpd.shutdown($srv);
    def t as task of Seen init spawn {
        return answerOne($srv);
    };
    def r as http.Response init send("http://" + httpd.address($srv) + "/gone", "hello");
    task.wait($t);
    testing.assertEqual($r.status, 404);
}

func testNoMentions() {
    def m as Message init noMentions(content(message(), "@everyone <@&123> hi"));
    testing.assertEqual(
        render($m),
        '{"content":"@everyone \u003c@\u0026123\u003e hi","allowed_mentions":{"parse":[]}}');
}

func badColour() {
    embed(message(), "t", "d", 16777216);
}

func negativeColour() {
    embed(message(), "t", "d", -1);
}

func testEmbedColourRange() {
    testing.assertThrows("badColour", "discord");
    testing.assertThrows("negativeColour", "discord");
    testing.assertEqual(len(embed(message(), "t", "d", 16777215).embeds), 1);
    testing.assertEqual(len(embed(message(), "t", "d", 0).embeds), 1);
}

func testWebhookMustBeHttps() {
    for (def url in [
        "discord.com/api/webhooks/1/x",
        "http://discord.com/api/webhooks/1/x",
        "htps://discord.com/api/webhooks/1/x",
        "http://localhost.example.com/x",
        "http://127.0.0.1@evil.example/x",
        ""
    ]) {
        testing.assertThrowsWith("checkWebhook", [$url], "discord");
    }
}

func testWebhookAcceptsHttpsAndLoopback() {
    for (def url in [
        "https://discord.com/api/webhooks/1/x",
        "HTTPS://discord.com/api/webhooks/1/x",
        "http://127.0.0.1:8080/webhook",
        "http://localhost/webhook",
        "http://[::1]:9/webhook"
    ]) {
        checkWebhook($url);
    }
}

func testSendRefusesPlainHttpBeforeSending() {
    testing.assertThrowsWith("send", ["http://discord.com/api/webhooks/1/x", "x"], "discord");
}
