# Abrir e atualizar a versão 0.10.3

Esta pasta contém o projeto completo e editável do Horda Zumbi, incluindo os PNG, os áudios e as fontes. Use **Godot 4.5.1 stable**, com GL Compatibility. Abra `project.godot`.

Após a primeira importação, ou depois de alterar scripts, atualize a auditoria de inicialização:

```bash
godot --headless --path . --editor --import
python3 tools/refresh_startup_integrity.py
godot --path .
```

O cache `.godot/` é gerado pelo editor e não faz parte das fontes. Os arquivos `.import` e as licenças acompanham os recursos originais. A auditoria detecta arquivos de inicialização incompletos; ela precisa ser atualizada após alterações deliberadas.

## APK e progresso

O APK oficial está na Release `v0.10.3` do repositório `kauanbraga125-sketch/horda-zumbi`. Instale sobre a 0.10.2, sem desinstalar nem limpar os dados. O pacote Android continua sendo `com.kauan.noitedahorda.playtest091`, e a chave de assinatura é a original.

O nome interno `Horda Zumbi 0.9.1` em `project.godot` é intencional: ele identifica a pasta de dados existente. A versão exibida e a versão Android são 0.10.3. Não altere o pacote, o nome interno nem a chave para uma atualização compatível.

## Construir uma atualização com a base preservada

O método usado nesta entrega preserva as bibliotecas nativas e os recursos de jogo importados da 0.10.2. Exporta os novos recursos e substitui os scripts em texto, regenerando o índice do APK e a auditoria com os tamanhos finais.

```bash
godot --headless --path . --export-pack Android /caminho/absoluto/resources.zip
python3 tools/build_v103.py --base /caminho/Horda-Zumbi-v0.10.2.apk \
  --resources /caminho/resources.zip --source . \
  --output /caminho/Horda-Zumbi-v0.10.3.apk \
  --signing-zip /caminho/privado/Assinatura.zip \
  --signer-jar /caminho/apksigner.jar
```

A chave privada não está no repositório e nunca deve ser incluída nas fontes. A base original 0.10.2 pode ser recuperada pela branch `backup/v0.10.2-recuperada-20261020`, seguindo seu README.

## Validação

```bash
godot --headless --path . --script res://tests/v100_integration.gd
godot --headless --path . --script res://tests/v101_integration.gd
godot --headless --path . --script res://tests/v103_codex.gd
godot --headless --path . --script res://tests/v103_apk_runtime.gd
```

As capturas de tela e a prévia das animações foram renderizadas no próprio Godot. Consulte `NOTAS-v0.10.3.md` para as mudanças e os limites da validação. As artes do livro e sua direção estão em `assets/art/codex_v103/`.
