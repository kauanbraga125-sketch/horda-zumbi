# Horda Zumbi 0.10.27 — revisão dos acessórios

Parte da 0.10.26. Nove itens recebem ajustes individuais a partir de capturas
reais dos personagens: cabelo do cientista, capa do vampiro, cachecol,
corrente, gorro do caos, elmo do norte, chapéu das estrelas, cartola listrada
e coroa de gelo.

O cabelo novo segue o crânio, sem encolher com as piscadas. A gola e o ombro
permanecem inteiros. Capa, cachecol e corrente foram redesenhados junto ao
pescoço; as mãos e o rosto ocluem o tecido por meio de malhas próprias de cada
quadro. O capuz do esqueleto é separado da capa pela costura desenhada. Uma
camada nova completa a parte posterior do crânio, mantendo os olhos, a boca e
as expressões originais animadas.

As imagens PNG aprovadas dos personagens, as 263 medições e os outros 26
acessórios são preservados. Os desenhos novos permanecem inalterados em
assets/art/cosmetics_v127. Os recortes e a transição do crânio são feitos com
malhas UV. Texturas novas são importadas sem perdas.

Preparação reproduzível: Python com Pillow, NumPy, SciPy, scikit-image,
Shapely 2.1 e zstandard; executar tools/prepare_v127_items.py --source . dentro
da pasta monster-game. Os registros de encaixe, estudos sobre o personagem e
as artes extraídas acompanham o código.

A bancada de testes continua em Configurações → Desenvolvedor → Bancada de
itens, com nove estados, dois lados, zoom e quadro a quadro, sem alterar os
dados do jogador. Pacote e assinatura Android são mantidos; versão 130.
Teste em aparelho físico pendente.

Validação concluída: 2.454 renderizações dos nove itens, 126 combinações, 468 renderizações dos outros acessórios, 1.219 encaixes proporcionais, 203.830 amostras protegidas sem divergência e 17.594 amostras do cabelo antigo sem vazamento. Os cinco chapéus passaram em 835 checagens de afastamento dos olhos. Coleção: 7.170 verificações. Movimentação: 64. Bancada extraída do APK: 5.504 verificações, 35 itens, 263 quadros, dados do jogador preservados. Inicialização do APK: 143 arquivos e 55 classes verificados.

Para restaurar exatamente o ambiente do jogo, use o backup com o APK desta versão: python restaurar_projeto.py --apk Horda-Zumbi-v0.10.27-ARM64.apk --output horda-zumbi-recuperado. A base pública exata será baixada; --base-dir permite fornecer uma cópia local dessa base. A fonte é aplicada depois dos recursos do APK, preservando a configuração atual. A assinatura fica separada da pasta do projeto. Sem o APK, abra o projeto no Godot 4.5.1, importe os recursos e atualize a auditoria pelo script indicado.
