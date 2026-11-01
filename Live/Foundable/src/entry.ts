// Opens Foundable's real window on one board's screen and state: #board=<Pin board id>. The route and clicks are the
// same ones that made the Penpot pictures (penpot-mcp/foundable/shots.py), so a state is reached through the app itself.
import { press } from "./start"; // must stay first: the window has to find the stand-in and the route ready
import "../../../../foundable-app/src/main";

const W = (ms: number) => new Promise(r => setTimeout(r, ms));
(async () => {
  for (let i = 0; i < 100 && !window.__ready; i++) await W(30);
  await W(120);
  await press();
})();
