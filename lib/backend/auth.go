package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"net/smtp"
	"os"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
	"golang.org/x/crypto/bcrypt"
)

// --- Yardımcı Fonksiyonlar ---
func generateVerificationCode() string {
	code := fmt.Sprintf("%06d", rand.Intn(999999))
	return code
}

func hashPassword(password string) (string, error) {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), 14)
	return string(bytes), err
}

func checkPasswordHash(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}

// --- HTTP İşleyicileri ---

// sendCodeHandler, doğrulama kodu gönderir
func sendCodeHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		http.Error(w, "Yalnızca POST destekleniyor", http.StatusMethodNotAllowed)
		return
	}

	var req SendCodeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Geçersiz istek gövdesi", http.StatusBadRequest)
		return
	}

	// Koleksiyonlara global değişkenler üzerinden erişim
	var existingUser User
	err := usersCollection.FindOne(context.Background(), bson.M{"email": req.Email}).Decode(&existingUser)
	if err == nil {
		http.Error(w, "Bu email zaten kayıtlı", http.StatusConflict)
		return
	}
	if err != mongo.ErrNoDocuments {
		log.Printf("MongoDB sorgu hatası: %v", err)
		http.Error(w, "Sunucu hatası", http.StatusInternalServerError)
		return
	}

	code := generateVerificationCode()
	expiresAt := time.Now().Add(3 * time.Minute)

	// verification_codes koleksiyonu yerine pendingUsersCollection kullanıyoruz
	_, err = verificationCollection.UpdateOne(
		context.Background(),
		bson.M{"email": req.Email},
		bson.M{"$set": bson.M{
			"code":      code,
			"expiresAt": expiresAt,
		}},
		options.Update().SetUpsert(true),
	)
	if err != nil {
		log.Printf("Doğrulama kodu kaydetme hatası: %v", err)
		http.Error(w, "Doğrulama kodu gönderilemedi", http.StatusInternalServerError)
		return
	}

	from := os.Getenv("SMTP_USER")
	password := os.Getenv("SMTP_PASSWORD")
	host := os.Getenv("SMTP_HOST")
	port := os.Getenv("SMTP_PORT")
	if from == "" || password == "" || host == "" || port == "" {
		log.Println("Hata: SMTP ortam değişkenleri tanımlanmamış.")
		http.Error(w, "E-posta servisi yapılandırılamadı", http.StatusInternalServerError)
		return
	}

	mailBody := fmt.Sprintf("Merhaba,\n\nDoğrulama kodunuz: %s\n\nBu kod 3 dakika içinde geçerliliğini yitirecektir.\n\nİyi günler.", code)
	msg := "From: " + from + "\n" +
		"To: " + req.Email + "\n" +
		"Subject: Hesap Doğrulama Kodunuz\n\n" +
		mailBody
	auth := smtp.PlainAuth("", from, password, host)
	addr := host + ":" + port

	err = smtp.SendMail(addr, auth, from, []string{req.Email}, []byte(msg))
	if err != nil {
		log.Printf("E-posta gönderim hatası: %v", err)
		http.Error(w, "Doğrulama kodu gönderilemedi", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(MessageResponse{Message: "Doğrulama kodu e-mail adresinize başarıyla gönderildi."})
}

// registerHandler, kullanıcıyı kaydeder
func registerHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		http.Error(w, "Yalnızca POST destekleniyor", http.StatusMethodNotAllowed)
		return
	}

	var req RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Geçersiz istek gövdesi", http.StatusBadRequest)
		return
	}

	// Koleksiyonlara global değişkenler üzerinden erişim
	var verCode VerificationCode
	err := verificationCollection.FindOne(context.Background(), bson.M{"email": req.Email}).Decode(&verCode)
	if err != nil {
		http.Error(w, "Doğrulama kodu geçersiz veya süresi dolmuş", http.StatusUnauthorized)
		return
	}

	if verCode.Code != req.VerificationCode || time.Now().After(verCode.ExpiresAt) {
		http.Error(w, "Doğrulama kodu geçersiz veya süresi dolmuş", http.StatusUnauthorized)
		return
	}

	hashedPassword, err := hashPassword(req.Sifre)
	if err != nil {
		log.Printf("Şifre şifreleme hatası: %v", err)
		http.Error(w, "Sunucu hatası", http.StatusInternalServerError)
		return
	}

	newUser := User{
		Ad:          req.Ad,
		Soyad:       req.Soyad,
		Telefon:     req.Telefon,
		DogumTarihi: req.DogumTarihi,
		Email:       req.Email,
		Sifre:       hashedPassword,
		CreatedAt:   time.Now(),
	}

	_, err = usersCollection.InsertOne(context.Background(), newUser)
	if err != nil {
		log.Printf("Kullanıcı kaydetme hatası: %v", err)
		http.Error(w, "Kayıt işlemi başarısız oldu", http.StatusInternalServerError)
		return
	}

	_, err = verificationCollection.DeleteOne(context.Background(), bson.M{"email": req.Email})
	if err != nil {
		log.Printf("Doğrulama kodu silme hatası: %v", err)
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(MessageResponse{Message: "Kayıt işlemi başarıyla tamamlandı."})
}