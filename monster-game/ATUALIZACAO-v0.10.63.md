# 0.10.63 — serra distante e gigante sobre o relevo

A projeção vertical de 0,018 da versão anterior mantinha o gigante quase no mesmo ponto da tela enquanto a horda subia. Agora ele compartilha a altitude do mundo e a projeção da montanha onde caminha. Quando a câmera sobe, o gigante e a serra ficam para baixo e deixam o enquadramento. Na descida, a mesma região volta à vista.

O fundo ganhou uma serra pintada em violeta e lavanda. Três camadas usam deslocamentos horizontais de 0,008, 0,015 e 0,025; as duas cadeias posteriores têm projeções verticais de 0,42 e 0,68. A cadeia que sustenta o gigante usa projeção vertical completa, 1,0. O deslocamento horizontal lento mantém a região alcançável visualmente no retorno.

Os pés do gigante seguem o contorno real da arte, medido pelo alfa e interpolado por coluna. A altura só varia com o relevo por onde ele caminha. Sombra de contato, névoa, contraste suave e transparência gradual na base das montanhas integram o monstro ao cenário. Nenhuma montanha cria piso ou obstáculo para a horda.

A correção da abertura do esgoto e as três rotas físicas permanecem ativas. Os impulsos, capturas, obstáculos e demais regras do céu não foram alterados.

## Verificação

- 223 verificações do cenário: pés sobre a silhueta pintada, altitude independente da câmera, saída por baixo em alturas maiores e visibilidade da região na descida, em três tamanhos de tela.
- 1.800 verificações de regressão do horizonte e da abertura, sem falhas. A expectativa antiga que tolerava o gigante acompanhar a câmera foi corrigida.
- Inicialização no Godot 4.5.1: 341 recursos e 55 classes conferidos, cena principal carregada.
- Gameplay contínua de 52,53 s, 1.576 quadros a 30 fps, pico de 381,30 m, passagem pelo Universo Maligno e volta à rua com 14 membros e 9 almas. Os toques, eventos e percurso são idênticos à gravação anterior.

A gravação usa toques programados pela interface normal. O encontro inicial é preparado no laboratório; altitude, cargas, velocidade, colisões e perigos permanecem sob as regras do jogo durante o voo. Renderização OpenGL Compatibility em desktop; teste em aparelho Android físico ainda pendente. Código de versão Android: **166**.

## Reproduzir

Use Godot **4.5.1 stable**. Após importar e atualizar a auditoria:

```bash
HORDA_VALIDATION_DIR=/tmp/horda-v163 godot --headless --path monster-game --script res://tests/v163_landscape.gd
HORDA_VALIDATION_DIR=/tmp/horda-v163 godot --headless --path monster-game --script res://tests/v162_regression.gd
HORDA_VALIDATION_DIR=/tmp/horda-v163-frames godot --path monster-game --fixed-fps 30 --script res://tests/v163_preview.gd
```

A prévia requer um display com OpenGL. A origem da arte e sua direção visual estão em `assets/art/v163/SOURCE.md`. O relatório de validação registra os toques e o percurso.
