const { DatabaseSync } = require('node:sqlite');
const path = require('path');

const db = new DatabaseSync(path.join(__dirname, 'database.sqlite'));

console.log('--- DAFTAR ADMIN ---');
console.table(db.prepare('SELECT * FROM admins').all());

console.log('\n--- DAFTAR TOKEN ---');
console.table(db.prepare('SELECT * FROM tokens').all());
