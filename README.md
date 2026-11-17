# Jadual Kerja & Claim

Web app untuk jadual kerja shift, rekod OT, cuti/tukar shift dan borang **Application for Overtime / Allowance** (Excel). Boleh di-install di Android sebagai apps dan jalan tanpa internet.

## Fail
| Fail | Guna |
|---|---|
| `index.html` | Apps (semua kod dan templat borang Excel ada di dalam) |
| `manifest.webmanifest`, `sw.js`, `icon-192.png`, `icon-512.png` | Supaya boleh di-install dan jalan tanpa internet |

> `backup_faisal.json` **jangan** upload ke GitHub — itu data peribadi. Simpan dalam phone dan buka melalui *Tetapan → Buka backup*.

## Letak di GitHub Pages (sekali sahaja)
1. Log masuk github.com → **New repository** → nama `jadual-kerja` → *Public* → **Create repository**.
2. Tekan **uploading an existing file**, seret 5 fail di atas (index.html, manifest.webmanifest, sw.js, icon-192.png, icon-512.png) → **Commit changes**.
3. Pergi **Settings → Pages** → *Source*: **Deploy from a branch** → Branch **main**, folder **/ (root)** → **Save**.
4. Tunggu 1–2 minit. Link apps: `https://<username-github>.github.io/jadual-kerja/`

## Install di Android
1. Buka link tadi dalam **Chrome**.
2. Menu **⋮ → Install app** (atau *Add to Home screen*).
3. Buka apps dari ikon → **Tetapan → Buka backup** → pilih `backup_faisal.json` (atau isi nama & maklumat sendiri untuk rakan kerja).

## Masuk (rakan kerja)
1. Buka https://gempak100.github.io/Rapid_CTO/ dalam Chrome → **⋮ → Install app**.
2. Masukkan **kata laluan pasukan** (diberi dalam group kerja) dan **no. pekerja (ID)**.
3. Jadual kerja kau dimuat terus dari roster. Isi maklumat borang (Depot, Designation, Grade, Contact) dalam **Tetapan**.

## Roster berkunci
- Folder `roster/` mengandungi roster setiap bulan dalam bentuk **berkunci (AES-256-GCM, kata laluan pasukan)**. Tanpa kata laluan, nama, ID dan jadual staf tidak boleh dibaca walaupun repo ini Public.
- `roster/index.json` senarai bulan yang ada.
- Roster bulan baru: hantar PDF roster kepada Claude untuk ditambah. Apps setiap orang akan kemas kini sendiri bila dibuka dengan internet; perubahan sendiri (tukar shift, cuti, OT) tidak ditimpa.

## Guna setiap bulan
1. Roster dimuat sendiri. (Kalau perlu isi manual: **Tetapan → Isi roster sebulan**, kod dipisah koma, cth `B3, B3, OFF, REST, A2/B2`.)
2. **Kalendar**: semak, tambah OT tambahan / AL / EL / CL / tukar shift dengan tekan hari.
3. **Kalendar → Muat turun calendar bulan ni (.ics)** → buka fail untuk notification shift dalam calendar phone.
4. **Claim → Borang Claim OT (Excel)** → fail borang siap diisi.
5. **Tetapan → Simpan backup** selalu (data disimpan dalam phone sahaja).

## Rakan kerja
Setiap orang buka link yang sama, install, dan isi nama/maklumat sendiri di Tetapan. Data setiap orang disimpan dalam phone masing-masing.
