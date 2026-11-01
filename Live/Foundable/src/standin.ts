// Stands in for Foundable's Electron bridge. Everything happens in memory on this page: no engine, no network,
// no API, no keys, no real data. A press changes only what this board shows, and reloading brings it back.
import type { Row, Snapshot } from "../../../../foundable-app/src/data";
import { fresh } from "./fixtures";

const blocked = () => { throw new Error("A Pin board never goes online"); };
function cutNetwork() {
  const w = window as unknown as Row;
  w.fetch = () => Promise.reject(new Error("A Pin board never goes online"));
  for (const k of ["XMLHttpRequest", "WebSocket", "EventSource"]) w[k] = blocked;
  navigator.sendBeacon = () => false;
}

export function install(start: Snapshot) {
  cutNetwork();
  let s = start, n = 0;
  const changed = new Set<() => void>();
  const row = (list: Row[], id: unknown) => list.find(r => r.id === id);
  const ops: Record<string, (a: Row) => unknown> = {
    "chat.new": () => { const id = "c-new" + ++n; s.chats = [{ id, title: "New chat", created_at: Date.now(), updated_at: Date.now(), unread: 0 }, ...s.chats]; return id; },
    "chat.read": a => { const c = row(s.chats, a.id); if (c) c.unread = 0; },
    "chat.rename": a => { const c = row(s.chats, a.id); if (c) c.title = a.title; },
    "chat.delete": a => { s.chats = s.chats.filter(c => c.id !== a.id); },
    "item.read": a => { const i = row(s.items, a.id); if (i) i.unread = 0; },
    "item.decide": a => { const i = row(s.items, a.id); if (i) i.needs_ok = 0; },
    "suggestion.set": a => { s.suggestions = s.suggestions.filter(x => x.id !== a.id); },
    "setting.set": a => { s.settings = { ...s.settings, [a.key]: String(a.value) }; },
    "notify.readAll": () => { s.notifications = s.notifications.map(x => ({ ...x, read: 1 })); },
    "step.toggle": a => { const x = row(s.steps, a.id); if (x) x.done = x.done ? 0 : 1; },
    "task.toggle": a => { const x = row(s.tasks, a.id); if (x) x.done = x.done ? 0 : 1; },
    "task.delete": a => { s.tasks = s.tasks.filter(x => x.id !== a.id); },
    "task.save": a => { s.tasks = [...s.tasks, { id: "t-new" + ++n, title: a.title, notes: a.notes, due_at: a.due_at, repeat: null, done: 0, created_at: Date.now() }]; },
    "email.read": a => { const x = row(s.emails, a.id); if (x) x.unread = 0; },
    "email.archive": a => { const x = row(s.emails, a.id); if (x) x.folder = "archive"; },
    "email.save": a => { s.emails = [...s.emails, { id: "e-new" + ++n, folder: "drafts", subject: a.subject, recipient: a.recipient, sender: "", body: a.body, unread: 0, status: null, created_at: Date.now() }]; },
    "foundable.reset": () => { s = fresh(); },
  };
  const say = (chatId: string, role: string, content: string, meta?: object) => {
    s.messages = [...s.messages, { id: "m-new" + ++n, chat_id: chatId, role, content, created_at: Date.now(), meta: meta ? JSON.stringify(meta) : null }];
  };
  window.api = {
    snapshot: async () => ({ ...s }),
    mutate: async (op, args = {}) => ops[op]?.(args),
    tedSend: async (chatId, text) => {
      say(chatId, "user", text);
      changed.forEach(f => f());
      await new Promise(r => setTimeout(r, 700));
      say(chatId, "assistant", "This is a design board, so Ted isn’t connected. This reply is made up.", { final: true, worked: "1 s" });
      return { ok: true };
    },
    tedStop: async () => true,
    revealData: async () => false,
    doorwayInfo: async () => ({ on: true, running: true, url: "http://127.0.0.1:0000", cli: "foundable ask \"…\"", mcp: "claude mcp add foundable …" }),
    webInfo: async () => ({ on: true, running: true, url: "https://example.invalid", link: "" }),
    copyText: async () => false,
    onChanged: cb => { changed.add(cb); return () => { changed.delete(cb); }; },
    onTed: () => () => {},
  };
}
