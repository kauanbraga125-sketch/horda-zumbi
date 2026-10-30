# Horda Zumbi

Versão de testes atual: **0.10.41 — espaço e esgoto como eventos aleatórios**.

**Para editar e compilar pelo próprio GitHub:** [guia de continuação](CONTINUAR-NO-GITHUB.md) · [compilar novo APK dos fontes no Actions](https://github.com/kauanbraga125-sketch/horda-zumbi/actions/workflows/horda-compilar-apk.yml). Alterações em `monster-game/` geram uma compilação de teste automaticamente; o botão **Run workflow** permite escolher a branch. Baixe o APK em **Artifacts** da execução concluída.

- [Baixar o APK 0.10.41](https://github.com/kauanbraga125-sketch/horda-zumbi/releases/download/v0.10.41/Horda-Zumbi-v0.10.41-TESTE-1M-ESGOTO-ARM64.apk)
- [Projeto Godot completo](monster-game/)
- [Mecânicas, referências e instruções](monster-game/EVENTOS-v0.10.41.md)
- [Relatório de validação](monster-game/VALIDACAO-v0.10.41.json)
- [Reconstruir o APK e os fontes a partir da cópia verificada](release-v0.10.41/)

Espaço e esgoto agora são eventos aleatórios da mesma corrida. A nave abduz a horda diretamente; o esgoto começa pelo fim da rua: cada personagem cai ao passar pela borda e chega ao seu próprio assento. Os eventos saíram da loja e das melhorias de duração, com reembolso único das compras antigas. O diretor impede sobreposição e dá intervalo entre jornadas.

Os pilotos e passageiros têm 24 corpos desenhados para montar a sela, com uma perna do lado visível e cabeças originais opacas. A enchente monstruosa tem 16 quadros, aparece perto da cauda e se mistura à água. Boias ficam na superfície, suportes alcançam o teto, a bomba tem base de pedra e as moedas mantêm o tamanho da corrida. Dois fugitivos inspirados em Leon e Ashley aparecem sozinhos ou juntos em outro jet-ski, com animação própria e captura real. A entrada e a saída preservam uma trajetória contínua, sem a fachada de pedra atravessando os personagens.

Os seguidores repetem o salto ao chegar ao mesmo ponto do mundo; o atraso extra começa em hordas grandes. Durante o evento, o espaço tem camadas por barra de impulso, investida, naves destrutíveis e pilotáveis, perigos que retiram membros, ovos e parasitas, colecionáveis e poderes exclusivos. O Caçador Noturno traz civis reais, o Manto Espectral absorve impactos e os poderes espaciais são Simbionte Cósmico e Escudo Orbital.

As melhorias permanentes de altura do salto e ímã foram removidas com reembolso único. O ímã agora é um consumível de uma partida. Coletar uma formação completa de moedas dá **PERFECT!** com som original.

Há acesso direto ao teste espacial e à reposição de moedas na tela inicial. No espaço, **arraste em todas as direções para guiar** e toque em **INVESTIDA** para atacar. Em **Configurações → Desenvolvedor**, teste o espaço, o Caçador e o Manto, ou ajuste o tamanho da horda. A bancada de itens mantém nove animações, pausa, quadro a quadro, dois lados, comparação, zoom e velocidade. Os 35 cosméticos e os sprites aprovados dos personagens são preservados.

Esta edição repõe ao abrir o aplicativo um saldo mínimo de **1.000.000 de moedas e 10.000 olhos**, preservando valores maiores e o progresso anterior. Desative a opção `testing/catalog_funds_enabled` antes do lançamento comercial.

APK ARM64, Godot 4.5.1, GL Compatibility, Android mínimo 24 e alvo 35. Mantém o pacote e a assinatura da **0.10.40** (`com.kauan.noitedahorda.reconstruida`), permitindo atualizar essa edição sem apagar os dados. Nome instalado: **Horda Esgoto R41**.

Os testes verificam os quadros, a bancada, as compras, a estabilidade dos itens nas transformações, a integridade e a inicialização do APK. A instalação em aparelho Android físico ainda precisa ser conferida pelo proprietário.

As artes, fontes, áudios, licenças, medições, ferramentas e testes estão incluídos. A chave de assinatura permanece no backup privado do proprietário. As versões anteriores e as demais pastas históricas continuam preservadas no Git.

Na 0.10.41 todas as camadas da rua terminam na borda da abertura e cada membro cai por uma trajetória própria; a saída usa rampa e salto até o próprio cenário normal. Detalhes, limitações e validação: `monster-game/EVENTOS-v0.10.41.md` e `monster-game/VALIDACAO-v0.10.41.json`.
