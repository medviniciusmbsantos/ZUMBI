# ZUMBI — Último Voo

> **Downloads suspensos — análise de segurança pendente.** Foi relatada uma detecção do Windows Defender, `Trojan:Script/Ulthar.A!ml`, no pacote `ZUMBI-ABRIR-NO-STUDIO.zip`. Os arquivos de distribuição foram retirados da versão atual. Não restaure o arquivo da quarentena nem desative a proteção. A causa ainda não foi determinada; não há confirmação de falso positivo. Consulte [o registro da investigação](docs/SEGURANCA.md). As instruções de execução abaixo documentam o projeto e não constituem liberação de segurança.

Jogo de sobrevivência cooperativa para Roblox, solo ou com até 6 jogadores. Um avião cai na cidade de Aurora; a equipe explora os prédios, restaura a energia, enfrenta 15 hordas e tenta embarcar no último resgate.

O projeto foi escrito do zero. O mapa usa a ideia de sobrevivência urbana por hordas como referência, com igreja, delegacia e cemitério, mas tem layout, nomes e construções próprios. Não é uma reprodução exata de um mapa do Hypixel e não contém seus assets.

**Estado:** implementação inicial com arquivo de lugar gerável e testes de código aprovados. O motor Roblox não está disponível neste ambiente Linux: física, navegação, interface real, multiplayer, extração e compras precisam da validação descrita em [TESTES](docs/TESTES.md) antes de chamar a experiência de pronta para lançamento. A arte é geométrica, gerada por código; uma produção final ainda pede áudio, identidade visual, ajustes a partir de playtests e divulgação. Nenhum sistema garante viralização.

## Abrir e jogar no Studio

O arquivo entregue está em `build/ZUMBI-Ultimo-Voo.rbxlx`. Para reconstruí-lo, use Python 3.10+ na raiz do repositório:

```sh
python3 tools/build_place.py
```

1. No **Roblox Studio**, use **File → Open from File** e abra esse `.rbxlx`.
2. Pressione **Play (F5)**. O mapa aparece durante a execução; no modo de edição, o lugar contém os scripts que o constroem.
3. Aguarde o carregamento. A primeira preparação dura 40 segundos. Feche o guia, equipe a pistola e explore. Não são necessários modelos, plugins, chaves de API ou bibliotecas de terceiros para jogar o protótipo.
4. Sem acesso a DataStore no Studio, a partida usa progresso temporário e desativa compras. Isso não impede a partida local. Para testar persistência, publique uma experiência **de testes** separada e habilite o acesso do Studio às APIs nas configurações de segurança.
5. Para publicar, siga [PUBLICAÇÃO](docs/PUBLICACAO.md), configure os IDs dos produtos e limite o lugar a 6 jogadores.

Alternativa para desenvolvimento com **Rojo 7**:

```sh
rojo serve default.project.json
# ou gerar o lugar com o próprio Rojo
rojo build default.project.json -o build/ZUMBI-Rojo.rbxlx
```

O gerador Python foi verificado neste ambiente; os comandos Rojo são uma alternativa e não foram executados aqui. O código-fonte é a fonte de verdade. Alterações feitas apenas no arquivo gerado serão perdidas na próxima geração.

## O que está implementado

| Sistema | Comportamento |
| --- | --- |
| Partida | Preparação inicial, pausas, 15 hordas, chefes nas hordas 5/10/15, derrota coletiva e reinício automático |
| Extração | Helicóptero, zona verde, prazo de 45 segundos e recompensa individual para quem chegar |
| Mapa | Igreja com bancos e altar; delegacia com recepção e cela; hospital com macas; oficina; mercado; cemitério com cripta; central de energia; destroços do avião |
| Exploração | Entradas físicas, 3 portas desbloqueadas para a equipe, loot renovado por horda, marcadores de destino e radar de colegas |
| Combate | Pistola, SMG, escopeta e rifle; munição, reserva, recarga, disparos automáticos, cobertura sólida, headshots e 3 níveis de aprimoramento |
| Inimigos | Infectados, corredores e comandante; busca de jogadores e Pathfinding; ataques calculados no servidor |
| Buffs | Titã (+75 vida), Mãos rápidas (recarga 35% menor), Corredor (+3 velocidade), descarga elétrica da praça |
| Resgate | Eliminados voltam na próxima pausa; resgate de partida por moedas na igreja; tokens opcionais persistentes |
| Cosméticos | 5 acabamentos de armas e rastros coloridos; sem dano adicional por acabamento |
| Progressão | Moedas, abates, melhor horda, vitórias, cosméticos e resgates persistidos via DataStore |
| Robux | Developer Products para moedas/resgate/boost de abates, passe Vanguarda; IDs zerados deixam as ofertas indisponíveis |
| Equipe | Assistências, recursos compartilhados, placar da sessão, espectador e convite nativo do Roblox |
| Entrada | Mouse/teclado, botões de toque e controle; loja, guia e mapa dentro do jogo |

## Controles

| Ação | Computador | Controle | Celular |
| --- | --- | --- | --- |
| Atirar | Botão esquerdo do mouse | RT | ATIRAR |
| Recarregar | R | X | RECARGA |
| Correr | Segurar Shift | Alternar com L3 | CORRER |
| Interagir | E próximo ao objeto | Y | Prompt do objeto |
| Armas | 1–4 / mochila Roblox | Mochila Roblox | Barra de armas Roblox |
| Loja | B / botão LOJA | D-pad direita | LOJA |
| Mapa | M / botão MAPA | D-pad cima | MAPA |

A câmera padrão permite terceira pessoa e aproximação até primeira pessoa. No celular/controle, a mira usa o centro da câmera. No computador, usa a posição do mouse. A mochila e os controles de movimento são os nativos do Roblox.

## Economia e compras

Moedas podem ser ganhas jogando e gastas em armas, portas, buffs e cosméticos. A caixa de armas aleatória é **gratuita**, uma vez por horda por jogador; cada arma tem 25% de chance. Não há compra de sorteios. Os resgates da igreja expiram no fim da partida; os tokens de Developer Product ficam no perfil até serem usados. O boost de abates dura 15 minutos de relógio e acumula duração.

Não há prompt automático de compra ao morrer ou entrar. A loja só abre a confirmação oficial após clique do jogador. Preços vêm do MarketplaceService, e ofertas com ID zero aparecem como “Em breve”. Veja [PUBLICAÇÃO](docs/PUBLICACAO.md) para configurar os produtos; não coloque segredos em scripts.

## Desenvolvimento e verificações

```sh
python3 tools/check.py
# Com as ferramentas oficiais Luau disponíveis:
python3 tools/check.py --luau /caminho/luau --compiler /caminho/luau-compile
# Lugar separado com smoke test para executar no Roblox Studio:
python3 tools/build_place.py --smoke-test --output build/ZUMBI-Teste-Studio.rbxlx
```

Sem os executáveis Luau, o comando informa explicitamente que compilação e testes Luau não foram executados. O smoke test do Studio usa um namespace de DataStore separado e deve ser aberto com F5; **não publique o arquivo de teste**. Os testes locais não substituem a execução no Studio.

```text
src/shared/Balance.luau       Regras, preços, armas e escalonamento
src/shared/Config.luau        IDs de Developer Products/passe e namespace de dados
src/server/World.luau         Construção do mapa e interações locais
src/server/GameService.luau   Hordas, progressão da partida, buffs e extração
src/server/ZombieService.luau Rigs, navegação, combate e contabilização dos inimigos
src/server/CombatService.luau Armas, raycasts, cadência, munição e aprimoramento
src/server/DataService.luau   Perfis, sessões, salvamento e recibos idempotentes
src/server/CommerceService.luau Catálogo, passe e entrega de produtos
src/client/main.client.luau   HUD, menus, input, espectador e efeitos locais
tools/build_place.py         Empacotamento do lugar XML, sem dependências Python
```

Para ajustar posições e interiores, altere `World.luau`. Para ajustar dificuldade, preços e armas, altere `Balance.luau`. Não crie outro worktree: trabalhe no checkout existente, já isolado pelo ambiente de nuvem.
