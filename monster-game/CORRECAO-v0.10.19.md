# Horda Zumbi 0.10.19 — chapéu do aventureiro

O chapéu do aventureiro (z_adventure, item 06 da bancada) mostrava uma grande cavidade escura sob a aba, parecendo vazio sobre a cabeça. O desenho foi refeito com edição de imagem: aba contínua, copa de couro com base fechada, faixa escura e fivela dourada preservadas. O apoio agora acompanha o crânio com escala uniforme e centro medido nos eixos da cabeça, também ao espelhar o personagem.

A proporção é compacta e a altura foi ajustada para manter os centros dos olhos visíveis. A nova textura de 512 × 247 usa WebP lossless nos dois APKs. O original gerado e o prompt completo ficam em tools/art_sources/v119/. O sprite pronto fica em assets/art/cosmetics_v119/adventure.png. O preparo recorta as margens transparentes, exporta a resolução de uso e verifica os pixels da textura compilada.

## Preservação

Os outros 34 acessórios mantêm os mesmos dados gráficos. A cartola, o chapéu da bruxa e o boné do sobrevivente continuam aprovados; os ajustes do boné do encanador e do chapéu de palha da 0.10.18 permanecem enquanto aguardam nova avaliação. Coleção, progresso, movimentação, áudio e sprites dos personagens não mudaram.

## Verificação

- 634 verificações do aventureiro: 96 quadros medidos do zumbi, encaixe uniforme, centro, proporção e centros dos olhos descobertos.
- 196 imagens do chapéu nas nove animações e nos dois lados; inspeção de painéis e da bancada no mesmo quadro 6 enviado pelo Kauan.
- 980 comparações renderizadas dos cinco chapéus revisados antes: pixels idênticos à 0.10.18.
- Bancada a partir dos arquivos do APK final: 5.504 verificações, 35 itens e 4.534 amostras, sem alteração dos dados do jogador.
- Coleção: 7.170 verificações; teste geral: 64 verificações; sem falhas.
- Inicialização a partir do APK final: versão 0.10.19, 101 arquivos e 55 classes verificados.
- Carregamento da textura a partir do APK final: dimensões e SHA-256 dos pixels RGBA iguais ao PNG de origem.
- Assinatura mantida, índice e ZIP válidos, resources.arsc sem compressão e alinhado. Os 235 arquivos antigos de mídia e bibliotecas permanecem idênticos em cada perfil; apenas a textura do aventureiro foi acrescentada.

Teste no aparelho físico e aprovação visual do Kauan ainda pendentes. Use Configurações → Desenvolvedor → Bancada de itens → 06 Chapéu do Aventureiro.

## Arquivos e recuperação

- Horda-Zumbi-v0.10.19-ARM64.apk: 89684406 bytes (89.68 MB), SHA-256 03e1cfa50def000dbc0533ee8d3b51d1a385dbc4d3832a659e9a1d3733aca9c0.
- Horda-Zumbi-v0.10.19-Sem-Perdas-ARM64.apk: 184945078 bytes (184.95 MB), SHA-256 947184d29b61ce7d6f52514525275ed5ffa877dac10abf084efa2a881f0c1299.

As versões anteriores continuam separadas. O backup privado contém o delta completo desde a base pública, arte, testes, configuração compilada, três texturas novas e assinatura. Para restaurar, é necessária a base pública no commit indicado ou uma cópia local dela. Não publique a pasta de assinatura privada no GitHub.
