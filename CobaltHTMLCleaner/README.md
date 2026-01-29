# Cobalt HTML Cleaner

Alat ini digunakan untuk membersihkan dan memadatkan (compact) log HTML dari **Cobalt Executor Session** menjadi script Lua yang bersih dan siap pakai.

## Cara Menggunakan

1.  **Siapkan Log HTML**:
    *   Simpan session log dari Cobalt dalam format `.html`.
    *   Pindahkan file `.html` tersebut ke dalam folder **`input`**.

2.  **Jalankan Script**:
    *   **Cara Cepat**: Klik file `cleaner.py` dua kali.
    *   **Cara Terminal (Copy-Paste)**:
        ```powershell
        cd "C:\Users\Administrator\Desktop\CobaltHTMLCleaner"
        python cleaner.py
        ```

3.  **Pilih Mode**:
    *   **1. Process Latest HTML**: Otomatis memproses file `.html` paling baru di folder `input`.
    *   **2. Process All HTML Files**: Memproses SEMUA file `.html` yang ada di folder `input`.
    *   **3. Select HTML from List**: Menampilkan daftar file dan Anda bisa pilih nomornya.

4.  **Ambil Hasil**:
    *   Buka folder **`output`**.
    *   Script Lua yang sudah bersih (Cleaned) akan muncul di sana dengan akhiran `_clean.lua`.

## Fitur
*   **Ultra-Compact**: Output script Lua dipadatkan menjadi 1 baris per event agar mudah dibaca.
*   **Universal**: Bisa digunakan untuk semua game Roblox yang di-record menggunakan Cobalt.
*   **HTML Only**: Dirancang khusus untuk membaca format data JSON dari Cobalt HTML Session.
