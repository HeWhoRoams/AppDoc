package main

import (
	"database/sql"
	"xorm.io/xorm"
)

func main() {
	db, _ := sql.Open("postgres", dsn)
	engine, _ := xorm.NewEngine("postgres", dsn)
	_, _ = db, engine
}
