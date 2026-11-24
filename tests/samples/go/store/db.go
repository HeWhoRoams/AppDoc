package store

import (
	"database/sql"

	"github.com/jmoiron/sqlx"
	"xorm.io/xorm"
)

func openAll(dsn string) {
	a, _ := sql.Open("postgres", dsn)
	b, _ := sqlx.Open("mysql", dsn)
	engine, _ := xorm.NewEngine("sqlite3", "tickets.db")
	_, _, _ = a, b, engine
	db.RegisterModel(new(Ticket))
	db.RegisterModel(&Comment{})
}
