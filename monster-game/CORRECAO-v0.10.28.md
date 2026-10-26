# Horda Zumbi 0.10.28 — oito acessórios encaixados

Atualização sobre a **0.10.27**, mantendo a assinatura Android e o pacote
`com.kauan.noitedahorda.reconstruida`. Instale sobre a versão anterior.

| Acessório | Correção |
| --- | --- |
| Coroa de gelo | Menor, mais baixa e com a faixa apoiada no crânio. |
| Elmo do norte | Profundidade e largura próprias, com a borda envolvendo a testa. |
| Chapéu das estrelas | Aba mais baixa; encaixe por quadro para preservar os olhos no salto. |
| Cartola listrada | Base mais baixa e centralizada, com a mesma proteção durante as animações. |
| Tricórnio fantasma | Nova arte desenhada vestida sobre o esqueleto, com aba curva e sem abertura vazia aparente. |
| Capacete espacial | Nova carcaça próxima ao crânio; abertura acompanha o rosto e aro do queixo passa acima da gola. |
| Coroa do rei ossudo | Nova faixa curva envolvendo a testa, rubis proporcionais e sem fundo oco visível. |
| Máscara da peste | Nova perspectiva, tiras e bico; os olhos originais continuam aparecendo pelas lentes. |

As quatro artes novas foram criadas com a ferramenta integrada de geração de
imagens sobre uma referência do personagem. Os PNGs completos permanecem
intactos em `assets/art/cosmetics_v128/`. As malhas UV selecionam apenas os
acessórios. O conjunto dos prompts está em `tools/art_sources/v128/` e a
preparação pode ser repetida com `tools/prepare_v128_items.py --source .`.
As quatro artes existentes dos primeiros itens são preservadas.

O encaixe respeita os 167 quadros medidos do esqueleto e os nove estados da
bancada, nos dois lados. Os 263 registros originais de personagens não mudam.
As abas dos dois chapéus altos usam uma margem medida dos olhos e uma
transição suave entre quadros. Capacete, coroas e máscara não recebem o
cisalhamento que deformava os acessórios antigos.

Validação final no Godot 4.5.1:

- 2.672 renderizações individuais dos oito itens e 144 com acessórios combinados.
- 486 renderizações dos outros 27 itens idênticas à 0.10.27.
- 1.336 encaixes proporcionais e 843 verificações de espaço dos olhos.
- 197.504 amostras protegidas do corpo, mãos e capa, sem divergências.
- 2.032 amostras das íris originais, sem divergências.
- Coleção: 7.170 verificações aprovadas.
- Bancada: 5.504 verificações, 35 itens acessíveis e dados do jogador preservados.
- APK: assinatura anterior, versão Android 131, 861 recursos indexados e
  151 arquivos verificados na inicialização. Os 254 recursos anteriores de
  imagem, áudio, fontes e bibliotecas nativas permanecem byte a byte iguais.

Os testes de inicialização e bancada também usam os arquivos extraídos do
APK assinado. Teste de instalação e execução em aparelho Android físico
ainda pendente.

O backup completo inclui código, artes, fontes, sons, importações e testes.
Ele abre diretamente em `projeto/monster-game/project.godot`, sem baixar uma
base antiga. A assinatura fica separada em `assinatura_privada`; essa pasta e
o ZIP de recuperação são privados e não devem ser publicados no GitHub.
