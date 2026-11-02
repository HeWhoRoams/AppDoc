import { Router, Request, Response } from 'express';
import { getTickets, getTicketById, createTicket, deleteTicket, getSummary } from '../data/db';
import { Ticket } from '../models/Ticket';

const router = Router();

// Minimal auth middleware stub (fixture only): proves the extractor captures the LAST
// argument as the controller function even when middleware args precede it.
const requireAuth = (_req: Request, res: Response, next: (err?: unknown) => void) => { next(); };

// GET /api/tickets — list all open tickets, optionally filtered by status.
router.get('/api/tickets', async (req: Request, res: Response) => {
  const status = req.query.status as string | undefined;
  const tickets = await getTickets(status);
  res.json({ count: tickets.length, tickets });
});

// GET /api/tickets/:id — fetch a single ticket by its numeric id.
router.get('/api/tickets/:id', async (req: Request, res: Response) => {
  const id = Number(req.params.id);
  const ticket = await getTicketById(id);
  if (!ticket) {
    res.status(404).json({ error: 'ticket not found', id });
    return;
  }
  res.json(ticket);
});

// POST /api/tickets — create a new ticket from the JSON body.
router.post('/api/tickets', async (req: Request, res: Response) => {
  const payload = req.body as Omit<Ticket, 'id'>;
  if (!payload.subject) {
    res.status(400).json({ error: 'subject is required' });
    return;
  }
  const created = await createTicket(payload);
  res.status(201).json(created);
});

// DELETE /api/tickets/:id — close and remove a ticket.
router.delete('/api/tickets/:id', async (req: Request, res: Response) => {
  const id = Number(req.params.id);
  const deleted = await deleteTicket(id);
  if (!deleted) {
    res.status(404).json({ error: 'ticket not found', id });
    return;
  }
  res.json({ deleted: true, id });
});

// Controller idiom: the handler is a bare identifier (not an inline function), so the
// Express endpoint extractor must capture it. Also exercises a route with leading
// middleware (the last arg is the real controller function).
router.get('/api/tickets/summary', requireAuth, getSummary);

export default router;
