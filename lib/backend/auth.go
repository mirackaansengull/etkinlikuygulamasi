package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io" // ioutil yerine io paketi kullanıldı
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
	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
)

// --- Yardımcı Fonksiyonlar ---

func generateVerificationCode() string {
	code := fmt.Sprintf("%06d", rand.Intn(999999))
	return code
}

func hashPassword(password string) (string, error) {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), 12)
	return string(bytes), err
}

func checkPasswordHash(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}

// E-posta gönderme fonksiyonu
func sendEmail(to, subject, body string) error {
	smtpHost := os.Getenv("SMTP_HOST")
	smtpPort := os.Getenv("SMTP_PORT")
	smtpUsername := os.Getenv("SMTP_USER")
	smtpPassword := os.Getenv("SMTP_PASSWORD")

	msg := []byte("To: " + to + "\r\n" +
		"Subject: " + subject + "\r\n" +
		"\r\n" +
		body + "\r\n")

	auth := smtp.PlainAuth("", smtpUsername, smtpPassword, smtpHost)
	addr := smtpHost + ":" + smtpPort

	err := smtp.SendMail(addr, auth, smtpUsername, []string{to}, msg)
	if err != nil {
		return err
	}
	return nil
}


var googleOAuthConfig *oauth2.Config
var facebookOAuthConfig *oauth2.Config

func init() {
	// Google OAuth2 yapılandırması
	googleOAuthConfig = &oauth2.Config{
		ClientID:     os.Getenv("GOOGLE_CLIENT_ID"),
		ClientSecret: os.Getenv("GOOGLE_CLIENT_SECRET"),
		RedirectURL:  os.Getenv("GOOGLE_REDIRECT_URL"),
		Scopes:       []string{"https://www.googleapis.com/auth/userinfo.email", "https://www.googleapis.com/auth/userinfo.profile"},
		Endpoint:     google.Endpoint,
	}

	// Facebook OAuth2 yapılandırması
	facebookOAuthConfig = &oauth2.Config{
		ClientID:     os.Getenv("FACEBOOK_CLIENT_ID"),
		ClientSecret: os.Getenv("FACEBOOK_CLIENT_SECRET"),
		RedirectURL:  os.Getenv("FACEBOOK_REDIRECT_URL"),
		Scopes:       []string{"email", "public_profile"},
		Endpoint: oauth2.Endpoint{
			AuthURL:  "https://www.facebook.com/v10.0/dialog/oauth",
			TokenURL: "https://graph.facebook.com/v10.0/oauth/access_token",
		},
	}
}

// --- Handler Fonksiyonları ---

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

	go func() {
		mailBody := fmt.Sprintf("Merhaba,\n\nDoğrulama kodunuz: %s\n\nBu kod 3 dakika içinde geçerliliğini yitirecektir.\n\nİyi günler.", code)
		err = sendEmail(req.Email, "Hesap Doğrulama Kodunuz", mailBody)
		if err != nil {
			log.Printf("E-posta gönderim hatası (asenkron): %v", err)
		} else {
			log.Printf("Doğrulama kodu başarıyla gönderildi: %s", req.Email)
		}
	}()

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(MessageResponse{Message: "Doğrulama kodu e-mail adresinize başarıyla gönderildi."})
}

func loginHandler(w http.ResponseWriter, r *http.Request) {
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

	var req LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Geçersiz istek gövdesi", http.StatusBadRequest)
		return
	}

	var user User
	err := usersCollection.FindOne(context.Background(), bson.M{"email": req.Email, "provider": "email"}).Decode(&user)
	if err == mongo.ErrNoDocuments {
		http.Error(w, "Kullanıcı bulunamadı veya yanlış kimlik doğrulama yöntemi", http.StatusUnauthorized)
		return
	} else if err != nil {
		log.Printf("Veritabanı hatası: %v", err)
		http.Error(w, "Sunucu hatası", http.StatusInternalServerError)
		return
	}

	if !checkPasswordHash(req.Sifre, user.Sifre) {
		http.Error(w, "Hatalı şifre", http.StatusUnauthorized)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"status":  "success",
		"message": "Giriş başarılı",
	})
}

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
		Provider:    "email",
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

func googleLoginHandler(w http.ResponseWriter, r *http.Request) {
	url := googleOAuthConfig.AuthCodeURL("random-state", oauth2.AccessTypeOffline, oauth2.ApprovalForce)
	http.Redirect(w, r, url, http.StatusTemporaryRedirect)
}

func googleCallbackHandler(w http.ResponseWriter, r *http.Request) {
	state := r.FormValue("state")
	if state != "random-state" {
		http.Error(w, "State geçersiz", http.StatusBadRequest)
		return
	}

	code := r.FormValue("code")
	token, err := googleOAuthConfig.Exchange(context.Background(), code)
	if err != nil {
		log.Printf("Token hatası: %v", err)
		http.Error(w, "Token alınamadı", http.StatusInternalServerError)
		return
	}

	client := googleOAuthConfig.Client(context.Background(), token)
	resp, err := client.Get("https://www.googleapis.com/oauth2/v2/userinfo")
	if err != nil {
		log.Printf("Google API hatası: %v", err)
		http.Error(w, "Kullanıcı bilgileri alınamadı", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	googleUser := GoogleUser{}
	err = json.NewDecoder(resp.Body).Decode(&googleUser)
	if err != nil {
		log.Printf("JSON çözme hatası: %v", err)
		http.Error(w, "Kullanıcı bilgileri çözülemedi", http.StatusInternalServerError)
		return
	}

	var user User
	err = usersCollection.FindOne(context.Background(), bson.M{"email": googleUser.Email, "provider": "google"}).Decode(&user)
	if err == mongo.ErrNoDocuments {
		newUser := User{
			Ad:          googleUser.GivenName,
			Soyad:       googleUser.FamilyName,
			Email:       googleUser.Email,
			Provider:    "google",
			SocialID:    googleUser.Email,
			CreatedAt:   time.Now(),
		}
		_, err = usersCollection.InsertOne(context.Background(), newUser)
		if err != nil {
			log.Printf("Yeni kullanıcı kaydetme hatası: %v", err)
			http.Error(w, "Kayıt başarısız", http.StatusInternalServerError)
			return
		}
	} else if err != nil {
		log.Printf("Veritabanı hatası: %v", err)
		http.Error(w, "Sunucu hatası", http.StatusInternalServerError)
		return
	}
	http.Redirect(w, r, "etkinlikuygulamasi://login/success", http.StatusFound)
}

// Facebook girişini başlatan handler
func facebookLoginHandler(w http.ResponseWriter, r *http.Request) {
	url := facebookOAuthConfig.AuthCodeURL("state")
	http.Redirect(w, r, url, http.StatusTemporaryRedirect)
}

// Facebook'tan gelen callback'i işleyen handler
func facebookCallbackHandler(w http.ResponseWriter, r *http.Request) {
	state := r.FormValue("state")
	if state != "state" {
		http.Error(w, "Geçersiz durum (state)", http.StatusBadRequest)
		return
	}

	code := r.FormValue("code")
	if code == "" {
		http.Error(w, "Code parametresi eksik", http.StatusBadRequest)
		return
	}

	token, err := facebookOAuthConfig.Exchange(context.Background(), code)
	if err != nil {
		log.Printf("Token değişimi hatası: %v", err)
		http.Error(w, "Token değişimi başarısız oldu", http.StatusInternalServerError)
		return
	}

	resp, err := http.Get("https://graph.facebook.com/v10.0/me?fields=id,name,email,picture&access_token=" + token.AccessToken)
	if err != nil {
		log.Printf("Facebook API çağrısı hatası: %v", err)
		http.Error(w, "Facebook kullanıcı bilgileri alınamadı", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	var fbUser FacebookUser
	body, err := io.ReadAll(resp.Body) // ioutil.ReadAll yerine io.ReadAll kullanıldı
	if err != nil {
		log.Printf("Vücut okuma hatası: %v", err)
		http.Error(w, "Kullanıcı bilgileri okunamadı", http.StatusInternalServerError)
		return
	}
	if err := json.Unmarshal(body, &fbUser); err != nil {
		log.Printf("JSON ayrıştırma hatası: %v", err)
		http.Error(w, "Kullanıcı bilgileri ayrıştırılamadı", http.StatusInternalServerError)
		return
	}

	var user User
	err = usersCollection.FindOne(context.Background(), bson.M{"email": fbUser.Email, "provider": "facebook"}).Decode(&user)
	if err == mongo.ErrNoDocuments {
		newUser := User{
			Ad:        fbUser.Name,
			Email:     fbUser.Email,
			Provider:  "facebook",
			SocialID:  fbUser.ID,
			CreatedAt: time.Now(),
		}
		_, err := usersCollection.InsertOne(context.Background(), newUser)
		if err != nil {
			log.Printf("Facebook kullanıcısı kaydetme hatası: %v", err)
			http.Error(w, "Kullanıcı kaydedilemedi", http.StatusInternalServerError)
			return
		}
		log.Printf("Yeni Facebook kullanıcısı kaydedildi: %s", fbUser.Email)
	} else if err != nil {
		log.Printf("Veritabanı hatası: %v", err)
		http.Error(w, "Sunucu hatası", http.StatusInternalServerError)
		return
	}

	http.Redirect(w, r, "etkinlikuygulamasi://login/success", http.StatusFound)
}

// Şifre sıfırlama kodu gönderme handler'ı
func sendPasswordResetCodeHandler(w http.ResponseWriter, r *http.Request) {
	var req SendCodeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Geçersiz istek gövdesi", http.StatusBadRequest)
		return
	}

	var user User
	err := usersCollection.FindOne(context.Background(), bson.M{"email": req.Email, "provider": "email"}).Decode(&user)
	if err == mongo.ErrNoDocuments {
		http.Error(w, "Kullanıcı bulunamadı", http.StatusNotFound)
		return
	} else if err != nil {
		log.Printf("Veritabanı hatası: %v", err)
		http.Error(w, "Sunucu hatası", http.StatusInternalServerError)
		return
	}

	verificationCode := generateVerificationCode()
	err = sendEmail(req.Email, "Şifre Sıfırlama Kodunuz", fmt.Sprintf("Şifre sıfırlama kodunuz: %s", verificationCode))
	if err != nil {
		log.Printf("E-posta gönderme hatası: %v", err)
		http.Error(w, "E-posta gönderme başarısız", http.StatusInternalServerError)
		return
	}

	_, err = verificationCollection.UpdateOne(
		context.Background(),
		bson.M{"email": req.Email},
		bson.M{
			"$set": bson.M{
				"email":     req.Email,
				"code":      verificationCode,
				"expiresAt": time.Now().Add(10 * time.Minute), // 10 dakika geçerlilik süresi
			},
		},
		options.Update().SetUpsert(true),
	)
	if err != nil {
		log.Printf("Doğrulama kodu kaydetme hatası: %v", err)
		http.Error(w, "Sunucu hatası", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(MessageResponse{Message: "Şifre sıfırlama kodu gönderildi"})
}

// Şifre sıfırlama handler'ı
func resetPasswordHandler(w http.ResponseWriter, r *http.Request) {
	var req ResetPasswordRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Geçersiz istek gövdesi", http.StatusBadRequest)
		return
	}

	var storedCode VerificationCode
	err := verificationCollection.FindOne(context.Background(), bson.M{"email": req.Email, "code": req.Code}).Decode(&storedCode)
	if err == mongo.ErrNoDocuments || time.Now().After(storedCode.ExpiresAt) {
		http.Error(w, "Geçersiz veya süresi dolmuş kod", http.StatusUnauthorized)
		return
	} else if err != nil {
		log.Printf("Veritabanı hatası: %v", err)
		http.Error(w, "Sunucu hatası", http.StatusInternalServerError)
		return
	}

	hashedPassword, err := hashPassword(req.NewPassword)
	if err != nil {
		http.Error(w, "Şifre şifreleme hatası", http.StatusInternalServerError)
		return
	}

	_, err = usersCollection.UpdateOne(
		context.Background(),
		bson.M{"email": req.Email},
		bson.M{"$set": bson.M{"sifre": hashedPassword}},
	)
	if err != nil {
		log.Printf("Şifre güncelleme hatası: %v", err)
		http.Error(w, "Şifre güncellenemedi", http.StatusInternalServerError)
		return
	}

	_, err = verificationCollection.DeleteOne(context.Background(), bson.M{"email": req.Email})
	if err != nil {
		log.Printf("Doğrulama kodu silme hatası: %v", err)
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(MessageResponse{Message: "Şifreniz başarıyla sıfırlandı."})
}