# Horda Zumbi 0.10.22 — tricórnio e óculos

O Kauan apontou problemas no Tricórnio Pirata, nos Óculos Cibernéticos e nos Óculos a Vapor. O tricórnio mostrava uma cavidade escura sob a aba; os óculos ficavam grandes e inclinados de forma pouco natural, com hastes sobrepostas ao rosto e às orelhas.

## Alterações

- **Tricórnio Pirata, item 11:** redesenhado com couro escuro, acabamento dourado, três cantos dobrados e ossos cruzados preservados. A base fica fechada e acompanha o crânio com dois contatos medidos e escala uniforme. O personagem é desenhado inteiro por baixo do acessório.
- **Óculos Cibernéticos, item 12:** lentes dimensionadas e apoiadas individualmente nos centros dos olhos. A ponte e as hastes se adaptam à cabeça; a haste de trás passa sob o cabelo e a orelha. O encaixe não exige girar toda a peça para compensar a perspectiva do desenho.
- **Óculos a Vapor, item 13:** mesmo sistema de apoio por lente, com tamanho menor e escala uniforme nas regiões das lentes. A ponte e a correia acompanham a cabeça sem achatar as lentes. A orelha oculta a haste também na pose de captura, em que ela fica mais próxima do olho.

Os PNGs e as texturas compiladas dos óculos permanecem iguais aos da 0.10.21. A correção usa malhas e camadas nativas; nenhum PNG do personagem foi alterado. Os outros 32 acessórios mantêm os mesmos dados e pixels renderizados, incluindo os três aprovados e os itens corrigidos nas revisões anteriores.

## Arte e prompt salvos

O tricórnio foi redesenhado com a ferramenta de imagens integrada. Caminhos relativos à pasta monster-game, incluídos no backup:

- Sprite final: assets/art/cosmetics_v122/pirate.png, 512 × 324.
- Original gerado: tools/art_sources/v122/pirate-generated.png.
- Prompt completo: tools/art_sources/v122/pirate-prompt.txt.

A textura nova usa WebP lossless nos dois APKs. Os pixels RGBA carregados pelo motor foram comparados com o PNG final e são idênticos. Os óculos reutilizam suas artes originais, sem nova imagem gerada ou recompressão.

## Verificações

- 1.467 verificações dos itens, sem falhas. Os 263 conjuntos de medidas e malhas dos personagens permanecem byte a byte iguais aos da 0.10.21.
- 588 renderizações dos três itens nas nove animações, nos dois lados; mais 576 renderizações dos óculos com chapéus, cabelos, capa e acessórios de pescoço.
- 8.480 renderizações dos outros 32 itens com pixels idênticos aos da versão anterior.
- 784 verificações dos centros das lentes na imagem renderizada, todas corretas; verificações de escala e ausência de achatamento nas regiões das lentes dos 96 quadros medidos do zumbi.
- 83.148 amostras opacas das orelhas preservadas. A comparação identificou e permitiu corrigir a sobreposição das hastes na pose de captura.
- 7.424.955 amostras de transparência do personagem original, sem perda de cobertura acima da tolerância de 3 níveis em 255. Preservadas 1.117.782 amostras do corpo e 373.422 do rosto visível: rosto completo no teste do tricórnio e região da boca nos testes dos óculos. As lentes cobrem intencionalmente os olhos. Bordas translúcidas podem se misturar com o acessório atrás delas.
- Bancada executada a partir do APK final: 5.504 verificações, 35 itens e 4.534 amostras de animação, sem alterar os dados do jogador.
- Coleção: 7.170 verificações. Teste geral: 64 verificações principais e regressões de sobreviventes, sem falhas.
- Inicialização do APK final: versão 0.10.22, 111 arquivos e 55 classes verificados. Carregamento da nova textura e SHA-256 dos pixels RGBA conferidos.
- Assinatura mantida, índice com 820 entradas, ZIP válido e resources.arsc sem compressão e alinhado a 4 bytes. Os 240 arquivos antigos de mídia e bibliotecas permanecem idênticos em cada perfil.

Aprovação visual do Kauan e instalação em aparelho físico ainda pendentes. Testar em Configurações → Desenvolvedor → Bancada de itens → 11, 12 e 13.

## APKs e recuperação

- Horda-Zumbi-v0.10.22-ARM64.apk: 90.357.125 bytes (90,36 MB). SHA-256: b1f3854169e1541752baa084c7193b36e14190129c66b2886d7212af237c056b.
- Horda-Zumbi-v0.10.22-Sem-Perdas-ARM64.apk: 185.617.797 bytes (185,62 MB). SHA-256: 447187a7592fcc6fd482d0be9bbeda0b98f916bf1147f285a1a06c68460a4a7d.

Pacote e assinatura mantidos para atualização da versão anterior. O backup privado inclui o delta completo das fontes desde a base pública, artes, prompts, testes, configuração compilada, oito texturas adicionais acumuladas e assinatura. A restauração exige o commit-base público indicado no manifesto ou uma cópia local dele. A assinatura privada não deve ser publicada no GitHub. As versões anteriores continuam separadas.
