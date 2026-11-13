import cron from 'node-cron';
import { CronJob } from 'cron';
import { syncTickets } from './services/itsm';

cron.schedule('*/15 * * * *', syncTickets);
cron.schedule('0 3 * * *', () => {
  purgeClosed();
}, { scheduled: false });

export const digest = new CronJob('0 7 * * 1-5', sendDigest, null, true);
const nightly = new CronJob({ cronTime: '30 2 * * *', onTick: rebuildIndex, start: false });
