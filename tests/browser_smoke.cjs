const assert = require('node:assert/strict');
const fs = require('node:fs');
const { chromium } = require('playwright');

(async () => {
  fs.mkdirSync('test-results', { recursive: true });
  fs.writeFileSync('test-results/.gdignore', '');
  const system = process.env.CHROMIUM_PATH || (fs.existsSync('/usr/bin/chromium') ? '/usr/bin/chromium' : undefined);
  const browser = await chromium.launch({ executablePath: system, headless: true,
    args: ['--no-sandbox', '--enable-unsafe-swiftshader', '--use-angle=swiftshader'] });
  const errors = [];
  const results = [];
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  const state = () => page.evaluate(() => window.__wandAtelier);
  const pass = label => { results.push(label); console.log('PASS:', label); };
  const fire = async (x, y) => {
    await page.mouse.move(x, y, { steps: 4 });
    await page.waitForTimeout(150);
    await page.mouse.down();
  };
  try {
    await page.goto(process.env.TEST_URL || 'http://127.0.0.1:8000');
    await page.waitForFunction(() => window.__wandAtelier, { timeout: 60000 });
    assert.equal((await state()).shots, 0);
    pass('Web build loads without automatically firing');
    await page.screenshot({ path: 'test-results/atelier.png' });
    let target = (await state()).targets[1];
    await fire(target.x, target.y);
    await page.waitForFunction(() => window.__wandAtelier.hits > 0 && window.__wandAtelier.payloads > 0, { timeout: 30000 });
    pass('Mouse aiming and held fire hit the projected target and trigger payload');
    await page.waitForFunction(() => window.__wandAtelier.waiting, { timeout: 30000 });
    pass('Held fire exhausts mana and visibly pauses execution');
    await page.screenshot({ path: 'test-results/casting.png' });
    await page.mouse.up();
    await page.waitForFunction(() => !window.__wandAtelier.waiting, { timeout: 30000 });
    await page.waitForTimeout(2500);
    const releasedShots = (await state()).shots;
    await page.waitForTimeout(1500);
    assert.equal((await state()).shots, releasedShots);
    pass('Releasing mouse stops new casts after in-flight effects finish');

    await page.mouse.click(326, 165);
    await page.waitForFunction(() => window.__wandAtelier.slots[0] === 'bounce');
    await fire(957, 460);
    await page.waitForFunction(() => window.__wandAtelier.bounces > 0, { timeout: 30000 });
    await page.mouse.up();
    pass('Ricochet recipe reflects projectiles in the rendered arena');

    await page.mouse.click(434, 165);
    await page.waitForFunction(() => window.__wandAtelier.slots[0] === 'split');
    await fire(720, 410);
    await page.waitForFunction(() => window.__wandAtelier.splits > 0, { timeout: 30000 });
    await page.screenshot({ path: 'test-results/split.png' });
    await page.mouse.up();
    pass('Split recipe creates branching projectiles');

    await page.mouse.move(145, 784);
    await page.mouse.down();
    await page.mouse.move(380, 784, { steps: 15 });
    await page.mouse.up();
    await page.waitForFunction(() => window.__wandAtelier.slots[0] === 'bolt' && window.__wandAtelier.slots[1] === 'split');
    pass('Dragging slots changes actual execution order');
    await page.keyboard.press('6');
    await page.mouse.click(130, 583);
    await page.waitForFunction(() => window.__wandAtelier.slots[5] === 'spark');
    pass('Keyboard slot selection and archive equip work');
    await page.mouse.click(1360, 722);
    await page.waitForFunction(() => window.__wandAtelier.slots[5] === '');
    pass('Clear slot removes the equipped spell');

    await page.mouse.click(641, 165);
    await page.waitForFunction(() => window.__wandAtelier.slots[0] === 'timer');
    await fire(720, 340);
    await page.waitForFunction(() => window.__wandAtelier.payloads > 0, { timeout: 30000 });
    await page.mouse.up();
    pass('Timer recipe emits its delayed payload');
    await page.keyboard.press('Space');
    await page.waitForFunction(() => window.__wandAtelier.paused);
    const pausedMana = (await state()).mana;
    await page.waitForTimeout(500);
    assert.equal((await state()).mana, pausedMana);
    await page.keyboard.press('Space');
    await page.waitForFunction(() => !window.__wandAtelier.paused);
    pass('Pause freezes simulation and resumes');

    await page.mouse.click(1110, 655);
    await page.waitForFunction(() => window.__wandAtelier.pitch > 55);
    await page.screenshot({ path: 'test-results/high-angle.png' });
    pass('Camera angle changes independently of simulation');
    await page.keyboard.press('r');
    await page.waitForFunction(() => window.__wandAtelier.shots === 0 && window.__wandAtelier.mana === 60);
    pass('Reset clears experiment and refills mana');
    target = (await state()).targets[1];
    await page.mouse.click(target.x, target.y);
    await page.waitForFunction(() => window.__wandAtelier.shots > 0);
    pass('A single quick click fires without requiring a held button');
    assert.deepEqual(errors, []);
    pass('No browser or Godot runtime errors');
    fs.writeFileSync('test-results/browser-results.json', JSON.stringify({ passed: results, errors }, null, 2));
    console.log(`${results.length} browser checks passed`);
  } catch (error) {
    await page.screenshot({ path: 'test-results/failure.png' });
    console.error('State:', await state(), 'Errors:', errors);
    throw error;
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
