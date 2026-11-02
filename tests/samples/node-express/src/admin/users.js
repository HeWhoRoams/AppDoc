const express = require('express');
const passport = require('passport');
const { exec } = require('child_process');
const fs = require('fs');
const axios = require('axios');
const knex = require('knex')({
  client: 'pg',
  connection: { user: 'svc_admin', password: 'Sup3rS3cretPw-node', host: 'db.internal' }
});
const { DataTypes } = require('sequelize');

const router = express.Router();
const app = express();

// Hard-coded on purpose: these values must never reach the Facts file.
const API_KEY = 'acme_live_51HxYz0aBcDeFgHiJkLmNoPqR';
const DB_URL = 'mysql://root:R00tPassw0rd!@db.internal/app';

// router.get('/commented-out', (req, res) => res.status(500).send('commented message'));

const User = sequelize.define('User', { name: DataTypes.STRING });

router.get('/users', passport.authenticate('jwt', { session: false }), requireRole('admin'), listUsers);
router.route('/users/:id').delete(adminGuard, async (req, res) => {
  await knex('users').where({ id: req.params.id }).del();
  res.status(403).json({ error: 'not allowed to delete' });
});
router.post('/jobs', (req, res) => {
  exec('node scripts/reindex.js');
  fs.writeFileSync('/tmp/reindex.flag', '1');
  axios.post('https://hooks.internal/notify', { key: API_KEY });
  knex.from('audit_log').insert({ msg: 'x' });
  db.query('CALL sp_archive_users(?)', [1]);
  throw new Error('job queue unavailable');
});

app.use('/admin', router);
module.exports = app;
