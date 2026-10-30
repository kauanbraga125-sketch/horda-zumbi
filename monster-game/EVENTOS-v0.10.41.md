# Horda Zumbi 0.10.41 — fim da rua e queda ao esgoto

Na 0.10.40, uma segunda faixa de calçada continuava desenhada além da abertura. A animação também puxava os personagens para posições quase iguais antes da descida, formando uma coluna. A aproximação e a queda agora usam a mesma borda móvel em coordenadas do mundo.

- O chão, a calçada do fundo e os objetos da rua terminam na borda visível.
- Cada personagem continua sobre a parte sólida até o seu próprio pé alcançar o fim. Depois cai com gravidade, avança horizontalmente e chega ao seu assento real.
- A câmera acompanha a extensão da horda durante a queda, sem escurecimento da cena. A parede lateral continua para baixo, evitando o bloco de piso suspenso.
- A aproximação reservada não elimina seguidores pela borda da câmera em telas estreitas.
- A saída pela rampa, o salto e a retomada da corrida foram verificados quadro a quadro. Os membros existentes permanecem na mesma partida.

Os eventos aleatórios de esgoto e espaço, os pilotos e passageiros da 0.10.40, os fugitivos menores, a captura, a onda e os obstáculos permanecem disponíveis. As 355 entradas de mídia da versão anterior foram preservadas byte a byte. O saldo de testes continua em pelo menos 1.000.000 de moedas e 10.000 olhos.

Validação feita com os arquivos extraídos do APK assinado: inicialização normal, dados existentes, moedas, contatos, eventos, poses e trajetórias. O teste de transição captura a aproximação, a queda e a saída em 1280×720, 1800×810 e 960×720 e verifica o recorte realmente renderizado. A prévia reproduz 1.440 quadros nativos, a 30 quadros por segundo, incluindo os dois lados da transição.

Android ARM64, versão 0.10.41, código 144, mesmo pacote e certificado da 0.10.40. Nome instalado: Horda Esgoto R41. Fontes, ferramentas e validação estão preservados; a identidade de assinatura fica somente no backup privado.

Não houve instalação ou teste em aparelho Android físico nesta sessão.
