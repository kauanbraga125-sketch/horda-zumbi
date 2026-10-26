# Horda Zumbi — reconstrução 0.10.13, revisão de instalação 0.10.13.1

APK compacto: 89,024,309 bytes (89.02 MB; 84.90 MiB).
APK sem perdas: 184,284,981 bytes (184.28 MB).
O compacto é 64.85% menor que o APK recuperado de referência, v0.10.3 (253.238.824 bytes), e inclui a reconstrução dos recursos posteriores.

A opção compacta usa WebP de alta qualidade, com pequenas alterações de cor. A resolução dos atlas, os quadros das animações e a transparência das regiões usadas são preservados. A opção sem perdas mantém os pixels visíveis e as bordas; as 12 capturas comparadas foram idênticas à renderização do projeto original reconstruído. Os PNGs originais do projeto não foram alterados.

Foram restaurados 35 cosméticos para zumbis e esqueletos, com coleção ativa, filtros, prévias animadas, moedas e sete itens exclusivos de Olhos Malditos. A distribuição visual é estável por membro, respeita espécie e posição do acessório e não altera o sorteio da partida. Os encaixes usam 263 medições de quadros e camadas separadas para rosto, braços, cabelo e capas.

A formação responde melhor em grupos pequenos, ajusta sobreposição mais lentamente no ar, mantém o atraso progressivo em grupos grandes e permite que outro membro assuma a frente. A fila transmite força ao empurrar veículos. Os pés ficam na superfície de colisão, sem empilhamento vertical artificial. Resultados com almas animadas, estoque, experimentos, coleção, perfis, soldados e sistemas anteriores foram mantidos.

São duas opções ARM64 para Android 7.0 ou posterior. O pacote é `com.kauan.noitedahorda.reconstruida`, versão Android 116 (versionName 0.10.13.1). A assinatura privada antiga não foi recuperada; esta instalação fica ao lado da antiga. Para levar o progresso, use COPIAR BACKUP no app antigo e LER BACKUP/CONFIRMAR RESTAURAÇÃO no novo. As duas opções novas usam a mesma assinatura e o mesmo pacote.

A validação inclui inicialização, integridade de 94 arquivos, índice dos 803 recursos, assinatura Android, tabela de recursos e testes do conteúdo extraído do APK. A coleção, movimentação, encaixes, sistemas anteriores e navegação passaram. Foram renderizados 24 painéis de acessórios, com oito poses e os dois lados, e 12 cenas do mercado e da partida. Falta o teste em um aparelho Android físico.

Para reconstruir: importar `monster-game/project.godot` no Godot 4.5.1, executar `tools/refresh_startup_integrity.py`, exportar os recursos com `Godot --headless --path monster-game --export-pack Android recursos.zip`, gerar o cache com `tools/optimize_v113_images.py` (`--profile compact` ou `lossless`) e chamar `tools/build_v113.py`. O empacotador valida a base pública v0.10.3, recebe recursos, cache, assinatura, apksigner e zipalign por argumentos e verifica o APK ao terminar. Dependências de preparação: Pillow, NumPy, SciPy, Shapely 2.1.2, scikit-image e zstandard.

Base do código: https://github.com/kauanbraga125-sketch/horda-zumbi/tree/f7bebdd9b8cf8d81cf4e0f28ebfb16dcfccfc720
Base Android: https://github.com/kauanbraga125-sketch/horda-zumbi/releases/download/v0.10.3/Horda-Zumbi-v0.10.3.apk

A revisão 0.10.13.1 corrige a rejeição do instalador Android observada no aparelho: `resources.arsc` estava comprimido. Para target SDK 30 ou superior, o Android exige essa tabela sem compressão e alinhada a quatro bytes. Agora o empacotador usa ZIP_STORED nessa entrada e verifica explicitamente a regra após assinar. A regressão foi reproduzida nos dois APKs 0.10.13 e passou nas duas opções corrigidas. Assinatura, alinhamento, CRC, recursos Android e integridade dos 94 arquivos foram verificados. Os 803 arquivos de conteúdo do jogo e as bibliotecas nativas são idênticos aos da entrega anterior; apenas a versão Android e os metadados de integridade/índice mudam. A tabela de recursos também é idêntica após descompressão. Teste físico do APK corrigido ainda pendente.
