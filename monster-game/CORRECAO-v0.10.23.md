# Horda Zumbi 0.10.23 — quatro acessórios

Base: fontes e APKs verificados da **0.10.22**, recuperados de Horda-Zumbi-v0.10.22-Recuperacao.zip. Todos os scripts herdados foram comparados com o APK dessa versão antes da edição.

## Alterações

- **Óculos Cibernéticos (z_cyber):** a armação inteira acompanha os dois olhos com uma única transformação de rotação, translação e escala uniforme. A ponte permanece contínua, com as lentes sem deformação. A haste traseira continua sob o cabelo e a orelha.
- **Óculos a Vapor (z_goggles):** o mesmo encaixe preserva as lentes redondas, a ponte e a perspectiva original da peça.
- **Máscara do Gelo (z_hockey):** ajuste uniforme por olhos e queixo, preservando a altura e o formato da máscara. As aberturas dos olhos são vazadas na malha nativa para mostrar os olhos do personagem, sem editar o PNG.
- **Cabelo do Palhaço (z_clown):** menor, apoiado mais baixo na cabeça e separado em camadas para passar atrás do rosto e do corpo. O cabelo original é ocultado por malhas próprias dos 96 quadros do zumbi. Olhos, sobrancelhas e boca possuem proteção explícita; roupa, mãos e pés usam os pixels originais.

Os 31 outros acessórios mantêm os mesmos dados gráficos e o mesmo resultado nas comparações de renderização. Nenhum PNG de personagem ou acessório foi editado. Os 263 conjuntos de medidas e malhas originais em fitting.bin continuam byte a byte iguais aos da 0.10.22.

## Arquivos principais

- scripts/cosmetics.gd: montagem e desenho das quatro peças.
- assets/art/cosmetics_v113/graphics.json: encaixes e malhas dos quatro itens.
- assets/art/cosmetics_v123/clown_sources.bin: malhas complementares da peruca.
- tools/prepare_v123_items.py: preparação reproduzível a partir das artes existentes.
- tools/build_v123.py: atualização verificável dos APKs da 0.10.22.
- tests/v123_items.gd e tests/v123_items_visual.gd: comparações gráficas, proteção dos pixels e prévias.

## Instalação e revisão

O APK ARM64 mantém o pacote `com.kauan.noitedahorda.reconstruida`, a assinatura da 0.10.22 e usa versionCode 126. Instale como atualização sobre a versão reconstruída anterior. A assinatura privada fica fora do repositório.

Para revisar os itens: **Configurações → Desenvolvedor → Bancada de itens → itens 12 a 15**. A bancada permite pausar, avançar quadros, mudar a animação, inverter o lado e comparar com o personagem sem o acessório.

## Validação e limites

Os relatórios que acompanham o APK e o backup registram os resultados finais dos testes de renderização, coleção, movimentação, bancada, integridade dos recursos, assinatura e inicialização a partir dos arquivos do APK final. Os APKs preservam as 241 entradas anteriores de imagens, áudio, fontes e bibliotecas de cada perfil.

O teste em aparelho Android físico continua pendente; a execução automatizada usa Godot 4.5.1 no computador com os recursos extraídos do APK.
