# Horda Zumbi 0.10.30 — Abdução Maldita

Base verificada: 0.10.29, GitHub 6620a95c41e6f0b255b4d850c551107fbb993fca. Preservar pacote e assinatura. Código Android 133.

Escopo autorizado: poder espacial com 30/40/50/60 segundos, progresso horizontal e túneis reais durante o voo, altitude crescente, NPCs animados, meteoros/satélites/ovos/nave fantasma, buraco negro, referências de terror espacial, cenário com paralaxe e animação, APK para teste e backups.

Arquitetura: scripts/space.gd como subsistema de HordeRun; sem substituir sprites de zumbi/esqueleto e sem alterar cosméticos. Mercado com poder grátis e melhoria de tempo. Espaço separado das metamorfoses, sem acumular poderes. Primeiro item garantido cedo no modo de testes e laboratório espacial. Durante o voo não há colisões terrestres; na volta, área livre e proteção breve, mantendo distância, túneis e horda. Perigos espaciais reduzem tempo. Capturas rendem almas e membros.

Artes geradas: tools/art_sources/v130/npc-generated.png (4x4, astronauta flutuar/pânico e parasita flutuar/ataque), props-generated.png (4x4, OVNI/cérebro/meteoritos/caixão/satélite/cápsula/nave/ovo), orbit-generated.png, nebula-generated.png. Preparar atlas normalizado e fundos em assets/art/space_v130.

Referências: Alien (parasita e ovo), Dead Space (destroços de mineração), Event Horizon (nave gótica e horizonte perdido), monólito 2001 como encontro raro. Artes próprias em tom de paródia.

Pendências: implementar, importar/validar, integrar áudio/mercado/dev, compilar APK assinado, verificar APK e preservar GitHub + backup privado. Nunca enviar assinatura_privada ao GitHub.


Checkpoint após desconexão do ambiente: implementação e artes concluídas. Simulação do código passou em 96.184 verificações. A primeira compilação passou na abertura real do pacote, 96.182 verificações espaciais, 45 verificações de saldo e 13 cenas renderizadas. A corrida sem o novo poder reproduziu exatamente 3.295 amostras da 0.10.29 em seis cenários. O APK final foi recompilado após corrigir a contagem de missões da captura no último instante; a conferência final e o salvamento foram interrompidos pela indisponibilidade do ambiente. O binário ainda não foi publicado. Leia RETOMAR-v0.10.30.md antes de continuar.
