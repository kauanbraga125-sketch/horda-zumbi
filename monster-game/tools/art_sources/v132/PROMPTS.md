# Artes originais — aventura 0.10.32

Geradas com a ferramenta integrada de imagens, usando a direção visual cartoon pintada do projeto: contornos escuros, sombras roxas, metal envelhecido, ouro e luzes ciano/menta. Não foram extraídos sprites de filmes ou jogos. Fontes PNG mantidas nesta pasta, com atlas transparentes separados em células 256 × 256. Os originais não devem ser substituídos pelos atlas.

## fleet-generated.png

Atlas transparente 4 × 4. Ônibus de excursão orbital dourado com passageiros assustados, estado intacto e danificado; cargueiro de mineração azul, intacto e danificado; disco de invasão verde e roxo, intacto e danificado; caça de sucata com turbinas vermelhas, intacto e danificado; fragata fantasma com velas escuras e luz ciano, intacta e danificada; drone de reparo com braços fechados e abertos; cápsula de simbionte; gerador de escudo orbital; combustível; núcleo de impulso. Objetos inteiros, expressivos, leitura lateral, sem texto.

## helpers-generated.png

Atlas transparente 4 × 4. Primeira linha: quatro quadros de uma única criatura alada original com chapéu e casaco esfarrapado, levando um civil de casaco azul pelo tecido na boca, sem ferimentos. Segunda linha: soltar o civil e prosseguir voando. Terceira linha: quatro quadros de espectro protetor de capuz, crânio creme, olhos ciano, mãos estendidas e névoa violeta. Quarta linha: quatro quadros de companheiro alienígena roxo de carapaça alongada, cauda e luz verde, crouch/salto/ataque/retorno.

## civil-generated.png

O PNG de ajudantes foi fornecido como referência. Atlas 4 × 4 apenas do mesmo civil de cabelo castanho, casaco azul, calça e botas marrons. Linha 1: quatro quadros de queda após ser solto, de inclinado para ereto. Linha 2: pouso e corrida assustada. Linha 3: reação à captura e brilho mágico menta. Linha 4: pendurado pelo tecido do casaco, sem desenhar o monstro. Um corpo por célula, mesma identidade e escala por sequência.

## Preparação e registro

`tools/prepare_adventure_v132.py` identifica os dezesseis corpos principais de cada fonte, preserva as bordas e elimina vazamento de células vizinhas. A criatura usa registro pelo rosto nas sequências de voo, para evitar saltos de posição ao bater as asas. As sequências compartilham escala. O civil lançado é uma entidade real do jogo, com atlas próprio; a saída do ajudante usa um quadro sem civil embutido, impedindo duplicação visual.

`assets/art/adventure_v132/manifest.json` preserva caixas de origem, escala, posição de cada célula e SHA-256. O empacotamento valida os PNGs depois de gravar. Sons novos são procedurais e não usam amostras comerciais.
