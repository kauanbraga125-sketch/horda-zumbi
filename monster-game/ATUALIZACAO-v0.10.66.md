# Horda Zumbi 0.10.66 — céus vivos

Os céus recebem quatro encontros de fundo, com poses de preparação, ataque e reação inspiradas em filmes e cultura pop. Cada cena tem uma altitude própria no mundo: sobe e desce pela tela quando a câmera passa, sem acompanhar a altura da horda.

| Região | Encontro | Movimento e integração |
| --- | --- | --- |
| Bruma do cemitério | Verme listrado inspirado em Beetlejuice | Abre a boca, investe contra um viajante minúsculo, mastiga e solta um sopro espectral; base envolta em névoa. |
| Ventos malditos | Duelo inspirado em Godzilla e Kong | Soco, recuo, defesa e sopro azul; apoio no perfil da rocha distante, sombras de contato, partículas e névoa. |
| Atmosfera sombria | Caçada inspirada em Alien e Predador | Aproximação, salto, guarda, camuflagem e contra-ataque de plasma entre destroços orbitais. |
| Universo maligno | Carro voador inspirado em De Volta para o Futuro | Travessia horizontal em altitude fixa, rastro discreto e brilho de portal. |

São encontros decorativos, sem novas colisões ou alterações no ritmo, nas cargas, capturas e perigos. Três atlas WebP com alfa compartilham 21 quadros, carregados sob demanda e descartados da pintura fora da região visível. As posições verticais dos quatro encontros não usam a altura da câmera; animações de salto, investida e partículas são movimentos locais ao redor dessas posições.

## Validação

Godot 4.5.1: 27 casos das três rotas físicas e 2.975 verificações de abertura persistente, serra, cosmos, regiões e novos encontros passaram, totalizando 3.002 casos/verificações sem falhas. As verificações novas cobrem três tamanhos de viewport, cinco altitudes, três posições horizontais, quadros compartilhados, mudanças de pose e apoio das criaturas na rocha.

A gravação nativa de gameplay usa os toques do piloto de prévia, física normal, obstáculos e capturas: 1.576 quadros em 30 fps, 52,53 s, pico de 381,30 m e retorno à rua com 14 membros e 9 almas. A sequência de entradas, eventos e estados é idêntica à 0.10.65. Uma gravação separada de inspeção, identificada na tela, mantém a câmera parada por região durante 32 s para mostrar os ciclos de animação com clareza.

A auditoria de abertura cobre 353 recursos e 55 classes. A compilação Android usa versionCode 169 e mantém a edição de teste `com.kauan.noitedahorda.github`. O APK passa pela exportação, alinhamento, assinatura e inicialização automatizados do Actions. A instalação em Android físico continua pendente de conferência pelo proprietário.

Relatório detalhado: [VALIDACAO-v0.10.66.json](VALIDACAO-v0.10.66.json). Artes e registros: [assets/art/v166/SOURCE.md](assets/art/v166/SOURCE.md). As versões anteriores, os cosméticos, a abertura do esgoto e as três rotas físicas estão preservados.
