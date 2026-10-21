# Horda Zumbi 0.10.5

Abra `monster-game/project.godot` no Godot 4.5.1 stable com GL Compatibility. As [notas](NOTAS-v0.10.5.md) descrevem o comportamento e a [validação](VALIDACAO-v0.10.5.json) identifica o APK entregue.

## Integração

`mission_catalog.gd` carrega 90 templates em `assets/art/experiment_v105/missions.json`. Três slots persistentes têm chaves por emissão. A migração deriva missões de templates confiáveis e preserva slots antigos incompletos. A substituição espera 1,9 segundo após concluir; o histórico evita famílias repetidas e a elegibilidade considera poderes/áreas do jogador. Objetivos de uma partida emitidos durante uma corrida esperam a próxima partida, evitando reaproveitar um pico antigo. Objetivos acumulativos usam a diferença entre amostras da corrida.

A telemetria distingue soldados de policiais, civis de passageiros, grupos a pé, veículos específicos, capturas por criatura, moedas físicas em Frenesi e sequências sem perdas. Duplicadores atribuem exatamente o valor coletado; moedas concedidas por veículos/bônus não contam como coleta física nas condições específicas.

`experiment_vessel.gd`, `experiment_liquid.gdshader` e `experiment_specimen.gdshader` desenham líquido em qualquer porcentagem, ondas e espuma, bolhas subindo/estourando, vidro e objetos flutuantes com movimento. `experiment_art.gd` combina 12 paletas com pares de 15 objetos, gerando 500 misturas distintas e determinísticas até o nível máximo. O 16º sprite é o frasco de essência dos cartões.

`experiment_presentation.gd` anima uma fila de preenchimento, reação, recompensa e próxima mistura. `HordeProgress.ritual` grava as moedas/olhos e o excedente antes da animação. O saldo visual desconta somente os créditos ainda em voo. Trocar de tela ou reiniciar não recredita a recompensa. O relatório por nível inclui só moedas efetivamente creditadas, respeitando o limite da carteira. Recompensas existentes foram mantidas; não há novos monstros nem novos prêmios por marcos de nível.

## Importar e testar

```bash
godot --headless --path monster-game --editor --import
python3 monster-game/tools/refresh_startup_integrity.py
for suite in v100_integration v101_integration v103_codex v103_apk_runtime v104_integration v105_integration; do
  godot --headless --path monster-game --script "res://tests/${suite}.gd"
done
```

`tests/v105_visual_capture.gd` captura a tela, 12 cores e etapas da recompensa no renderizador real. Defina `HORDA_VALIDATION_DIR` e execute com OpenGL e uma tela disponível. `tests/v104_visual_capture.gd` continua disponível para as ações do Mascarado e perfil.

## Reconstruir APK

```bash
godot --headless --path monster-game --export-pack Android /caminho/resources.zip
python3 monster-game/tools/build_v105.py \
  --base /caminho/Horda-Zumbi-v0.10.4.apk \
  --resources /caminho/resources.zip --source monster-game \
  --output /caminho/Horda-Zumbi-v0.10.5.apk \
  --signing-zip /caminho/privado/Assinatura.zip \
  --signer-jar /caminho/apksigner.jar
```

O construtor preserva bibliotecas nativas e recursos importados anteriores, sobrepõe fontes e novos assets, mantém scripts em texto e regenera o índice esparso e a auditoria com os bytes finais. As artes-fonte e retângulos de recorte estão em `art-source/v0.10.5`; `tools/prepare_v105_art.gd` produz os PNGs de runtime sem redesenhar a arte.

versionCode 105; pacote `com.kauan.noitedahorda.playtest091`; nome interno `Horda Zumbi 0.9.1` preservado por compatibilidade dos salvamentos. Mesma assinatura das edições de testes anteriores. Validação em Godot/Linux e por inspeção estrutural/criptográfica; instalação, toques e desempenho em Android físico não foram testados nesta sessão.
