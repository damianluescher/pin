// Made-up data for the live boards. A business that does not exist; no real account, chat, mail or website.
import type { Snapshot } from "../../../../foundable-app/src/data";
const now = Date.now(), min = 60e3, day = 86400e3;

const SITE = `<!doctype html><html lang="en"><head><title>Sunroom Studio</title><style>
body{margin:0;font:18px/1.5 Georgia,serif;background:#fbf5ea;color:#2b241c}header{padding:96px 80px;background:#f2c879}h1{font-size:72px;line-height:1;margin:0 0 20px}
section{display:flex;gap:32px;padding:64px 80px}section div{flex:1}h2{font-size:24px;margin:0 0 8px}</style></head><body>
<header><h1>Pottery for slow mornings</h1><p>Small-batch cups and bowls, made in a sunny room in Winterthur.</p></header>
<section><div><h2>Cups</h2>Eight glazes, thrown by hand.</div><div><h2>Bowls</h2>For soup, for fruit, for keys.</div><div><h2>Classes</h2>Saturday mornings, six people.</div></section></body></html>`;

const baseSettings = { plan: "Max", theme: "light", language: "English", model: "claude-opus-5-5", user_name: "Mia Keller", user_email: "mia@example.com" };
const STEPS = ["Build:Say hi to Ted in chat", "Build:Publish your first site", "Launch:Ask Ted to change your site", "Launch:Start accepting payments", "Launch:Add your own domain", "Run:Connect a social channel", "Run:Publish your first post"]
  .map((s, i) => ({ id: "s" + i, grp: s.split(":")[0], title: s.split(":")[1], ord: i }));
const empty = { projects: [{ id: "p1", name: "Sunroom Studio" }], project: null, blueprint: null, blueprints: [], pageData: {} };

// A brand-new account, the same as Foundable's own first run.
export function fresh(): Snapshot {
  return { ...empty, projects: [{ id: "p1", name: "New foundable" }],
    chats: [{ id: "c-first", title: "New chat", created_at: now, updated_at: now, unread: 0 }], messages: [], items: [], activity: [], emails: [], tasks: [], notifications: [], suggestions: [],
    steps: STEPS.map(s => ({ ...s, done: 0 })),
    settings: { ...baseSettings, foundable_name: "New foundable", named: "0", tagline: "", reasoning: "high", business_email: "", ted_code: "LOCAL-ONLY", project: "p1" } };
}

const msg = (id: string, chat_id: string, role: string, content: string, ago: number, meta?: object) =>
  ({ id, chat_id, role, content, created_at: now - ago * min, meta: meta ? JSON.stringify(meta) : null });
const long = "Here is where the shop stands:\n\n" + Array.from({ length: 5 }, (_, i) => ["- **Website:** the first version is ready, with cups, bowls and classes", "- **Prices:** cups at 38 and bowls at 54 hold up against the three studios nearby", "- **Classes:** Saturday mornings look like the best first offer", "- **Email:** one draft to the Winterthur market waits for your OK", "- **Plan:** a one-page business plan is saved under From Ted"][i]).join("\n") +
  "\n\n**Decisions I need from you:**\n- **Pricing:** six people per class, or eight?\n- **Name:** is it staying Sunroom Studio?\n- **Buttons:** where should “Book a class” lead?\n\nI’ve added two next steps on Home.\n\nSources:\n- Made-up market notes\n- Made-up price list";

export function real(): Snapshot {
  const plan = "# Sunroom Studio: first plan\n\nSmall-batch pottery and Saturday classes.\n\n## Who it is for\nPeople who want one good cup, not a set of twelve.\n\n## What it sells\n- Cups, 38 CHF\n- Bowls, 54 CHF\n- Classes, 90 CHF per person\n\n## First three months\n1. Open the website\n2. Run four classes\n3. Sell at two markets";
  return { ...empty,
    chats: [
      { id: "c-first", title: "Help me start a pottery studio", created_at: now - 90 * min, updated_at: now - 5 * min, unread: 0 },
      { id: "c-2", title: "Write my outreach email", created_at: now - 80 * min, updated_at: now - 20 * min, unread: 1 },
      { id: "c-3", title: "Compare class prices", created_at: now - day, updated_at: now - day, unread: 0 },
      { id: "c-4", title: "Name ideas", created_at: now - 3 * day, updated_at: now - 3 * day, unread: 0 },
    ],
    messages: [
      msg("m1", "c-first", "user", "I want to sell my pottery and teach a Saturday class. Where do I start?", 40),
      msg("m2", "c-first", "assistant", long, 39, { steps: 6, worked: "2 min" }),
      msg("m3", "c-first", "user", "What is still missing before I can show people?", 12),
      msg("m4", "c-first", "assistant", long, 11, { final: true, steps: 4, worked: "1 min", effort: "medium", suggestion: "Book a class should open an email" }),
      msg("m5", "c-2", "user", "Write to the Winterthur market about a stall.", 25),
      msg("m6", "c-2", "assistant", "The draft is ready and **waits for your OK**. Nothing is sent from here.", 24, { final: true, steps: 1, worked: "20 s", effort: "medium" }),
    ],
    items: [
      { id: "i-doc", kind: "document", title: "Sunroom: market research", subtitle: "Document · 5 min read", body: "# Market research\n\nThree studios teach within 30 minutes of Winterthur.\n\n## What they charge\n- Studio A: 110 CHF\n- Studio B: 85 CHF\n- Studio C: 95 CHF\n\n## What is missing\nNobody sells online.", needs_ok: 0, unread: 1, from_direction: 0, created_at: now - 30 * min },
      { id: "i-sheet", kind: "spreadsheet", title: "Sunroom: competitors and prices", subtitle: "Spreadsheet · 4 rows", body: JSON.stringify({ columns: ["Studio", "Class", "Cup", "Online shop"], rows: [["Studio A", "110", "42", "No"], ["Studio B", "85", "35", "No"], ["Studio C", "95", "40", "Yes"], ["Sunroom", "90", "38", "Yes"]] }), needs_ok: 0, unread: 1, from_direction: 1, created_at: now - 35 * min },
      { id: "i-mail", kind: "email", title: "A stall at the Winterthur market?", subtitle: "Email draft · to markt@example.com", body: "e-draft", needs_ok: 1, unread: 1, from_direction: 0, created_at: now - 24 * min },
      { id: "i-plan", kind: "plan", title: "Sunroom: first business plan", subtitle: "Business plan · 1 page", body: plan, needs_ok: 0, unread: 0, from_direction: 0, created_at: now - 60 * min },
      { id: "i-bmail", kind: "business-email", title: "Your business email is ready", subtitle: "hello@sunroomstudio.example", body: "# Your business email\n\nhello@sunroomstudio.example now shows in your Inbox. Sending stays off in the local copy.", needs_ok: 0, unread: 0, from_direction: 0, created_at: now - 70 * min },
      { id: "site", kind: "website", title: "Sunroom Studio", subtitle: "Website · version 3", body: SITE, needs_ok: 0, unread: 0, from_direction: 0, created_at: now - 75 * min },
    ],
    activity: [
      { id: "a1", kind: "saved", text: "Saved a document", detail: "Sunroom: market research" },
      { id: "a2", kind: "saved", text: "Saved a spreadsheet", detail: "Sunroom: competitors and prices" },
      { id: "a3", kind: "drafted", text: "Drafted an email to markt@example.com", detail: "A stall at the Winterthur market?" },
      { id: "a4", kind: "saved", text: "Wrote a business plan", detail: "Sunroom: first business plan" },
      { id: "a5", kind: "finished", text: "Built your website", detail: "First Sunroom site: hero, three offers, class booking" },
    ],
    steps: STEPS.map((s, i) => ({ ...s, done: i < 1 || i === 2 ? 1 : 0 })),
    emails: [
      { id: "e-draft", folder: "drafts", subject: "A stall at the Winterthur market?", recipient: "markt@example.com", sender: "Sunroom Studio", body: "Hello,\n\nI make small-batch pottery in Winterthur and would love a stall at your spring market.\n\nDo you still have room?\n\nThank you,\nMia", unread: 0, status: null, created_at: now - 24 * min },
      { id: "e-in", folder: "inbox", subject: "Welcome to your business inbox", recipient: "hello@sunroomstudio.example", sender: "Ted at Foundable <ted@example.com>", body: "This is where mail to your business lands. I draft replies, you say OK.", unread: 1, status: null, created_at: now - 70 * min },
    ],
    tasks: [],
    notifications: [{ id: "n1", read: 0 }, { id: "n2", read: 0 }],
    suggestions: [{ id: "sg1", label: "Product · Classes", title: "Open bookings for the first Saturday class", detail: "Add a simple form so six people can book a place, with a list of who is coming.", state: "open" }],
    settings: { ...baseSettings, foundable_name: "Sunroom Studio", named: "1", tagline: "Pottery for slow mornings", reasoning: "medium", business_email: "hello@sunroomstudio.example", ted_code: "TED-4821", project: "p1" } };
}

// The same account with an error reply, a stopped build and tasks in the calendar.
export function states(): Snapshot {
  const s = real();
  s.messages.push(
    msg("x1", "c-first", "user", "Can you publish the site now?", 1),
    msg("x2", "c-first", "assistant", "Ted can’t reach Claude right now. Claude Code is not signed in on this Mac.", 0.8, { error: true }),
    msg("x3", "c-first", "assistant", "I changed the header, but the build stopped.", 0.6, { build: "interrupted" }));
  s.tasks = ([["Send the class invite to Lena", 0, 0], ["Photograph the new cups", 1, 0], ["Check the site speed", 3, 1], ["Write the launch post", 6, 0]] as const)
    .map(([title, off, done], i) => ({ id: "t" + i, title, notes: null, due_at: now + off * day, repeat: null, done, created_at: now }));
  return s;
}
