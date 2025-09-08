package main

import (
	"log"
	"net/http"
	"os"
    
	"github.com/gorilla/mux"
	"github.com/rs/cors"
)

func main() {
	err := ConnectDB() 
	if err != nil {
		log.Fatalf("MongoDB bağlantı hatası: %v", err)
	}


	r := mux.NewRouter()
	r.HandleFunc("/send-code", sendCodeHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/register", registerHandler).Methods("POST", "OPTIONS")
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
		port = "8080" // Varsayılan port
	}

	log.Printf("Sunucu %s portunda başlıyor...", port)
	log.Fatal(http.ListenAndServe(":"+port, handler))
}