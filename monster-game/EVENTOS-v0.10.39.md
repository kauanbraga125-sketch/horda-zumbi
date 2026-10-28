# Horda Zumbi 0.10.39 — jornadas aleatórias e fuga do esgoto

Espaço e esgoto são variações da mesma partida. Saíram da loja, das melhorias de duração e da geração de itens de poder. Um diretor compartilhado sorteia oportunidades em trechos seguros: primeira janela entre 45 e 75 segundos, chance de 68% por oportunidade e nova tentativa entre 12 e 24 segundos quando o sorteio falha. Após o retorno, o intervalo é de 105 a 155 segundos. Os eventos não se sobrepõem e a próxima jornada natural evita repetir a anterior. Poderes ativos, itens de poder visíveis e túneis impedem a interrupção naquele momento.

Na abdução, a nave começa diretamente a animação de subida; não é necessário pegar um cérebro espacial. O evento dura 30 segundos. No esgoto, a corrida encontra um porto visível e a horda embarca antes de iniciar a fuga de 32 segundos. Distância, túneis, almas e recordes continuam na mesma partida. As compras antigas de duração recebem reembolso único: até 9.100 moedas para o espaço, além do reembolso anterior do esgoto. A posse de outros poderes permanece.

## Personagens e transições

Há 24 corpos novos de piloto, passageiro e abaixamento. Cada personagem monta a sela com uma perna do lado visível; a outra fica do lado oposto do casco. O rosto vem da arte original aprovada, como uma camada opaca independente do corpo. Os acessórios usam as medições originais da cabeça. O recorte de cabelo/capuz não apaga mais os olhos, a boca ou o nariz.

Antes do salto, os pés que correm ficam sobre a margem sólida. Os barcos esperam na água à frente, com dois lugares para membros reais. A horda pula da margem, senta e acelera para dentro. A mudança de iluminação e cenário substitui a fachada de pedra que cobria os corpos. Na saída, há uma subida breve na rampa, lançamento contínuo e pouso no mapa real da corrida, sem atravessar uma fachada sobreposta. Hordas ímpares deixam um assento vazio; recrutas usam vagas antes de abrir outro barco.

## Água, obstáculos e perseguição

A enchente tem 16 quadros novos, com uma caveira formada pela espuma, garras, ossos e veios vermelhos na água escura. O ciclo é mais longo e recebe deformação contínua. Sua frente acompanha a cauda, permanece visível e se aproxima com acidentes. O pé da onda se mistura à água do canal.

As boias usam a linha da água medida em cada quadro, com balanço discreto e ondulações ao redor. Canos e comportas têm sustentação metálica opaca que segue até o teto. A bomba giratória tem uma base de alvenaria que continua abaixo da água, usando a textura de pedra do próprio esgoto. As moedas usam o mesmo diâmetro de 54 unidades da corrida normal.

Saltos, abaixamento, naufrágios, barris, bombas, teto desabando e perseguições na passarela continuam ativos. Um erro pode retirar um passageiro real e aproximar a enchente. Uma formação completa de moedas continua dando PERFECT. Não há imunidade permanente durante a fuga.

## Fugitivos de jet-ski

Dois humanos originais usam como referência visual a fuga de Leon e Ashley em Resident Evil 4: um agente de roupa escura e uma jovem de blusa laranja. Há 12 quadros novos: quatro para o agente sozinho, quatro para a jovem sozinha e quatro para os dois no mesmo jet-ski azul. Eles dirigem, se inclinam e olham para trás enquanto fogem. Cada ocupante capturado acrescenta exatamente uma alma e um membro; o veículo não pode repetir o prêmio.

A foto comercial serviu apenas de referência e não é distribuída no jogo. Fontes da referência e os prompts completos estão em `tools/art_sources/v139/PROMPTS.json`. Os quatro PNGs originais foram criados com **ImageGen integrado**. `tools/prepare_v139_art.py` reproduz o empacotamento e as medições dos atlas; os PNGs antigos dos personagens permanecem intactos.

## Teste e recuperação

Use **EVENTO ESGOTO** ou **EVENTO ESPAÇO** na tela inicial para testar imediatamente. O modo desenvolvedor também permite testar controles, tamanhos de horda e duração espacial sem comprar uma melhoria. Esta edição repõe ao abrir pelo menos **1.000.000 de moedas e 10.000 olhos**, preservando saldos maiores e o progresso.

APK Android 0.10.39, código 142, ARM64, Android mínimo 24 e alvo 35. Nome instalado: **Horda Eventos R39**. Pacote e assinatura iguais aos da 0.10.38, permitindo atualizar sem apagar os dados.

O relatório `VALIDACAO-v0.10.39.json` registra os testes e a auditoria do APK. As capturas e a prévia usam os scripts e as artes extraídos do APK assinado, no renderizador nativo Godot. Não houve teste em aparelho Android físico nesta sessão.

O GitHub guarda o projeto completo e a reconstrução byte a byte do APK assinado em `release-v0.10.39/`. A cópia privada do projeto inclui também as importações para abrir sem rede e a identidade de assinatura. O APK fica preservado separadamente no GitHub e no arquivo de aplicativo entregue. A chave e a senha não são publicadas no repositório.
