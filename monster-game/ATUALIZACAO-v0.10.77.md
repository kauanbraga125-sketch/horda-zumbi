# Horda Zumbi 0.10.77 — Agourinho: última chance da horda

- Agourinho só age quando a perda atingiria a última criatura viável. Perdas isoladas, inclusive de um membro que já está caindo enquanto outro sobrevive, não usam o poder.
- Na queda simultânea da horda inteira, preserva uma única criatura real, com o mesmo identificador, espécie e acessórios. Não recompõe a horda inteira e não cria moedas, almas ou recompensas de captura.
- Um único resgate por partida. A proteção breve dura 1 / 1,5 / 2 segundos conforme as barras. O poder continua gasto se a horda crescer ou se a corrida for continuada; uma partida nova restaura a carga.
- Novas seis poses do Agourinho com asas e fitas completas. O portal roxo, as penas orbitando, a magia da ave e a proteção acompanham o sobrevivente. O atlas tem as mesmas dimensões do anterior, 1152 × 768, e substitui sua textura em execução; os dez pequenos efeitos de pena não usam nós de partículas.
- Retorno de buracos procura chão com margem para os pés e impede a formação de puxar imediatamente o sobrevivente de volta à queda. A pausa congela a apresentação. O resgate funciona também nas outras atividades e no segundo ninho.
- Verificações específicas de último membro, quedas simultâneas, cache de contagem desatualizado, proteção, identidade, pausa, ave bloqueada, continuação e nova partida. Regressões de Ferrugem, Fiapo, Pipoco, coleção, fusão e sistemas passaram.

[APK Android ARM64](https://github.com/kauanbraga125-sketch/horda-zumbi/releases/download/v0.10.77/Horda-Zumbi-v0.10.77-GitHub-TESTE-ARM64.apk)

Edição **Horda GitHub Teste**, pacote `com.kauan.noitedahorda.github`, código Android 180. A publicação exige validação completa dos mesmos fontes e os testes específicos nos recursos extraídos do APK. Teste em aparelho físico pendente.
