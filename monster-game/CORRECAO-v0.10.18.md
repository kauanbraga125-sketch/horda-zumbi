# Horda Zumbi 0.10.18 — proporção e centro do chapéu de palha

O chapéu de palha (z_straw, item 05 da bancada) estava grande e deslocado em relação ao crânio. A peça foi reduzida em 20% na largura e na altura. O apoio da faixa foi deslocado para trás e ligeiramente para baixo, em eixos locais da cabeça, acompanhando a inclinação em cada quadro e o espelhamento.

O desenho e a textura lossless de 512 × 276 da 0.10.17 permanecem exatamente iguais. O ajuste acontece no desenho do jogo, sem recortar, recomprimir ou esticar a palha. Os outros 34 acessórios, sprites, áudio, movimentação, coleção e progresso foram preservados.

## Validação

- 630 verificações do encaixe, incluindo os 96 quadros medidos do zumbi, proporção, centro de apoio e olhos visíveis.
- 196 imagens do chapéu nas nove animações e nos dois sentidos, com inspeção de painéis e prévia da bancada.
- 784 comparações renderizadas da cartola, chapéu da bruxa, boné do sobrevivente e boné do encanador: imagens idênticas às da 0.10.17.
- Bancada: 5.504 verificações, 35 itens, 4.534 amostras; dados do jogador preservados.
- Coleção: 7.170 verificações; teste geral: 64 verificações, sem falhas.
- Inicialização a partir dos arquivos do APK final: versão 0.10.18, 99 arquivos e 55 classes verificados.
- Assinatura mantida, ZIP e índice conferidos, resources.arsc sem compressão e alinhado; todos os 235 arquivos de mídia/bibliotecas permanecem idênticos em cada perfil.

Teste no aparelho físico e aprovação visual do Kauan ainda pendentes. Use Configurações → Desenvolvedor → Bancada de itens → 05 Chapéu de Palha.

## Arquivos

- Horda-Zumbi-v0.10.18-ARM64.apk: 89,594,103 bytes (89.59 MB), SHA-256 22f70319ff9ca5096f24ea847ce6952bc1954eddda7d230de3fc2bf69440beb0.
- Horda-Zumbi-v0.10.18-Sem-Perdas-ARM64.apk: 184,854,775 bytes (184.85 MB), SHA-256 9912b07bb7172904787c2120fbf352c3722891a9d6605ad7f9e89ed5de5cc1b0.

Mesma identidade da versão reconstruída; as versões anteriores continuam separadas. O backup privado inclui o delta completo desde a base pública, os testes, a configuração compilada, ambas as texturas novas e a assinatura. Para restaurar, é necessária a base pública no commit indicado ou uma cópia local dela. Não publique a assinatura privada no GitHub.
