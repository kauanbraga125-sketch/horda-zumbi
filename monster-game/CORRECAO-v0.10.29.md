# Horda Zumbi 0.10.29 — acessórios e teste de animações

Atualização da versão 0.10.28, com o mesmo pacote Android e a mesma assinatura de atualização.

## Sete ajustes individuais

- Óculos góticos: desenho em perspectiva com apenas a haste visível e encaixe rígido na linha dos olhos.
- Máscara dos quadrinhos: desenho bicolor em perspectiva; aberturas acompanham os olhos de cada sprite, incluindo repouso e dano.
- Cabelo prateado: raiz mais à frente, crânio completo e rosto original preservado.
- Crista punk: encaixe proporcional, crânio restaurado e membros originais preservados.
- Colete da meia-noite: redesenhado sobre o torso; segue o fecho e o cinto reais de cada quadro, com braços à frente.
- Capa de morcego: tecido em preto e violeta usando as 167 poses originais do esqueleto, incluindo a queda da capa durante o salto. A substituição preserva os sprites e a silhueta nativa.
- Ampulheta do além: novo pingente dourado com areia âmbar mais legível, maior e centralizado no peito; corrente acompanha o corpo.

Os PNGs originais dos personagens permanecem intactos. Os outros 28 cosméticos mantêm suas artes da 0.10.28. As marcações dos olhos do esqueleto no repouso e em quadros de dano também foram corrigidas: a busca antiga confundia os olhos com posições abaixo do nariz, fazendo acessórios descerem para a boca. Os pontos corrigidos valem para todos os itens do esqueleto.

## Bancada e jogo

Em Configurações → Desenvolvedor → Bancada de itens, toque em ANIMAÇÕES. Escolha corrida, parado, subida, no ar, queda, pouso, empurrão, captura ou dano/pânico. Há também reprodução de todas em sequência. Pausa, avanço por quadro, dois lados, comparação, zoom e velocidade continuam disponíveis.

A transição para os poderes agora mantém os acessórios no personagem original até ele desaparecer na transformação. As escolhas de itens de cada membro da horda continuam estáveis ao trocar de animação.

Esta versão de testes repõe, ao abrir o aplicativo, um saldo mínimo de 1.000.000 de moedas e 10.000 olhos. Valores maiores e o progresso anterior são preservados. Há um botão de reposição no menu Desenvolvedor. As compras continuam funcionando normalmente. Para encerrar essa facilidade antes do lançamento, desative testing/catalog_funds_enabled em project.godot.

## Recuperar e exportar

Use Godot 4.5.1. O backup privado completo inclui importações, fontes, artes, áudio, medições, ferramentas, testes e a identidade de assinatura. Guarde a pasta assinatura_privada separada; ela não pertence ao repositório público.

A cópia pública contém todos os fontes. Após um clone limpo, execute a importação do editor e tools/refresh_startup_integrity.py antes de testar ou exportar. O preset Android foi atualizado para 0.10.29 (código 132), ARM64, SDK mínimo 24 e alvo 35, com todas as medições adicionais incluídas.

A revisão renderizou 9.068 amostras individuais dos 35 itens e 1.080 combinações adicionais. As 24 marcações de cabeça corrigidas também foram verificadas nos itens anteriores. Nas sete revisões novas, foram conferidas 379.620 amostras dos membros e 15.510 dos olhos, sem diferenças nas regiões protegidas. O teste da bancada percorre todos os 35 itens e os 263 quadros medidos. Os relatórios estão na entrega. A instalação em um aparelho Android físico não foi executada neste ambiente.
