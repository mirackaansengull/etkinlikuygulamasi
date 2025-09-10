package main

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

// User, veritabanındaki kullanıcı belgesini temsil eder.
type User struct {
	ID        primitive.ObjectID `json:"id" bson:"_id,omitempty"`
	Ad        string             `json:"ad" bson:"ad"`
	Soyad     string             `json:"soyad" bson:"soyad"`
	Telefon   string             `json:"telefon" bson:"telefon"`
	DogumTarihi string           `json:"dogumTarihi" bson:"dogumTarihi"`
	Email     string             `json:"email" bson:"email"`
	Sifre     string             `json:"sifre" bson:"sifre"`
	CreatedAt time.Time          `json:"createdAt" bson:"createdAt"`
}

// VerificationCode, email doğrulama kodlarını geçici olarak saklar.
type VerificationCode struct {
	ID        primitive.ObjectID `json:"id" bson:"_id,omitempty"`
	Email     string             `json:"email" bson:"email"`
	Code      string             `json:"code" bson:"code"`
	ExpiresAt time.Time          `json:"expiresAt" bson:"expiresAt"`
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