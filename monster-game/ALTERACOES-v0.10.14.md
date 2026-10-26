# Horda Zumbi 0.10.14 — correção dos cosméticos

Acessórios de cabeça agora preservam o cabelo ou capuz visível abaixo da aba, a roupa, o pescoço e os membros. A troca da capa do esqueleto usa um recorte separado, preserva o capuz e protege botas e luvas de cor roxa. O colarinho novo é desenhado à frente do corpo. O capuz elétrico usa escala uniforme entre o alto da abertura e o queixo, preservando o formato das orelhas; quatro cabelos exagerados foram reduzidos sem modificar os PNGs.

As prévias do mercado usam os limites do personagem equipado ao longo de todo o ciclo de corrida, com escala estável. Os 35 itens ficam dentro de seus cartões. Os identificadores, preços, compras, coleção, probabilidades, progressos e jogabilidade permanecem iguais aos da 0.10.13.1.

As 16 folhas originais de personagens correspondem exatamente ao commit público de base, incluindo a primeira fileira aprovada do esqueleto. Os 233 arquivos de mídia e bibliotecas de cada APK são idênticos aos da respectiva opção 0.10.13.1. Não houve nova compressão de imagens nem corte de quadros. A opção compacta mantém o WebP da versão compacta anterior; a opção sem perdas mantém suas imagens sem perdas.

Validação: 263 quadros com malhas e transformações válidos; 24 painéis em oito poses e nas duas direções; 560 prévias renderizadas dentro dos limites; seis pares de cosméticos em quatro poses e nos dois lados. Coleção, movimentação e testes de partida passaram. Índice de 803 recursos, integridade de 94 arquivos, versão de execução, CRC, assinatura e alinhamento Android verificados. Teste em aparelho físico pendente.

O pacote continua com.kauan.noitedahorda.reconstruida, ARM64, Android 7 ou posterior, código 117 e assinatura da reconstrução. Pode atualizar a 0.10.13.1 sem desinstalar. As versões 0.10.13.1 continuam guardadas separadamente.

Compilação: tools/build_v114.py recebe uma das opções verificadas 0.10.13.1 por --input, o projeto restaurado por --source, destino --output, assinatura --key, apksigner --signer, zipalign --zipalign e opcionalmente --project-binary. O arquivo compilacao/project.binary deste backup é o usado nesta entrega. Também pode ser gerado com tools/save_runtime_config.gd em um projeto sem project.binary antigo. A chave e a senha ficam fora do projeto, em assinatura_privada. Não publicar essa pasta.

Este backup contém as alterações completas sobre a base pública f7bebdd9b8cf8d81cf4e0f28ebfb16dcfccfc720; restaurar_projeto.py baixa essa base ou aceita --base-dir com uma cópia local. Não é uma cópia offline de todos os arquivos da base.

- Horda-Zumbi-v0.10.14-ARM64.apk: 89,364,282 bytes (89.36 MB); SHA256 a2972e1938cd32e89b1cc7abbf1d627d272c70f8cc6ae9c9f9600fad5e24792c
- Horda-Zumbi-v0.10.14-Sem-Perdas-ARM64.apk: 184,624,954 bytes (184.62 MB); SHA256 4ec1c48823b313115f57cf62d06760b2452a05cd9e1dfac187f44441e9034f4d
