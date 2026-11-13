package main

import (
	"net/http"
	"os"

	"github.com/go-chi/chi/v5"
)

func main() {
	r := chi.NewRouter()
	r.Use(jwtMiddleware)
	r.Get("/health", healthHandler)
	// r.Get("/old-health", oldHealth)
	r.Route("/api", func(r chi.Router) {
		r.Get("/items", listItems)
		r.Post("/items", requireAuth, createItem)
		r.Route("/admin", func(r chi.Router) {
			r.Delete("/items/{id}", deleteItem)
		})
	})

	mux := http.NewServeMux()
	mux.HandleFunc("GET /legacy/{id}", legacyHandler)
	http.HandleFunc("/ping", pingHandler)

	/* r.Get("/commented-block", hidden) */
	addr := os.Getenv("LISTEN_ADDR")
	http.ListenAndServe(addr, r)
}
