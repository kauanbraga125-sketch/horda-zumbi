# Horda Zumbi 0.10.9

Invocação da horda com gesto, névoa, espirais, aparição e aterrissagem. Veja as [notas](NOTAS-v0.10.9.md) e a [validação](VALIDACAO-v0.10.9.json). Abra `project.godot` no Godot 4.5.1, GL Compatibility.

## Sequência visual

`prepare_ritual.gd` coordena poses dos personagens e desenha anéis, símbolos, feixes, espirais, almas e ondas de aterrissagem. A duplicação usa 3,25 segundos; os demais efeitos usam até 2,55 segundos. As aparições têm pequenos atrasos por membro e mantêm a altura nativa. Os sprites e animações atuais de gesto, subida, queda, pouso e corrida são reaproveitados.

`prepare_mist.gdshader` produz névoa animada com ruído em três escalas e fluxo contínuo. Duas camadas delimitadas ao grupo posicionam a névoa atrás e à frente dos monstros; não há processamento da tela inteira. As camadas são criadas uma vez, reutilizadas e ocultadas ao sair da preparação, começar a partida ou terminar o efeito. O shader usa funções compatíveis com o renderizador GL Compatibility.

`prepare_effects.gd` mantém os efeitos específicos de cada bônus e a ordem das fases. `prepare_ui.gd` integra as poses, ecos, mistura de transformação, sons e retorno à corrida. A carta apresenta a ativação, e o efeito se desenvolve no chão e no corpo da horda. A câmera, o cenário contínuo e o chão plano seguem o layout aprovado.

As regras e o registro de ativação da [0.10.8](README-v0.10.8.md) permanecem. Nenhum encontro, moeda real ou progresso de missão é gerado pela cerimônia. Iniciar durante a apresentação transfere o bônus completo para a corrida e não cobra novamente.

## Testar

```bash
godot --headless --path monster-game --editor --import
python3 monster-game/tools/refresh_startup_integrity.py
for suite in v100_integration v101_integration v103_codex v104_integration v105_integration v107_integration v108_integration v109_integration v103_apk_runtime; do
  godot --headless --path monster-game --script "res://tests/${suite}.gd"
done
```

`v109_integration` verifica as quatro quantidades iniciais, início durante o efeito, saída e volta do mercado/menu, término e reutilização dos dois nós de névoa. `v109_visual_capture` aciona botões por coordenadas e captura sete fases para zumbi básico, horda de oito, Titã Mascarado e Mosca, mais início real e outros bônus. `v109_motion_capture` grava 96 quadros de dois exemplos a 12 quadros por segundo. Os scripts visuais usam `HORDA_VALIDATION_DIR`, OpenGL e uma tela disponível.

## Construir APK

```bash
godot --headless --path monster-game --export-pack Android /caminho/resources.zip
python3 monster-game/tools/build_v109.py \
  --base /caminho/Horda-Zumbi-v0.10.8.apk \
  --resources /caminho/resources.zip --source monster-game \
  --output /caminho/Horda-Zumbi-v0.10.9.apk \
  --signing-zip /caminho/privado/Assinatura.zip \
  --signer-jar /caminho/apksigner.jar
```

Importe e atualize a auditoria antes de exportar. O construtor também aceita um ZIP apenas com `project.binary` atualizado e manifestos JSON de arte; lê scripts, shaders, cenas e cache de classes do projeto. Preserva mídias importadas e bibliotecas nativas e regenera auditoria e índice com os bytes finais.

versionCode 109, versionName 0.10.9; pacote `com.kauan.noitedahorda.playtest091`, nome interno de salvamento `Horda Zumbi 0.9.1` e mesma assinatura. Chaves privadas permanecem fora do repositório. Validação no Godot/Linux e dos recursos do APK; Android físico não testado nesta sessão.
