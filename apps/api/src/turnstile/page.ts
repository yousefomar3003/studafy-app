import { Hono } from "hono";
import type { AppEnv } from "../bootstrap/app";
import type { TurnstileOptions } from "./verification";

/** Public widget page: only the public site key enters this response. */
export function createTurnstilePage(options: TurnstileOptions): Hono<AppEnv> {
  const routes = new Hono<AppEnv>();
  routes.get("/auth/bot-check", (c) => {
    const nonce = crypto.randomUUID().replaceAll("-", "");
    const siteKey = JSON.stringify(options.siteKey).replaceAll("<", "\\u003c");
    const ar = c.req.query("lang") === "ar";
    c.header(
      "Content-Security-Policy",
      "default-src 'none'; script-src 'nonce-" + nonce +
        "' https://challenges.cloudflare.com; style-src 'nonce-" + nonce +
        "'; frame-src https://challenges.cloudflare.com; connect-src https://challenges.cloudflare.com; " +
        "img-src data:; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
    );
    return c.html(
      `<!doctype html><html lang="${ar ? "ar" : "en"}" dir="${
        ar ? "rtl" : "ltr"
      }">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Studafy</title><style nonce="${nonce}">
body{font:17px system-ui;background:#f5f7fb;color:#192333;margin:0;padding:32px 16px;text-align:center}
main{max-width:420px;margin:24px auto;background:white;border-radius:24px;padding:24px 8px}
button{padding:12px 24px;border:0;border-radius:12px;background:#5146e5;color:white;font:inherit}
#status{min-height:48px}h1{font-size:24px}
</style></head><body><main><h1>${
        ar ? "تحقق سريع" : "A quick security check"
      }</h1>
<p>${
        ar
          ? "أكمل التحقق للبحث عن معرّف طفلك."
          : "Complete this check to look up your child’s ID."
      }</p>
<div id="widget"></div><p id="status" role="status"></p>
<button id="retry" type="button">${
        ar ? "إعادة المحاولة" : "Try again"
      }</button></main>
<script nonce="${nonce}">
let widgetId;
const status = document.getElementById('status');
const reset = () => { status.textContent = ''; if (widgetId !== undefined) turnstile.reset(widgetId); };
document.getElementById('retry').addEventListener('click', reset);
window.startWidget = () => {
 widgetId = turnstile.render('#widget', {
  sitekey: ${siteKey}, action: 'student_lookup', language: '${
        ar ? "ar" : "en"
      }',
  callback: token => {
   if (window.StudafyChallenge) {
    window.StudafyChallenge.postMessage(token);
    // The native caller closes this page and redeems this token once.
    // A subsequent attempt creates a fresh widget.
   } else { status.textContent = '${
        ar
          ? "افتح التحقق من تطبيق Studafy."
          : "Open this check from the Studafy app."
      }'; }
  },
  'expired-callback': reset,
  'error-callback': () => { status.textContent = '${
        ar
          ? "تعذر التحقق. حاول مرة أخرى."
          : "Verification unavailable. Please try again."
      }'; }
 });
};
</script><script nonce="${nonce}" src="https://challenges.cloudflare.com/turnstile/v0/api.js?onload=startWidget&amp;render=explicit" async defer></script>
</body></html>`,
    );
  });
  return routes;
}
