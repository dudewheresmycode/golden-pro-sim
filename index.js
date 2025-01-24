const fs = require('fs');
const path = require('path');
const express = require('express');
const { spawn } = require('child_process');

const BASE_PATH = __dirname;
const MAME_PATH = path.join(BASE_PATH, 'mame');
const PLUGINS_PATH = path.join(BASE_PATH, 'mame/plugins');
const ROM_PATH = path.join(BASE_PATH, 'roms');
const DATA_PATH = path.join(BASE_PATH, 'data');
console.log('MAME_PATH', MAME_PATH);

// const ScriptTemplate = fs.readFileSync(path.join(BASE_PATH, 'scripts/shot.lua'));
let mame;

const RANGE_BALL_SPEED = [0, 240]; // in MPH
const RANGE_HLA = [-45, 45]; // in degrees

function sleep(time) {
  return new Promise(resolve => setTimeout(resolve, time));
}

function initMame() {
  let inited = false;
  return new Promise((resolve, reject) => {
    const opts = [
      '-window',
      '-skip_gameinfo',
      '-rompath', ROM_PATH,
      '-homepath', DATA_PATH,
      '-pluginspath', [
        path.join(MAME_PATH, 'plugins'),
        path.join(BASE_PATH, 'plugin')
      ].join(';'),
      '-console',
      // '-debug',
      'gtclassc'
    ];
    console.log(`Launching MAME with options: ${opts.join(' ')}`)
    mame = spawn(path.join(MAME_PATH, 'mame.exe'), opts);
    mame.stdout.on('data', data => {
      console.log(`MAME stdout: ${data}`);
      if (!inited && data.toString().includes('[MAME]')) {
        inited = true;
        resolve();
      }
    });
    mame.stderr.on('data', data => {
      console.log(`MAME stderr: ${data}`);
    });
    mame.on('close', code => {
      console.log(`MAME exited with code: ${code}`);
      process.exit(code);
    });
  });
}

function sendToMame(method) {
  return mame.stdin.write(`require('goldenpro').${method}\n`);
}

function sendToMameWithResult(method, callback) {
  return new Promise(resolve => {
    mame.stdout.on('data', data => {
      console.log(`data: ${data}`);
      resolve();
    });
  });
}

function convertRange(value, r1, r2) {
  return ((value - r1[0]) * (r2[1] - r2[0])) / (r1[1] - r1[0]) + r2[0];
}

function clampToRange(val, min, max) {
  return Math.min(Math.max(val, min), max);
}

const app = express();
app.get('/club', async (req, res) => {
  const { direction } = req.query;
  await sendToMame(`pressLeftRight(${direction})`);
  res.sendStatus(202);
});
app.get('/coin', async (req, res) => {
  // const gen = ScriptTemplate.toString().replace('_SHOT_COMMAND_', '"coin"');
  // await sendToMame(gen);
  await sendToMame('pressCoin()');
  res.sendStatus(202);
});
app.get('/start', async (req, res) => {
  // const gen = ScriptTemplate.toString().replace('_SHOT_COMMAND_', '"start"');
  // await sendToMame(gen);
  await sendToMame('pressStart()');
  res.sendStatus(202);
});

app.get('/init', async (req, res) => {
  await sendToMame('autostart()');
  res.sendStatus(202);
});

// power should be between 0-1
app.get('/shot', async (req, res) => {
  const { ballSpeed, hla } = req.query;
  if (!ballSpeed || !hla) {
    return res.sendStatus(400);
  }
  const ballSpeedNumber = new Number(ballSpeed);
  let hlaNumber = new Number(hla);
  if (!ballSpeedNumber || !hlaNumber) {
    return res.sendStatus(400);
  }

  // const result = await sendToMameWithResult('getYardage()');

  // return res.sendStatus(200);
  console.log(`ballSpeed: ${ballSpeedNumber}, hlaNumber, ${hlaNumber}`);

  // we need to invert the HLA degree for golen tee
  hlaNumber = hlaNumber * -1;
  // convert our ball speed and horizontal angle to value between 0 - 1
  // we use this to calculate the percent of trackball speed/spin to apply
  const trackballX = Math.round(convertRange(clampToRange(hlaNumber, ...RANGE_HLA), RANGE_HLA, [0, 256]));
  const trackballY = convertRange(clampToRange(ballSpeedNumber, ...RANGE_BALL_SPEED), RANGE_BALL_SPEED, [0, 1]);
  console.log(`trackballX: ${trackballX}, trackballY, ${trackballY}`);
  // send the shot data to MAME
  // we replace some string values in our loader script
  // const gen = ScriptTemplate.toString().replace('_SHOT_COMMAND_', `"shot", ${trackballY}, ${trackballX}`);
  await sendToMame(`sendShot(${ballSpeedNumber}, ${trackballX})`);

  res.sendStatus(202);
});
(async () => {
  app.listen(4443);
  await initMame();
  console.log('MAME is ready!');
  // await sendToMame('initialize()');
})();