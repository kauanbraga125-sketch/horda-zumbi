# Horda Zumbi 0.10.44 — descida contínua ao esgoto

A entrada anterior esticava um sprite de borda sobre os personagens, colocava a parede do poço acima do chão e deixava a cidade aparecer através do cenário subterrâneo. Ao terminar a descida, trocava toda a parede por outra imagem em um quadro.

## Nova passagem

- Uma entrada coberta usa o arco dos túneis da corrida e prepara visualmente a descida.
- O chão termina na mesma coordenada usada pela física; cada membro cai depois de cruzar essa borda.
- A cidade fica em uma camada opaca, recortada pela superfície que sobe enquanto a câmera desce. Não há mistura por transparência entre cidade e esgoto.
- O poço recebeu uma parede própria, sem pisos pintados, e uma peça de teto de pedra que encobre a junção com a galeria inundada. Essas peças ficam atrás dos personagens.
- A borda pequena usa a arte de buracos do terreno normal. Os quatro SVGs de transição anteriores foram removidos.
- A entrada dura 4,8 s, reduzindo a espera após o embarque. O último quadro da descida e o primeiro da navegação usam a mesma galeria.

Os personagens, cosméticos, captura, comandos de salto e abaixar, navegação e saída pela rampa continuam usando os sistemas existentes. As duas novas artes e seus prompts estão em `assets/art/v144/manifest.json`.

## Validação reproduzível

Use Godot 4.5.1, importe o projeto e execute `python3 tools/refresh_startup_integrity.py`.

- `tests/v140_sewer.gd`: lugares, membros, colisões, captura, comandos e retorno à corrida.
- `tests/v141_transitions.gd`: trajetórias, chão sólido, recorte e saída em 1280×720, 1800×810 e 960×720.
- `tests/v144_descent.gd`: imagens da camada da rua isolada, ausência de vazamento abaixo do chão e comparação de pixels na passagem da descida para a navegação.
- `tests/v144_preview.gd`: 360 quadros nativos, formando uma prévia de 12 s a 30 fps. Essa captura automatizada desativa os perigos após a entrada para permitir examinar a transição.

Os resultados desta revisão estão em `VALIDACAO-v0.10.44.json`. Não houve teste em um aparelho Android físico.
