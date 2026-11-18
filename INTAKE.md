# AgentGate — Binance Agent ID Hackathon (60.000 USDC, submit tutup 9 Des 2026 15:00 WIB)
Diperintah ipot 2026-11-18 22:41 WIB ("Bangun coba").

## Konsep
dApp gerbang khusus pemegang Agent ID di BNB Chain:
- Kontrak mengecek balanceOf di registry Agent ID resmi 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F (SPACE ID, ERC-721 soulbound).
- checkIn() harian (1x/hari UTC per alamat) — hanya untuk pemegang Agent ID; mencatat streak + total + member unik.
- Badge ERC-721 soulbound setelah ambang check-in (mis. 3x) — mint hanya oleh kontrak inti.
- TANPA dana pengguna sama sekali: tidak ada transfer, approval, pajak, pause, janji return — bersih dari semua red line hackathon.
- Owner = deployer (alamat Agentic Wallet ipot 0xF43F767E85a8560E3CC3197d8Ba7d3A02b33B06A); kewenangan owner didokumentasikan di README.

## Kriteria juri (Innovation): Agent ID depth 30%, praktikalitas 25%, kelengkapan produk 25%, inovasi 20%.
## Syarat: produk live + >=30 alamat Agent ID berinteraksi selama 18 Nov–9 Des. Project Awards juga dihitung dari metrik yang sama.
## Batas malam ini: bangun + tes lokal SAJA. Deploy = spend gas BNB -> butuh go eksplisit ipot dengan angka biaya.
