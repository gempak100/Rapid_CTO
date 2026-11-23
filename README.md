# Jadual Kerja & Tugasan Harian

Web app untuk jadual kerja shift, rekod OT, tukar shift / cuti dan borang **Application for Overtime / Allowance** (Excel). Boleh dipasang di telefon sebagai apps dan berjalan tanpa internet.

## Fail
| Fail | Guna |
|---|---|
| `index.html` | Apps (kod dan templat borang Excel kosong) |
| `manifest.webmanifest`, `sw.js`, `icon-*.png` | Supaya boleh dipasang dan berjalan tanpa internet |
| `roster/` | Roster bulanan dalam bentuk **berkunci (AES-256-GCM)**. Tanpa kata laluan pasukan, kandungan tidak boleh dibaca. |
| `demo/` | Demo Fasa 2 (semakan leader) — data rekaan sahaja |

## Privasi
- Repo ini tidak mengandungi data peribadi dalam bentuk terbuka. Nama, ID, jadual staf dan tandatangan hanya ada di dalam fail roster berkunci.
- Data claim setiap user (OT, tukar shift, cuti) disimpan dalam telefon user sendiri, tidak dihantar ke repo ini.
- Jangan muat naik fail backup, kata laluan pasukan, roster asal (PDF/JSON) atau gambar tandatangan ke repo ini.
