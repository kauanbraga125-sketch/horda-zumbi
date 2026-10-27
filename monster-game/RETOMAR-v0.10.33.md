# Retomar a Horda Zumbi — 0.10.33

Base: 0.10.32. Revisão dos problemas visuais enviados pelo proprietário, da clareza dos encontros e da entrada/saída do espaço. Leia `ESPACO-v0.10.33.md` e `VALIDACAO-v0.10.33.json`.

- Godot 4.5.1; Android 0.10.33, código 136, ARM64, GL Compatibility.
- Pacote `com.kauan.noitedahorda.reconstruida`; nome `Horda Espaco R33`.
- Preservar certificado SHA-256 `a641a59f39561af0210f2f1cd246f58c5bfd9ab05462bf5b0635e626d681d15d`.
- APK `Horda-Zumbi-v0.10.33-TESTE-1M-ESPACO-REVISADO-ARM64.apk`.
- Não criar `project.binary` antigo na raiz dos fontes. A configuração desta versão é `.godot/v133-project.binary`.
- Depois de editar, rodar `tools/refresh_startup_integrity.py`. O cache continua com 55 classes; os módulos espaciais novos não têm `class_name`.
- As duas cabines e o vórtice são imagens originais novas. A máscara magenta nos originais é técnica; é removida por `tools/prepare_space_v133.py` e jamais aparece no jogo. Os ocupantes são desenhados num viewport 640x400, recortados por `cabin_mask.gdshader` e cobertos pela estrutura da nave.
- `space_visual.gd` é responsável por apresentação e uma fila única de mensagens; `space_combat.gd` controla encontros e colisões; `space.gd` preserva a horda, os túneis e as fases do voo.
- `tools/build_v133.py` usa o APK verificado da 0.10.32 e a chave privada do proprietário. A chave e sua senha ficam somente no backup privado.
- `release-v0.10.33/restore_release.py` reconstrói o APK exato já assinado sem precisar da chave.
- O backup completo restaura as importações a partir do APK incluído; não duplica cache no ZIP.
- Não houve teste em Android físico; não afirmar isso em uma retomada.
