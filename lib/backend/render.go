package main

import (
    "context"
    "encoding/json"
    "log"
    "net/http"
)

// healthHandler, MongoDB bağlantısını kontrol eder
func healthHandler(w http.ResponseWriter, r *http.Request) {
    // CORS başlıkları (Flutter için)
    w.Header().Set("Access-Control-Allow-Origin", "*")
    w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
    w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

    // OPTIONS isteklerini yönet
    if r.Method == http.MethodOptions {
        w.WriteHeader(http.StatusOK)
        return
    }

    // Sadece GET isteklerini işle
    if r.Method != http.MethodGet {
        http.Error(w, "Yalnızca GET istekleri destekleniyor", http.StatusMethodNotAllowed)
        return
    }

    // MongoDB bağlantısını test et
    err := client.Ping(context.Background(), nil)
    if err != nil {
        log.Printf("MongoDB ping hatası: %v", err)
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusInternalServerError)
        json.NewEncoder(w).Encode(map[string]string{
            "status":  "error",
            "message": "MongoDB bağlantısı başarısız: " + err.Error(),
        })
        return
    }

    // Başarılı yanıt
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusOK)
    json.NewEncoder(w).Encode(map[string]string{
        "status":  "ok",
        "message": "MongoDB connected",
    })
}