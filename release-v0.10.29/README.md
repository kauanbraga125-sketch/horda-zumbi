# Horda Zumbi 0.10.29 — cópia verificada

O APK assinado e a atualização completa dos fontes estão preservados em partes verificadas por SHA-256. O workflow horda-v01029 publica o APK completo e sincroniza os fontes de monster-game.

Para reconstruir localmente após clonar o repositório:

```bash
python3 release-v0.10.29/restore_release.py --apply-source --package-source --out dist
```

A pasta dist terá o APK instalável, o projeto público completo e as prévias. A identidade privada de assinatura permanece apenas no backup privado do proprietário.

[Download da versão de testes](https://github.com/kauanbraga125-sketch/horda-zumbi/releases/tag/v0.10.29)
