package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
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

// --- OAuth2 Yapılandırması ---

var googleOAuthConfig *oauth2.Config
var facebookOAuthConfig *oauth2.Config

func init() {
	// Google OAuth2 yapılandırması
	googleOAuthConfig = &oauth2.Config{
		ClientID:     os.Getenv("GOOGLE_CLIENT_ID"),
		ClientSecret: os.Getenv("GOOGLE_CLIENT_SECRET"),
		RedirectURL:  os.Getenv("GOOGLE_REDIRECT_URL"), // Ortam değişkenlerinden alınacak
		Scopes:       []string{"https://www.googleapis.com/auth/userinfo.email", "https://www.googleapis.com/auth/userinfo.profile"},
		Endpoint:     google.Endpoint,
	}

	// Facebook OAuth2 yapılandırması
	facebookOAuthConfig = &oauth2.Config{
		ClientID:     os.Getenv("FACEBOOK_CLIENT_ID"),
		ClientSecret: os.Getenv("FACEBOOK_CLIENT_SECRET"),
		RedirectURL:  os.Getenv("FACEBOOK_REDIRECT_URL"), // Ortam değişkenlerinden alınacak
		Scopes:       []string{"email", "public_profile"},
		Endpoint: oauth2.Endpoint{
			AuthURL:  "https://www.facebook.com/v10.0/dialog/oauth",
			TokenURL: "https://graph.facebook.com/v10.0/oauth/access_token",
		},
	}
}

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
        from := os.Getenv("SMTP_USER")
        password := os.Getenv("SMTP_PASSWORD")
        host := os.Getenv("SMTP_HOST")
        port := os.Getenv("SMTP_PORT")
        
        if from == "" || password == "" || host == "" || port == "" {
            log.Println("Hata: SMTP ortam değişkenleri tanımlanmamış.")
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

    // Başarılı giriş
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusOK)
    json.NewEncoder(w).Encode(map[string]string{
        "status":  "success",
        "message": "Giriş başarılı",
    })
}

func registerHandler(w http.ResponseWriter, r *http.Request) {
    startTime := time.Now()

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

    startStep1 := time.Now()
    var verCode VerificationCode
    err := verificationCollection.FindOne(context.Background(), bson.M{"email": req.Email}).Decode(&verCode)
    if err != nil {
        http.Error(w, "Doğrulama kodu geçersiz veya süresi dolmuş", http.StatusUnauthorized)
        return
    }
    log.Printf("Adım 1: FindOne süresi: %v", time.Since(startStep1))

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
        Provider:    "email", // E-posta ile kayıt olduğu için 'email'
        CreatedAt:   time.Now(),
    }

    startStep2 := time.Now()
    _, err = usersCollection.InsertOne(context.Background(), newUser)
    if err != nil {
        log.Printf("Kullanıcı kaydetme hatası: %v", err)
        http.Error(w, "Kayıt işlemi başarısız oldu", http.StatusInternalServerError)
        return
    }
    log.Printf("Adım 2: InsertOne süresi: %v", time.Since(startStep2))

    startStep3 := time.Now()
    _, err = verificationCollection.DeleteOne(context.Background(), bson.M{"email": req.Email})
    if err != nil {
        log.Printf("Doğrulama kodu silme hatası: %v", err)
    }
    log.Printf("Adım 3: DeleteOne süresi: %v", time.Since(startStep3))

    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(MessageResponse{Message: "Kayıt işlemi başarıyla tamamlandı."})

    log.Printf("Toplam kayıt işlemi süresi: %v", time.Since(startTime))
}

func handleGoogleLogin(w http.ResponseWriter, r *http.Request) {
	state := fmt.Sprintf("%d", rand.Intn(1000000))
	url := googleOAuthConfig.AuthCodeURL(state)
	http.Redirect(w, r, url, http.StatusTemporaryRedirect)
}

func handleGoogleCallback(w http.ResponseWriter, r *http.Request) {
    

    code := r.FormValue("code")
    if code == "" {
        http.Error(w, "Code not found", http.StatusBadRequest)
        return
    }

    token, err := googleOAuthConfig.Exchange(context.Background(), code)
    if err != nil {
        http.Error(w, "Token değişimi başarısız: "+err.Error(), http.StatusInternalServerError)
        return
    }

    // Google'dan kullanıcı bilgilerini al
    resp, err := http.Get("https://www.googleapis.com/oauth2/v2/userinfo?access_token=" + token.AccessToken)
    if err != nil {
        http.Error(w, "Kullanıcı bilgisi alınamadı", http.StatusInternalServerError)
        return
    }
    defer resp.Body.Close()

    body, err := ioutil.ReadAll(resp.Body)
    if err != nil {
        http.Error(w, "Yanıt okunamadı", http.StatusInternalServerError)
        return
    }

    var googleUser GoogleUser
    if err := json.Unmarshal(body, &googleUser); err != nil {
        http.Error(w, "Kullanıcı bilgisi çözümlenemedi", http.StatusInternalServerError)
        return
    }

    // Veritabanında kullanıcıyı kontrol et veya oluştur
    var existingUser User
    err = usersCollection.FindOne(context.Background(), bson.M{"email": googleUser.Email, "provider": "google"}).Decode(&existingUser)

    if err == mongo.ErrNoDocuments {
        // Yeni kullanıcıyı kaydet
        newUser := User{
            Ad:          googleUser.Name,
            Soyad:       googleUser.FamilyName,
            Email:       googleUser.Email,
            Provider:    "google",
            CreatedAt:   time.Now(),
        }
        _, err = usersCollection.InsertOne(context.Background(), newUser)
        if err != nil {
            http.Error(w, "Kayıt işlemi başarısız", http.StatusInternalServerError)
            return
        }
    } else if err != nil {
        http.Error(w, "Veritabanı hatası", http.StatusInternalServerError)
        return
    }
}

func handleGoogleTokenVerification(w http.ResponseWriter, r *http.Request) {
    var requestBody struct {
        Token string `json:"token"`
    }
    if err := json.NewDecoder(r.Body).Decode(&requestBody); err != nil {
        http.Error(w, "Geçersiz istek gövdesi", http.StatusBadRequest)
        return
    }

    // Google'dan gelen idToken'ı doğrulamak için Google'ın kendi API'sini kullanmak gerekir.
    // Ancak basitleştirilmiş bir örnek olarak, token'ı kullanarak kullanıcı bilgilerini alacağız.
    // Bu, güvenlik açısından önerilmeyen bir yöntemdir.
    // Önerilen: `google-api-go-client` gibi bir kütüphane kullanarak token'ı doğrulayın.
    resp, err := http.Get("https://www.googleapis.com/oauth2/v2/userinfo?access_token=" + requestBody.Token)
    if err != nil {
        http.Error(w, "Kullanıcı bilgisi alınamadı", http.StatusInternalServerError)
        return
    }
    defer resp.Body.Close()

    var googleUser GoogleUser
    if err := json.NewDecoder(resp.Body).Decode(&googleUser); err != nil {
        http.Error(w, "Kullanıcı bilgisi çözümlenemedi", http.StatusInternalServerError)
        return
    }

    // Veritabanında kullanıcıyı kontrol et veya oluştur
    var existingUser User
    err = usersCollection.FindOne(context.Background(), bson.M{"email": googleUser.Email, "provider": "google"}).Decode(&existingUser)

    if err == mongo.ErrNoDocuments {
        // Yeni kullanıcıyı kaydet
        newUser := User{
            Ad:        googleUser.Name,
            Soyad:     googleUser.FamilyName,
            Email:     googleUser.Email,
            Provider:  "google",
            SocialID:  googleUser.Email,
            CreatedAt: time.Now(),
        }
        _, err = usersCollection.InsertOne(context.Background(), newUser)
        if err != nil {
            http.Error(w, "Kayıt işlemi başarısız", http.StatusInternalServerError)
            return
        }
    } else if err != nil {
        http.Error(w, "Veritabanı hatası", http.StatusInternalServerError)
        return
    }

    // Başarılı giriş
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusOK)
    json.NewEncoder(w).Encode(map[string]string{
        "message": "Giriş Başarılı",
        "token":   "oluşturulan_token", // Gerçek bir token oluşturma kodunu buraya ekleyin
    })
}

// handleFacebookCallback, Facebook OAuth2 yönlendirmesini işler
func handleFacebookCallback(w http.ResponseWriter, r *http.Request) {
    code := r.URL.Query().Get("code")
    if code == "" {
        http.Error(w, "Yetkilendirme kodu eksik", http.StatusBadRequest)
        return
    }

    token, err := facebookOAuthConfig.Exchange(context.Background(), code)
    if err != nil {
        http.Error(w, "Token değişimi başarısız", http.StatusInternalServerError)
        log.Printf("Facebook OAuth token değişimi hatası: %v", err)
        return
    }
    
    resp, err := http.Get("https://graph.facebook.com/me?fields=id,name,email&access_token=" + token.AccessToken)
    if err != nil {
        http.Error(w, "Kullanıcı bilgisi alınamadı", http.StatusInternalServerError)
        return
    }
    defer resp.Body.Close()

    body, err := ioutil.ReadAll(resp.Body)
    if err != nil {
        http.Error(w, "Yanıt okunamadı", http.StatusInternalServerError)
        return
    }
    
    var fbUser FacebookUser
    if err := json.Unmarshal(body, &fbUser); err != nil {
        http.Error(w, "Kullanıcı bilgisi çözümlenemedi", http.StatusInternalServerError)
        return
    }

    var existingUser User
    err = usersCollection.FindOne(context.Background(), bson.M{"email": fbUser.Email, "provider": "facebook"}).Decode(&existingUser)

    if err == mongo.ErrNoDocuments {
        newUser := User{
            Ad:        fbUser.Name,
            Soyad:     "",
            Email:     fbUser.Email,
            Provider:  "facebook",
            SocialID:  fbUser.ID,
            CreatedAt: time.Now(),
        }
        _, err = usersCollection.InsertOne(context.Background(), newUser)
        if err != nil {
            http.Error(w, "Kayıt işlemi başarısız", http.StatusInternalServerError)
            return
        }
    } else if err != nil {
        http.Error(w, "Veritabanı hatası", http.StatusInternalServerError)
        return
    }

    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusOK)
    json.NewEncoder(w).Encode(MessageResponse{Message: "Facebook ile giriş başarılı."})
}