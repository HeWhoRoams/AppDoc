package store

import (
	"context"
	"database/sql"
	"net/http"
	"os"
)

func loadSettings(cfg *ini.File) {
	srv := cfg.Section("server")
	_ = srv.Key("DOMAIN").String()
	_ = srv.Key("HTTP_PORT").MustInt(3000)
	_ = setting.Cfg.Section("security").Key("SECRET_KEY").String()
	_ = os.Getenv("DB_PASSWORD")
	_, _ = os.LookupEnv("FEATURE_X")
}

func listUsers(ctx context.Context, db *sql.DB) {
	rows, _ := db.Query("SELECT id, name FROM users WHERE active = ?", true)
	_ = rows
	db.Exec("DELETE FROM sessions WHERE expires < now()")
	db.QueryRowContext(ctx, `SELECT count(*)
		FROM orders o JOIN users u ON u.id = o.user_id`)
	db.Exec("UPDATE users SET name = ? WHERE id = ?", "x", 1)
	db.Exec("git gc") // not SQL
}

func notify(ctx context.Context, id string) {
	req, _ := http.NewRequest("GET", "https://api.example.com/v1/ping?token=abc", nil)
	_ = req
	http.Get("https://user:pw@hooks.example.com/notify")
	http.NewRequestWithContext(ctx, "POST", baseURL+"/tickets/"+id, nil)
	http.Post(target, "application/json", nil)
}
