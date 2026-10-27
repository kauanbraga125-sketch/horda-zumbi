# Horda Zumbi

Versão de testes atual: **0.10.35 — subida visível, contatos físicos e espaço vivo**.

- [Baixar o APK 0.10.35](https://github.com/kauanbraga125-sketch/horda-zumbi/releases/download/v0.10.35/Horda-Zumbi-v0.10.35-TESTE-1M-ESPACO-VIVO-ARM64.apk)
- [Projeto Godot completo](monster-game/)
- [Mecânicas, referências e instruções](monster-game/ESPACO-v0.10.35.md)
- [Relatório de validação](monster-game/VALIDACAO-v0.10.35.json)
- [Reconstruir o APK e os fontes a partir da cópia verificada](release-v0.10.35/)

A subida agora tem aceleração, postura voltada para cima e cenário passando para baixo. Minas animadas substituem os pilares provisórios. Contatos sólidos bloqueiam e recuam os membros mesmo durante proteção contra dano, e mortes no espaço usam uma saída flutuante com os acessórios do personagem. Tráfego distante, detritos, propulsores e escudos em movimento dão vida ao cenário. Rotas, combos, contra-ataques, almas e recordes continuam na mesma partida.

Os seguidores repetem o salto ao chegar ao mesmo ponto do mundo; o atraso extra começa em hordas grandes. O espaço tem camadas por barra de impulso, investida, naves destrutíveis e pilotáveis, perigos que retiram membros, ovos e parasitas, colecionáveis e poderes exclusivos. O Caçador Noturno traz civis reais, o Manto Espectral absorve impactos e os poderes espaciais são Simbionte Cósmico e Escudo Orbital.

As melhorias permanentes de altura do salto e ímã foram removidas com reembolso único. O ímã agora é um consumível de uma partida. Coletar uma formação completa de moedas dá **PERFECT!** com som original.

Há acesso direto ao teste espacial e à reposição de moedas na tela inicial. No espaço, **arraste em todas as direções para guiar** e toque em **INVESTIDA** para atacar. Em **Configurações → Desenvolvedor**, teste o espaço, o Caçador e o Manto, ou ajuste o tamanho da horda. A bancada de itens mantém nove animações, pausa, quadro a quadro, dois lados, comparação, zoom e velocidade. Os 35 cosméticos e os sprites aprovados dos personagens são preservados.

Esta edição repõe ao abrir o aplicativo um saldo mínimo de **1.000.000 de moedas e 10.000 olhos**, preservando valores maiores e o progresso anterior. Desative a opção `testing/catalog_funds_enabled` antes do lançamento comercial.

APK ARM64, Godot 4.5.1, GL Compatibility, Android mínimo 24 e alvo 35. Mantém o pacote e a assinatura da **0.10.34** (`com.kauan.noitedahorda.reconstruida`), permitindo atualizar essa edição sem apagar os dados. Nome instalado: **Horda Espaco R35**.

Os testes verificam os quadros, a bancada, as compras, a estabilidade dos itens nas transformações, a integridade e a inicialização do APK. A instalação em aparelho Android físico ainda precisa ser conferida pelo proprietário.

As artes, fontes, áudios, licenças, medições, ferramentas e testes estão incluídos. A chave de assinatura permanece no backup privado do proprietário. As versões anteriores e as demais pastas históricas continuam preservadas no Git.
