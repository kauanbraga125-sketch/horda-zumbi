# Novas animações — civil feminina e esqueleto v0.8.13

Branch isolada: feat/garota-4-animacoes-esqueleto-idle-panic-0813

A atualização modifica apenas a variante civil feminina 1 e o esqueleto kind 1.
O civil azul, o trabalhador, o soldado, o policial e o zumbi original não são substituídos.

## Importar o pacote de imagens
Adicione SOMENTE o arquivo `novas_animacoes_v0813.zip`, entregue na conversa, ao caminho:

`monster-game/novas_animacoes_v0813.zip`

A action `.github/workflows/noite-da-horda-android.yml` extrai esse ZIP **depois** dos quatro sprites antigos do esqueleto e testa as dimensões das novas seis folhas antes da compilação.

Os novos atlas estão nestes caminhos:
- `assets/art/civil-feminina-v0813/idle.png` — 36 quadros, parada.
- `assets/art/civil-feminina-v0813/startle.png` — 36 quadros, susto ao ver a horda.
- `assets/art/civil-feminina-v0813/run.png` — 36 quadros, corrida.
- `assets/art/civil-feminina-v0813/capture.png` — 36 quadros, cair durante captura.
- `assets/art/esqueleto_aprovado/idle.png` — 15 quadros.
- `assets/art/esqueleto_aprovado/panic.png` — 15 quadros.

A garota tem tiles de 256x256 (6 colunas) e o esqueleto tiles de 384x288 (6 colunas), com pivô do pé e escala estáveis.

**O código tem fallback:** antes de enviar o ZIP, o jogo continua utilizando o visual antigo da garota e o rig antigo do esqueleto nos estados adicionais. Após importar as imagens, as novas animações são ativadas automaticamente.

Não copiar por cima de `rig-civilian-woman-v4.png`, `rig-zombie.png`, `zombie_sprite.gd` nem `sprites_aprovados.zip`.

O pacote inteiro também contém um instalador local para checkout da branch estável. As mudanças não foram mescladas na `main` e ainda exigem teste real do APK.
