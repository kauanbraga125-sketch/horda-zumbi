# Arte integrada na versão 0.10.4

`profile_icons.png`, `loss_icons.png` e `stat_panels.png` foram gerados com image_gen a partir da direção visual de perfil e perdas aprovada pelo usuário. Os valores e textos são desenhados pelo jogo, nunca incorporados nessas imagens.

`extraction.json` contém os retângulos de cada ilustração, pois o espaçamento do atlas de origem é irregular. Rode `monster-game/tools/prepare_v104_art.gd` pelo Godot para recortar os recursos e preparar dano/captura com a mesma origem das folhas novas.

Os metadados e as folhas de dano/captura preservam as animações aprovadas anteriormente. A caminhada e as três novas ações estão prontas em `monster-game/assets/art/masked_v104`. `manifest.json` nesse diretório documenta todos os tempos, a grade comum e as posições de encaixe da mão.
