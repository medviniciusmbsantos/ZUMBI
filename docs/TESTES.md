# Validação

## Executado no ambiente de nuvem

O comando completo é:

```sh
python3 tools/check.py --luau /caminho/luau --compiler /caminho/luau-compile
```

As ferramentas usadas foram compiladas do repositório oficial `luau-lang/luau`, commit `9d7748a`. Não são dependências do jogo publicado.

- Compilação de todos os módulos e scripts em `src` pelo compilador oficial Luau.
- **134 verificações** de escalonamento das 15 hordas, chefes, recompensas, cadência, munição, aprimoramento e economia básica.
- **41 verificações** executando o código real de DataService com serviços Roblox simulados: carga, gastos, cosméticos, reconexão, sessão ocupada, compras, recibos repetidos, falhas de rede, ganho durante salvamento e fallback do Studio.
- **3 testes Python** de integridade do arquivo XML: hierarquia, presença exata dos fontes, unicidade das referências, geração determinística e separação do lugar de smoke test.
- Geração do `.rbxlx` normal e do arquivo separado de teste.

Essas verificações **não executam o motor Roblox**. Não comprovam navegação, colisão, comportamento dos rigs, câmera, prompts, GUI em aparelhos reais, multiplayer, persistência na nuvem Roblox ou entrega de compras na plataforma.

## Smoke test automático no Studio — ainda não executado

```sh
python3 tools/build_place.py --smoke-test --output build/ZUMBI-Teste-Studio.rbxlx
```

Abra o arquivo de teste no Roblox Studio, mostre **Output** e pressione **Play (F5)**, sem movimentar o personagem durante a execução inicial. Ele deve terminar com a mensagem `[ZUMBI SMOKE] COMPLETED`, sem `FAIL` nem erros vermelhos. O script verifica montagem do mapa, locais, loot, portas, personagem, arma, consumo de munição, acerto real, bloqueio por parede, rejeição de cadência impossível/NaN, recarga e atribuição de abate.

O arquivo de teste acrescenta `ZumbiStudioSmoke` e usa `ZumbiUltimoVoo_smoke_v1` em vez do namespace normal. Ele não testa compras reais e não deve ser publicado. O jogo normal não contém esse script.

## Playtest obrigatório antes do lançamento — ainda não executado

| Cenário | Resultado esperado |
| --- | --- |
| Play solo, API do Studio desativada | Mapa e personagem carregam; aviso de progresso temporário; compras desativadas; jogo continua |
| Inicialização com dados habilitados em experiência de testes | Perfil carrega, 120 moedas no primeiro acesso e pistola no inventário |
| Queda do avião | Cena visual sem explosão física que mate jogadores ou destrua o mapa |
| Igreja / delegacia / central | Porta inicialmente fechada; moedas descontadas uma única vez; porta aberta para toda a equipe |
| Todos os locais | Entrada, saída, piso e circulação funcionam; sem objetos prendendo jogadores ou pontos de queda fora do mapa |
| Caixa de resgate | Uma arma gratuita por jogador por horda, sem gasto e sem prompt de Robux |
| Loot | Um uso por caixa por horda; uso simultâneo não duplica prêmio; próximo ciclo renova caixas |
| Armas e cobertura | Cadência e recarga distintas; headshot causa 1,7× de dano; paredes bloqueiam; sem dano entre jogadores |
| Inimigos | Caminham até o jogador pela porta aberta, causam dano próximo e não atravessam paredes; chefes entram nos locais |
| Navegação travada | Inimigos presos por 28 segundos são retirados sem recompensa, evitando horda interminável |
| Energia / buffs | Antes do gerador, buffs/aprimoramento recusam a compra; depois, efeitos correspondem à descrição |
| Corrida | Consome stamina ao se mover; esgotamento cancela corrida; recuperação permite correr novamente |
| Morte de um jogador | Pode espectar a equipe; volta na pausa; resgate disponível pode trazê-lo antes |
| Morte coletiva | Contagem de 8 segundos permite usar resgate; sem sobreviventes após o prazo, derrota e nova partida |
| Hordas 5 / 10 / 15 | Comandante com mais vida; equipe pode abatê-lo; próxima fase acontece |
| Extração | Após a horda 15, zona verde e helicóptero aparecem; só os vivos na zona quando o tempo zera ganham vitória e +300 |
| Nova partida | Portas, gerador, loot e buffs reiniciam; moedas, cosméticos e recordes continuam |
| Cosmetics | Compra cobra uma vez; equipar novamente é gratuito; acabamento e rastro são vistos por outro cliente |
| Reentrada | Moedas, abates, recorde, vitórias e cosméticos mantidos na experiência de testes |
| Multiplayer 2 e 6 clientes | Sem dano entre jogadores; mesmas fases, portas, inimigos e loot para todos; assistências e resgates coerentes |
| Device Emulator e aparelho real | HUD legível, botões acessíveis, movimento, câmera, disparo e recarga simultâneos |
| Controle | RT/X/Y não conflitam; D-pad abre loja/mapa; seleção navega e B fecha o menu |
| Compras configuradas | Preço do prompt correto; um único benefício entregue e salvo; produto não é entregue somente porque o prompt fechou |

Use a sessão de servidor com múltiplos clientes na aba **Test** do Studio. Percorra o mapa inteiro com um cliente e acompanhe outro no modo espectador. No primeiro teste das 15 hordas, registre a duração, mortes e armas usadas; ajuste Balance a partir desses resultados, sem tornar a loja paga um requisito de sobrevivência.

## Verificações de abuso

Em uma experiência de testes, tente eventos de disparo com vetores inválidos e frequência excessiva; compras de acabamentos com chaves desconhecidas; interações a distância; resgates quando vivo; e entrada no mesmo perfil em servidores diferentes. Os testes locais cobrem parte dessas regras. A proteção de cadência, munição, dano e moedas fica no servidor, mas isso não equivale a um sistema completo contra teleporte ou outras explorações de física do Roblox.

As barricadas desta primeira versão são pontos de manutenção com recompensa limitada por jogador/horda; não são um sistema completo de cerco/destruição por zumbis. Áudio próprio, animações refinadas, acessibilidade avançada e métricas de retenção também ficam para a etapa de polimento.
