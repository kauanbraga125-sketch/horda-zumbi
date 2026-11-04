# Horda Zumbi 0.10.46 — parede da queda alinhada ao piso

A queda aprovada na 0.10.45 é mantida. Esta correção remove a parte da parede que começava acima do chão e encobria a ponte e o cemitério ao fundo.

- O material subterrâneo começa na superfície física da rua e fica transparente acima dela, em vez de avançar aproximadamente 100 unidades para cima.
- A camada intermediária do cenário conserva sua altura e extensão originais à frente do buraco. A cor de fundo acompanha o recorte até o piso; assim, baixar a parede não reabre a faixa vazia da versão anterior.
- O terreno próximo continua terminando na borda real do buraco. A câmera, os movimentos, o tempo da queda, a mistura das raízes com o esgoto e o embarque permanecem iguais.

## Verificação

Godot 4.5.1, renderer OpenGL Compatibility:

- `tests/v146_ground_alignment.gd`: 39 verificações em 1280×720/6 membros, 1800×810/12 membros e 960×720/12 membros. Compara o fundo real com a parede ativada e desativada em quatro momentos por tela. Nenhum pixel amostrado acima do piso foi encoberto, e a parede preencheu todas as amostras imediatamente abaixo da borda.
- `tests/v145_surface.gd`: 21 verificações de continuidade nas mudanças de fase e de cenário definido pela profundidade.
- `tests/v144_descent.gd`: 48 verificações de recorte da rua e passagem à galeria.
- `tests/v145_preview.gd`: nova gravação da versão 0.10.46, com 420 quadros/14 s a 30 fps. A comparação dos metadados com a prévia da 0.10.45 encontrou movimentos, posições, câmera, fases e borda idênticos em todos os quadros.
- `tests/v141_startup.gd`: inicialização comum com dados novos, sem desviar da auditoria; 15 verificações.

Os quadros críticos da aproximação e da queda foram examinados em sequência, com detalhes em resolução original. A gravação isola a transição, desativando perigos após o embarque, e não contém áudio.

O workflow `horda-transicao-visual.yml` inclui a nova verificação de alinhamento e produz a prévia da revisão atual. Para reproduzir localmente, importe o projeto, atualize `startup_integrity.json` com `tools/refresh_startup_integrity.py` e execute cada teste gráfico com `HORDA_VALIDATION_DIR` apontando para uma pasta absoluta de resultados. Os parâmetros de captura e Xvfb estão no [guia da 0.10.45](TRANSICAO-v0.10.45.md).

Resultados e hashes das entregas: `VALIDACAO-v0.10.46.json`. Ainda não houve teste em aparelho Android físico.
