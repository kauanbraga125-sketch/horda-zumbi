# Horda Zumbi 0.10.37 — perseguição no esgoto

Esta versão corrige a fuga introduzida na 0.10.36. O jet-ski tem **dois assentos**, com os membros reais da horda. Os passageiros ficam presos ao quadril, inclinam com o casco e não reproduzem o ciclo inteiro de empurrar veículos. Com uma horda ímpar, o último barco pode ter um assento vazio; nenhum personagem é inventado para completar a dupla.

A enchente usa oito quadros de uma crista desenhada, espuma, spray e água em movimento. Sua frente acompanha a posição da cauda da horda e se aproxima quando há acidentes. A colisão retira um passageiro real e desacelera brevemente os barcos, com um intervalo de proteção para evitar perdas múltiplas no mesmo instante. O som da correnteza cresce com o perigo.

O deslocamento da água, os rastros e os elementos do cenário são mais rápidos. Canos e comportas têm suportes até o teto. O naufrágio tem um casco reconhecível e os barris ficam parcialmente na água. Destroços e barris pedem salto; canos e comportas baixas pedem ficar na água. O salto segurado é registrado e repetido pelos seguidores conforme a distância até o obstáculo.

## Sobreviventes e cenário vivo

Há três sobreviventes próprios do esgoto, com nove quadros de natação e pedido de socorro: mulher com capa de chuva, operário com capacete e homem de capuz e óculos. Eles substituem o antigo civil montado por peças. Na passarela, dois civis e um mutante têm doze quadros de corrida. Há perseguições, vazamentos, destroços caindo e pessoas despencando na água. Uma pessoa que cai pode se tornar um resgate jogável e acrescentar exatamente uma alma e um membro, sem duplicação.

As animações, cores e volumes seguem o desenho gótico do jogo. A fuga cinematográfica serve de inspiração; os personagens, artes e elementos novos são originais.

## Saída no próprio mapa

A paisagem alternativa da saída foi retirada do caminho de renderização. Durante o salto, o jogo já desenha **o céu, o distrito, o chão e os túneis da corrida normal**, com o mesmo avanço do mundo. O interior do esgoto sai de cena junto de um arco que usa a arte original do jogo. A câmera aproxima gradualmente até a escala da corrida. Os barcos ficam para trás, e os mesmos membros pousam na pista.

As aves, os 35 cosméticos, os poderes, as almas, os recordes e o progresso dos túneis são preservados. A edição de testes continua iniciando com pelo menos **1.000.000 de moedas e 10.000 olhos**. Na tela inicial, use **ESGOTO R37**; também há o teste em Configurações → Desenvolvedor. Toque para saltar e segure brevemente para alongar.

## Fontes, arte e validação

Versão Android 0.10.37, código 140, ARM64, mínimo 24 e alvo 35; Godot 4.5.1 e GL Compatibility. Nome instalado: **Horda Esgoto R37**. Mantém o pacote e a assinatura da 0.10.36 para permitir a atualização com os dados anteriores.

O relatório VALIDACAO-v0.10.37.json registra assinatura, integridade, inicialização normal, resgates, assentos, obstáculos, perdas e regressões. A prévia é capturada pelo renderizador nativo com entradas reais de toque e inclui um erro real contra um barril. Não houve teste em celular Android físico nesta sessão.

As quatro artes originais foram criadas com **ImageGen integrado**, com transparência, e estão em `tools/art_sources/v137/`. O conjunto completo de prompts está em [PROMPTS.json](tools/art_sources/v137/PROMPTS.json). Os sete WebPs preparados ficam em `assets/art/v137/`; `tools/prepare_v137_art.py` reproduz a separação e o alinhamento. Os dois efeitos originais de som ficam em `assets/audio/v137/` e podem ser recriados por `tools/generate_v137_audio.py`.

O GitHub preserva fontes e a reconstrução byte a byte do APK assinado em `release-v0.10.37/`. O backup privado contém também a identidade de assinatura, o APK e o projeto completo; a chave e a senha não são publicadas no repositório.
