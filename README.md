# Horda Zumbi

Versão de testes atual: **0.10.29 — acessórios e animações**.

- [Baixar o APK 0.10.29](https://github.com/kauanbraga125-sketch/horda-zumbi/releases/download/v0.10.29/Horda-Zumbi-v0.10.29-ARM64.apk)
- [Projeto Godot completo](monster-game/)
- [Correções e instruções para abrir o projeto](monster-game/CORRECAO-v0.10.29.md)
- [Relatório de validação](monster-game/VALIDACAO-v0.10.29.json)
- [Reconstruir o APK e os fontes a partir da cópia verificada](release-v0.10.29/)

Os 35 cosméticos foram verificados nas nove animações da bancada. A atualização corrige os sete últimos itens do esqueleto e 24 marcações de cabeça que faziam acessórios descerem em quadros de repouso, dano, salto e captura. Os sprites originais dos personagens estão preservados.

Em **Configurações → Desenvolvedor → Bancada de itens → ANIMAÇÕES**, há nove estados e reprodução em sequência, além de pausa, quadro a quadro, dois lados, comparação, zoom e velocidade.

Esta edição repõe ao abrir o aplicativo um saldo mínimo de **1.000.000 de moedas e 10.000 olhos**, preservando valores maiores e o progresso anterior. Desative a opção `testing/catalog_funds_enabled` antes do lançamento comercial.

APK ARM64, Godot 4.5.1, GL Compatibility, Android mínimo 24 e alvo 35. Mantém o pacote e a assinatura da **0.10.28** (`com.kauan.noitedahorda.reconstruida`), permitindo atualizar essa edição sem apagar os dados.

Os testes verificam os quadros, a bancada, as compras, a estabilidade dos itens nas transformações, a integridade e a inicialização do APK. A instalação em aparelho Android físico ainda precisa ser conferida pelo proprietário.

As artes, fontes, áudios, licenças, medições, ferramentas e testes estão incluídos. A chave de assinatura permanece no backup privado do proprietário. As versões anteriores e as demais pastas históricas continuam preservadas no Git.
