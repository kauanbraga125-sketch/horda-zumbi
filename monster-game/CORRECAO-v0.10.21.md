# Horda Zumbi 0.10.21 — feiticeiro, elétrico e gorro

O Kauan reprovou o encaixe do feiticeiro e do capuz elétrico da 0.10.20 e apontou a abertura vazia do Gorro da Madrugada. Esta revisão altera somente o visual desses três acessórios; as aprovações anteriores continuam preservadas.

## Alterações

- **Feiticeiro, item 08:** novo desenho com copa menos volumosa, aba mais estreita e borda curva. O apoio usa dois contatos medidos na própria arte e nos eixos do crânio, mantendo escala uniforme nos dois lados.
- **Elétrico, item 09:** o personagem inteiro passa a ser desenhado por baixo do acessório. O recorte antigo do cabelo e da cabeça não é mais usado. A textura original do capuz é preservada; a copa ganha cobertura sobre o crânio por uma malha UV, as orelhas conservam suas proporções, o forro fica atrás do corpo e a borda que atravessava a testa foi removida da camada frontal. Nenhum PNG do personagem ou do capuz foi modificado.
- **Gorro, item 10:** novo desenho com punho de tecido fechado, sem cavidade escura. O apoio acompanha a testa e a parte de trás do crânio com escala uniforme. O personagem também permanece inteiro por baixo.

O redesenho do gorro e do feiticeiro usou a ferramenta de imagens integrada. O redesenho do capuz foi bloqueado pela ferramenta; sua correção final usa a arte existente e a geometria nativa do jogo.

## Artes e prompts salvos

Os caminhos abaixo são relativos à pasta monster-game do projeto e estão incluídos no backup:

| Peça | Sprite usado pelo jogo | Original gerado | Prompt completo |
| --- | --- | --- | --- |
| Feiticeiro | assets/art/cosmetics_v121/sorcerer.png, 512 × 343 | tools/art_sources/v121/sorcerer-generated.png | tools/art_sources/v121/sorcerer-prompt.txt |
| Gorro | assets/art/cosmetics_v121/beanie.png, 512 × 383 | tools/art_sources/v121/beanie-generated.png | tools/art_sources/v121/beanie-prompt.txt |

As duas novas texturas compiladas usam WebP lossless em ambos os APKs. Os pixels RGBA carregados pelo motor conferem com os PNGs de uso. As artes e os prompts das revisões anteriores continuam separados.

## Verificações

- 1.081 verificações dos três itens, sem falhas. Os 263 conjuntos de medidas e malhas da 0.10.20 permanecem byte a byte idênticos.
- 588 renderizações dos três itens nas nove animações e nos dois lados, mais 108 renderizações do capuz com capa, cachecol e outros acessórios.
- 8.480 renderizações dos outros 32 itens com pixels idênticos aos da 0.10.20.
- Comparação de transparência com um renderizador independente do personagem original, incluindo cabelo e contorno: 2.474.985 amostras, nenhuma com perda de cobertura acima da tolerância de 3 níveis em 255. O recorte anterior apresentou 307.165 amostras com perda de cobertura na mesma comparação.
- 268.758 amostras do interior opaco do rosto e 372.594 do corpo preservadas; maior desvio de cor do rosto de 2 níveis em 255, dentro da tolerância de rasterização de 8. Isso não afirma identidade das bordas translúcidas, que podem se misturar com o tecido atrás delas.
- Bancada executada a partir do APK final: 5.504 verificações, 35 itens visitados, 4.534 amostras de animação e dados do jogador preservados.
- Coleção: 7.170 verificações. Teste geral e regressões de sobreviventes: 64 verificações principais, sem falhas.
- Inicialização do APK final: 109 arquivos e 55 classes verificados, versão 0.10.21.
- Assinatura, índice e ZIP verificados. resources.arsc permanece sem compressão e alinhado a 4 bytes. Os 238 arquivos antigos de mídia e bibliotecas permanecem idênticos em cada perfil.
- O construtor também confere se os scripts das fontes correspondem aos scripts enviados no APK; configuração de exportação e ferramentas de recuperação foram atualizadas para esta versão.

Aprovação visual do Kauan e instalação em aparelho físico ainda pendentes. Testar em Configurações → Desenvolvedor → Bancada de itens → 08, 09 e 10.

## APKs e recuperação

- Horda-Zumbi-v0.10.21-ARM64.apk: 90.197.187 bytes (90,20 MB). SHA-256: 58450bb84731f647e00a243dee046dfce13ab8dd5ebbc61839cd9bded1d55e3c.
- Horda-Zumbi-v0.10.21-Sem-Perdas-ARM64.apk: 185.457.859 bytes (185,46 MB). SHA-256: d0a7df0aafb30b4a2bb58076c9349908fa3faf1f2582fdb5a5bf72457ad7bf6f.

Os dois perfis mantêm o pacote e a assinatura da versão anterior. O backup privado reúne o delta completo das fontes desde a base pública, artes, prompts, testes, configuração compilada, sete texturas adicionais acumuladas e a assinatura. A restauração exige o commit-base público indicado no manifesto ou uma cópia local dessa base. A pasta de assinatura privada não deve ser publicada no GitHub. Os APKs e o backup da 0.10.20 continuam separados.
