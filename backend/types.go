package main

import (
	"time"
	"github.com/dgrijalva/jwt-go"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

// User, veritabanındaki kullanıcı belgesini temsil eder.
type User struct {
	ID          primitive.ObjectID `json:"id" bson:"_id,omitempty"`
	Ad          string             `json:"ad" bson:"ad"`
	Soyad       string             `json:"soyad" bson:"soyad"`
	Telefon     string             `json:"telefon" bson:"telefon,omitempty"`
	DogumTarihi string             `json:"dogumTarihi" bson:"dogumTarihi,omitempty"`
	Email       string             `json:"email" bson:"email"`
	Sifre       string             `json:"sifre" bson:"sifre,omitempty"` // Sosyal girişlerde boş kalabilir
	Provider    string             `json:"provider" bson:"provider"`    // 'email', 'google', 'facebook'
	SocialID    string             `json:"socialId" bson:"socialId,omitempty"` // Google/Facebook ID'si
	CreatedAt   time.Time          `json:"createdAt" bson:"createdAt"`
}

// VerificationCode, email doğrulama kodlarını geçici olarak saklar.
type VerificationCode struct {
	ID        primitive.ObjectID `json:"id" bson:"_id,omitempty"`
	Email     string             `json:"email" bson:"email"`
	Code      string             `json:"code" bson:"code"`
	ExpiresAt time.Time          `json:"expiresAt" bson:"expiresAt"`
}

type LoginRequest struct {
    Email    string `json:"email"`
    Sifre    string `json:"sifre"`
}

// Handler'lar için istek ve yanıt yapıları
type RegisterRequest struct {
	Ad               string `json:"ad"`
	Soyad            string `json:"soyad"`
	Telefon          string `json:"telefon"`
	DogumTarihi      string `json:"dogumTarihi"`
	Email            string `json:"email"`
	Sifre            string `json:"sifre"`
	VerificationCode string `json:"verificationCode"`
}

type SendCodeRequest struct {
	Email string `json:"email"`
}

type MessageResponse struct {
	Message string `json:"message"`
}

// Sosyal giriş kullanıcı tipleri kaldırıldı

type ResetPasswordRequest struct {
	Email       string `json:"email"`
	Code        string `json:"code"`
	NewPassword string `json:"newPassword"`
}

type Claims struct {
	Email string `json:"email"`
	jwt.StandardClaims
}

// UserProfileResponse, kullanıcı profil bilgilerini döndürmek için kullanılır
type UserProfileResponse struct {
	ID          string    `json:"id"`
	Ad          string    `json:"ad"`
	Soyad       string    `json:"soyad"`
	Email       string    `json:"email"`
	Telefon     string    `json:"telefon,omitempty"`
	DogumTarihi string    `json:"dogumTarihi,omitempty"`
	Provider    string    `json:"provider"`
	CreatedAt   time.Time `json:"createdAt"`
}

// UpdateProfileRequest, profil güncelleme isteği için kullanılır
type UpdateProfileRequest struct {
	Ad          string `json:"ad"`
	Soyad       string `json:"soyad"`
	Telefon     string `json:"telefon"`
	DogumTarihi string `json:"dogumTarihi"`
}