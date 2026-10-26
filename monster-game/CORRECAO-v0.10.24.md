# Horda Zumbi 0.10.24 — máscara e peruca redesenhadas

Esta revisão parte das fontes e dos APKs verificados da **0.10.23**. A versão anterior continua preservada em seus APKs, backup de recuperação e referência local `backup/v0.10.23`.

## Resultado

- **Máscara do Gelo, item 14:** nova arte em três quartos, com o formato mais largo do rosto. As duas aberturas transparentes acompanham os centros dos olhos; o apoio inferior acompanha o queixo. Uma camada do personagem mantém as orelhas na frente da peça.
- **Cabelo do Palhaço, item 15:** nova peruca com cachos maiores, coroa preenchida e franja curta. O encaixe uniforme cobre o cabelo antigo e acompanha as medidas da cabeça em cada quadro. As camadas originais preservam olhos, sobrancelhas, boca, orelhas, roupa, mãos e pés.

Os 33 outros acessórios, incluindo os dois óculos corrigidos na 0.10.23, mantêm os mesmos dados gráficos. Os PNGs dos personagens e o arquivo original fitting.bin permanecem inalterados.

## Arte e prompts

As artes foram criadas e refinadas com a ferramenta de imagens integrada, usando o próprio zumbi como referência de estilo e perspectiva. Os PNGs finais foram copiados para o projeto sem alteração de pixels; as texturas do jogo usam compressão sem perdas.

- Arte da máscara: `assets/art/cosmetics_v124/hockey.png`.
- Arte da peruca: `assets/art/cosmetics_v124/clown.png`.
- Prompt da máscara: `tools/art_sources/v124/hockey-prompt.txt`.
- Refinamento das aberturas: `tools/art_sources/v124/hockey-fit-edit-prompt.txt`.
- Prompt da peruca: `tools/art_sources/v124/clown-prompt.txt`.
- Referência visual e primeira arte da máscara: `tools/art_sources/v124/`.
- Preparação reproduzível das texturas e camadas: `tools/prepare_v124_items.py`.

## Verificações

- 434 verificações específicas, sem falhas: encaixes, 96 quadros do zumbi e medidas originais.
- 392 renderizações dos dois itens, nos dois lados e nas nove animações.
- 594 renderizações dos outros 33 itens com pixels idênticos aos da 0.10.23.
- 566.480 amostras protegidas de olhos, boca e corpo, sem diferenças acima da tolerância de 8 níveis em 255 entre malha e textura original.
- Coleção: 7.170 verificações; teste geral de jogo: 64 verificações principais e regressões de sobreviventes, sem falhas.
- Texturas novas comparadas no Godot com os pixels RGBA dos PNGs; aberturas da máscara transparentes.

Os relatórios junto do backup registram a validação final da inicialização e da bancada com os recursos extraídos do APK entregue. A assinatura, o pacote e as 241 entradas anteriores de mídia e bibliotecas são preservados em cada perfil. A auditoria de inicialização confere 117 arquivos e 55 classes.

O teste físico no Moto G71 continua pendente. Os testes automatizados usam Godot 4.5.1 no computador, incluindo a execução dos recursos do APK final.

## Instalação e revisão

Versão 0.10.24, versionCode 127, pacote `com.kauan.noitedahorda.reconstruida`. Instale como atualização sobre a edição reconstruída anterior, sem desinstalar nem apagar os dados.

Para revisar: **Configurações → Desenvolvedor → Bancada de itens → itens 14 e 15**. A bancada permite comparar, inverter o lado, pausar, avançar quadros e trocar a animação sem comprar ou equipar os itens no progresso do jogador.
