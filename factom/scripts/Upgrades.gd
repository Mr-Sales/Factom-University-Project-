extends Reference
# Dados dos upgrades (aba "Upgrades" da barra de baixo).
# Preços e textos ficam aqui. A ordem da lista é a ordem em que aparecem na aba.
#
# type:
#   "shape"   -> libera um minério para a máquina de Início (target = forma)
#   "machine" -> libera uma máquina na aba Máquinas (target = id no CATALOG do Main.gd)
#   "config"  -> libera a opção "Configurar" no Início
#   "ore2"    -> libera um minério de 2º nível (evolução de outro). A máquina dele vem no upgrade seguinte
#   "refine"  -> libera "Virar refinadora" nas máquinas de 2º nível (target = id da máquina)
# requires: id do upgrade que precisa estar comprado antes ("" = nenhum)
# name = nome curto (cabe no botão), title = nome completo (janelinha)

const LIST = [
	{
		"id": "tri_ore", "type": "shape", "target": "triangle", "requires": "", "price": 100,
		"name": "Triângulo", "title": "Minério: Triângulo", "icon": "triangulo",
		"desc": "Libera o TRIÂNGULO como minério.\n\nA partir daqui o Início cospe círculo e depois triângulo, em ciclo, por cada uma das suas saídas.\n\nCuidado: uma máquina só aceita a forma dela, o resto que chegar é perdido. Para refinar triângulos você vai precisar da máquina do triângulo (próximo upgrade).",
	},
	{
		"id": "tri_machine", "type": "machine", "target": "triangle", "requires": "tri_ore", "price": 150,
		"name": "Máq. Triângulo", "title": "Máquina do Triângulo", "icon": "estado_triangulo",
		"desc": "Libera a MÁQUINA DO TRIÂNGULO na aba Máquinas.\n\nEla recebe triângulos crus, segura cada um por um tempo e devolve o triângulo refinado, que vale bem mais no Fim.",
	},
	{
		"id": "sq_ore", "type": "shape", "target": "square", "requires": "tri_machine", "price": 300,
		"name": "Quadrado", "title": "Minério: Quadrado", "icon": "quadrado",
		"desc": "Libera o QUADRADO como minério.\n\nO Início passa a cuspir círculo, triângulo e quadrado, em ciclo, por cada saída. Para refinar quadrados você vai precisar da máquina do quadrado (próximo upgrade).",
	},
	{
		"id": "sq_machine", "type": "machine", "target": "square", "requires": "sq_ore", "price": 400,
		"name": "Máq. Quadrado", "title": "Máquina do Quadrado", "icon": "estado_quadrado",
		"desc": "Libera a MÁQUINA DO QUADRADO na aba Máquinas.\n\nEla recebe quadrados crus e devolve quadrados refinados, que valem mais no Fim.",
	},
	{
		"id": "cfg_start", "type": "config", "target": "", "requires": "sq_machine", "price": 500,
		"name": "Config. Início", "title": "Configurar o Início", "icon": "estado_inicio",
		"desc": "Libera a configuração da máquina de Início.\n\nClique no Início e escolha \"Configurar\": ele pode cuspir só círculo, só triângulo ou só quadrado (ou voltar ao ciclo com todos). Cada Início é configurado separadamente.\n\nÓtimo para não desperdiçar minério em máquinas que não aceitam a forma.",
	},
	{
		"id": "hex_ore", "type": "ore2", "target": "hexagon", "requires": "cfg_start", "price": 700,
		"name": "Octógono", "title": "Minério: Octógono", "icon": "octogono",
		"desc": "O OCTÓGONO é a evolução do CÍRCULO. Ele não sai do Início: o círculo precisa ser refinado na máquina do círculo e depois passar pela máquina do octógono, que o transforma em octógono.\n\nEste upgrade libera o minério. A máquina vem logo depois.",
	},
	{
		"id": "hex_machine", "type": "machine", "target": "hexagon", "requires": "hex_ore", "price": 900,
		"name": "Máq. Octógono", "title": "Máquina do Octógono", "icon": "estado_octogono",
		"desc": "Libera a MÁQUINA DO OCTÓGONO na aba Máquinas.\n\nEla recebe círculos JÁ REFINADOS e, depois de um tempo, os transforma em octógonos.\n\nCadeia: Início > Círculo > Octógono > Fim.",
	},
	{
		"id": "hex_refine", "type": "refine", "target": "hexagon", "requires": "hex_machine", "price": 1200,
		"name": "Refin. Octógono", "title": "Refinaria do Octógono", "icon": "octogono_branco",
		"desc": "Libera a opção \"Virar refinadora\" (Upgrade > Virar refinadora) nas máquinas do octógono. Uma máquina convertida passa a transformar octógono em octógono refinado, que vale muito mais.\n\nSó dá para converter uma máquina que recebe itens de outra máquina do octógono.\n\nCadeia completa: Início > Círculo > Octógono > Octógono (refinadora) > Fim, passando por 3 máquinas.",
	},
	{
		"id": "star_ore", "type": "ore2", "target": "star", "requires": "hex_refine", "price": 2000,
		"name": "Estrela", "title": "Minério: Estrela", "icon": "estrela",
		"desc": "A ESTRELA é a evolução do TRIÂNGULO. O triângulo precisa ser refinado na máquina do triângulo e depois passar pela máquina da estrela.\n\nEste upgrade libera o minério. A máquina vem logo depois.",
	},
	{
		"id": "star_machine", "type": "machine", "target": "star", "requires": "star_ore", "price": 2500,
		"name": "Máq. Estrela", "title": "Máquina da Estrela", "icon": "estado_estrela",
		"desc": "Libera a MÁQUINA DA ESTRELA na aba Máquinas.\n\nEla recebe triângulos JÁ REFINADOS e, depois de um tempo, os transforma em estrelas.\n\nCadeia: Início > Triângulo > Estrela > Fim.",
	},
	{
		"id": "star_refine", "type": "refine", "target": "star", "requires": "star_machine", "price": 3200,
		"name": "Refin. Estrela", "title": "Refinaria da Estrela", "icon": "estrela_branco",
		"desc": "Libera a opção \"Virar refinadora\" nas máquinas da estrela. Uma máquina convertida transforma estrela em estrela refinada.\n\nSó dá para converter uma máquina que recebe itens de outra máquina da estrela.\n\nCadeia completa: Início > Triângulo > Estrela > Estrela (refinadora) > Fim.",
	},
	{
		"id": "dia_ore", "type": "ore2", "target": "diamond", "requires": "star_refine", "price": 5000,
		"name": "Losango", "title": "Minério: Losango", "icon": "losangulo",
		"desc": "O LOSANGO é a evolução do QUADRADO. O quadrado precisa ser refinado na máquina do quadrado e depois passar pela máquina do losango.\n\nEste upgrade libera o minério. A máquina vem logo depois.",
	},
	{
		"id": "dia_machine", "type": "machine", "target": "diamond", "requires": "dia_ore", "price": 6000,
		"name": "Máq. Losango", "title": "Máquina do Losango", "icon": "estado_losangulo",
		"desc": "Libera a MÁQUINA DO LOSANGO na aba Máquinas.\n\nEla recebe quadrados JÁ REFINADOS e, depois de um tempo, os transforma em losangos.\n\nCadeia: Início > Quadrado > Losango > Fim.",
	},
	{
		"id": "dia_refine", "type": "refine", "target": "diamond", "requires": "dia_machine", "price": 7500,
		"name": "Refin. Losango", "title": "Refinaria do Losango", "icon": "losangulo_branco",
		"desc": "Libera a opção \"Virar refinadora\" nas máquinas do losango. Uma máquina convertida transforma losango em losango refinado, o item mais valioso do jogo.\n\nSó dá para converter uma máquina que recebe itens de outra máquina do losango.\n\nCadeia completa: Início > Quadrado > Losango > Losango (refinadora) > Fim.",
	},
]
