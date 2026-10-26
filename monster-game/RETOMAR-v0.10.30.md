# Retomar a entrega 0.10.30 após desconexão

O código e as artes completos estão nesta branch. A main permanece na versão 0.10.29, já publicada. Não anuncie um link de APK 0.10.30 como pronto: o ambiente foi desconectado antes de preservá-lo.

## Estado verificado

- Base main: 6620a95c41e6f0b255b4d850c551107fbb993fca.
- Código Android 133. Pacote com.kauan.noitedahorda.reconstruida.
- Identidade pública do certificado: a641a59f39561af0210f2f1cd246f58c5bfd9ab05462bf5b0635e626d681d15d.
- APK 0.10.29 de base: 221ec982137efca60aac576a268f2ad3961ce038eb7d7cc6c27128f82f62469a.
- Primeiro APK 0.10.30: 117347686 bytes, SHA-256 9fdedbd197e56147b26f169dc3992d8f2ff257db21f37a9d0a3adfc44c098dee. Passou na abertura dos 176 arquivos/55 classes, 96.182 verificações espaciais, 45 de saldo e 13 cenas nativas.
- Último APK local após corrigir as missões da captura na reentrada: 117347692 bytes, SHA-256 b50e9ef42b4e96ead84eb0d91e320e5dbb0129651ce1a345b2c79ad9d5c4d1c5. Compilação, assinatura e preservação das 262 mídias anteriores verificadas. Testes no código atual: 96.184 verificações, sem falhas. A conferência final no pacote foi iniciada e precisa ser confirmada.
- Seis corridas sem o poder espacial deram exatamente as mesmas 3.295 amostras da 0.10.29 (SHA-256 do relatório d9526066d9088db243adde3667d6503e88c47ca3c01f4f45709ce9fe80777794).
- Não houve teste em aparelho Android físico.

## Arquivos do ambiente anterior, se recuperáveis

/workspace/scratch/6752b369573f/build/Horda-Zumbi-v0.10.30-ARM64.apk
/workspace/scratch/6752b369573f/build/Horda-Zumbi-v0.10.30-ARM64.json
/workspace/scratch/6752b369573f/work/v130-packaged-boot.log
/workspace/scratch/6752b369573f/work/v130-packaged-space.log
/workspace/scratch/6752b369573f/work/v130-packaged-visual.log
/workspace/scratch/6752b369573f/work/packaged-space-visual/
/workspace/scratch/6752b369573f/project/monster-game/.godot/v130-project.binary

Uma reserva de upload foi criada, mas os bytes NÃO foram transferidos nem finalizados. Não trate a reserva como um APK salvo. A tentativa de envio direto falhou com “no primary turn environment is available”.

## Reconstruir com segurança

1. Se os arquivos locais tiverem desaparecido, materialize o backup privado completo 0.10.29 do proprietário e sobreponha o projeto com esta branch. A chave fica apenas no backup privado; nunca publique chave, senha, assinatura_privada ou esse ZIP no GitHub.
2. Remova o project.binary antigo da raiz de trabalho (guarde como arquivo histórico). Ele sobrepõe o project.godot e manteria a configuração 0.10.29. Exporte a nova configuração nativa para .godot/v130-project.binary com tools/save_runtime_config.gd no Godot 4.5.1.
3. Atualize startup_integrity.json com tools/refresh_startup_integrity.py. O manifesto antigo desta branch fica desatualizado enquanto o projeto é editado; sua regeneração é obrigatória antes de abrir boot.tscn ou compilar.
4. Compile usando o APK base verificado e tools/build_v130.py. Use a identidade privada existente, ZIP alignment, scripts em texto e o mesmo pacote.
5. Repita abertura, tests/v130_space.gd, tests/v130_visual.gd e saldo sobre os arquivos extraídos do APK assinado. Confirme o caso de captura iniciado no último instante e finalizado no pouso.
6. Preserve APK + recuperação completa com fonte, importações, artes, testes e identidade privada. Publique somente fontes, artes e o APK assinado no GitHub, mantendo a chave privada.

## Implementação entregue no código

Poder grátis tipo 4, cápsula de cérebro verde, 30/40/50/60 segundos, primeiro item antecipado no modo de testes. Segure para subir e solte para descer. A distância e os túneis avançam; quatro camadas por altitude, NPC astronauta capturável, parasita, meteoros, satélite, cápsula, caixão, nave, ovo e monólito. Buraco negro animado e referências a terror espacial. Impactos custam tempo; energia prolonga com limite. Aterrissagem em área segura mantendo horda, itens e progresso. Mercado e laboratório espacial incluídos. Há 32 células de sprites, dois fundos e oito faixas/efeitos originais.
