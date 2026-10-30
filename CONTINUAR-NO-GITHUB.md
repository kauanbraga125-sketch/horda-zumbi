# Continuar o Horda Zumbi pelo GitHub

A base atual é **0.10.41**, preservada na tag [v0.10.41](https://github.com/kauanbraga125-sketch/horda-zumbi/releases/tag/v0.10.41). Os fontes completos, sprites, áudio, licenças e testes estão em [`monster-game/`](monster-game/). Nenhum serviço deste chat é necessário para editar ou compilar.

## Editar e baixar um novo APK

1. Abra [`monster-game/`](monster-game/) na branch **main**. Use o lápis para editar um arquivo ou pressione **.** no repositório para abrir o editor web do GitHub.
2. Salve suas mudanças com **Commit changes**. Para trabalhar separado, crie uma branch e um pull request; a compilação também roda no pull request.
3. Abra [Actions → Horda Zumbi — compilar APK dos fontes](https://github.com/kauanbraga125-sketch/horda-zumbi/actions/workflows/horda-compilar-apk.yml).
4. A compilação começa após alterações em `monster-game/`. Para iniciar manualmente, clique em **Run workflow**, escolha a branch e deixe `assinatura: teste`.
5. Espere a execução ficar verde. Abra-a e, no fim da página, baixe **Artifacts → Horda-Zumbi-APK-teste-…**. Extraia o ZIP e instale o arquivo `.apk`.

O APK é **ARM64**, compatível com o Moto G71 5G, Android mínimo 24. A compilação de teste funciona imediatamente, sem cadastrar senhas. Ela instala como **Horda GitHub Teste**, pacote `com.kauan.noitedahorda.github`, com progresso separado. A identidade de teste fica no cache do Actions. Se o GitHub apagar esse cache por inatividade, pode ser necessário desinstalar **somente a edição de teste** para instalar a próxima compilação.

Os artefatos das execuções ficam disponíveis por até 90 dias; execute novamente quando precisar de outro download. O [APK oficial 0.10.41](https://github.com/kauanbraga125-sketch/horda-zumbi/releases/download/v0.10.41/Horda-Zumbi-v0.10.41-TESTE-1M-ESGOTO-ARM64.apk) permanece na release.

## Onde mexer

| O que mudar | Arquivos principais |
| --- | --- |
| Corrida, formação, saltos | `monster-game/scripts/runner.gd` |
| Evento do esgoto, queda e embarque | `monster-game/scripts/sewer.gd` |
| Jet-skis, onda e composição visual | `monster-game/scripts/sewer_presentation.gd` |
| Chão e HUD | `monster-game/scripts/gameplay_ui.gd` |
| Cenários e camadas da rua | `monster-game/scripts/scene.gd` |
| Câmera e fluxo do jogo | `monster-game/scripts/game.gd` |
| Sprites e áudio | `monster-game/assets/art/` e `monster-game/assets/audio/` |
| Versão e opções de teste | `monster-game/project.godot` |
| Código de versão Android | `monster-game/export_presets.cfg`, campo `version/code` |
| Compilação editável | `.github/workflows/horda-compilar-apk.yml` e `monster-game/tools/ci_android_build.py` |

Para outra versão, altere `application/config/version` em `project.godot` e aumente `version/code` em `export_presets.cfg`. O nome do APK acompanha a versão do projeto. O compilador usa pelo menos código Android **145**, acima da base publicada, e respeita códigos maiores definidos no preset.

## Como esta compilação funciona

O workflow importa os arquivos atuais com **Godot 4.5.1**, atualiza a auditoria, exporta todos os recursos novamente e substitui **todo o conteúdo do jogo** no APK. O APK 0.10.41 é baixado e conferido por SHA256 apenas como base nativa Android/Godot. Scripts, cenas, sprites, metadados e áudios vêm do commit escolhido, inclusive novos arquivos. Uma cópia temporária evita modificar os fontes durante a compilação.

O índice de recursos e a auditoria são recriados; o APK é alinhado, assinado e verificado. A abertura é testada novamente com os arquivos extraídos do novo APK. O artefato inclui commit, SHA256 e relatório em `compilacao.json`. Isso verifica o pacote e sua inicialização, sem substituir o teste em celular físico.

Os workflows históricos **Horda Zumbi 0.10.xx — …** recuperam entregas antigas. Para compilar suas alterações, escolha sempre **Horda Zumbi — compilar APK dos fontes**. A validação completa dos fontes continua em outro workflow.

## Gerar atualização com a assinatura original

Para o novo APK atualizar a edição oficial instalada e manter seus dados, ele precisa da chave original do proprietário. Essa chave está no backup privado entregue, e não no repositório público.

Em **Settings → Secrets and variables → Actions → New repository secret**, cadastre:

| Secret | Valor |
| --- | --- |
| `HORDA_ANDROID_KEYSTORE_BASE64` | Conteúdo do keystore original convertido para Base64, em uma linha |
| `HORDA_ANDROID_KEY_ALIAS` | Alias original do keystore |
| `HORDA_ANDROID_KEYSTORE_PASSWORD` | Senha original do keystore |
| `HORDA_ANDROID_KEY_PASSWORD` | Opcional; só se a chave tiver senha diferente do keystore |

Converta o arquivo localmente. Linux/macOS: `base64 < horda-reconstruida.keystore | tr -d '\n'`. PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes('horda-reconstruida.keystore'))`. Cole o resultado diretamente no Secret; nunca em commits, issues ou logs.

Depois execute **Run workflow → assinatura: oficial**. O resultado usa o pacote `com.kauan.noitedahorda.reconstruida` e só é aprovado se o certificado corresponder ao original. Os Secrets oficiais só são fornecidos a uma execução manual no modo oficial. Pull requests e compilações automáticas usam a identidade de teste.

## Abrir no Godot fora do GitHub

Clone o repositório e importe `monster-game/project.godot` no **Godot 4.5.1 stable**. Execute `python3 monster-game/tools/refresh_startup_integrity.py` após a importação ou depois de editar scripts/recursos auditados, antes de abrir o jogo. A compilação do Actions já faz isso automaticamente.

Antes de um lançamento comercial, desative `testing/catalog_funds_enabled` em `project.godot`; a edição atual mantém o saldo de teste autorizado pelo proprietário.
