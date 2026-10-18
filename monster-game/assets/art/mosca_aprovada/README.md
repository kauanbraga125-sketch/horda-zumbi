# Mosca Mutante — teste Android 0.8.13

A base desta branch é `feat/garota-4-animacoes-esqueleto-idle-panic-0813` no commit `4d0b752`. Zumbi, esqueleto e civis não foram alterados.

## Carregamento de sprites (necessário para gerar o APK)
Copie estes seis PNGs do arquivo `HordaZumbi_Mosca_v0813_Pacote_Integracao.zip` para a pasta `monster-game/assets/art/mosca_aprovada/` **nesta branch**:

- `voo.png` — 2304×1728, 36 quadros
- `corrida.png` — 2304×1440, 30 quadros
- `pouso.png` — 2304×1152, 24 quadros
- `captura.png` — 2304×1728, 36 quadros
- `push.png` — 2304×1728, 36 quadros
- `dano.png` — 2304×864, 16 quadros

Os arquivos são RGBA de 384×288 por célula e 6 colunas, normalizados preservando a paleta original.

A integração é exclusiva da Mosca (kind 3) para estados idle/rise/fly, run, fall, capture, push e panic. A animação de dano possui flash e partículas. A colisão, o zumbi, o esqueleto e os civis mantêm a lógica original.

Depois de enviar os seis PNGs em um commit, o workflow `noite-da-horda-mosca.yml` é acionado automaticamente. Baixe o APK no artefato **Horda-0813-Mosca-Atualizada** da execução aprovada. O pacote Android é `com.kauan.noitedahorda.mosca0813` para não sobrescrever builds instaladas. A geração não foi executada sem os PNGs.
