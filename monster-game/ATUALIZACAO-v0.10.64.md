# 0.10.64 — colossos no abismo cósmico

O planeta de fundo e o devorador usavam proporções do enquadramento, então permaneciam perto da horda durante suas variações de altura. Ambos agora têm coordenadas verticais absolutas no mundo. A câmera passa por eles na subida e os reencontra na descida; o tamanho da tela não altera a altitude desses marcos. O deslocamento horizontal continua lento para dar distância.

O Universo Maligno ganhou duas regiões de cenário detalhado com nebulosas, ruínas cósmicas e cinturões de destroços. O planeta fica acima e à esquerda do devorador para preservar sua leitura. As diferentes velocidades horizontais, a luz ambiente e os veículos minúsculos ao redor ajudam a estabelecer a escala.

O devorador deixou de ser um recorte que desaparece depois da antiga janela de 6,4 segundos. É um marco persistente da região, com ciclo próprio de mordida. Seu enquadramento foi ampliado; um véu de poeira cobre os ombros e o corte inferior do busto. A presa continua separada e animada. Fragmentos, brilho na boca e uma onda de choque discreta acompanham a mordida, dentro da mesma camada distante.

Os grandes elementos da Atmosfera Sombria — leviatã, destroços de nave e olhos — também passam a ocupar regiões verticais próprias. As animações de voo e balanço são independentes da câmera. Os cenários e efeitos ficam atrás dos atores interativos e do HUD.

As três rotas físicas, a abertura persistente do esgoto, a serra, os impulsos, as capturas e os perigos do céu continuam funcionando sob as mesmas regras.

## Validação

- 153 verificações dos marcos cósmicos, recursos, cobertura do corte do busto e persistência, em três tamanhos de tela e várias alturas e distâncias.
- 1.800 verificações de regressão da abertura e do horizonte, sem falhas.
- Inicialização no Godot 4.5.1: 344 recursos, 55 classes e cena principal carregada.
- Prévia contínua de 52,53 s, 1.576 quadros a 30 fps, pico de 381,30 m e retorno à rua com 14 membros e 9 almas. Percurso, toques e eventos idênticos à prévia anterior.

Os encontros iniciais são preparados no laboratório de rotas; o voo usa toques pela interface normal. A gravação usa OpenGL Compatibility no Godot desktop. Teste em Android físico ainda pendente. Código de versão Android: **167**.

## Reproduzir

```bash
HORDA_VALIDATION_DIR=/tmp/horda-v164 godot --headless --path monster-game --script res://tests/v164_cosmic.gd
HORDA_VALIDATION_DIR=/tmp/horda-v164 godot --headless --path monster-game --script res://tests/v162_regression.gd
HORDA_VALIDATION_DIR=/tmp/horda-v164-frames godot --path monster-game --fixed-fps 30 --script res://tests/v164_preview.gd
```

Use Godot 4.5.1, importe os fontes e atualize `startup_integrity.json` antes de abrir o jogo. A gravação requer um display OpenGL. A origem das artes e os prompts estão em `assets/art/v164/SOURCE.md`.
