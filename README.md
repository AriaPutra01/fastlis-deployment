# FastLIS Deployment Repository

Repositori ini secara eksklusif didedikasikan untuk kebutuhan **Deployment Infrastruktur FastLIS** di lingkungan *On-Premise* (Server Klien/Klinik/Lab). 

Repositori ini **TIDAK BERISI *source code*** (Golang/React), melainkan bertindak sebagai cetak biru (blueprint) infrastruktur untuk mengatur bagaimana FastLIS dijalankan menggunakan Docker, serta bagaimana sistem melakukan pembaharuan secara otomatis.

---

## 🎯 Apa Fungsi Repositori Ini?

1. **Keamanan Ekstra:** Memisahkan *source code* berharga Anda dari server klien. Klien on-premise hanya perlu melakukan clone ke repo ini.
2. **Infrastructure as Code (IaC):** Berisi resep `docker-compose.yml` untuk memanggil *Docker Images* dari GitHub Container Registry (GHCR).
3. **Automasi Pemeliharaan:** Menyediakan *script* terintegrasi untuk proses instalasi 1-klik, pembaruan otomatis (via Cron Job), serta utilitas *Backup & Restore* database.

---

## 🌊 Alur Kerja Sistem (End-to-End Flow)

Berikut adalah bagaimana ekosistem LIMS Anda bekerja dari hulu (Developer) ke hilir (Klinik/Lab):

### TAHAP 1: Developer Side (CI/CD GitHub Actions)
*Ini terjadi di repositori rahasia/private Anda (`fastlis`)*

1. Anda menulis kode dan melakukan `git push` beserta *release tags* (misal: `v1.2.0`).
2. GitHub Actions mem- *build* kode tersebut menjadi paket aplikasi siap pakai.
3. Paket didorong ke rak penyimpanan **GHCR** sebagai:
   - `ghcr.io/ariaputra01/fastlis-backend:latest`
   - `ghcr.io/ariaputra01/fastlis-frontend:latest`
   - `ghcr.io/ariaputra01/fastlis-sync:latest` (Adapter SIMRS Dual-Mode)

### TAHAP 1.5: Opsi Integrasi SIMRS (fastlis-sync)
Sistem ini dilengkapi dengan `fastlis-sync` yang bisa berjalan dalam 2 mode (diatur via saat instalasi):
- **Mode API**: Bertindak sebagai Webhook Proxy. Eksternal menembak HTTP POST ke `http://<ip>:8081/api/webhook/orders`.
- **Mode DB**: Bertindak sebagai *Background Worker*. Eksternal menulis langsung ke tabel `registration` dan `ordered_item` di PostgreSQL, lalu sistem akan memprosesnya.

### TAHAP 2: Inisialisasi Server Klien (Satu Kali Saja)
*Ini terjadi di komputer server On-Premise*

1. Klien / Teknisi Anda mengeksekusi perintah 1-klik:
   **Untuk Linux / Mac:**
   ```bash
   curl -fsSL https://raw.githubusercontent.com/AriaPutra01/fastlis-deployment/main/install.sh | bash
   ```
   **Untuk Windows (Jalankan PowerShell sebagai Administrator):**
   ```powershell
   Invoke-RestMethod -Uri "https://raw.githubusercontent.com/AriaPutra01/fastlis-deployment/main/install.ps1" | Invoke-Expression
   ```
2. `install.sh` melakukan keajaibannya:
   - Memastikan Docker & Docker Compose terinstal.
   - Melakukan `git clone` terhadap repositori ini (`fastlis-deployment`).
   - Menghasilkan konfigurasi `.env` (Password Database, Token JWT, dll).
   - Mengonfigurasi **Cron Job Auto-Update**.
   - Mengeksekusi `docker compose up -d` untuk pertama kalinya.

### TAHAP 3: Hari-ke-Hari (Operasional & Pemeliharaan Klien)
*Infrastruktur berjalan secara background (Ansible-pull flow)*

1. Klien menggunakan aplikasi via `http://<ip-klien>:5173`. Database & Redis bekerja dari dalam container.
2. Teknisi klien bisa melakukan pemeliharaan database secara mandiri menggunakan `scripts/backup.sh` atau `scripts/restore.sh`.

### TAHAP 4: Siklus Pembaruan Otomatis (Auto-Update)
*Ketika Anda merilis fitur baru di masa depan*

1. Anda me-rilis versi `v1.3.0` di repo utama. GHCR akan ter-update dengan *image* baru.
2. Jika ada perubahan infrastruktur (misal tambah container MinIO), Anda perbarui `docker-compose.yml` di repo ini.
3. **Di Server Klien:** Tepat pukul 02:00 pagi (sesuai setting cron job):
   - Sistem klien memanggil perintah `git pull` dari repositori ini, mengambil `docker-compose.yml` paling anyar.
   - Sistem mengeksekusi `docker compose pull` untuk mengunduh *image* LIMS `v1.3.0` dari GHCR.
   - Sistem mengeksekusi `docker compose up -d`. Kontainer lama dimatikan sekilas, dan diganti dengan versi baru.
   - *Downtime* terjadi kurang dari 5 detik, klien mendapatkan fitur baru keesokan paginya tanpa campur tangan teknisi!

---

## 📂 Struktur Direktori

```text
├── docker-compose.yml          # Resep Docker untuk Production (Tarik dari GHCR)
├── install.sh                  # Skrip Instalasi 1-Klik interaktif
├── TROUBLESHOOTING.md          # Panduan kilat atasi error klien
└── scripts/
    ├── ansible-pull-setup.sh   # Skrip setup otomatisasi pembaruan background
    ├── backup.sh               # Utilitas backup database Postgres
    └── restore.sh              # Utilitas restore database Postgres
```
