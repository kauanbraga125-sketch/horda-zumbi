# Retomar a Horda Zumbi — 0.10.35

Base confirmada: 0.10.34, commit `244789f6be414d8a8c48098c4913efad46733f98`. Leia `ESPACO-v0.10.35.md` e `VALIDACAO-v0.10.35.json`.

- Godot 4.5.1; Android ARM64, versão 0.10.35, código 138. Pacote `com.kauan.noitedahorda.reconstruida`, rótulo `Horda Espaco R35`.
- Certificado SHA-256 `a641a59f39561af0210f2f1cd246f58c5bfd9ab05462bf5b0635e626d681d15d`. Nunca publicar a chave, a senha ou o ZIP privado.
- APK `Horda-Zumbi-v0.10.35-TESTE-1M-ESPACO-VIVO-ARM64.apk`.
- Não copiar um `project.binary` antigo para a raiz do projeto. Esta configuração fica em `.godot/v135-project.binary`. Após editar ou importar, executar `tools/refresh_startup_integrity.py`.
- O cache continua com 55 classes. Os novos módulos usam `preload` e não têm `class_name`.
- `space_contacts.gd`: separação de sólidos independentemente da graça de dano. Priorizar a primeira interseção do trajeto, mesmo quando o final está dentro do obstáculo; não projetar para o lado oposto.
- A colisão corporal tem centro ligeiramente à frente do pé para corresponder à face dos sprites. A cabine usa um único casco visível e ignora a antiga formação escondida.
- `space_atmosphere.gd`: cenário em movimento, profundidade, borda suave da Terra, tráfego distante, propulsores e rastros. Elementos distantes não entram no plano de colisões.
- A subida entre camadas usa `BOOST_SECONDS`, conserva tempo jogável e poderes e desloca objetos para baixo. Não substituir por uma troca de rótulo e um pequeno balanço vertical.
- Mortes espaciais transportam posição, tamanho e acessórios no evento `hit`; `space_visual.gd` anima a saída. Não usar a rotina de caixão de chão nesse caso.
- Os sprites antigos de personagens e acessórios permanecem intactos. Original, prompt e preparação da mina nova ficam em `tools/art_sources/v135` e `tools/prepare_space_v135.py`.
- Suítes atuais: `v135_contacts`, `v135_flight`, `v135_adventure`, `v135_readability`, `v135_startup`, `v135_visual`, `v135_preview`. Preservar testes de moeda, cabines, transformações e regressões antigas.
- Em testes headless antigos de menus, não definir `HORDA_VALIDATION_DIR`: snapshots esperam um quadro renderizado e precisam do renderizador nativo quando solicitados.
- `tools/build_v135.py` usa o APK verificado da 0.10.34 e a identidade privada. `release-v0.10.35/restore_release.py` reproduz o APK já assinado sem precisar da chave.
- O backup privado contém fontes, artes originais, testes, APK e assinatura. `restaurar_importacoes.py` restaura offline as importações a partir do APK; `verificar_backup.py` confere os hashes.
- Não houve instalação ou teste em telefone Android físico nesta sessão.
