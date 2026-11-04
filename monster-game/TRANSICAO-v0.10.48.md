# Horda Zumbi 0.10.48 — neblina na descida

A faixa entre o cemitério e o esgoto recebe bancos de neblina em movimento. A borda superior da alvenaria deixa de usar uma transparência longa: a parede fica sólida por trás da névoa, que acompanha a descida e sai do enquadramento com o cenário.

## Ajuste visual

- A névoa tem duas concentrações sobrepostas, variação de densidade e correntes lentas em sentidos diferentes. Tons lilás, cinza e azul esverdeado conectam as cores da superfície e do esgoto.
- O efeito ocupa a abertura e a emenda em coordenadas do mundo. Sua densidade depende da profundidade; o tempo só anima as nuvens. Não existe um instante que desliga o efeito ou troca o cenário.
- A faixa de mistura da borda da parede passa de 130 para 28 unidades. Abaixo dela, o material é opaco: o cemitério não atravessa a alvenaria. A névoa cobre essa borda curta sem tornar a parede inteira transparente.
- A animação usa o relógio visual do jogo e fica parada na pausa, nos resultados e na tela de reviver. O efeito permanece atrás dos personagens e termina antes da galeria inferior.

A câmera, os movimentos, as poses, a física e os assentos da 0.10.47 foram preservados. A comparação dos metadados das duas prévias encontrou os mesmos valores em todos os 420 quadros, incluindo posições dos membros, profundidade, fases, câmera, borda e geometria.

## Verificação

Godot 4.5.1, renderer OpenGL Compatibility/Mesa llvmpipe, versão 0.10.48:

- `v148_fog.gd`: 21 verificações em 1280×720/6 membros, 1800×810/12 e 960×720/12. Com o cenário e a câmera imóveis, alterar o relógio move milhares de amostras da névoa; não altera a galeria inferior. Trocar o fundo distante entre preto e magenta não muda nenhuma amostra atrás da parede sólida. O controle positivo detecta essa troca no espaço aberto acima da parede. A pausa congela o relógio e a imagem do efeito.
- `v147_reveal.gd`: 52 verificações de revelação da parede, preservação da superfície e ausência de emenda no recorte, incluindo 4:3 com câmera inicialmente afastada.
- `v145_surface.gd`: 21 verificações de continuidade ao ativar a entrada, alterar apenas o relógio da fase, embarcar e iniciar a saída.
- `v141_startup.gd`: 15 verificações na abertura comum com dados novos, incluindo a auditoria de 296 arquivos.
- `v148_preview.gd`: 420 quadros nativos/14 s, 1280×720 a 30 fps. Aproximação, queda e embarque reais; perigos desativados após o embarque para examinar o cenário. Captura sem áudio.

Os 120 quadros consecutivos 70–189 foram revistos visualmente em sequência. Os quadros 110, 125 e 140 também foram examinados em tamanho original e comparados à 0.10.47; foram conferidas capturas nas outras duas proporções de tela. A gravação enviada pelo usuário é idêntica à prévia nativa da 0.10.47 usada nessa comparação.

Os resultados e hashes estão em `VALIDACAO-v0.10.48.json`. A validação do evento completo com comandos, capturas e retorno está em `VALIDACAO-v0.10.47.json`; os sistemas de jogo não mudaram nesta revisão. Ainda não houve teste em Android físico ou medição de desempenho nesse aparelho.

## Reprodução

Importe o projeto com Godot 4.5.1 e atualize a auditoria:

```bash
godot --headless --path monster-game --editor --import
python3 monster-game/tools/refresh_startup_integrity.py
HORDA_VALIDATION_DIR=/tmp/horda-fog xvfb-run -a godot --path monster-game --audio-driver Dummy --rendering-method gl_compatibility --script res://tests/v148_fog.gd
HORDA_VALIDATION_DIR=/tmp/horda-preview xvfb-run -a godot --path monster-game --audio-driver Dummy --rendering-method gl_compatibility --script res://tests/v148_preview.gd
```

O workflow `horda-transicao-visual.yml` inclui o novo teste de névoa e entrega vídeo, quadros e relatórios da versão atual.
