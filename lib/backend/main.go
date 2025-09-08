package main

import (
	"log"
	"net/http"
	"os"
	
	"github.com/gorilla/mux"
	"github.com/rs/cors"
)

func main() {
	// MongoDB bağlantısını başlat
	InitMongoDB() // Artık bu fonksiyonu çağırıyoruz

	r := mux.NewRouter()

	// Rotaları kaydet
	r.HandleFunc("/api/send-code", sendCodeHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/api/register", registerHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/health", healthHandler).Methods("GET", "OPTIONS")

	c := cors.New(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"*"},
		AllowCredentials: true,
	})

	handler := c.Handler(r)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	
	log.Printf("Sunucu %s portunda başlıyor...", port)
	log.Fatal(http.ListenAndServe(":"+port, handler))
}