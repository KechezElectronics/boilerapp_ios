// Generates a random secret for provisioning a boiler.
//
//   node gen_secret.js code        -> claim code,  e.g. 7KQ2-M9XA-4TFR   (12 chars, grouped)
//   node gen_secret.js password    -> device password, 24 chars, no spaces
//
// Uses Node's cryptographically secure RNG. Letters that are easy to
// misread (0/O, 1/I/L) are left out so a claim code can be read off a label.
const crypto = require('crypto');

const kind = (process.argv[2] || 'code').toLowerCase();
const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

function random(length) {
  let out = '';
  for (let i = 0; i < length; i++) out += alphabet[crypto.randomInt(alphabet.length)];
  return out;
}

if (kind === 'code') {
  console.log(random(12).match(/.{4}/g).join('-'));
} else if (kind === 'password') {
  console.log(random(24));
} else {
  console.error('Usage: node gen_secret.js code | password');
  process.exit(1);
}
