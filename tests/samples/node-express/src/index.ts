import express from 'express';
import ticketsRouter from './routes/tickets';

const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'helpdesk-tickets-api' });
});

// Mount the tickets API router
app.use('/api', ticketsRouter);

const server = app.listen(port, () => {
  console.log(`helpdesk-tickets-api listening on port ${port}`);
});

export default app;
