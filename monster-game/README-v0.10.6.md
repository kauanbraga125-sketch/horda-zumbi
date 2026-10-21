# Horda Zumbi 0.10.6

Correção do civil no tutorial Como jogar. Veja [notas](NOTAS-v0.10.6.md), [validação do APK](VALIDACAO-v0.10.6.json) e [documentação da base 0.10.5](README-v0.10.5.md).

Abra `project.godot` no Godot 4.5.1 com GL Compatibility. O clipe `corrida` de `HordeCivilSprite` é compartilhado pela demonstração e pelo jogo, sem novas artes nem mudanças no layout.

Para reconstruir, importe o projeto e atualize a auditoria conforme a documentação da 0.10.5. Exporte os recursos com `godot --headless --path monster-game --export-pack Android /caminho/resources.zip`. Use `tools/build_v106.py`, a base `Horda-Zumbi-v0.10.5.apk`, o ZIP de recursos, a chave privada existente e o `apksigner.jar`, com os mesmos parâmetros do construtor da versão anterior. O construtor também aceita um ZIP contendo somente os recursos alterados; scripts, cenas e cache de classes são lidos do projeto.

versionCode 106; pacote e nome interno de salvamento preservados. As chaves ficam fora do repositório.
