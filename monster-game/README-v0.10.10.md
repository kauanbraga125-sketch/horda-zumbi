# Horda Zumbi 0.10.10

A Noite Terminou mantém a tabela aprovada, com 100 espaços em dez linhas e dez colunas, novas almas ilustradas, voos em curva, rastros, luz e reação no encaixe. O frasco é maior e a essência das missões é apresentada enchendo o líquido nesta tela.

## Progresso e apresentação

`results_ui.gd` controla a tabela, as chegadas, o som e a apresentação de essência. Ao completar 100 almas, a tabela fica cheia durante a reação, limpa e recebe a sobra. Não há nós por alma: uma busca binária e uma janela de voos limitam o trabalho aos elementos visíveis. A legenda LÁPIDES GANHAS conta unidades, mantendo a economia existente de duas lápides por conjunto de 100 almas. A navegação conta apenas lápides disponíveis.

`HordeProgress` continua creditando e salvando missões durante a corrida. `game.gd` retém os relatórios e suas recompensas individuais; a primeira entrada nos resultados os apresenta em ordem a partir do valor anterior. A fila visual não é consumida durante a corrida. Entrar, desenhar, sair ou voltar não paga nem cobra nada. Sair conclui apenas os contadores e para o som do líquido.

A máquina, suas 12 cores, 500 misturas e objetos flutuantes existentes continuam. O líquido usa o shader contínuo com ondas e bolhas; o fluxo de essência acompanha o enchimento. Um nível completo provoca reação, moedas em curva até a carteira e início da próxima mistura com a sobra. O contador da carteira acompanha os ganhos já salvos. Vários níveis são apresentados em ordem.

## Arte e áudio

`assets/art/results_v110/souls.png` é a folha RGBA original criada com **imagegen integrado**, baseada na referência aprovada. Seus pixels não foram alterados. Seis regiões de AtlasTexture são carregadas; o ciclo usa cinco poses com ida e volta e altura constante. A pose que vira o rosto foi excluída do ciclo. Manifesto e recortes ficam junto da imagem.

`tools/prepare_v110_audio.py` prepara cinco efeitos dos sons atuais: alma, líquido, frasco cheio, moeda e prêmio. Remove silêncio da entrada, prepara envelopes e a passagem contínua do líquido. Originais preservados; fontes, hashes e tratamento no manifesto. PCM mono 16 bits a 32 kHz carrega diretamente no APK, sem nova importação. Os efeitos respeitam o volume e a opção de som.

Som, contador e encaixe de cada alma seguem o mesmo instante de chegada. O líquido soa apenas nas fases de enchimento; reação, prêmio e moedas seguem os eventos visuais. A música reduz de volume durante os momentos principais.

## Abrir e testar

Godot 4.5.1, GL Compatibility. Importe um checkout novo antes de testar.

```bash
godot --headless --path monster-game --editor --import
python3 monster-game/tools/refresh_startup_integrity.py
for suite in v100_integration v101_integration v103_codex v104_integration v105_integration v107_integration v108_integration v109_integration v110_integration v103_apk_runtime; do
  godot --headless --path monster-game --script "res://tests/${suite}.gd"
done
```

`v110_integration` cobre missão real, recompensa salva antes da animação, chegada com som, enchimento, vários níveis, interrupção, retorno, salvamento, múltiplos de 100, 1.200 almas, nível 500, contagem de lápides e quatro tamanhos. `v110_visual_capture` toca os botões por coordenadas e captura as fases, a navegação e a preparação. `v110_motion_capture` gera 156 quadros com os instantes reais de emissão dos sons.

## APK

Pode-se exportar pelo Godot com os templates Android e a chave privada original. A alternativa abaixo preserva a base Android e suas mídias importadas:

```bash
godot --headless --path monster-game --script res://tools/save_runtime_config.gd -- /absoluto/project.binary
# Crie recursos.zip com project.binary e os manifestos JSON anteriores de arte.
python3 monster-game/tools/build_v110.py \
  --base /absoluto/Horda-Zumbi-v0.10.9.apk \
  --resources /absoluto/recursos.zip --source monster-game \
  --output /absoluto/Horda-Zumbi-v0.10.10.apk \
  --signing-zip /absoluto/privado/Assinatura.zip \
  --signer-jar /absoluto/apksigner.jar
```

O construtor inclui scripts, shaders, cenas, novos PNG/PCM e manifestos, regenera auditoria e índice, preserva as bibliotecas nativas e verifica a assinatura. Chaves privadas não estão no repositório.

versionCode 110, versionName 0.10.10; pacote `com.kauan.noitedahorda.playtest091`; nome interno `Horda Zumbi 0.9.1` e mesma assinatura. Instale sobre a anterior para preservar o salvamento. Sem moedas ou estoque de teste. A invocação e o uso único dos bônus da 0.10.9 continuam.

Validação em Godot/Linux e nos arquivos do APK; capturas reais OpenGL em 1280×720 e 1600×720. Sem teste em Android físico. A prévia de 13 segundos usa quadros do jogo e uma mistura offline dos sons a partir dos eventos registrados pelo motor; não é uma gravação do áudio de um Android.
