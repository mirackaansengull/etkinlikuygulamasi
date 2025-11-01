package main

import (
	"log"
	"net/http"
	"os"

	"github.com/gorilla/mux"
	"github.com/joho/godotenv"
	"github.com/rs/cors"
)

func main() {
	// MongoDB bağlantısını başlat
	_ = godotenv.Load("backend/eventra.env")
	_ = godotenv.Load("eventra.env")
	InitMongoDB()

	r := mux.NewRouter()
	r.HandleFunc("/health", healthHandler).Methods("GET", "OPTIONS")

	// Auth endpoints
	r.HandleFunc("/send-code", sendCodeHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/login", loginHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/register", registerHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/verify-token", verifyTokenHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/forgot-password/send-code", sendPasswordResetCodeHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/forgot-password/reset", resetPasswordHandler).Methods("POST", "OPTIONS")

	// Google OAuth endpoints
	r.HandleFunc("/google/login", googleLoginHandler).Methods("GET", "OPTIONS")
	r.HandleFunc("/google/callback", googleCallbackHandler).Methods("GET", "OPTIONS")

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
