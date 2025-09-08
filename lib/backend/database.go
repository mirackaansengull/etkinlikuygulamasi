package main

import (
    "context"
    "log"
    "time"
    "os"

    "go.mongodb.org/mongo-driver/mongo"
    "go.mongodb.org/mongo-driver/mongo/options"
)

var client *mongo.Client

func ConnectDB() error {
    // MongoDB Atlas bağlantı dizesi
	connectionString := os.Getenv("MONGO_URI")
    
    // Client seçeneklerini ayarla
    clientOptions := options.Client().ApplyURI(connectionString).
        SetConnectTimeout(10 * time.Second)

    // MongoDB'ye bağlan
    var err error
    client, err = mongo.Connect(context.Background(), clientOptions)
    if err != nil {
        log.Printf("MongoDB bağlantı hatası: %v", err)
        return err
    }

    // Bağlantıyı test et
    err = client.Ping(context.Background(), nil)
    if err != nil {
        log.Printf("MongoDB ping hatası: %v", err)
        return err
    }

    log.Println("MongoDB Atlas'a başarıyla bağlanıldı!")
    return nil
}