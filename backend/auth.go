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

    "github.com/dgrijalva/jwt-go"
    "go.mongodb.org/mongo-driver/bson"
    "go.mongodb.org/mongo-driver/mongo"
    "go.mongodb.org/mongo-driver/mongo/options"
    "golang.org/x/crypto/bcrypt"
)

var jwtKey = []byte(os.Getenv("JWT_SECRET_KEY"))

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


// Sosyal girişler kaldırıldı; herhangi bir init yapılandırması yok

func createToken(email string) (string, error) {
	expirationTime := time.Now().Add(24 * 7 * time.Hour) // Token 7 gün geçerli olacak
	claims := &Claims{
		Email: email,
		StandardClaims: jwt.StandardClaims{
			ExpiresAt: expirationTime.Unix(),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString(jwtKey)
	if err != nil {
		return "", err
	}
	return tokenString, nil
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

    // Kullanıcıyı veritabanında ara
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

    // Şifreyi kontrol et
    if !checkPasswordHash(req.Sifre, user.Sifre) {
        http.Error(w, "Hatalı şifre", http.StatusUnauthorized)
        return
    }

	// Token oluştur ve yanıtla birlikte gönder
    token, err := createToken(user.Email)
    if err != nil {
        log.Printf("Token oluşturma hatası: %v", err)
        http.Error(w, "Token oluşturulamadı", http.StatusInternalServerError)
        return
    }
    
    // Başarılı giriş
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusOK)
    json.NewEncoder(w).Encode(map[string]string{
        "status":  "success",
        "message": "Giriş başarılı",
		"token": token,
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

// Google/Facebook sosyal giriş handler'ları kaldırıldı

// verifyTokenHandler, gönderilen token'ı doğrular ve geçerliyse kullanıcı bilgilerini döndürür
func verifyTokenHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	tokenString := r.Header.Get("Authorization")
	if tokenString == "" {
		http.Error(w, "Yetkilendirme token'ı eksik", http.StatusUnauthorized)
		return
	}

	claims := &Claims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		return jwtKey, nil
	})

	if err != nil || !token.Valid {
		http.Error(w, "Geçersiz token", http.StatusUnauthorized)
		return
	}

	var user User
	err = usersCollection.FindOne(context.Background(), bson.M{"email": claims.Email}).Decode(&user)
	if err != nil {
		http.Error(w, "Kullanıcı bulunamadı", http.StatusUnauthorized)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"message": "Token geçerli",
	})
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