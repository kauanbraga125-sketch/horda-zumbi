# Horda Zumbi 0.10.32 — aventura orbital e controle da horda

Atualização sobre a versão entregue 0.10.31, preservando o pacote Android, a assinatura instalada, o progresso e os sprites aprovados dos personagens.

## Controle na Terra

O comando de salto dos seguidores agora registra a coordenada do mundo em que o líder saltou. Cada membro repete o salto ao chegar àquele ponto; o tempo de sustentação do toque também é repetido. Antes, quatro membros separados por 52 pixels recebiam atrasos que não correspondiam à distância até o obstáculo e os últimos podiam aterrissar dentro de um buraco.

O atraso adicional começa depois do 15º seguidor, cresce gradualmente e tem limite de 0,55 s. Hordas grandes continuam exigindo antecipação. O impulso é fixo em 610, sem altura comprada e sem salto duplo permanente. O toque antecipado no pouso mantém a duração real de um toque curto. A separação entre membros compara vizinhos por faixa, reduzindo o trabalho em hordas grandes.

## Poderes novos

| Poder | Onde | Comportamento | Evolução |
| --- | --- | --- | --- |
| Caçador Noturno | Terra | Uma criatura alada traz um civil pelo casaco e o solta para ser capturado de verdade. Nenhum zumbi é clonado. | 16 a 28 s; intervalo de 6 a 3,75 s entre passagens, sem sobreposição. |
| Manto Espectral | Terra | Espectro animado absorve dois impactos; buracos continuam fatais. | Duração de 8 a 14 s; quantidade de proteções fixa. |
| Simbionte Cósmico | Espaço | Companheiro alienígena com ácido automático contra naves e ataques contra ameaças próximas. | 7 a 13 s. |
| Escudo Orbital | Espaço | Três cargas para impactos e disparos. | Duração de 8 a 14 s; quantidade de cargas fixa. |

Os poderes podem ser liberados e evoluídos no mercado. O Caçador e o Manto também têm chamados consumíveis para iniciar a próxima corrida. Só um desses dois ajudantes pode ser preparado por vez; uma tentativa incompatível não consome estoque.

## Espaço

Arraste para guiar a horda na vertical. O botão **INVESTIDA** avança contra naves e destroços, com uma janela de ataque e recarga de 1,15 s. As naves têm integridade; a força da horda aumenta o dano de cada investida. Disparos inimigos têm aviso visual antes de atingir a faixa.

A barra de impulso enche com tempo, capturas, núcleos e destruições. Ao completar, a horda se reúne, prepara o corpo e se lança para a próxima camada. São quatro regiões: órbita terrestre, cemitério orbital, ninho alienígena e horizonte perdido. A duração do poder continua sendo 30, 40, 50 ou 60 s conforme a melhoria de Abdução Maldita.

O baralho de encontros inclui ônibus de excursão orbital, cargueiro infectado, caça, disco de invasão, fragata fantasma, meteoros, parasitas, drones e corredores de laser. Existem cápsulas com astronautas, ovos que eclodem, combustível, olhos, núcleos e poderes exclusivos. A composição, o número de perigos e a frequência dos ataques aumentam com hordas grandes. Os impactos retiram membros reais; perder a horda encerra a partida.

Destruir certas naves permite tomá-las durante oito segundos: o grupo embarca, a nave dispara e o casco suporta três impactos antes de ser perdido. A horda original retorna ao fim da pilotagem. Outras naves soltam passageiros, recursos ou parasitas. A fragata e o monólito aparecem nas camadas superiores.

As animações de flutuação, carga, impulso, abordagem, dano e reentrada usam quadros aprovados do zumbi e do esqueleto, com o mesmo movimento aplicado ao corpo e aos acessórios. Os PNGs antigos não são redesenhados.

A corrida terrestre e os túneis continuam avançando. A reentrada prepara o terreno uma vez, reduz a velocidade progressivamente, reorganiza os membros e concede um breve trecho seguro. Depois os encontros terrestres voltam.

## Moedas e melhorias

Removidas as melhorias permanentes de altura do salto e ímã. A migração devolve integralmente as moedas desses níveis uma única vez, sem apagar recordes, partidas, coleção ou poderes. O **Ímã de Expedição** custa 220 moedas, é comprado antes de jogar e vale apenas para uma partida.

Coletar uma formação completa de pelo menos três moedas mostra **PERFECT!** e toca um som original. Funciona na Terra e no espaço; uma formação com moeda perdida não concede a mensagem. Moedas isoladas e recompensas de destruição não contam como uma formação.

Esta compilação de testes mantém pelo menos **1.000.000 moedas e 10.000 olhos** na abertura normal. O botão de reposição continua na tela inicial e no desenvolvedor. Desative `testing/catalog_funds_enabled` e `testing/space_early_pickup_enabled` antes de uma publicação comercial.

## Referências consultadas e decisão de implementação

- Documentação oficial do Godot 4.5, [Jitter, stutter e atrasos](https://docs.godotengine.org/en/4.5/tutorials/rendering/jitter_stutter.html).
- Documentação oficial do Godot 4.5, [Uso de interpolação física](https://docs.godotengine.org/en/4.5/tutorials/physics/interpolation/using_physics_interpolation.html).
- Descrição do desenvolvedor de [Zombie Tsunami](https://play.google.com/store/apps/details?id=net.mobigame.zombietsunami&hl=en), para a referência pública de controle da horda com um toque.

A física e o acompanhamento da câmera são atualizados no passo fixo. A repetição dos comandos por coordenada do mundo é uma decisão própria baseada no diagnóstico do código deste projeto. Nenhum algoritmo interno de outro jogo foi acessado ou copiado. As diferenças entre jitter de câmera e custo de processamento foram tratadas separadamente; desempenho em Android físico ainda precisa de teste.

## Validação reproduzível

Importe em Godot 4.5.1 e execute `python3 tools/refresh_startup_integrity.py`. Depois execute as suítes `tests/v132_adventure.gd`, `tests/v131_startup.gd` (fixtures nova e existente), os testes históricos e `tests/verify_packaged_boot.gd`. `tests/v132_visual.gd` registra imagens do motor real e verifica toque e arraste. Não houve teste em telefone físico nesta sessão.

As novas artes originais e registros de recorte ficam em `tools/art_sources/v132` e `assets/art/adventure_v132`. Sons novos têm geração determinística em `tools/make_adventure_audio_v132.py`.
