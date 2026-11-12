# Trilhas e efeitos fornecidos por Kauan — 12/11/2026

As nove músicas foram fornecidas em MP3, na ordem dos prompts confirmada pelo usuário. Os efeitos chegaram no arquivo `sons jogo.rar`. Os originais permanecem preservados pelo proprietário. O projeto não reivindica autoria das gravações fornecidas.

| Ordem | Região | Arquivo original |
| --- | --- | --- |
| 01 | Bruma do Cemitério | Midnight_Graveyard_Kart_Dash.mp3 |
| 02 | Ventos Malditos | Storm_Over_The_Floating_Isles.mp3 |
| 03 | Atmosfera Sombria | The_Last_Airlock.mp3 |
| 04 | Universo Maligno do pula-pula | The_Unmaker’s_Reach.mp3 |
| 05 | Esgoto | The_Floodgate_Turn.mp3 |
| 06 | Espaço: Órbita da Terra | Gravity_s_Edge.mp3 |
| 07 | Espaço: Cemitério Orbital | Beneath_the_Wreckage.mp3 |
| 08 | Espaço: Ninho do Passageiro | Under_A_Pale_Carapace.mp3 |
| 09 | Espaço: Horizonte Perdido | Colossus_at_the_Gate.mp3 |

`manifest.json` registra os nomes completos, hashes das fontes, identificação, duração, tratamento e hashes dos resultados. A identificação dos efeitos usa os prefixos dos prompts, datas e sequência de geração. O usuário autorizou resolver as ambiguidades por estimativa e pediu para preservar as variações.

- A vocalização `Crie_uma_vocalização_#3-1794501121977.mp3` foi atribuída provisoriamente ao ataque do Alien (S16). Não houve confirmação semântica independente do conteúdo.
- Não há arquivo individual identificado com segurança como cliques S17; o caçador mantém os sinais de camuflagem e disparo.
- Para S19, o disparo usa o efeito original já existente `space_dash`, de `adventure_v132`, com ajuste de reprodução. Não é apresentado como um novo arquivo enviado pelo usuário.
- As duas gravações distintas identificadas como pula-pula (S24) estão preservadas e alternam a cada ativação.
- `monstro comendo tudo.mp3` é cópia byte a byte de S11; foi deduplicada, sem apagar ou alterar o original recebido.

As músicas receberam normalização em duas passagens para -20 LUFS e teto de -2 dBTP. Os efeitos receberam ajuste de ganho baseado na energia ativa, proteção de pico e pequenos fades. Os arquivos são Ogg Vorbis em contêineres `.bin`, lidos por `AudioStreamOggVorbis.load_from_buffer` no Godot 4.5.1. Isso evita cópias de importação e buffers PCM integrais das músicas. Os dados permanecem comprimidos, com cache limitado.

Os arquivos prontos para reprodução e seus hashes estão incluídos neste diretório. Os MP3 originais, o arquivo RAR e a ferramenta de preparação usada na sessão original permanecem fora desta cópia pública. O manifesto preserva os parâmetros de tratamento e a correspondência com as fontes; nenhuma gravação original foi sobrescrita.
