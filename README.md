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

## Guna setiap bulan
1. **Tetapan → Isi roster sebulan**: pilih bulan, tulis kod shift hari 1 hingga akhir bulan dipisah koma (cth `B3, B3, OFF, REST, A2/B2, B PTH STBY`).
2. **Kalendar**: semak, tambah OT tambahan / AL / EL / CL / tukar shift dengan tekan hari.
3. **Kalendar → Muat turun calendar bulan ni (.ics)** → buka fail untuk notification shift dalam calendar phone.
4. **Claim → Borang Claim OT (Excel)** → fail borang siap diisi.
5. **Tetapan → Simpan backup** selalu (data disimpan dalam phone sahaja).

## Rakan kerja
Setiap orang buka link yang sama, install, dan isi nama/maklumat sendiri di Tetapan. Data setiap orang disimpan dalam phone masing-masing.
