# Horda Zumbi 0.10.68 — Cliques sincronizados

Corrige o atraso nos sons de abrir o mercado, confirmar a navegação e voltar. As duas variações de cada som foram ajustadas: foram retirados entre 401 e 733 ms do início quase silencioso. O ataque audível agora começa cerca de 4 ms após o início do arquivo, na medição do áudio decodificado, sem incluir a latência do celular ou do dispositivo de áudio.

O volume, o timbre e a cauda dos sons são preservados, com uma transição de 1,5 ms na borda do corte. As músicas, os efeitos da corrida e as regras do jogo continuam os da versão 0.10.67.

- [Baixar APK Android ARM64](https://github.com/kauanbraga125-sketch/horda-zumbi/releases/download/v0.10.68/Horda-Zumbi-v0.10.68-GitHub-TESTE-ARM64.apk)
- [Medições de cada variação](assets/audio/v168/manifest.json)
- [Verificações desta atualização](VALIDACAO-v0.10.68.json)

Edição de teste **Horda GitHub Teste**, pacote `com.kauan.noitedahorda.github`, código Android 171. A compilação do GitHub verifica assinatura, integridade e inicialização do APK. O ajuste precisa ser ouvido no celular para confirmar a sincronização percebida.
