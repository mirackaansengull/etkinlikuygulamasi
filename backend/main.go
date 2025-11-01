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
	InitMongoDB()

	r := mux.NewRouter()
	r.HandleFunc("/health", healthHandler).Methods("GET", "OPTIONS")
	r.HandleFunc("/send-code", sendCodeHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/login", loginHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/register", registerHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/verify-token", verifyTokenHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/forgot-password/send-code", sendPasswordResetCodeHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/forgot-password/reset", resetPasswordHandler).Methods("POST", "OPTIONS")
	// Sosyal giriş endpoint'leri kaldırıldı

	// User profile endpoints
	r.HandleFunc("/user/profile", getUserProfileHandler).Methods("GET", "OPTIONS")
	r.HandleFunc("/user/profile", updateUserProfileHandler).Methods("PUT", "OPTIONS")

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
