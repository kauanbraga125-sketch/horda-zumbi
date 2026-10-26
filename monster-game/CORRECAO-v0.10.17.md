# Horda Zumbi 0.10.17 — Chapéu de Palha

O desenho anterior mostrava uma abertura oval escura embaixo da aba, como se o chapéu estivesse vazio sobre o cabelo. A nova arte mostra a superfície de palha da aba e uma base contínua. Mantém palha dourada, faixa vermelha, laço traseiro e as bordas desfiadas.

O encaixe acompanha a copa junto ao crânio e mantém a aba fora dos centros dos olhos nos 96 quadros medidos do zumbi. A escala é uniforme, para preservar a textura e as proporções do desenho.

Abra **Configurações → Desenvolvedor → Bancada de itens → 05 Chapéu de Palha**. A aprovação final do novo desenho depende do Kauan.

Os outros 34 gráficos permanecem iguais aos da 0.10.16. A cartola, o chapéu da bruxa, o boné do sobrevivente e a correção do boné do encanador são comparados em 784 renderizações para garantir que permaneçam visualmente idênticos. Os três primeiros foram aprovados pelo usuário; o boné do encanador ainda aguarda avaliação após a correção.

O novo chapéu foi criado com a ferramenta de geração de imagens. O original e o prompt estão em `tools/art_sources/v117/`. O preparo reproduzível está em `tools/prepare_v117_straw.py`. A textura para o jogo mede 512 × 276 pixels e é armazenada sem perdas nos dois APKs.

Os 234 recursos anteriores de imagens, áudio e bibliotecas nativas permanecem byte por byte iguais em cada perfil. A nova peça recebe sua própria textura. Nenhuma imagem anterior é recomprimida.

Os APKs preservam pacote e assinatura da 0.10.16, com código de versão 120. O backup inclui as texturas compiladas do boné e do chapéu em `compilacao/`; para reaproveitá-las, copie os `.ctex` para `monster-game/.godot/imported/`. Os importadores também podem recriar as texturas a partir dos PNGs do projeto. Teste em aparelho físico pendente.
