# Horda Zumbi 0.10.4

Abra `monster-game/project.godot` com Godot 4.5.1 stable e GL Compatibility.

## Mudanças

O Mascarado agora usa as seis animações aprovadas: caminhada, pulo, pouso, captura, dano e virada de veículo. Todas compartilham célula de 512 × 512, origem (224, 480) e altura de referência de 414 px. A escala não é recalculada pela silhueta de cada pose. O salto continua respondendo ao comando imediatamente; as poses no ar acompanham a velocidade vertical e o pouso começa no contato real com o chão.

A captura mantém os tempos de jogo (0,62 s para civil e 0,82 s para soldado), usando as mãos da animação como ponto de encaixe do civil. A virada mantém contagem, moedas e resgates; a rotação visual acompanha a preparação do Mascarado. A reação de dano aparece na proteção por escudo e na perda do membro.

O Perfil da Horda segue a referência aprovada: melhor partida em destaque, oito cartões ilustrados, molduras roxas/douradas e números inteiros. Perdas da Horda mostra todas as 12 causas atuais mesmo quando zeradas, mais total e maior causa. Nomes antigos de veículos e quedas são agrupados; registros históricos desconhecidos aparecem em Outras perdas. Os valores vêm do progresso real do jogador.

| Registro | Rótulo no menu |
| --- | --- |
| fall | Buracos e quedas (inclui chão que cede) |
| camera | Ficou para trás |
| air_bomb | Bombas aéreas |
| rushing_car | Atropelamentos |
| bullet | Tiros do soldado |
| rocket_explosion | Foguetes do soldado |
| bomb | Bombas no chão |
| helicopter | Helicópteros |
| spikes | Espinhos |
| crate | Caixas |
| hump | Lombadas |
| vehicle | Colisões com veículos |

## APK e progresso existente

Instale `Horda-Zumbi-v0.10.4.apk` sobre a versão anterior. O pacote é `com.kauan.noitedahorda.playtest091`, versionCode 104, com a mesma assinatura do playtest 0.9.1/0.10.3. O nome interno `Horda Zumbi 0.9.1` é mantido para conservar a pasta de dados. Não desinstale a versão anterior nem limpe seus dados para atualizar.

## Importar e validar

```bash
godot --headless --path monster-game --editor --import
python3 monster-game/tools/refresh_startup_integrity.py
```

Execute as suítes `v100_integration`, `v101_integration`, `v103_codex`, `v103_apk_runtime` e `v104_integration`:

```bash
godot --headless --path monster-game --script res://tests/v104_integration.gd
```

A suíte 0.10.4 verifica as seis artes, alinhamento e escala comuns, entrada de salto, pouso real, tempos e recompensas de captura, virada sem recompensa duplicada, proteção e morte por tiro, todas as causas, migração de registros e disposição dos botões em diferentes larguras. `tests/v104_visual_capture.gd` captura as duas telas e as ações no renderizador real do Godot; indique a pasta de saída em `HORDA_VALIDATION_DIR`.

## Construir com a base preservada

```bash
godot --headless --path monster-game --export-pack Android /caminho/resources.zip
python3 monster-game/tools/build_v104.py \
  --base /caminho/Horda-Zumbi-v0.10.3.apk \
  --resources /caminho/resources.zip --source monster-game \
  --output /caminho/Horda-Zumbi-v0.10.4.apk \
  --signing-zip /caminho/privado/Assinatura.zip \
  --signer-jar /caminho/apksigner.jar
```

O construtor preserva as bibliotecas nativas da base, mantém scripts em texto, atualiza a versão Android e regenera o índice esparso e a auditoria de inicialização com os bytes finais. A chave privada fica fora do repositório.

As ilustrações de origem e os retângulos de extração estão em `art-source/v0.10.4`. `tools/prepare_v104_art.gd` extrai os ícones e normaliza dano e captura no Godot; as quatro outras folhas já estão em `assets/art/masked_v104`. Esta entrega foi validada em Godot/Linux e por inspeção estrutural e criptográfica do APK. Não foi executada em um aparelho Android físico nesta sessão.
