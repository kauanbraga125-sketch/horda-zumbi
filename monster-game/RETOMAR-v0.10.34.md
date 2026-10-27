# Retomar a Horda Zumbi — 0.10.34

Base: 0.10.33. Leia `ESPACO-v0.10.34.md` e `VALIDACAO-v0.10.34.json`.

- Godot 4.5.1; Android ARM64, versão 0.10.34, código 137, GL Compatibility.
- Pacote `com.kauan.noitedahorda.reconstruida`; rótulo `Horda Espaco R34`.
- Certificado SHA-256 `a641a59f39561af0210f2f1cd246f58c5bfd9ab05462bf5b0635e626d681d15d`. A chave e a senha ficam apenas no backup privado.
- APK `Horda-Zumbi-v0.10.34-TESTE-1M-ESPACO-ROTAS-ARM64.apk`.
- Não colocar um `project.binary` antigo na raiz. A configuração nativa desta versão fica em `.godot/v134-project.binary`.
- O backup privado inclui APK e importações recuperáveis offline com `restaurar_importacoes.py`, fontes, artes originais, testes e identidade de assinatura. Execute também `verificar_backup.py`.
- Depois de editar/importar: `python3 tools/refresh_startup_integrity.py`. Permanecem 55 classes registradas; os módulos novos usam `preload`, sem `class_name`.
- `space.gd`: líder, histórico de trajetória, fases, horda e túneis; `space_routes.gd`: padrões, recuperação e saída física; `space_combat.gd`: alvos, avisos, colisões e combos; `space_visual.gd`: HUD, arte, cabine e transições.
- `ribbon_count` é fixado no começo do voo. Não redistribuir toda a formação ao resgatar um novo membro.
- `next_group=1e6` suspende o diretor apenas em cenas de validação. Em jogo, o diretor usa tempo de contato e deixa o encontro terminar antes do portal.
- Novas imagens em `assets/art/space_v134`; original em `tools/art_sources/v134`. Imagens antigas de personagens e acessórios não foram redesenhadas.
- `tools/build_v134.py` usa a 0.10.33 verificada como base e a mesma chave privada. `release-v0.10.34/restore_release.py` reproduz o APK assinado exato a partir da base pública e do delta, sem chave.
- Suítes atuais: `v134_flight`, `v134_adventure`, `v134_readability`, `v134_startup`, `v134_visual`; manter também moeda, regressões antigas e `v133_cabins`.
- A prévia usa o conteúdo extraído do APK e toques automatizados. Não houve teste em telefone Android físico.
