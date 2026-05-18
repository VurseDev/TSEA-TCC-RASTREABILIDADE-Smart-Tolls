const fs = require('fs');
const html = fs.readFileSync('index.html','utf8');
const match = html.match(/<script>([\s\S]*)<\/script>/);
if (!match) { console.error('Script tag not found'); process.exit(1); }
const lines = match[1].split(/\r?\n/);
for (let i = 0; i < lines.length; i++) {
  const code = lines.slice(0, i+1).join('\n');
  try { new Function(code); } catch (err) {
    console.error('line', i+1, err.toString());
    process.exit(0);
  }
}
console.log('no_error');
