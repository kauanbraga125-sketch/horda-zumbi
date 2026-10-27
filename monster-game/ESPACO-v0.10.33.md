# Horda Zumbi 0.10.33 — espaço revisado

A revisão corrige os problemas de leitura, sobreposição e encaixe observados nas fotos da 0.10.32. A horda tem formação própria no espaço, poses aéreas estáveis e transições distintas de impulso, captura, dano e retorno. Os sprites aprovados e os 35 cosméticos anteriores são preservados.

## Como jogar

- Arraste verticalmente para subir ou descer. Soltar mantém a altura escolhida; um toque isolado não dispara outro movimento vertical.
- Use **INVESTIDA** para atacar. O número sobre a nave indica a horda necessária para destruí-la com uma investida; hordas menores causam dano parcial.
- Tomar um ônibus orbital ou caça concede oito segundos de pilotagem e três pontos de casco. A nave atira automaticamente e continua aceitando investidas. Ao terminar ou perder o casco, os mesmos membros voltam à formação.
- Moedas, astronautas e núcleos ajudam a preencher o impulso. A barra cheia inicia a animação e leva à próxima camada. As quatro regiões apresentam encontros próprios; o horizonte perdido inclui vórtices que puxam a formação.
- Lasers têm emissor, linha de mira e 1,25 segundo de aviso. A rajada retira no máximo um membro de hordas pequenas e dois de hordas a partir de 16. Enquanto pilota, as colisões atingem o casco visível.
- O drone com **+** e aro azul oferece reparo/proteção. Escudo Orbital e Simbionte Cósmico continuam disponíveis.

## Correções

- Os quadros de astronautas e objetos são compartilhados corretamente entre sessões. Reiniciar ou trocar de laboratório não apaga os sprites.
- A formação distribui os membros em linhas e colunas, mantém a cauda dentro da tela e introduz reação extra a partir do 16.º seguidor. A altura e o espaço disponível são considerados na direção vertical.
- As cabines foram redesenhadas voltadas para a direção do jogador. Os ocupantes são os personagens reais, com seus cosméticos. Um viewport pequeno e um stencil de transparência recortam corpo, chapéu e roupa dentro da janela; não há passageiros antigos atrás deles.
- Naves atravessam a tela em vez de ficarem estacionadas na frente da horda. A velocidade espacial tem limite próprio, sem impedir o avanço da distância e dos túneis no chão.
- Os encontros alternam ameaça, resgate e coleta. Trilhas de moedas contornam obstáculos. Cada camada introduz famílias diferentes, com um orçamento de ameaças mais baixo para hordas pequenas.
- A interface espacial destaca horda, moedas, tempo e impulso. As notificações ocupam um único espaço, respeitam prioridade e expiram; PERFECT não cobre os avisos de camada.
- O escudo envolve toda a formação. Naves danificadas mantêm a mesma geometria e recebem fumaça/impacto; não trocam bruscamente de tamanho.
- O buraco negro usa uma ilustração compatível com o cenário. A subida e a descida passam por uma breve cobertura de nuvens, com cenas opacas, evitando a mistura de cidade e Terra.
- O retorno prepara o terreno uma vez, mantém os membros e seus itens, reorganiza a horda e concede proteção de pouso antes dos próximos obstáculos.

## Testes e recuperação

Os testes cobrem movimento terrestre herdado, poderes, migração, compras, cache de sprites entre sessões, formação de 1 a 88 membros, avisos e alcance dos lasers, pilotagem, prioridades da interface, abertura normal e fundos de teste. As verificações visuais usam o renderizador real do Godot, incluindo um teste de pixels que exige zero ocupantes fora do stencil da janela.

O APK distribuído é conferido após a assinatura e seus arquivos são comparados com os fontes. A inicialização é testada também extraindo os recursos do próprio APK. **Não houve teste em Android físico nesta sessão.**

Esta versão de testes mantém no mínimo **1.000.000 de moedas e 10.000 olhos** ao abrir, preservando valores maiores e progresso anterior. A tela inicial oferece teste de espaço e reposição do saldo. Desative `testing/catalog_funds_enabled` e `testing/space_early_pickup_enabled` antes do lançamento comercial.

Godot 4.5.1, GL Compatibility, ARM64, Android mínimo 24 e alvo 35. Versão Android 0.10.33, código 136, pacote `com.kauan.noitedahorda.reconstruida`, nome instalado **Horda Espaco R33**, mesma assinatura da 0.10.32.

Os fontes e o APK ficam no GitHub. O backup completo privado inclui o APK, o projeto, as artes, testes, restauração das importações e a identidade de assinatura. Não publique a pasta `assinatura_privada` nem o ZIP privado no GitHub.
