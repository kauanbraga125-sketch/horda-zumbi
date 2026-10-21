# Mascarado — caminhada v0.1

Animação de caminhada lenta e pesada, em loop, para o Mascarado de Horda Zumbi. Ele anda ereto, com passos curtos, alternância de apoio e o facão baixo. Somente caminhada nesta versão.

O visual mantém o personagem do projeto: máscara creme com marcas vermelhas e tiras marrons, macacão azul escuro, luvas e botas marrons.

## Arquivos

- `mascarado_andando.png`: sprite sheet PNG RGBA com transparência real, oito quadros, quatro colunas por duas linhas. Ordem: esquerda para a direita, linha de cima antes da linha de baixo.
- `frames/`: oito PNG individuais em telas de tamanho idêntico, mantendo o espaço transparente e a posição de cada quadro.
- `mascarado_andando.tres`: SpriteFrames para Godot 4.5.1, animação `andando`, 7 quadros/s, loop ligado; duração aproximada de 1,14 s por ciclo.
- `preview.tscn`, `preview.gd` e `project.godot`: projeto de demonstração independente. Abra o projeto e execute para ver o ciclo.
- `animacao.json`: regiões, velocidade e âncora para a integração.
- `PROMPT.txt`: prompt final exato e modo de criação da arte.

## Usar no jogo

Copie a pasta para o projeto e use `mascarado_andando.tres` no campo Sprite Frames de um AnimatedSprite2D. Reproduza `andando`. O personagem aponta para a direita; `flip_h` permite inverter o sentido. O recurso usa caminho relativo para o PNG vizinho.

Use as dimensões completas dos quadros e uma âncora fixa na linha do chão, conforme `animacao.json`. Evite recortar o espaço transparente ou redimensionar cada pose separadamente, pois isso produz variação de escala e de posição durante o ciclo.

Este pacote de arte não contém mudanças na progressão, no inventário, nos saves ou no APK 0.10.3.

## Procedência e edição

Arte final criada com **builtin image_gen**, usando o Mascarado do projeto e um guia de caminhada renderizado no Godot a partir de suas peças originais. O guia definiu as fases e posições de apoio. O acabamento final unifica tecido, articulações e detalhes do personagem. O recorte dos quadros é mecânico, pelo Godot, sem alteração dos pixels da arte.

A sequência foi empacotada como versão inicial para revisão visual no tamanho de jogo. O fundo e a linha do chão da prévia não estão nos sprites.
