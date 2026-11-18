# AgentGate — Rencana Deploy (disusun 2026-11-18 malam, BELUM dieksekusi)

## Biaya terukur (bukan tebakan)
Gas diukur dari deploy beneran di EVM lokal (anvil), kontrak yang sama persis:
- Deploy AgentBadge: 1.113.643 gas
- Deploy AgentGate: 534.721 gas
- setBadge (wiring): 47.428 gas
- setMinter (wiring): 47.486 gas
- **Total: 1.743.278 gas**

Harga gas BSC saat diukur (2026-11-18 22:50 WIB, read-only dari BSC RPC): **0,05 gwei**
→ Biaya = 1.743.278 × 0,05 gwei = **0,0000872 BNB ≈ $0,05** (BNB $581,65, CoinGecko).
Skenario gas naik 20× (1 gwei): 0,00174 BNB ≈ $1,01. Tetap kecil di semua skenario wajar.

## Saldo deployer (read-only, 2026-11-18 22:50 WIB)
Agentic Wallet ipot `0xF43F767E85a8560E3CC3197d8Ba7d3A02b33B06A`: **0,002997 BNB** — cukup ±34× biaya deploy terukur.

## Jalur eksekusi (setelah go eksplisit ipot)
Deploy lewat baw (Binance Agentic Wallet) — kontrak dibuat via contract-call dengan
bytecode hasil `forge build`:
1. Preview deploy AgentBadge (creation bytecode, value 0) → periksa preview → execute.
2. Preview deploy AgentGate(registry 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F) → execute.
3. Preview + execute setBadge(badge) di Gate; setMinter(gate) di Badge.
4. Verifikasi read-only: hasAgentId(wallet ipot) == true; uniqueMembers == 0.
5. BscScan: submit source verification (flattened source + compiler 0.8.24 + OZ 5.1.0)
   untuk kedua kontrak → status verified.
6. Repo publik GitHub garp702/agentgate (kontrak + test + README + LICENSE MIT),
   alamat kontrak ditulis ke web/config.js, halaman web dipublish (GitHub Pages).
7. Isi form submit hackathon: nama, website, alamat kontrak, deskripsi Agent ID,
   alamat penerima hadiah = Erjv (OKX ipot) — konfirmasi ke ipot sebelum submit.

## Yang TIDAK dilakukan tanpa perintah terpisah
- Tidak ada transaksi apa pun sebelum go. Tidak ada pembelian, approval, atau transfer.
- Drive 30 alamat Agent ID = distribusi manual (link dibagikan ipot / komunitas), bukan bot.
