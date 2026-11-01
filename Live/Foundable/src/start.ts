// Runs before Foundable's window starts: picks the board's data and route, and knows what to press afterwards.
import boards from "./boards.json";
import { fresh, real, states } from "./fixtures";
import { install } from "./standin";

const W = (ms: number) => new Promise(r => setTimeout(r, ms));
const Q = (s: string) => document.querySelector<HTMLElement>(s);
const A = (label: string) => Q(`[aria-label="${label}"]`);
const T = (text: string) => [...document.querySelectorAll("button")].find(b => b.textContent?.trim() === text) ?? null;
const All = (s: string) => [...document.querySelectorAll<HTMLElement>(s)];
const C = async (e: HTMLElement | null | undefined) => { e?.click(); await W(150); };
const type = async (e: HTMLInputElement | null, value: string) => {
  if (!e) return;
  Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value")!.set!.call(e, value);
  e.dispatchEvent(new Event("input", { bubbles: true }));
  await W(100);
};

// Named states: where to open, then what to press.
const NAMED: Record<string, [string, () => Promise<void>]> = {
  "home": ["/home", async () => {}],
  "home-ok": ["/home", async () => C(All(".seg button")[1])],
  "home-folded": ["/home", async () => C(A("Hide Ted’s activity"))],
  "notifications": ["/home", async () => C(A("Notifications"))],
  "foundable-menu": ["/home", async () => C(Q(".fd-switch"))],
  "account-menu": ["/home", async () => C(A("Account menu"))],
  "more": ["/home", async () => C(A("More tools"))],
  "chat-history": ["/home", async () => C(A("Chat history"))],
  "chat-other": ["/home", async () => { await C(A("Chat history")); await C(All(".history .row").find(r => r.textContent?.includes("outreach"))); await C(A("Chat history")); }],
  "chat-scrolled": ["/home", async () => { const c = Q(".conv"); if (c) { c.scrollTop = 0; c.dispatchEvent(new Event("scroll")); await W(150); } }],
  "chat-menu": ["/home", async () => C(Q('.chat-head [aria-label^="Chat actions"]'))],
  "chat-rename": ["/home", async () => C(Q(".chat-head .title"))],
  "chat-reasoning": ["/home", async () => C(Q(".reasoning"))],
  "chat-add": ["/home", async () => C(A("Add"))],
  "chat-hidden": ["/home", async () => C(A("Hide chat"))],
  "site-phone": ["/build/site", async () => C(T("Phone"))],
  "run-library": ["/run", async () => C(T("Library"))],
  "inbox-reading": ["/inbox", async () => C(Q(".thread"))],
  "inbox-drafts": ["/inbox", async () => C(All(".folders .item")[2])],
  "inbox-sent": ["/inbox", async () => C(T("Sent"))],
  "inbox-archived": ["/inbox", async () => C(T("Archived"))],
  "inbox-social": ["/inbox", async () => C(T("Social"))],
  "schedule-week": ["/schedule", async () => C(T("Week"))],
  "schedule-day": ["/schedule", async () => C(T("Day"))],
  "schedule-year": ["/schedule", async () => C(T("Year"))],
  "schedule-list": ["/schedule", async () => C(T("All tasks"))],
  "new-task-day": ["/schedule", async () => C(Q(".day.today"))],
  "general-bottom": ["/home?modal=settings/general", async () => { const m = Q(".set-main"); if (m) m.scrollTop = 9999; }],
  "domains-search": ["/home?modal=settings/domains", async () => { await type(document.querySelector(".set-main input"), "sunroom"); await C(T("Search")); }],
  "search-typed": ["/home?modal=search", async () => type(document.querySelector(".palette input"), "sunroom")],
};

function route(state: string): [string, () => Promise<void>] {
  const [kind, arg] = [state.slice(0, 2), state.slice(2)];
  const none = async () => {};
  if (kind === "r:") return [arg, none];
  if (kind === "d:") return ["/home?modal=" + arg, none];
  if (kind === "i:") return ["/home?item=" + arg, none];
  return NAMED[state] ?? NAMED.home;
}

const id = new URLSearchParams(location.hash.slice(1)).get("board") ?? "mac-home";
const key = (boards as Record<string, string>)[id] ?? "real-home";
const cut = key.indexOf("-");
const data = { real, fresh, states }[key.slice(0, cut)] ?? real;
const [path, pressed] = route(key.slice(cut + 1));

install(data());
location.hash = path;
export const press = pressed;
