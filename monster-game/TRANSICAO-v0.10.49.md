# Horda Zumbi 0.10.49 — jet skis individuais e chegada ao esgoto

Cada integrante recebe um jet ski compacto com um único assento. Os seis personagens da prévia navegam em seis veículos, em duas fileiras alternadas. A névoa da descida fica mais densa, e a câmera leva a parede superior para fora da tela após o embarque do grupo.

## Veículos e movimentos

- Novo casco roxo e dourado, com banco curto, guidão e caveira na proa, seguindo o veículo anterior. O sprite tem transparência real; o casco é desenhado atrás do piloto e sua borda inferior passa à frente dos pés.
- Cada veículo pertence a um único ID de integrante. Resgates acrescentam veículos; perdas removem apenas o veículo correspondente. Os lugares existentes permanecem estáveis. A distribuição inicial considera as posições na pista para que os personagens avancem para a abertura durante a queda.
- A formação usa colunas e fileiras alternadas, com câmera ajustada ao tamanho da horda. Os pilotos mantêm seus cosméticos, poses de condução e de abaixar. Cada casco recebe balanço, inclinação, rastro e espuma próprios.
- A água geral fica atrás dos pilotos, evitando que os integrantes das fileiras inferiores pareçam transparentes. Espuma local e respingos conectam cada veículo à água.
- A rampa de saída mantém uma velocidade fixa durante a sequência. A altura de lançamento parte da altura real de cada casco, inclusive para um sobrevivente recém-resgatado. A câmera acompanha o retorno de todos os integrantes à pista.
- Coletas e resgates compensam a profundidade visual das fileiras, preservando seu acesso para os sobreviventes das fileiras inferiores.

O sprite de execução está em `assets/art/v149/jetski_solo.webp` (1024×451); a fonte está em `tools/art_sources/v149/jetski_solo.webp`. A referência, o prompt completo e a âncora do piloto constam de `assets/art/v149/manifest.json`.

## Névoa e parede

Os bancos de névoa ganham densidade e uma concentração adicional sobre a junção entre as fundações e a galeria. A animação continua espacial e acompanha o relógio visual do jogo, congelando durante a pausa. Não foi necessário acrescentar uma sequência de sprites para a névoa.

A junção entre os materiais passa a uma faixa curta de 28 unidades, com borda irregular. Ela não depende de um relógio para desaparecer. Após todos os integrantes embarcarem, a câmera conclui a descida e deixa toda essa junção acima do limite visível, em vez de mantê-la como parede translúcida. A galeria permanece visível e opaca.

## Verificação nativa

Godot 4.5.1, OpenGL Compatibility/Mesa llvmpipe, fontes da versão 0.10.49:

| Verificação | Resultado |
| --- | --- |
| `v149_solo.gd` | 44.405 verificações e 35 capturas; 6, 12, 20 e 64 pilotos, em 16:9, tela larga e 4:3; um integrante por veículo, enquadramento, embarque, comandos reais de salto/abaixar, resgate, perda e retorno contínuo |
| `v141_transitions.gd` | 37.649 verificações e 51 capturas de trajetórias e câmera |
| `v140_sewer.gd` / `v140_systems.gd` | 235 / 66 verificações de mecânicas, incluindo coletas e resgates nas fileiras inferiores |
| `v141_journeys.gd` | 5.163 verificações de jornadas, identidades, embarque, resgates e retorno |
| `v144_descent.gd` / `v145_surface.gd` | 48 / 21 verificações de terreno, recorte e continuidade entre fases |
| `v147_reveal.gd` | 52 verificações de revelação por profundidade e preservação da superfície |
| `v148_fog.gd` | 21 verificações de movimento da névoa, pausa, opacidade da parede e estabilidade da galeria inferior |
| `v141_startup.gd` | 15 verificações com dados novos; auditoria de 298 arquivos e 55 classes |
| `v145_full_cycle.gd` | 1.500 quadros/50 s com comandos reais; evento concluído e retorno à pista com 9 integrantes; 5 capturados, 2 perdas e 3 comandos de abaixar |
| `v149_preview.gd` | 420 quadros/14 s a 30 fps, 1280×720; aproximação, queda e embarque reais |

Todas as verificações acima terminaram sem falhas. No evento completo, os contatos ocorreram em um desabamento e em um barril deliberadamente não evitado pelo controlador da gravação. A prévia curta desativa perigos depois do embarque para permitir examinar o cenário e os veículos; ela não contém áudio.

Os 144 quadros consecutivos 70–213 da prévia foram examinados em sequência, além dos quadros 125, 190 e 240 em tamanho original e capturas em outras proporções de tela. A comparação com a 0.10.48 usa os mesmos instantes do trecho; as posições finais e o enquadramento mudam para acomodar os veículos individuais.

Os resultados, medições e hashes estão em `VALIDACAO-v0.10.49.json`. O workflow gráfico inclui a formação individual e gera vídeo e relatórios da versão atual; o workflow Android compila os fontes e verifica o pacote. Ainda não houve teste em Android físico ou medição de desempenho nesse aparelho.

## Reprodução

```bash
godot --headless --path monster-game --editor --import
python3 monster-game/tools/refresh_startup_integrity.py
HORDA_VALIDATION_DIR=/tmp/horda-solo xvfb-run -a godot --path monster-game --audio-driver Dummy --rendering-method gl_compatibility --script res://tests/v149_solo.gd
HORDA_VALIDATION_DIR=/tmp/horda-fog xvfb-run -a godot --path monster-game --audio-driver Dummy --rendering-method gl_compatibility --script res://tests/v148_fog.gd
HORDA_VALIDATION_DIR=/tmp/horda-preview xvfb-run -a godot --path monster-game --audio-driver Dummy --rendering-method gl_compatibility --script res://tests/v149_preview.gd
```
