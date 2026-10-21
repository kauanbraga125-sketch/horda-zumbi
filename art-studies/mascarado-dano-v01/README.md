# Mascarado — reação ao dano v0.1

Reação curta a um impacto vindo pela frente: o Mascarado recua, flexiona os joelhos, protege o peito e retoma a postura. A máscara, o macacão azul, as luvas e as botas seguem a caminhada aprovada. O facão permanece baixo.

## Conteúdo

- `mascarado_dano.png`: sprite sheet RGBA transparente, 4 colunas × 2 linhas, 8 quadros.
- `frames/`: 8 PNG individuais, todos com 444 × 444 px, registrados pela linha de contato dos pés.
- `mascarado_dano.tres`: SpriteFrames para Godot 4.5.1; animação `dano`, sem loop, com duração total de 0,64 s.
- `dano_flash.gdshader`: brilho de impacto opcional, separado da pintura dos sprites.
- `preview.tscn`, `preview.gd`, `project.godot`: demonstração independente; toque ou espaço repete o impacto. A prévia também se repete automaticamente com uma pausa.
- `animacao.json`: ordem dos quadros, tempos e âncora.
- `PROMPT.txt`: prompt final exato, criado com builtin image_gen.

## Integrar

Copie esta pasta para o projeto, carregue `mascarado_dano.tres` em um AnimatedSprite2D e execute `play("dano")` quando houver um impacto válido. Ao terminar, o controlador pode retomar a animação de caminhada. A animação de dano não deve ficar em loop nem reiniciar continuamente a cada quadro de uma colisão.

Os PNG mantêm suas cores originais. O shader permite um brilho breve por `hit_flash`, de 0 a 1. A cor e o fundo da prévia são apenas da demonstração. Nenhum sangue ou alteração permanente da máscara foi acrescentado.

Use o mesmo tamanho de tela e a mesma âncora da caminhada: `(222, 432)` em quadros de 444 px. As poses foram deslocadas por pixels inteiros para alinhar as solas, sem redimensionamento individual.

O último quadro reutiliza a postura inicial para terminar sem uma troca de tamanho ou posição.

Este é um pacote de arte e animação independente. Não modifica o APK 0.10.3 nem os dados do jogador.

## Procedência

Arte gerada com builtin image_gen a partir do sprite de caminhada aprovado pelo usuário. Recorte e montagem dos quadros pelo Godot, com registro mecânico de posição e preservação dos pixels. A imagem recebida do gerador está em `fonte_mascarado_dano.png`; a referência aprovada está em `referencias/`.
