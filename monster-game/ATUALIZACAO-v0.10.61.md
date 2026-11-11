# Horda Zumbi 0.10.61 — três caminhos físicos

A entrada do esgoto é um buraco finito na pista, com chão antes e depois.
O evento oferece três escolhas pelos controles normais:

| Movimento | Resultado |
| --- | --- |
| Pulo curto, pousando no pula-pula | Subida pelo céu |
| Seguir correndo | Queda individual dos zumbis no esgoto |
| Pular e segurar | Atravessar a abertura e continuar na rua |

O menu **EVENTO ESGOTO** abre diretamente este encontro para teste.
O botão **Entrar no esgoto** foi retirado. A queda só começa quando um pé
realmente passa do plano da rua dentro da abertura. O chão desenhado e a
colisão usam as mesmas duas margens. A formação não muda o ponto de salto dos
seguidores durante a travessia, e a câmera acompanha também o último zumbi.

Esta cópia recupera primeiro os fontes e as artes da versão 0.10.60, preservando
as melhorias da subida e do Universo Maligno. A recuperação veio do APK original
`Horda-v0.10.60-Android.apk`, SHA256
`944132b54c758bd053351bb1e25d8b6b93b5717845eb5f709b3c50fc7472c8b7`.

## Verificação

Godot 4.5.1, 27 casos: três caminhos, hordas de 1/6/20 personagens e passos de
30/60/120 FPS. Os mesmos casos rodam com os recursos extraídos do APK final.
Há ainda verificação da inicialização, integridade, assinatura e alinhamento
Android, teste do botão real do menu e três gravações com toque real simulado.
O teste em aparelho Android físico ainda precisa ser feito.

```
godot --headless --path monster-game --editor --import
python3 monster-game/tools/refresh_startup_integrity.py
godot --headless --path monster-game --script res://tests/v161_routes.gd
godot --headless --path monster-game --script res://tests/v161_lab.gd
```

`tools/build_v161_test.py` aceita o APK original acima, o Godot 4.5.1 e Android
Build-Tools 35. O APK de teste usa `com.kauan.noitedahorda.rotas`, instalando em
separado das edições anteriores. A chave de teste fica fora do versionamento.

Os dois commits locais separam a recuperação da 0.10.60 e esta correção. A
publicação no GitHub aguarda autorização do proprietário.
