# Horda Zumbi 0.10.45 — da rua ao esgoto por um cenário conectado

A entrada anterior mostrava uma parede inteira de repente e sobrepunha uma viga à trajetória da horda. Agora o fim da rua revela um poço cuja terra e raízes se transformam em fundações úmidas e na própria galeria do esgoto.

## Comportamento

- A aproximação e a descida usam a mesma rua recortada e a mesma parede de fundo. Iniciar a queda não troca as camadas.
- Uma textura nova liga os materiais do terreno à alvenaria. Um material único mistura essa arte com o esgoto existente por profundidade, com uma borda irregular; a mudança não depende de um instante da animação.
- A galeria fica a uma distância fixa da água em coordenadas do mundo. A câmera a revela durante a queda e a mantém ao começar a navegação.
- O chão termina na coordenada da física. Cada membro cai ao cruzar a borda; a câmera acompanha os membros e abre o enquadramento para conservar a horda na tela.
- A queda tem 1.100 unidades de profundidade, gravidade de 460 unidades/s² e uma entrada total de 5,7 s, incluindo embarque e preparação da navegação.
- Poeira permanece na borda rompida. Respingos acompanham o deslocamento da câmera e a enchente cresce gradualmente a partir da água.
- A entrada não desenha o arco horizontal dos túneis nem a viga de junção da revisão anterior.

Personagens, cosméticos, lugares nos jet skis, saltos, abaixar, capturas, colisões e retorno à corrida usam os sistemas existentes. A nova arte, suas referências e seu prompt estão em `assets/art/v145/manifest.json`.

## Verificação reproduzível

Use Godot 4.5.1. Importe o projeto com `--headless --editor --import --quit`, execute `python3 tools/refresh_startup_integrity.py` e use `--path . --script res://tests/NOME.gd` na pasta do projeto.

- `v140_sewer.gd`: 230 verificações de mecânica, identidade dos membros, lugares, comandos, colisões, resgates e retorno, com hordas de até 64 membros.
- `v141_transitions.gd`: 37.424 verificações de trajetórias, chão, enquadramento e retorno; 51 capturas em 1280×720, 1800×810 e 960×720.
- `v144_descent.gd`: 48 verificações de recorte da rua e continuidade da galeria. A camada subterrânea é isolada corretamente no teste do recorte.
- `v145_surface.gd`: 21 verificações, incluindo imagens antes/depois da ativação da queda, invariância do cenário em relação ao relógio, passagem à navegação e início da saída. A ativação da queda não mudou nenhum pixel amostrado do fundo nas três telas.
- `v145_preview.gd`: 420 quadros nativos, 14 s a 30 fps, com metadados por quadro. Os perigos da navegação são desativados depois do embarque para examinar a transição. A captura é sem áudio.
- `v145_full_cycle.gd`: 1.500 quadros nativos, 50 s a 30 fps, com comandos reais de toque, salto, abaixar, resgates e retorno. Um barril é deliberadamente ignorado para verificar o impacto. A horda termina viva, com 10 membros após 5 capturas e uma perda.
- `v141_startup.gd`: inicialização comum, sem desviar da auditoria, com dados novos e existentes; 15 e 16 verificações. Use pastas novas em `XDG_DATA_HOME`, `HORDA_STARTUP_FIXTURE=new` ou `existing` e `HORDA_STARTUP_WIDE=1` para o caso largo.

Os testes gráficos e capturas exigem uma tela real ou Xvfb; `tools/run_godot.py` inicia o renderer nativo. Configure `HORDA_VALIDATION_DIR` com uma pasta absoluta vazia para os resultados.

A revisão examinou todos os 420 quadros da entrada em sequência e detalhes em resolução original, além do ciclo completo e das outras proporções de tela. Os resultados e hashes das entregas estão em `VALIDACAO-v0.10.45.json`. A validação foi feita no renderer nativo de desktop; ainda não houve teste em aparelho Android físico.
