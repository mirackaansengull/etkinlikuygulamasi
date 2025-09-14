package main

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/dgrijalva/jwt-go"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
)



// getUserProfileHandler, kullanıcının profil bilgilerini döndürür
func getUserProfileHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	// Authorization header'ından token'ı al
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		http.Error(w, `{"error": "Authorization header gerekli"}`, http.StatusUnauthorized)
		return
	}

	// "Bearer " prefix'ini kaldır
	tokenString := strings.TrimPrefix(authHeader, "Bearer ")
	if tokenString == authHeader {
		http.Error(w, `{"error": "Bearer token formatı gerekli"}`, http.StatusUnauthorized)
		return
	}

	// Token'ı doğrula ve email'i çıkar
	email, err := validateTokenAndGetEmail(tokenString)
	if err != nil {
		http.Error(w, `{"error": "Geçersiz token"}`, http.StatusUnauthorized)
		return
	}

	// Kullanıcıyı veritabanından bul
	user, err := getUserByEmail(email)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			http.Error(w, `{"error": "Kullanıcı bulunamadı"}`, http.StatusNotFound)
			return
		}
		http.Error(w, `{"error": "Veritabanı hatası"}`, http.StatusInternalServerError)
		return
	}

	// Kullanıcı bilgilerini response formatına çevir
	profileResponse := UserProfileResponse{
		ID:          user.ID.Hex(),
		Ad:          user.Ad,
		Soyad:       user.Soyad,
		Email:       user.Email,
		Telefon:     user.Telefon,
		DogumTarihi: user.DogumTarihi,
		Provider:    user.Provider,
		CreatedAt:   user.CreatedAt,
	}

	// JSON olarak döndür
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(profileResponse)
}

// updateUserProfileHandler, kullanıcının profil bilgilerini günceller
func updateUserProfileHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	// Authorization header'ından token'ı al
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		http.Error(w, `{"error": "Authorization header gerekli"}`, http.StatusUnauthorized)
		return
	}

	// "Bearer " prefix'ini kaldır
	tokenString := strings.TrimPrefix(authHeader, "Bearer ")
	if tokenString == authHeader {
		http.Error(w, `{"error": "Bearer token formatı gerekli"}`, http.StatusUnauthorized)
		return
	}

	// Token'ı doğrula ve email'i çıkar
	email, err := validateTokenAndGetEmail(tokenString)
	if err != nil {
		http.Error(w, `{"error": "Geçersiz token"}`, http.StatusUnauthorized)
		return
	}

	// Request body'yi parse et
	var updateReq UpdateProfileRequest
	if err := json.NewDecoder(r.Body).Decode(&updateReq); err != nil {
		http.Error(w, `{"error": "Geçersiz JSON formatı"}`, http.StatusBadRequest)
		return
	}

	// Güncelleme verilerini hazırla
	updateData := bson.M{}
	if updateReq.Ad != "" {
		updateData["ad"] = updateReq.Ad
	}
	if updateReq.Soyad != "" {
		updateData["soyad"] = updateReq.Soyad
	}
	if updateReq.Telefon != "" {
		updateData["telefon"] = updateReq.Telefon
	}
	if updateReq.DogumTarihi != "" {
		updateData["dogumTarihi"] = updateReq.DogumTarihi
	}

	// Veritabanında güncelle
	collection := mongoClient.Database("etkinlikapp").Collection("users")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	filter := bson.M{"email": email}
	update := bson.M{"$set": updateData}

	result, err := collection.UpdateOne(ctx, filter, update)
	if err != nil {
		http.Error(w, `{"error": "Profil güncellenirken hata oluştu"}`, http.StatusInternalServerError)
		return
	}

	if result.MatchedCount == 0 {
		http.Error(w, `{"error": "Kullanıcı bulunamadı"}`, http.StatusNotFound)
		return
	}

	// Güncellenmiş kullanıcı bilgilerini döndür
	updatedUser, err := getUserByEmail(email)
	if err != nil {
		http.Error(w, `{"error": "Güncellenmiş bilgiler alınamadı"}`, http.StatusInternalServerError)
		return
	}

	profileResponse := UserProfileResponse{
		ID:          updatedUser.ID.Hex(),
		Ad:          updatedUser.Ad,
		Soyad:       updatedUser.Soyad,
		Email:       updatedUser.Email,
		Telefon:     updatedUser.Telefon,
		DogumTarihi: updatedUser.DogumTarihi,
		Provider:    updatedUser.Provider,
		CreatedAt:   updatedUser.CreatedAt,
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(profileResponse)
}

// validateTokenAndGetEmail, JWT token'ını doğrular ve email'i döndürür
func validateTokenAndGetEmail(tokenString string) (string, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		return jwtKey, nil
	})

	if err != nil {
		return "", err
	}

	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims.Email, nil
	}

	return "", jwt.ErrSignatureInvalid
}

// getUserByEmail, email'e göre kullanıcıyı veritabanından getirir
func getUserByEmail(email string) (*User, error) {
	collection := mongoClient.Database("etkinlikapp").Collection("users")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	var user User
	err := collection.FindOne(ctx, bson.M{"email": email}).Decode(&user)
	if err != nil {
		return nil, err
	}

	return &user, nil
}