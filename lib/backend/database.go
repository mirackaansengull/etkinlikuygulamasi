package main

import (
	"context"
	"log"
	"os"
	"sync"
	"time"

	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// Global MongoDB bağlantı ve koleksiyon referansları
var (
	client                 *mongo.Client
	database               *mongo.Database
	usersCollection        *mongo.Collection
	verificationCollection *mongo.Collection // Bu, sizin projenizdeki doğru koleksiyon adı
)

// Global değişkenler için mutex
var (
	dbInitMutex sync.Mutex
	isDBInit    bool
)

// InitMongoDB, MongoDB bağlantısını kurar ve koleksiyonları başlatır
func InitMongoDB() {
	dbInitMutex.Lock()
	defer dbInitMutex.Unlock()

	// Bağlantı zaten başlatıldıysa tekrar başlatma
	if isDBInit {
		return
	}

	mongoURI := os.Getenv("MONGO_URI")
	if mongoURI == "" {
		log.Fatal("MONGO_URI ortam değişkeni tanımlı değil.")
	}

	clientOptions := options.Client().ApplyURI(mongoURI)
	var err error
	client, err = mongo.Connect(context.Background(), clientOptions)
	if err != nil {
		log.Fatal("MongoDB bağlantı hatası:", err)
	}

	// Bağlantıyı test et
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	err = client.Ping(ctx, nil)
	if err != nil {
		log.Fatal("MongoDB ping hatası:", err)
	}

	log.Println("MongoDB'ye başarıyla bağlanıldı!")

	// Veritabanı ve koleksiyonları başlat
	database = client.Database("etkinlikuygulamasi") // Veritabanı adını kontrol edin
	usersCollection = database.Collection("users")
	verificationCollection = database.Collection("verification_codes")

	isDBInit = true
}

// CloseDB, MongoDB bağlantısını kapatır
func CloseDB() {
	if client == nil {
		return
	}
	err := client.Disconnect(context.Background())
	if err != nil {
		log.Println("MongoDB bağlantı kapatma hatası:", err)
	}
}