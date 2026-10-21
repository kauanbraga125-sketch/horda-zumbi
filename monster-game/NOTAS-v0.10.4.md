# Versão 0.10.4 — Mascarado e Perfil da Horda

- Seis animações aprovadas do Mascarado integradas, com escala e apoio comuns: caminhada, salto, pouso, captura, dano e virada de veículo.
- Captura com o civil separado e encaixado na mão; pouso no contato real com o solo e virada visual sincronizada. Recompensas e tempos de captura preservados.
- Perfil com recorde em destaque e oito cartões de estatísticas ilustrados.
- Perdas com as 12 causas existentes, inclusive zeradas, total de perdas e maior causa. `rushing_car` aparece como Atropelamentos. Valores são inteiros.
- Dados antigos continuam sendo somados; causas genéricas históricas não são descartadas.
- Pacote Android e certificado iguais aos da versão 0.10.3 para instalação como atualização.

## Validação desta entrega

Foram aprovadas 175 verificações nas cinco suítes executadas sobre os recursos extraídos do APK final: progressão/inventário (56), integração 0.10.1 (20), Livro dos Mortos (38), inicialização real/auditoria (20) e Mascarado/perfil 0.10.4 (41). A auditoria conferiu 66 arquivos e 47 classes; o índice do APK conferiu 702 entradas. As quatro bibliotecas nativas ARM da base foram preservadas byte a byte. Assinaturas v2 e v3 verificadas e certificado SHA-256 idêntico ao da base.

As telas e as seis ações foram renderizadas em Godot 4.5.1 com OpenGL Compatibility. Esses testes executam o conteúdo do APK em Linux; não substituem a instalação em um aparelho Android físico, que não esteve disponível nesta sessão. O encerramento dos testes herda avisos de liberação de recursos do projeto; não houve erro de script, auditoria ou teste funcional.

Consulte `VALIDACAO-v0.10.4.json` para hash, certificado, versão/pacote e resultados por suíte. Para construir novamente e manter o progresso existente, siga `README-v0.10.4.md`.
