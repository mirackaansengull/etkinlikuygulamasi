package main

import (
    "context"
    "log"
    "net/http"
    "os"

    "github.com/gorilla/mux"
    "github.com/rs/cors"
)

func main() {
    // MongoDB bağlantısını başlat
    err := ConnectDB() // database.go'dan gelen fonksiyon
    if err != nil {
        log.Fatalf("MongoDB bağlantı hatası: %v", err)
    }

    r := mux.NewRouter()
	r.HandleFunc("/health", healthHandler).Methods("GET", "OPTIONS")


	// CORS configuration
	c := cors.New(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"*"},
		AllowCredentials: true,
	})

	handler := c.Handler(r)

	// Get port from environment or use default
	port := os.Getenv("PORT")
	log.Printf("AnticoGold API server starting on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, handler))
}