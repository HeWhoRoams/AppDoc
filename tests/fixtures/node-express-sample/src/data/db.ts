import mysql, { Pool, RowDataPacket } from 'mysql2/promise';
import { Ticket } from '../models/Ticket';

// MySQL pool. Credentials come from the environment (see .env); never hard-coded.
const pool: Pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT) || 3306,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10
});

export async function getTickets(status?: string): Promise<Ticket[]> {
  if (status) {
    const [rows] = await pool.query<RowDataPacket[]>('SELECT * FROM tickets WHERE status = ? ORDER BY createdAt DESC', [status]);
    return rows as unknown as Ticket[];
  }
  const [rows] = await pool.query<RowDataPacket[]>('SELECT * FROM tickets ORDER BY createdAt DESC');
  return rows as unknown as Ticket[];
}

export async function getTicketById(id: number): Promise<Ticket | null> {
  const [rows] = await pool.query<RowDataPacket[]>('SELECT * FROM tickets WHERE id = ?', [id]);
  return (rows[0] as unknown as Ticket) ?? null;
}

export async function createTicket(t: Omit<Ticket, 'id'>): Promise<Ticket> {
  const [result] = await pool.query(
    'INSERT INTO tickets (subject, customerName, status, priority, createdAt, updatedAt) VALUES (?, ?, ?, ?, NOW(), NOW())',
    [t.subject, t.customerName, t.status, t.priority]
  );
  const insertId = (result as { insertId: number }).insertId;
  return { id: insertId, ...t };
}

export async function deleteTicket(id: number): Promise<boolean> {
  const [result] = await pool.query('DELETE FROM tickets WHERE id = ?', [id]);
  return (result as { affectedRows: number }).affectedRows > 0;
}

export async function getSummary(): Promise<Record<string, number>> {
  const [rows] = await pool.query<RowDataPacket[]>('SELECT status, COUNT(*) AS count FROM tickets GROUP BY status');
  const summary: Record<string, number> = {};
  for (const row of rows as unknown as { status: string; count: number }[]) {
    summary[row.status] = row.count;
  }
  return summary;
}
