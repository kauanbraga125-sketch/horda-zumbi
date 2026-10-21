# Horda Zumbi 0.10.8

Animações por bônus e ativação definitiva na preparação. Veja as [notas](NOTAS-v0.10.8.md) e a [validação do APK](VALIDACAO-v0.10.8.json). Abra `project.godot` no Godot 4.5.1 com GL Compatibility.

## Uso e persistência

`HordeMeta.activate_preparation` valida o objeto, estoque, uso anterior e exclusividade de transformação. Decrementa uma unidade e grava o ID em `data.prepared_items`. `prepare_ui.activate` salva ambos antes de disparar a animação; falha de escrita restaura o estado anterior. Uma ativação existente é válida mesmo quando seu estoque restante é zero.

A preparação e o mercado consultam o registro salvo. Reabrir a preparação mantém os bônus e limpa somente os efeitos transitórios. Migração de saves antigos acrescenta o campo vazio; validação remove IDs desconhecidos, duplicados e transformações conflitantes sem gastar estoque.

`start_run` transfere o registro para `runner.configure_items` e persiste sua remoção antes de iniciar. Não existe uma segunda cobrança ao começar. Se essa escrita falhar, o registro é restaurado e a partida não começa. A antiga seleção reversível e seu consumo no início foram removidos.

## Animações

`prepare_effects.gd` desenha trajetórias da carta até a horda, ondas, almas, moedas decorativas, relógio, faíscas e rastros usando os assets atuais. `prepare_ui.gd` integra aparição dos novos membros, mistura entre zumbi e transformação, bolha pulsante e brilho nos personagens. Efeitos duram até 1,65 segundo e não entram nas listas de entidades nem na telemetria da partida. O brilho ambiente dos bônus guardados permanece discreto.

Os dez efeitos são distintos. A prévia de duplicação acompanha as melhorias de horda; o enquadramento acomoda o Titã Mascarado. A câmera e o cenário da preparação seguem a implementação da [0.10.7](README-v0.10.7.md).

## Testar

```bash
godot --headless --path monster-game --editor --import
python3 monster-game/tools/refresh_startup_integrity.py
for suite in v100_integration v101_integration v103_codex v104_integration v105_integration v107_integration v108_integration v103_apk_runtime; do
  godot --headless --path monster-game --script "res://tests/${suite}.gd"
done
```

As regressões anteriores foram atualizadas para a regra de uso definitivo. `v108_integration` testa todos os objetos, toques repetidos, estoque zero após uso, retomada por JSON salvo, transferência para a corrida e falhas de escrita. `v108_visual_capture` aciona as cartas por coordenadas e captura cinco momentos de cada efeito, combinações e início real. `v108_motion_capture` grava 360 quadros dos dez efeitos a 18 quadros por segundo. Defina `HORDA_VALIDATION_DIR` e execute os scripts visuais com OpenGL e uma tela disponível.

## Construir APK

Depois de importar e atualizar a auditoria:

```bash
godot --headless --path monster-game --export-pack Android /caminho/resources.zip
python3 monster-game/tools/build_v108.py \
  --base /caminho/Horda-Zumbi-v0.10.7.apk \
  --resources /caminho/resources.zip --source monster-game \
  --output /caminho/Horda-Zumbi-v0.10.8.apk \
  --signing-zip /caminho/privado/Assinatura.zip \
  --signer-jar /caminho/apksigner.jar
```

Também é aceito um ZIP contendo apenas `project.binary` atualizado e os manifestos JSON de arte. Scripts, cenas e cache de classes são lidos do projeto. O construtor preserva as bibliotecas nativas e mídias importadas, regenera auditoria e índice esparso e verifica a assinatura.

versionCode 108, versionName 0.10.8; pacote `com.kauan.noitedahorda.playtest091`; nome interno de salvamento `Horda Zumbi 0.9.1`. Mesma assinatura das versões anteriores, com chaves privadas fora do repositório. Validação no Godot/Linux e dos recursos empacotados; Android físico não testado nesta sessão.
