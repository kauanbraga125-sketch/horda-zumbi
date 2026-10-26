# Horda Zumbi 0.10.25 — encaixe do cabelo do palhaço

Revisão sobre a versão 0.10.24, preservada no backup anterior. O cabelo roxo original ainda aparecia sob os cachos laranja porque os recortes de proteção dos olhos também preservavam a franja. Além disso, a testa era repintada por cima da peruca e repetia o contorno pontudo do cabelo antigo.

Esta versão recorta apenas o cabelo antigo com malhas nativas, mantém os olhos, sobrancelhas, boca, orelhas e corpo, coloca a testa sob os cachos e aproxima a peruca da linha da cabeça. O encaixe segue a mesma animação, rotação e escala do personagem, inclusive espelhado. Nenhum PNG foi alterado; a arte laranja da v0.10.24 foi mantida. Os outros 34 acessórios continuam iguais.

Arquivos principais: `scripts/cosmetics.gd`, `assets/art/cosmetics_v125/hair_layers.bin`, registro `z_clown` em `assets/art/cosmetics_v113/graphics.json` e gerador `tools/prepare_v125_hair.py`. O arquivo original `fitting.bin`, com 263 quadros medidos, foi preservado.

Validação: renderização das nove animações nos dois sentidos, revisão dos 96 quadros únicos do zumbi, comparação de olhos, boca e corpo com uma renderização independente do personagem original, detecção de vazamento do cabelo roxo e comparação dos outros 34 acessórios com a v0.10.24. Os relatórios completos ficam em `validacao` no ZIP de recuperação, junto das verificações do APK, bancada, coleção e inicialização.

Android: pacote `com.kauan.noitedahorda.reconstruida`, versão `0.10.25`, código `128`, nome `Horda Zumbi R25`. A assinatura das edições reconstruídas foi preservada. Instale sobre a v0.10.24 sem desinstalar nem apagar dados. A validação em aparelho físico continua pendente; não foi usado um Moto G71 nesta revisão.

O backup privado inclui todas as alterações acumuladas sobre a base pública no commit `f7bebdd9b8cf8d81cf4e0f28ebfb16dcfccfc720`, artes anteriores, ferramentas, evidências de validação e assinatura separada. A restauração usa esse commit público ou uma cópia local da base. Não publique a pasta `assinatura_privada`.
