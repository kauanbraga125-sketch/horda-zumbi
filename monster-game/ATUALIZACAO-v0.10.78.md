# Horda Zumbi 0.10.78 — Ritual de ressurreição do Agourinho

- A horda agora morre de verdade: todas as criaturas são removidas, as mortes são contabilizadas e o contador permanece em zero durante a invocação. O Agourinho continua sendo uma única chance por partida, somente após a perda total da horda.
- Sequência de 3,9 segundos: reação da ave e animações de morte; reunião de energia; abertura do vórtice; retorno de uma única criatura a partir de 3,35 segundos; saída do portal e retomada da partida. Identidade, espécie e acessórios são preservados, sem recompensas de captura ou moedas extras.
- Novo portal ilustrado com profundidade opaca, borda de penas, ornamentos dourados e espiral violeta/verde. A criatura emerge do centro e termina com os pés no chão. Removidos os antigos círculos transparentes sobre o monstro vivo.
- Oito novas poses de ação registradas pela posição do terceiro olho, transições suaves entre asas, mergulho, oscilação e movimento de conjuração. O voo normal também recebe transições entre poses. Sons de energia, abertura e retorno tocam nas respectivas etapas, com redução breve da música para destacar o ritual.
- Perigos, deslocamento, temporizadores e recrutamentos aguardam a sequência; a pausa também congela a invocação. A proteção de 1/1,5/2 segundos fica disponível após o retorno, sem deixar a criatura piscando transparente dentro do portal.
- Atlas de ação 1024 × 512 e portal 512 × 512, 3 MiB adicionais decodificados, carregados antecipadamente. Efeitos limitados a 14 pequenos pontos de luz, sem novos nós de partículas ou canais de áudio.
- Testes verificam a horda vazia, duração, eventos e sons em ordem, retorno único, pausa, abandono, identidade, proteção, segundo ninho, novas partidas, quedas reais e atividades. As regressões das outras aves e da coleção passaram. A publicação exige os mesmos testes nos recursos extraídos do APK.

[APK Android ARM64](https://github.com/kauanbraga125-sketch/horda-zumbi/releases/download/v0.10.78/Horda-Zumbi-v0.10.78-GitHub-TESTE-ARM64.apk)

Edição **Horda GitHub Teste**, pacote `com.kauan.noitedahorda.github`, código Android 181. Teste em aparelho físico pendente.
