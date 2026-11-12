# Serra distante — 0.10.63

`mountains.webp` é uma ilustração original criada para o cenário por geração de imagem integrada, com transparência real. O arquivo foi convertido para WebP com alfa preservado. Não contém personagens, interface ou colisões de gameplay.

Direção de arte: serra ampla de basalto, picos e ruínas distantes, pintura de fantasia gótica em lavanda e violeta, detalhes suaves de luz pêssego, vales índigo, contraste discreto, borda superior recortada e névoa na base. Sem céu, lua, nuvens, personagens, textos ou marcas.

Prompt de produção: “Production background layer for a 2D side-scrolling gothic fantasy game, a wide horizontal mountain range cutout on a truly transparent background. One cohesive hand-painted ridge of immense jagged basalt mountains, distant weathered spires and crags, softly layered lavender and dusky violet rock, with a few muted peach-lit edges and deep indigo valleys. Distant scenery with softened detail, low contrast, majestic scale and restrained texture. Peaks occupy the upper half and a connected rocky mass fills the lower half, disappearing into purple haze. No sky, moon, clouds, foreground, characters, monster, UI, text, watermark, borders or sprite-sheet grid.”

`ridge.json` mede a primeira linha com alfa de pelo menos 128 em cada coluna da arte final. A posição dos pés usa esse mesmo contorno, com interpolação. A serra principal e o gigante compartilham a projeção vertical do mundo. As duas cadeias posteriores usam velocidades e profundidades menores; a base das três recebe transparência gradual no código.
