# Horda Zumbi 0.10.26 — revisão de nove acessórios

Atualização sobre a v0.10.25, preservada no backup anterior. As dez imagens enviadas mostram nove itens diferentes; a capa do vampiro aparece duas vezes.

| Item | Correção |
| --- | --- |
| Cabelo do cientista | Nova arte de cabelo branco com coroa preenchida e franja curta; recorte do cabelo antigo e encaixe proporcional, preservando rosto e orelhas. |
| Capa do vampiro | Escala menor, fixação no pescoço e orientação pelo tronco; pano atrás do corpo e gola à frente, com rosto e braços na ordem correta. |
| Cachecol carmesim | Região do atlas ampliada para incluir a gola inteira, eliminando o corte reto; caudas atrás do personagem e gola menor acompanhando o pescoço. |
| Corrente do submundo | Pontos de fixação no pescoço, proporção uniforme e pingente sobre o peito; braços podem ocultar partes da corrente durante o movimento. |
| Gorro do caos | Nova base fechada, apoiada na cabeça, mantendo tecido verde e roxo e os guizos. |
| Elmo do norte | Nova borda inferior fechada, menor e assentada na testa, mantendo metal e chifres. |
| Chapéu das estrelas | Nova aba vista de cima e encaixe ajustado para deixar os olhos visíveis também em pulo, captura e pânico. |
| Cartola listrada | Nova aba fechada e base apoiada na cabeça, mantendo as listras vermelhas e brancas. |
| Coroa de gelo | Nova base fechada acompanhando a testa, mantendo cristais e pedras azuis. |

Os seis novos PNGs estão em `assets/art/cosmetics_v126/`: `scientist.png`, `s_chaos.png`, `s_north.png`, `s_wizard.png`, `s_striped.png` e `s_ice.png`. Foram criados com a ferramenta integrada de geração de imagens e importados com transparência e compressão sem perdas. Os prompts e a identificação do modo utilizado ficam em `tools/art_sources/v126/`. As artes e texturas anteriores permaneceram iguais.

Os encaixes e recortes ficam em `assets/art/cosmetics_v113/graphics.json`; as camadas nativas do rosto e membros para os acessórios do tronco ficam em `assets/art/cosmetics_v126/layers.bin`. A ferramenta `tools/prepare_v126_items.py` reproduz esses recursos. O arquivo original `fitting.bin`, com 263 quadros medidos, foi preservado. Os outros 26 acessórios mantêm os mesmos dados e são comparados com a renderização da v0.10.25.

A verificação inclui as nove animações e ambos os sentidos, todos os quadros dos nove acessórios, comparação dos demais itens com a versão anterior, preservação dos olhos, boca e membros em poses de cada animação, bancada de itens, coleção, integridade e inicialização dos recursos extraídos do APK final. Os resultados e comparativos ficam na pasta `validacao` do ZIP de recuperação. O cabelo branco usa sombras frias; a detecção de cabelo antigo compara também a imagem independente do personagem original, para distinguir essas sombras dos pixels originais.

Android: pacote `com.kauan.noitedahorda.reconstruida`, versão `0.10.26`, código `129`, nome `Horda Zumbi R26`. A assinatura das versões reconstruídas foi preservada. Instale por cima da v0.10.25, sem desinstalar nem apagar dados. Teste em aparelho físico pendente; esta revisão não foi instalada em um Moto G71.

O backup privado inclui todas as alterações acumuladas sobre o commit público `f7bebdd9b8cf8d81cf4e0f28ebfb16dcfccfc720`, artes, ferramentas, prompts e assinatura separada. A restauração precisa desse commit público ou de uma cópia local da base. Não publique a pasta `assinatura_privada`.
