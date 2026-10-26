# Horda Zumbi 0.10.20 — pesadelo, feiticeiro e capuz elétrico

Os itens 07, 08 e 09 da bancada foram corrigidos após a revisão do Kauan. Os dois chapéus pareciam vazios por baixo da aba; o capuz elétrico também apagava partes do rosto ao trocar a malha visível do personagem.

## Desenho e encaixe

- Chapéu do Pesadelo (z_nightmare): redesenhado com copa apoiada na cabeça, aba contínua e base fechada. Mantém feltro gasto, rasgo na copa e faixa vermelha envelhecida.
- Chapéu do Feiticeiro (z_sorcerer): redesenhado com aba completa e base fechada. Mantém cone azul curvado, estrelas e faixa prateadas. O apoio acompanha os eixos da cabeça com escala uniforme e os centros dos olhos permanecem descobertos nos 96 quadros medidos do zumbi.
- Capuz Elétrico (z_electric): mantém a arte original, com o centro da abertura alinhado à cabeça. O forro e o tecido lateral ficam atrás do rosto e dos braços; a borda amarela da copa fica na frente do cabelo. Uma nova malha preserva o rosto e o corpo completos, em vez de usar o recorte antigo que removia nariz, boca e outros detalhes.

Os dois chapéus foram redesenhados com a ferramenta de imagens. Os originais e os prompts completos estão em tools/art_sources/v120/. Os sprites de uso estão em assets/art/cosmetics_v120/: nightmare.png (512 × 300) e sorcerer.png (512 × 370). Ambas as texturas compiladas usam WebP lossless nos dois APKs; os pixels RGBA conferem com os PNGs de uso. O capuz foi corrigido no código e nas malhas, sem modificar sua imagem.

## Preservação

Os outros 32 acessórios mantêm os mesmos dados gráficos e pixels renderizados da 0.10.19. A cartola, o chapéu da bruxa e o boné do sobrevivente continuam aprovados. Encanador, palha e aventureiro conservam suas correções anteriores e aguardam nova avaliação. Os PNGs dos personagens, a coleção, o progresso, a movimentação e o áudio não foram alterados.

## Verificação

- 1.342 verificações dos três itens, sem falhas: 263 conjuntos antigos de medidas e malhas preservados; novas malhas do capuz nos 96 quadros do zumbi.
- 588 renderizações dos três itens nas nove animações e nos dois lados; mais 108 renderizações do capuz combinado com capa, cachecol e acessórios de rosto.
- 8.480 renderizações dos outros 32 itens com pixels idênticos à versão anterior.
- Comparação com o personagem original sem máscara: 268.758 amostras do interior opaco do rosto e 372.594 do corpo, sem amostras ausentes ou divergências acima da tolerância. O maior desvio de cor do rosto foi de 3 níveis em 255, dentro da tolerância de rasterização de 8. Bordas translúcidas podem se misturar com a cor do tecido atrás delas; isso não significa remoção de pixels do PNG original. O mesmo teste reproduziu 46.444 divergências no rosto com a máscara antiga.
- Bancada executada a partir do APK final: 5.504 verificações, 35 itens e 4.534 amostras de animação, sem alteração dos dados do jogador.
- Coleção: 7.170 verificações; teste geral: 64 verificações; sem falhas.
- Inicialização a partir do APK final: versão 0.10.20, 105 arquivos e 55 classes verificados.
- Carregamento das duas texturas do APK final: dimensões e SHA-256 dos pixels RGBA iguais aos PNGs de uso.
- Assinatura mantida, índice e ZIP válidos, resources.arsc sem compressão e alinhado. Os 236 arquivos antigos de mídia e bibliotecas permanecem idênticos em cada perfil; só as duas texturas novas e suas referências foram acrescentadas.

Teste no aparelho físico e aprovação visual do Kauan ainda pendentes. Use Configurações → Desenvolvedor → Bancada de itens → itens 07, 08 e 09.

## Arquivos e recuperação

- Horda-Zumbi-v0.10.20-ARM64.apk: 89.918.280 bytes (89,92 MB), SHA-256 d80409d56298897f05d906ce1b50fa37c2e45d29cf166b7556e3ae0433451b18.
- Horda-Zumbi-v0.10.20-Sem-Perdas-ARM64.apk: 185.178.952 bytes (185,18 MB), SHA-256 3fa448f25fa5ae7e38913a36f743d05e62b91b3a2a4e6c123ffddee8ba71b1fe.

As versões anteriores continuam separadas. O backup privado contém o delta completo desde a base pública, arte, prompts, testes, configuração compilada, cinco texturas novas acumuladas e assinatura. Para restaurar, é necessária a base pública no commit indicado ou uma cópia local dela. Não publique a pasta de assinatura privada no GitHub.
