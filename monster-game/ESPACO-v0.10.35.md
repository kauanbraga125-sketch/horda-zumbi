# Horda Zumbi 0.10.35 — subida, impactos e espaço vivo

Esta revisão parte da 0.10.34 e trata os problemas mostrados no vídeo: a troca de camada quase não parecia uma subida, os pilares tinham aparência provisória e a proteção contra dano deixava sobreviventes atravessarem obstáculos.

## Mudanças para jogar

- A decolagem desloca a cidade para baixo. Entre camadas, a horda se prepara, inclina para cima, acelera e deixa rastros; estrelas, Terra e objetos passam para baixo com profundidades diferentes. A borda da imagem da Terra desaparece com uma transição suave.
- A subida dura aproximadamente dois segundos. Ela preserva os segundos jogáveis do poder, do escudo e da nave. A distância e os túneis continuam avançando.
- As passagens usam minas orbitais completas, com arte própria, oscilação, inclinação e luzes de alerta. Foram removidos os retângulos e os pilares provisórios desses encontros.
- O contato com minas, rochas e cascos sólidos separa e empurra cada membro. Essa reação continua funcionando durante um escudo, uma investida e depois do limite de dano. O cálculo considera o trajeto entre quadros, inclusive quando um ataque rápido termina dentro do obstáculo.
- O dano continua protegido contra uma sequência instantânea de perdas. A reação física e o dano são decisões separadas. Desvie e a horda volta a se reunir gradualmente.
- Membros perdidos se desprendem no ponto do impacto e saem flutuando com os próprios acessórios. Mortes espaciais deixam de usar o caixão e a sombra de chão.
- Naves têm oscilação e propulsores; destroços quebram e desaparecem mais rapidamente após uma destruição. O escudo tem segmentos em movimento. Astronautas, cápsulas, ovos e parasitas mantêm suas animações.
- Tráfego distante, pequenos detritos e estrelas acrescentam movimento ao fundo. Esses elementos são menores e discretos e não têm colisão com a horda.

Almas, membros perdidos e maior horda continuam pertencendo à mesma partida. A investida, os combos, os contra-ataques alienígenas e os portais conquistados por ações da 0.10.34 permanecem. A liberdade do líder não diminui com o tamanho da horda.

## Como testar

Instale `Horda-Zumbi-v0.10.35-TESTE-1M-ESPACO-VIVO-ARM64.apk` sobre a edição anterior. O pacote e a identidade de assinatura foram mantidos; o código Android passa a 138.

Use **TESTAR ESPAÇO** na tela inicial ou **Desenvolvedor → Espaço**. Arraste uma área livre para guiar a horda e toque em **INVESTIDA** com outro dedo para atacar. No laboratório, os controles inferiores permitem mudar a camada, o tempo e os poderes.

A abertura normal conserva pelo menos **1.000.000 de moedas e 10.000 olhos no saldo da loja**. As moedas no HUD durante a partida são apenas as coletadas naquela corrida. O progresso anterior é preservado.

## Projeto e verificação

Os personagens e os 35 acessórios aprovados foram preservados. A mina nova está em `assets/art/space_v135/mine.png`; seu original e o prompt estão em `tools/art_sources/v135/`. A arte foi criada com imagegen integrado, seguindo a frota existente. `tools/prepare_space_v135.py` reproduz o sprite a partir do original transparente.

`space_contacts.gd` trata contato contínuo e recuo; `space_atmosphere.gd` trata profundidade, passagem de cenário, rastros e propulsores. `space.gd` mantém a horda e a partida principal, `space_combat.gd` mantém encontros e dano, e `space_visual.gd` mantém interface, cabines e a saída dos membros perdidos.

O APK é extraído para validar sua auditoria e executar os testes sobre o conteúdo realmente empacotado. A prévia usa esse conteúdo no Godot com entradas de toque automatizadas, incluindo decolagem, jogo, subidas e retorno. Os testes de contato incluem hordas pequenas e grandes, quadros lentos, escudo, casco pilotado e limite de dano já esgotado.

Os testes automatizados verificam as regras e a integridade; eles não substituem avaliar diversão, resposta ao toque e desempenho no aparelho. Não houve teste em Android físico nesta sessão.
