# Horda Zumbi 0.10.38 — evento do esgoto

O esgoto passa a ser um encontro aleatório durante a corrida. A primeira oportunidade aparece entre 48 e 72 segundos, em um trecho seguro depois do tutorial. A horda vê o pequeno porto, corre até os jet-skis, embarca em duplas e salta pela entrada do túnel. Após uma fuga, outra oportunidade só aparece depois de 105 a 150 segundos. O percurso e os túneis continuam avançando na mesma partida.

## Personagens desenhados para os assentos

Zumbi e esqueleto têm folhas novas com 16 poses cada: piloto, passageiro, abaixamento e embarque. Os corpos têm pernas dobradas e pés próprios; o ciclo de empurrar veículos deixou de representar quem está sentado. O quadril acompanha o casco e os 35 acessórios são adaptados às referências da cabeça e do corpo. Cada jet-ski leva até dois membros reais. Uma horda ímpar deixa um assento vazio. Os resgates preenchem vagas antes de criar outra dupla e não deslocam os barcos existentes.

## Fuga e desafios

Toque na área de jogo para saltar e segure brevemente para alongar o salto. Use **ABAIXAR** para passar pelos canos e pelas comportas. Os seguidores repetem as ações pela distância percorrida; o atraso adicional cresce a partir de 16 membros.

Há naufrágios, barris explosivos, bombas giratórias, comportas e teto desabando com aviso. Os obstáculos têm apoio físico no teto ou na água. O teto caído vira entulho para saltar. As sequências alternam desafios e resgates, com três trechos: Galeria Inundada, Casa das Bombas e Teto em Colapso. Acertar uma fileira completa de moedas dá PERFECT, afasta um pouco a enchente e aumenta brevemente a velocidade.

A enchente é uma muralha grande desenhada em 16 quadros, com crista, espuma, deformação e spray. Acidentes aproximam a onda, recuam o jet-ski e podem retirar passageiros reais. Uma proteção breve limita perdas repetidas no mesmo contato. O risco de perder a horda permanece.

Sobreviventes na água têm três personalidades e quatro poses cada. Mulher e operário correm com oito quadros na passarela, perseguidos pelos monstros do próprio jogo. Uma pessoa que cai pode virar um resgate real, sem duplicar a alma. Rastros, água em movimento, vazamentos e explosões reforçam a velocidade.

## Retorno e progresso

A saída mantém a transição aprovada: o salto revela o céu, o distrito, o chão e os túneis da própria corrida. Os barcos ficam para trás e os membros sobreviventes pousam na pista. Aves, espaço, almas, recordes e cosméticos permanecem na mesma partida.

O esgoto saiu da loja, do sorteio de poderes e das melhorias permanentes. As antigas compras de duração são reembolsadas uma única vez, até 9.100 moedas. O item antigo não ativa o evento.

Para testar sem esperar o encontro aleatório, use **EVENTO ESGOTO** na tela inicial ou o modo desenvolvedor. O atalho também começa pela corrida até o porto. A edição de testes continua repondo ao abrir pelo menos **1.000.000 de moedas e 10.000 olhos**, preservando saldos maiores.

## APK, arte e validação

Android 0.10.38, código 141, ARM64, mínimo 24 e alvo 35. Nome instalado: **Horda Esgoto R38**. Mantém `com.kauan.noitedahorda.reconstruida` e a assinatura da 0.10.37 para atualizar sem apagar o progresso.

Oito fontes de arte foram criadas com ImageGen integrado e estão em `tools/art_sources/v138/`. O arquivo `PROMPTS.json` registra os briefings reconstituídos e a proveniência. `tools/prepare_v138_art.py` prepara os atlas e mede os pontos de encaixe. Os PNGs antigos dos personagens permanecem intactos.

`VALIDACAO-v0.10.38.json` registra a auditoria do APK, os testes de controles, compras, migração, formação da horda e regressões. A prévia usa as artes e os scripts extraídos do APK e o renderizador nativo Godot com entradas de toque. Não houve teste em aparelho Android físico nesta sessão.

O GitHub guarda os fontes completos e a reconstrução byte a byte do APK assinado em `release-v0.10.38/`. O backup privado inclui também o projeto completo, as artes originais, o aplicativo e a identidade de assinatura. A chave e a senha não são publicadas no repositório.
