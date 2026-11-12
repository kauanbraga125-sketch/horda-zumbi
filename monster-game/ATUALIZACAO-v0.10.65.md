# 0.10.65 — cenários e efeitos completos do céu

As regiões restantes do céu receberam três artes novas e efeitos integrados: santuário espectral para o ancião, observatório nas tempestades para dragão e bruxa, e cemitério orbital para leviatã, nave abandonada e olhos. As duas regiões orbitais compartilham uma textura, carregada uma única vez. Névoa, luzes de altares, rastros de vento, pequenos destroços e veículos distantes ajudam a estabelecer profundidade e escala.

Ancião, dragão, bruxa, vaga-lumes e as pequenas criaturas de passagem agora seguem regiões e trajetórias do mundo. O enquadramento não redefine sua altitude e não há retorno vertical por módulo da altura da tela. Voos e oscilações continuam sendo movimentos próprios das criaturas. Os olhos ganharam uma cavidade de poeira e referências de escala; a nave e o leviatã têm véus de nebulosa à frente. O duelo cósmico ganhou poeira e efeitos de impacto no mesmo plano distante.

Serra, gigante caminhante, planeta e devorador permanecem como na composição aprovada. As regras da horda, impulsos, capturas, obstáculos e as três rotas físicas não mudaram. Os novos elementos de fundo não criam piso ou colisões.

## Entrega e validação

- Versão Android **168**, aplicativo de teste **Horda GitHub Teste**, pacote `com.kauan.noitedahorda.github`, ARM64.
- 564 verificações das novas regiões, cache e posições; 27 casos das rotas; 1.800 verificações da abertura e do horizonte; 223 da serra; 153 dos marcos cósmicos. Sem falhas.
- Inicialização no Godot 4.5.1: 348 recursos e 55 classes conferidos, cena principal carregada.
- Auditoria atualizada para incluir também as artes 0.10.63, 0.10.64 e 0.10.65 na compilação automática.
- Gravação contínua de 52,53 s, 1.576 quadros a 30 fps, pico de 381,30 m e retorno à rua com 14 membros e 9 almas. Eventos, entradas e percurso preservados em relação à 0.10.64.

O APK é compilado dos fontes pelo Actions, alinhado e assinado com a identidade de teste mantida pelo workflow. A compilação confere o conteúdo e abre novamente os recursos extraídos do APK. Isso não substitui o teste em aparelho físico.

## Reproduzir

Use Godot **4.5.1 stable**. Após importar e atualizar a auditoria:

```bash
HORDA_VALIDATION_DIR=/tmp/horda-v165 godot --headless --path monster-game --script res://tests/v165_regions.gd
HORDA_VALIDATION_DIR=/tmp/horda-v165 godot --headless --path monster-game --script res://tests/v161_routes.gd
HORDA_VALIDATION_DIR=/tmp/horda-v165 godot --headless --path monster-game --script res://tests/v162_regression.gd
HORDA_VALIDATION_DIR=/tmp/horda-v165-frames godot --path monster-game --fixed-fps 30 --script res://tests/v165_preview.gd
```

A gravação requer display OpenGL. Os toques são programados pela interface normal e o encontro inicial é preparado no laboratório. Nenhuma carga, velocidade, altitude ou regra de colisão é alterada durante o voo. A origem das novas artes está em `assets/art/v165/SOURCE.md`.
