#!/usr/bin/env node
import { chromium } from "playwright";
import { pathToFileURL } from "node:url";
import path from "node:path";

const root = path.dirname(new URL(import.meta.url).pathname);
const htmlPath = path.join(root, "Coretend_Apple_Support_Proposal.html");
const pdfPath = path.join(root, "Ahmet_Basbunar_Coretend_Apple_Support_Proposal.pdf");

const browser = await chromium.launch({
  channel: "chrome",
  headless: true,
  args: ["--allow-file-access-from-files"],
});
const page = await browser.newPage({ viewport: { width: 1240, height: 1754 }, deviceScaleFactor: 1 });
await page.goto(pathToFileURL(htmlPath).href, { waitUntil: "load" });
await page.emulateMedia({ media: "print", colorScheme: "light", reducedMotion: "reduce" });

const report = await page.evaluate(() => {
  const pages = [...document.querySelectorAll(".page")];
  return {
    pageCount: pages.length,
    overflows: pages.flatMap((page) => {
      const inner = page.querySelector(".page-inner");
      if (!inner) return [`page ${page.dataset.page}: missing .page-inner`];
      const tolerance = 2;
      return inner.scrollHeight > inner.clientHeight + tolerance || inner.scrollWidth > inner.clientWidth + tolerance
        ? [`page ${page.dataset.page}: ${inner.scrollWidth}x${inner.scrollHeight} inside ${inner.clientWidth}x${inner.clientHeight}`]
        : [];
    }),
    brokenImages: [...document.images]
      .filter((image) => !image.complete || image.naturalWidth === 0)
      .map((image) => image.getAttribute("src")),
  };
});

if (report.pageCount < 8 || report.pageCount > 12) {
  throw new Error(`Expected 8-12 pages, found ${report.pageCount}`);
}
if (report.overflows.length || report.brokenImages.length) {
  throw new Error(JSON.stringify(report, null, 2));
}

await page.pdf({
  path: pdfPath,
  format: "A4",
  printBackground: true,
  preferCSSPageSize: true,
  displayHeaderFooter: false,
  margin: { top: "0", right: "0", bottom: "0", left: "0" },
});
await browser.close();
console.log(JSON.stringify({ ...report, pdfPath }, null, 2));
