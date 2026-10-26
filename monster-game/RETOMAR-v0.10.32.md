# Retomar a Horda Zumbi — 0.10.32

Estado atual: atualização da 0.10.31 com correção do salto de seguidores, Caçador Noturno, Manto Espectral, combate espacial, quatro camadas por barra de impulso, investida, naves destrutíveis/pilotáveis, Simbionte Cósmico, Escudo Orbital, consumível de ímã, reembolso de melhorias e PERFECT com som.

- Motor: Godot 4.5.1.
- Versão Android: 0.10.32, código 135.
- Pacote: `com.kauan.noitedahorda.reconstruida`.
- Nome no Android: `Horda Aventura R32`.
- APK: `Horda-Zumbi-v0.10.32-TESTE-1M-AVENTURA-ARM64.apk`.
- Preservar a assinatura SHA-256 `a641a59f39561af0210f2f1cd246f58c5bfd9ab05462bf5b0635e626d681d15d`.
- Não publicar a identidade privada ou o backup privado no GitHub.
- Não colocar `project.binary` antigo na raiz: ele sobrepõe `project.godot`. A configuração nativa desta compilação fica em `.godot/v132-project.binary`.
- Auditoria de inicialização em `startup_integrity.json`; atualizar depois de editar ou reimportar.
- Descrição e referências em `AVENTURA-v0.10.32.md`.
- Fontes, artes, testes e reconstrução exata do APK ficam no GitHub; o backup privado inclui o projeto completo, importações, APK e identidade para futuras atualizações.

Testes: moeda de teste na abertura normal, fixture de progresso existente, controles por toque, capturas do motor, casos de salto com 1/4/8/16/24 membros em três velocidades, captura real dos civis entregues, danos no espaço, piloting, poderes e retorno com 41 membros. Não afirmar teste em Android físico sem realizá-lo.
