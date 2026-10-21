# Horda Zumbi 0.10.5

O Experimento de Ressurreição tem uma tela ilustrada, com a máquina de bronze, cartões de missão e recompensas legíveis. O líquido usa um shader contínuo: sobe em qualquer porcentagem, ondula, borbulha e estoura bolhas na superfície. Os objetos ficam submersos, flutuam, piscam e se movimentam.

São 90 missões (30 fáceis, 30 médias, 30 difíceis), com 25 condições de jogo e 24 ilustrações. Três ficam ativas por vez. Cada missão concluída permanece visível por 1,9 segundo e recebe uma substituta elegível, sem apagar as vizinhas. O catálogo evita missões de poderes ou áreas ainda bloqueadas e varia as famílias recentes. Objetivos de uma partida emitidos durante uma corrida começam na próxima partida; objetivos acumulativos contam apenas as próximas ações.

As 12 cores combinam independentemente com 15 objetos, oferecendo 500 misturas distintas até o nível máximo atual. Nomes incluem Soro Reanimador, Soro do Acampamento, Extrato do Porão e Plasma da Fita Perdida. São referências de atmosfera; a identidade das criaturas do jogo foi preservada.

Ao encher: essência entra, frasco reage, o nível sobe, moedas explodem e voam até a carteira, o saldo conta a recompensa e uma nova mistura começa. A mesma sequência atende todas as cores, múltiplos níveis e essência excedente. A recompensa é gravada antes do efeito visual: fechar ou trocar de tela não duplica nem perde o crédito.

As seis animações do Mascarado e as telas de Perfil/Perdas da 0.10.4 continuam incluídas. A migração preserva missões antigas em andamento, compras, moedas, olhos e demais dados. O pacote e a assinatura Android permanecem os mesmos da edição de testes 0.9.1 em diante. A atualização mantém o diretório de salvamento. Não desinstale a versão anterior para atualizar.

Não foram adicionados novos monstros ou um sistema novo de prêmios especiais por marcos de nível. As recompensas existentes de moedas/olhos continuam.

## Validação

Testes de regressão de inventário, progressão, livro, inicialização e animações, mais testes específicos da 0.10.5; renderização real no Godot 4.5.1 com OpenGL, incluindo as 12 misturas e etapas da recompensa. APK verificado com a assinatura original, bibliotecas ARM preservadas e índice de recursos reconstruído. A validação neste ambiente não substitui o teste de instalação, toques e desempenho em um Android físico.
