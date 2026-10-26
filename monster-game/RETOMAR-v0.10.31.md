# Retomar a versão 0.10.31

Última atualização sobre a 0.10.30: identificação Horda Espaco R31, atalhos de espaço e saldo na tela inicial, espaço em primeiro lugar no desenvolvedor. O problema relatado no aparelho não foi reproduzido nos testes de abertura normal da 0.10.30. Não trate a causa do aparelho como confirmada.

Configuração: Godot 4.5.1, pacote com.kauan.noitedahorda.reconstruida, código Android 134. Nunca coloque project.binary antigo na raiz dos fontes; a configuração nativa atual está em .godot/v131-project.binary no backup privado. Regere startup_integrity.json depois de editar ou importar.

Compilação: tools/build_v131.py usa o APK 0.10.30 verificado e a identidade privada existente. tests/v131_startup.gd testa a inicialização real sem --space-test; execute em um XDG_DATA_HOME temporário e vazio com HORDA_STARTUP_FIXTURE=new ou existing e HORDA_VALIDATION_DIR para evidências. Essa suíte exercita os botões pelo mesmo roteamento de toque. tests/v130_space.gd continua cobrindo o voo e tests/v129_currency.gd o orçamento da loja.

Leia CORRECAO-v0.10.31.md e VALIDACAO-v0.10.31.json para a entrega atual. release-v0.10.31/restore_release.py reconstrói o APK assinado por um delta do APK público 0.10.30, sem chave privada. O backup completo privado contém fonte, importações, artes, testes, APK e chave. Não publique a chave ou o backup privado.
