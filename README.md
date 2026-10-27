# Horda Zumbi

Versão de testes atual: **0.10.33 — espaço revisado, cabines e encontros legíveis**.

- [Baixar o APK 0.10.33](https://github.com/kauanbraga125-sketch/horda-zumbi/releases/download/v0.10.33/Horda-Zumbi-v0.10.33-TESTE-1M-ESPACO-REVISADO-ARM64.apk)
- [Projeto Godot completo](monster-game/)
- [Mecânicas, referências e instruções](monster-game/ESPACO-v0.10.33.md)
- [Relatório de validação](monster-game/VALIDACAO-v0.10.33.json)
- [Reconstruir o APK e os fontes a partir da cópia verificada](release-v0.10.33/)

A revisão espacial corrige o cache que apagava sprites entre testes, recorta os ocupantes dentro das cabines, distribui a formação e organiza ameaças com aviso e intervalos de coleta. A interface tem um único espaço de notificações, e a descida prepara o terreno antes do pouso.

Os seguidores repetem o salto ao chegar ao mesmo ponto do mundo; o atraso extra começa em hordas grandes. O espaço tem camadas por barra de impulso, investida, naves destrutíveis e pilotáveis, perigos que retiram membros, ovos e parasitas, colecionáveis e poderes exclusivos. O Caçador Noturno traz civis reais, o Manto Espectral absorve impactos e os poderes espaciais são Simbionte Cósmico e Escudo Orbital.

As melhorias permanentes de altura do salto e ímã foram removidas com reembolso único. O ímã agora é um consumível de uma partida. Coletar uma formação completa de moedas dá **PERFECT!** com som original.

Há acesso direto ao teste espacial e à reposição de moedas na tela inicial. No espaço, **arraste para guiar** e toque em **INVESTIDA** para atacar. Em **Configurações → Desenvolvedor**, teste o espaço, o Caçador e o Manto, ou ajuste o tamanho da horda. A bancada de itens mantém nove animações, pausa, quadro a quadro, dois lados, comparação, zoom e velocidade. Os 35 cosméticos e os sprites aprovados dos personagens são preservados.

Esta edição repõe ao abrir o aplicativo um saldo mínimo de **1.000.000 de moedas e 10.000 olhos**, preservando valores maiores e o progresso anterior. Desative a opção `testing/catalog_funds_enabled` antes do lançamento comercial.

APK ARM64, Godot 4.5.1, GL Compatibility, Android mínimo 24 e alvo 35. Mantém o pacote e a assinatura da **0.10.32** (`com.kauan.noitedahorda.reconstruida`), permitindo atualizar essa edição sem apagar os dados. Nome instalado: **Horda Espaco R33**.

Os testes verificam os quadros, a bancada, as compras, a estabilidade dos itens nas transformações, a integridade e a inicialização do APK. A instalação em aparelho Android físico ainda precisa ser conferida pelo proprietário.

As artes, fontes, áudios, licenças, medições, ferramentas e testes estão incluídos. A chave de assinatura permanece no backup privado do proprietário. As versões anteriores e as demais pastas históricas continuam preservadas no Git.
