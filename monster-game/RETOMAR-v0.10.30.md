# Retomar o projeto 0.10.30

A implementação de Abdução Maldita está concluída e o APK assinado foi reconstruído e validado após a desconexão. Leia CORRECAO-v0.10.30.md e VALIDACAO-v0.10.30.json para o comportamento e as evidências atuais.

APK: 117347692 bytes; SHA-256 b50e9ef42b4e96ead84eb0d91e320e5dbb0129651ce1a345b2c79ad9d5c4d1c5. Pacote com.kauan.noitedahorda.reconstruida, código Android 133. Certificado a641a59f39561af0210f2f1cd246f58c5bfd9ab05462bf5b0635e626d681d15d. Mesma identidade da 0.10.29.

## Entrega reproduzível

release-v0.10.30/restore_release.py reconstrói os bytes assinados a partir do APK público 0.10.29 e do pequeno delta verificado desta versão. Não precisa da chave privada. A rotina verifica também todos os fontes públicos e pode empacotá-los. O workflow .github/workflows/horda-v01030.yml confere a assinatura e publica o APK e o ZIP público no release v0.10.30.

O backup privado Horda-Zumbi-v0.10.30-Recuperacao-Completa.zip contém projeto, importações, artes originais, testes, APK e identidade de assinatura. Nunca publique assinatura_privada, senha ou esse backup privado no GitHub.

## Próxima edição

1. Abra projeto/monster-game/project.godot no Godot 4.5.1. Não deixe project.binary antigo na raiz: esse arquivo sobrepõe project.godot. A configuração binária atual do APK fica em .godot/v130-project.binary no backup completo.
2. Após editar ou reimportar, regenere startup_integrity.json com tools/refresh_startup_integrity.py. O APK atual contém 176 arquivos auditados e 55 classes.
3. Exporte a configuração nativa com tools/save_runtime_config.gd antes de compilar. Use tools/build_v130.py como referência para preservar identidade, recursos Android alinhados e mídias anteriores.
4. Valide os arquivos extraídos do APK assinado com tests/verify_packaged_boot.gd, tests/v130_space.gd, tests/v130_visual.gd e tests/v129_currency.gd. Use -- --space-test para não alterar os dados do jogador.
5. Atualize versão e código na próxima entrega. Preserve APK e recuperação completa em mais de um local.

Não houve teste em Android físico. O laboratório espacial está em Configurações → Desenvolvedor. A configuração de testes oferece saldo e primeira cápsula cedo; desative as duas flags testing antes do lançamento público.
