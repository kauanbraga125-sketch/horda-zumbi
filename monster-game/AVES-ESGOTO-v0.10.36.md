# Horda Zumbi 0.10.36

O Ninho das Aves Malditas, a fuga pelo esgoto e as cenas novas no espaço preservam almas, perdas, recordes e avanço dos túneis na mesma partida.

## Acesso e saldo de testes

Na tela inicial: **ESPAÇO R36**, **ESGOTO**, **AVES MALDITAS** e **REPOR 1M**. Também há acesso em Configurações → Desenvolvedor. O ninho oferece uma prévia gratuita de cada ave no nível 3, na terra, no espaço e no esgoto, sem modificar a coleção. Na corrida normal, a chave do esgoto aparece entre os poderes e inicia uma viagem temporária.

Ao abrir, esta versão mantém pelo menos **1.000.000 de moedas e 10.000 olhos**, preservando valores maiores e os dados antigos. O primeiro ovo é grátis; os seguintes custam **30 olhos**. Desative `testing/catalog_funds_enabled` antes do lançamento comercial.

## Cinco aves originais

| Classe | Ave | Personalidade e habilidade |
| --- | --- | --- |
| Clássica | Pipoco | Pombo gorducho e faminto; moedas extras por Perfect. |
| Super | Fiapo | Abutre magrelo e medroso; avisa sobre ameaças próximas. |
| Hiper | Ferrugem | Corvo mecânico mal-humorado; sabota ameaças e enfraquece naves e veículos. |
| Ultra | Agourinho | Coruja fantasmagórica de três olhos; salva um membro uma única vez por partida. |
| Lendária | Barão Goela | Nobre barrigudo; ataca após Perfects, até três vezes por partida. |

Cada ave tem seis poses, batidas de asas, piscada, susto, reação de habilidade, movimento próprio e voz sintetizada original. As artes não copiam personagens comerciais.

As chances base desta adaptação são **60%, 25%, 10%, 4% e 1%**. Após nove ovos sem Hiper ou superior, o próximo garante Hiper ou superior. Após 49 sem Lendária, o próximo garante Lendária. Esses valores não são taxas oficiais do jogo de referência.

As três primeiras cópias aumentam a habilidade até o nível 3; cópias adicionais viram essências. A fusão usa **seis essências e 500 moedas** para conceder a ave da classe seguinte, preservando o poder da ave usada. Com uma espécie inicial por classe, o resultado é mostrado antes da confirmação. Cobrança, resultado e garantias são salvos juntos antes da animação. Ao reabrir durante uma revelação, o mesmo prêmio é retomado sem cobrar nem sortear novamente.

## Fuga pelo esgoto

Os membros reais embarcam, até três por jet-ski. A viagem dura 30 segundos; a melhoria específica acrescenta quatro segundos por nível. Toque para saltar e segure brevemente para alongar. Os seguidores repetem o salto conforme sua distância até o obstáculo. O atraso extra começa somente nas hordas maiores.

Destroços e barris exigem salto; canos baixos exigem ficar na água. Um civil resgatado acrescenta uma alma e um membro reais. Acidentes podem retirar passageiros e aproximar a enchente, com limites de dano por obstáculo e proteção breve após um impacto. O final é um salto para a rua com pouso seguro e retomada da corrida. O mundo e os túneis continuam avançando durante a viagem.

O cenário tem arte nova, água ondulada, reflexos, rastros, respingos, vazamentos, explosões e queda de destroços. A pose sentada preserva os PNGs e acessórios aprovados, ocultando as pernas atrás do casco.

## Abdução e espaço

A nave abre um feixe conectado à posição da horda, eleva os membros suspensos e os libera em órbita. A câmera e o cenário acompanham a subida. Parasitas perseguem astronautas; cargueiros avariados ejetam uma cápsula antes de explodir. A tripulação ejetada é descontada para impedir recompensas duplicadas.

Arraste para guiar a horda e toque em **INVESTIDA** para atacar. Rotas, portais, camadas, naves, poderes e riscos de perder membros continuam ativos. As aves respeitam embarque, subida e pouso e só ativam ataques durante os trechos jogáveis.

## Versão e recuperação

APK ARM64, Godot 4.5.1, GL Compatibility, Android mínimo 24 e alvo 35. Versão 0.10.36, código 139, nome instalado **Horda Aves Esgoto R36**. Pacote e assinatura da 0.10.35 são mantidos: `com.kauan.noitedahorda.reconstruida`. Os 35 cosméticos e os PNGs anteriores dos personagens são preservados.

VALIDACAO-v0.10.36.json registra integridade, assinatura, testes e capturas nativas. A prévia usa o renderizador do jogo e entradas reais de toque. **Não houve teste em aparelho Android físico nesta sessão.**

O repositório contém fontes, artes originais, preparação dos sprites, áudio, testes e ferramentas. release-v0.10.36/restore_release.py reconstrói o APK assinado byte a byte usando o APK público anterior. O pacote privado de recuperação contém também a identidade de assinatura; a chave e a senha não são publicadas no GitHub.

Referência de estudo da coleção: [documentação comunitária de Zombirds](https://zombie-tsunami.fandom.com/wiki/Zombirds). O esgoto usa uma fuga cinematográfica como inspiração, com personagens, veículos e cenário próprios.
