# Smoke harnesses

These LÖVE 11.5 harnesses simulate the narrow public engine interfaces consumed by HCO. They validate failure isolation, contract lifecycle, persistence, social stealth, difficulty balance, drone sensing/combat/flight, native-airframe presentation, faction visuals and completion feedback without distributing Intravenous 2 code or assets.

Run all suites from the repository root:

```powershell
./scripts/test.ps1 -LovePath C:\path\to\lovec.exe
```

The harnesses are regression proof, not a replacement for `docs/PRODUCTION_READINESS.md`'s live `1.0` promotion matrix.
