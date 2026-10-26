// Renders store/art.html into the store PNGs: node store/render.js
const { chromium } = require("playwright");
const path = require("path");
const SIZES = { banner: [1840, 860], cover: [1200, 1800], logo: [1024, 1024] };
(async () => {
  const b = await chromium.launch();
  for (const [v, [w, h]] of Object.entries(SIZES)) {
    const pg = await b.newPage({ viewport: { width: w, height: h } });
    await pg.goto("file://" + path.join(__dirname, "art.html") + "?v=" + v);
    await pg.waitForFunction(() => document.title === "ready");
    await pg.screenshot({ path: path.join(__dirname, `PromptMuseum_${v}.png`), clip: { x: 0, y: 0, width: w, height: h } });
    await pg.close();
  }
  await b.close();
  console.log("ok");
})();
