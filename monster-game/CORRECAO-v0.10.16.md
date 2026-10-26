# Horda Zumbi 0.10.16 — Boné do Encanador

O boné vermelho tinha uma abertura escura e larga na base, parecendo uma peça solta sobre o cabelo. O novo desenho tem a faixa fechada, tecido envolvendo a parte de trás e aba mais curta. Seu encaixe usa escala uniforme, acompanha a cabeça e mantém os centros dos olhos visíveis nos 96 quadros medidos do zumbi.

O ID continua `z_plumber`; preço, raridade, coleção e seleção de acessórios continuam iguais. Os outros 34 gráficos são iguais aos da 0.10.15. A Cartola do Coveiro, o Chapéu da Bruxa e o Boné do Sobrevivente foram preservados também em comparação de pixels, com 588 renderizações nas animações e nos dois lados.

Abra **Configurações → Desenvolvedor → Bancada de itens → 04 Boné do Encanador** para conferir a nova peça. A aprovação final do novo desenho depende do Kauan.

O teste específico verificou os 96 quadros, ausência de deformação e visibilidade dos olhos; renderizou o novo boné em 196 combinações de quadro e orientação. O teste da bancada percorre todos os itens e preserva os dados do jogador.

O novo PNG tem 512 × 345 pixels e sua textura no APK usa WebP sem perdas, inclusive no APK compacto. Os 233 recursos anteriores de imagem, som e bibliotecas nativas são mantidos byte por byte em cada perfil. Nenhuma imagem anterior recebe nova compressão.

O original de alta resolução criado com a ferramenta de geração de imagens e o prompt final estão em `tools/art_sources/v116/`. O preparo reproduzível fica em `tools/prepare_v116_cap.py`; ele recorta o espaço transparente, redimensiona para o jogo e gera a malha e a textura sem perdas.

Os APKs usam o mesmo pacote e a mesma assinatura da versão 0.10.15, com código de versão 119. O backup também inclui a textura compilada em `compilacao/plumber-v116-lossless.ctex`. Para reaproveitá-la em um projeto restaurado, copie para `monster-game/.godot/imported/plumber-v116-lossless.ctex`; o importador também pode recriá-la a partir do PNG. A assinatura privada continua separada do projeto. Teste em aparelho físico pendente.
