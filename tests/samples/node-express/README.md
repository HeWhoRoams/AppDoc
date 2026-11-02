# helpdesk-tickets-api

A Node/Express + TypeScript help-desk ticket management service.

- Express REST API for CRUD on tickets (`/api/tickets`).
- MySQL persistence (mysql2) — credentials loaded from the environment (`.env`).
- Outbound integration to the ITSM support system (`src/services/itsm.ts`).

## Layout
- `src/index.ts` — Express bootstrap (`app.listen`).
- `src/routes/tickets.ts` — the ticket REST router.
- `src/models/Ticket.ts` — the exported `Ticket` model interface.
- `src/data/db.ts` — MySQL pool + ticket queries.
- `src/services/itsm.ts` — outbound ITSM sync (external HTTP call).

## Run
```
npm install
cp .env .env.local   # edit credentials
npm run dev
```
