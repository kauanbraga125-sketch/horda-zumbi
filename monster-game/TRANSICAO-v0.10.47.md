# Horda Zumbi 0.10.47 — o esgoto aparece durante a queda

A revisão anterior deixava uma linha roxa horizontal no fim da pista e mostrava a parede do subterrâneo antes de a horda cair. Agora existe espaço livre abaixo da borda: a câmera acompanha a queda, o cemitério recua para cima e a alvenaria aparece progressivamente em uma emenda irregular de névoa.

## O que mudou

- A parede começa pelo menos 180 unidades abaixo da superfície. A profundidade inicial se ajusta ao enquadramento enquanto ainda está fora de vista e fica fixa no mundo assim que o primeiro membro cai.
- O zoom começa a abrir após a saída real do primeiro pé da pista. A poeira também acompanha esse momento, em vez do relógio de ativação do evento.
- O fundo distante sobe a 40% do deslocamento da borda física. As raízes próximas acompanham o avanço do mundo; a galeria mantém seu movimento mais lento. Isso dá referências visíveis de profundidade durante a descida.
- As camadas intermediária e próxima perdem opacidade nas bordas inferiores; a vegetação próxima também se dissolve ao chegar ao buraco. A camada mais distante continua intacta para preservar sua composição com o céu.
- O retângulo de recorte do fundo termina atrás da parede já opaca. A pista física continua terminando na borda verdadeira, separadamente do cenário distante.

A gravidade de 460 unidades/s², a profundidade da queda de 1.100 unidades e a duração de entrada de 5,7 s foram mantidas. O enquadramento mudou; as imagens desta revisão não têm a mesma câmera da 0.10.46. Os sistemas existentes de assentos, cosméticos, comandos, colisões, resgates e saída continuam em uso.

## Verificação

Godot 4.5.1, renderer OpenGL Compatibility/Mesa llvmpipe:

- `v147_reveal.gd`: 52 verificações em 16:9, tela larga e 4:3, incluindo 4:3 com câmera inicialmente afastada. A substituição das texturas por magenta não altera pixels antes da queda e altera milhares de pixels mais abaixo, confirmando que o teste detecta a parede quando ela aparece. Acima da pista, nenhuma amostra foi encoberta. Estender o recorte do fundo não expõe emenda.
- `v144_descent.gd`: 48 verificações de terreno físico e continuidade da chegada à galeria. O teste alcança a borda pelo percurso real. O terreno é isolado do fundo distante para verificar que os ladrilhos não continuam dentro do buraco.
- `v145_surface.gd`: 21 verificações de continuidade. Ativar a entrada e alterar apenas o relógio, mantendo a profundidade, não mudaram pixels amostrados do fundo nas três telas. As passagens entrada/navegação/saída permanecem dentro das tolerâncias registradas.
- `v141_transitions.gd`: 37.424 verificações e 51 capturas de trajetórias, enquadramento, identidade dos membros e retorno.
- `v140_sewer.gd`: 230 verificações de mecânica do esgoto.
- `v145_full_cycle.gd`: evento completo de 50 s/1.500 quadros com toques reais. Houve cinco capturas, uma perda no barril deliberadamente ignorado, três comandos de abaixar e retorno vivo à corrida com dez membros.
- `v141_startup.gd`: inicialização comum da 0.10.47 com dados novos e existentes, sem desviar da auditoria: 15 e 16 verificações.
- `v147_preview.gd`: gravação final da 0.10.47 com 420 quadros/14 s, 1280×720 a 30 fps. Perigos desativados após o embarque para observar o cenário; captura sem áudio.

Os 120 quadros consecutivos 70–189 da aproximação, queda e embarque foram examinados em sequência, com detalhes em tamanho original e capturas adicionais nas outras proporções de tela. Foram necessárias quatro passagens de trabalho antes da gravação final. Os testes de runtime ocorreram antes da mudança do rótulo do projeto para 0.10.47; seus campos originais de versão foram preservados no relatório. Os metadados de todos os 420 quadros da gravação final coincidem com a passagem visual revisada.

O teste histórico `v146_ground_alignment.gd` exigia uma parede preenchendo o espaço imediatamente abaixo da pista. Esse requisito causava a exposição precoce reclamada. O workflow atual usa `v147_reveal.gd` para exigir espaço livre antes da queda, parede visível em profundidade e preservação da imagem acima da pista. Os testes de ausência de terreno continuam independentes.

Resultados, limites e hashes: `VALIDACAO-v0.10.47.json`. Ainda não houve teste em Android físico.

## Reprodução

Na raiz do repositório, com Godot 4.5.1 e Xvfb instalados:

```bash
godot --headless --path monster-game --editor --import
python3 monster-game/tools/refresh_startup_integrity.py
HORDA_VALIDATION_DIR=/tmp/horda-reveal xvfb-run -a godot --path monster-game --audio-driver Dummy --rendering-method gl_compatibility --script res://tests/v147_reveal.gd
HORDA_VALIDATION_DIR=/tmp/horda-preview xvfb-run -a godot --path monster-game --audio-driver Dummy --rendering-method gl_compatibility --script res://tests/v147_preview.gd
ffmpeg -framerate 30 -i /tmp/horda-preview/frame-%04d.jpg -c:v libx264 -crf 20 -pix_fmt yuv420p -movflags +faststart /tmp/Horda-v0.10.47-Previa.mp4
```

O workflow `horda-transicao-visual.yml` executa os testes gráficos, grava a revisão atual e disponibiliza vídeo, quadros e relatórios. O workflow de APK compila os fontes atuais e verifica o pacote separadamente.
