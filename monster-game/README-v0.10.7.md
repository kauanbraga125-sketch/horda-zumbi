# Horda Zumbi 0.10.7

Preparar a Horda agora usa o cenário da partida em movimento e a câmera um pouco mais próxima. Veja as [notas](NOTAS-v0.10.7.md) e a [validação do APK](VALIDACAO-v0.10.7.json). As animações do Mascarado, tutorial atualizado, perfil, missões e experimento das versões anteriores continuam incluídos.

Abra `project.godot` no Godot 4.5.1 com GL Compatibility. O nome interno `Horda Zumbi 0.9.1` é intencional: preserva a pasta de salvamento.

## Preparação

`scripts/prepare_ui.gd` compartilha os renderizadores de cenário, chão e personagens da partida. Mantém um `HordeRun` separado apenas para parâmetros de desenho: nunca chama `start`, `advance` ou o gerador de encontros. O chão tem um único segmento plano infinito. O deslocamento visual aumenta a 305 unidades por segundo, com as velocidades de paralaxe originais. Nenhum civil, veículo, moeda, buraco, bomba ou túnel aparece antes de Começar.

A câmera usa a âncora da gameplay e zoom 12% maior na preparação. O Titã Mascarado recebe enquadramento suficiente para sua cabeça não ficar sob as cartas. A câmera da partida mantém suas regras de enquadramento.

Os dez objetos existentes ficam em duas páginas de cinco cartas, incluindo os sem estoque. Seleção usa os IDs e as quantidades reais; não compra nem consome automaticamente. Horda em dobro atualiza a contagem e o grupo exibido. Os poderes Mosca/Mascarado continuam exclusivos entre si. Voltar do mercado mantém as escolhas e a página. Somente Começar chama o consumo de inventário já existente e inicia uma partida nova.

## Testar

Após importar o projeto, atualize a auditoria:

```bash
godot --headless --path monster-game --editor --import
python3 monster-game/tools/refresh_startup_integrity.py
for suite in v100_integration v101_integration v103_codex v104_integration v105_integration v107_integration v103_apk_runtime; do
  godot --headless --path monster-game --script "res://tests/${suite}.gd"
done
```

`tests/v107_integration.gd` verifica isolamento da prévia, dez minutos de espera, terreno contínuo, inventário, navegação, câmera, início real e layout em quatro larguras. `tests/v107_visual_capture.gd` usa o renderizador OpenGL, captura os dois estados de estoque, seleção, poderes, Titã Mascarado, horda melhorada, mercado e início da partida, acionando os botões por suas áreas de toque. Defina `HORDA_VALIDATION_DIR` antes de executar esse script com uma tela disponível.

## Reconstruir APK

Depois da importação e da atualização da auditoria:

```bash
godot --headless --path monster-game --export-pack Android /caminho/resources.zip
python3 monster-game/tools/build_v107.py \
  --base /caminho/Horda-Zumbi-v0.10.6.apk \
  --resources /caminho/resources.zip --source monster-game \
  --output /caminho/Horda-Zumbi-v0.10.7.apk \
  --signing-zip /caminho/privado/Assinatura.zip \
  --signer-jar /caminho/apksigner.jar
```

O construtor também aceita um ZIP só com `project.binary` atualizado e os manifestos JSON de arte: scripts, cenas e cache de classes são lidos do projeto. Preserva os recursos importados e as quatro bibliotecas nativas da base, regenera a auditoria e o índice esparso com os bytes finais e verifica a assinatura. A chave privada não está no repositório.

versionCode 107, versionName 0.10.7, pacote `com.kauan.noitedahorda.playtest091` e mesma assinatura das edições de testes anteriores. Instale sobre o APK anterior para manter o progresso. Validação no Godot/Linux e dos recursos extraídos do APK; não houve teste em Android físico nesta sessão.
