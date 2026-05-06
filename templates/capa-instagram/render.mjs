import puppeteer from 'puppeteer';
import path from 'path';
import { fileURLToPath } from 'url';
const __dirname = path.dirname(fileURLToPath(import.meta.url));

(async () => {
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  const page = await browser.newPage();
  
  await page.setViewport({ width: 1080, height: 1350 });
  await page.goto('file://' + path.resolve(__dirname, 'index.html'), {
    waitUntil: 'networkidle0',
    timeout: 15000
  });
  
  // Wait a bit for fonts
  await new Promise(r => setTimeout(r, 2000));
  
  await page.screenshot({
    path: path.resolve(__dirname, 'capa.png'),
    type: 'png',
    clip: { x: 0, y: 0, width: 1080, height: 1350 }
  });
  
  await browser.close();
  console.log('OK');
})();
