package main

import (
    "log"
    "net/http"
)

func main() {
    // MongoDB bağlantısını başlat
    err := ConnectDB() // database.go'dan gelen fonksiyon
    if err != nil {
        log.Fatalf("MongoDB bağlantı hatası: %v", err)
    }

    // Server'ı başlat (Vercel bunu otomatik yönetir)
    log.Println("Server başlatılıyor...")
    if err := http.ListenAndServe(":8080", nil); err != nil {
        log.Fatalf("Server başlatılamadı: %v", err)
    }
}