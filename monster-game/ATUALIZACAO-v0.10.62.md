# 0.10.62 — horizonte e abertura persistente

O gigante que caminha deixou de usar a altura variável do enquadramento e a oscilação vertical da câmera. Sua posição pertence a um plano distante, com paralaxe de 0,018, passada mais lenta, escala menor, contraste reduzido e duas camadas de névoa à frente. A subida da horda não altera a animação vertical do gigante.

A escolha do pula-pula consome a decisão de rota, mas preserva a geometria da abertura do esgoto. A abertura mantém posição, largura, recorte do cenário e colisão até a margem direita sair da tela. Se um impacto derrubar a horda sobre a mesma abertura, ela continua sendo uma entrada válida do esgoto. A pintura do céu permanece ativa durante esse intervalo.

As três rotas da 0.10.61 continuam funcionando: salto curto para o pula-pula, corrida para cair no esgoto e salto segurado para atravessar pela rua.

## Verificação

- 27 casos de regressão das três rotas, sem falhas.
- 1.800 verificações do horizonte e da abertura, sem falhas, incluindo hordas de 1, 6 e 20 membros, projeções em três tamanhos de tela e retorno sobre o mesmo buraco.
- Inicialização com Godot 4.5.1: 338 recursos e 55 classes conferidos, cena principal carregada.
- Gameplay contínua gravada no próprio Godot: 1.576 quadros a 30 fps (52,53 s), pico de 381,30 m, passagem pelo Universo Maligno e retorno à rua com 14 membros e 9 almas.
- A gravação usa toques programados pela interface normal, impulsos, capturas e perigos reais. Não altera altitude, velocidade, cargas ou colisões durante o voo. A entrada é preparada no laboratório de rotas para começar diretamente no encontro.

O vídeo usa renderização OpenGL Compatibility em desktop. Instalação e desempenho em aparelho Android físico ainda não foram verificados nesta versão.

## Reproduzir

Use Godot **4.5.1 stable**. Após importar os fontes e atualizar `startup_integrity.json`, execute:

```bash
godot --headless --path monster-game --script res://tests/v161_routes.gd
HORDA_VALIDATION_DIR=/tmp/horda-v162 godot --headless --path monster-game --script res://tests/v162_regression.gd
HORDA_VALIDATION_DIR=/tmp/horda-v162-frames godot --path monster-game --fixed-fps 30 --script res://tests/v162_preview.gd
```

A última execução precisa de um display com OpenGL e salva quadros JPEG e um relatório com os toques e o percurso. Os testes e ferramentas ficam excluídos da exportação Android. O código Android desta versão é **165**.
