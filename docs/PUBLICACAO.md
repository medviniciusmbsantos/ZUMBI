# Publicação e monetização

## Primeiro teste

1. Primeiro esclareça o alerta de segurança descrito em [SEGURANÇA](SEGURANCA.md). Depois da validação pendente, gere e abra `build/review/ZUMBI-Candidata.rbxlx` no Roblox Studio.
2. Execute o roteiro em [TESTES](TESTES.md), incluindo jogo em equipe e extração. Corrija qualquer falha encontrada antes do lançamento.
3. Publique uma cópia em uma experiência **de testes**, mantendo o acesso restrito enquanto valida.
4. Defina o limite do lugar para **6 jogadores** nas configurações do lugar.
5. Para testar DataStore no Studio, habilite **Enable Studio Access to API Services** apenas nessa experiência de testes. O ambiente de testes não deve compartilhar a experiência de produção: DataStores são separados por experiência, não apenas por lugar.

As sessões de perfis têm uma concessão de 150 segundos, renovada no salvamento periódico de 40 segundos. Uma falha de carga em servidor publicado impede o login para proteger dados; no Studio, permite partida temporária sem compras. O encerramento tenta salvar em paralelo por até 25 segundos. Ainda é necessário testar falhas de serviço e reconexão nas condições reais da plataforma.

## Produtos com Robux

Crie os itens no **Creator Dashboard**, na monetização da mesma experiência que será publicada. Substitua os IDs públicos em `src/shared/Config.luau`, gere o arquivo novamente e publique essa versão. Se preferir editar pelo Studio, o módulo está em `ReplicatedStorage → ZumbiShared → Config`; replique as alterações no código-fonte antes da próxima geração.

| Configuração | Tipo no Roblox | Benefício entregue |
| --- | --- | --- |
| `Products.CoinsSmall` (entrada com essa Key) | Developer Product | +500 moedas |
| `Products.CoinsLarge` | Developer Product | +1.800 moedas |
| `Products.Revive` | Developer Product | +1 token persistente de resgate |
| `Products.DoubleCoins` | Developer Product | +900 segundos de 2× moedas por abate |
| `VanguardPassId` | Game Pass | +25 vida base e +2 velocidade; benefício permanente |

`Products` é uma lista: localize a entrada pela propriedade `Key` e altere seu `Id`. Mantenha IDs únicos; `0` desativa uma oferta. Os preços são definidos no Dashboard e consultados no servidor, sem valores de Robux inventados na interface. O preço exibido no prompt oficial do Roblox é a confirmação final.

Todos os locais, armas e o final da partida são acessíveis sem gastar Robux. Os acabamentos são comprados por moedas; como essas moedas também podem ser adquiridas, há uma rota de compra de cosméticos com Robux. A caixa aleatória de armas é sempre gratuita, com probabilidades iguais, sem opções pagas de repetir sorteios.

`ProcessReceipt` é o único caminho de entrega dos Developer Products. O benefício e o identificador da compra são persistidos no mesmo `UpdateAsync`, e recibos repetidos não devem conceder benefícios repetidos. Se o perfil não estiver carregado ou o DataStore falhar, o servidor retorna `NotProcessedYet`, permitindo uma nova tentativa do Roblox. Não remova IDs antigos de produtos já vendidos: recibos pendentes ainda podem chegar.

Não conecte outro script a `MarketplaceService.ProcessReceipt` sem integrar os dois sistemas: existe um único callback por servidor. O resultado do prompt de compra não é usado para entregar produtos. A propriedade do passe é consultada por `UserOwnsGamePassAsync`.

As credenciais da sua conta Roblox não são necessárias neste repositório e não devem ser colocadas em scripts, commits ou chat. Publicar e cadastrar produtos exige sua conta no Studio/Dashboard; essas etapas não foram feitas neste ambiente.

## Preparar o lançamento

- Use o arquivo normal, sem `ZumbiStudioSmoke` no ServerScriptService.
- Execute os testes de 1, 2 e 6 jogadores, desktop, toque e controle.
- Verifique o desempenho dos 36 inimigos simultâneos em um celular de entrada. Ajuste o limite em Balance se necessário.
- Teste cada oferta de acordo com as ferramentas de teste de compras disponíveis na plataforma, sem pressupor que um prompt prova a entrega.
- Verifique moedas e cosméticos após sair e entrar; verifique a propriedade permanente do passe.
- Complete o questionário de maturidade/conteúdo da experiência e forneça ícone, miniaturas e descrição que correspondam ao jogo.
- Inclua música, sons e outros assets somente quando tiver permissão de uso. Esta versão não depende de IDs de áudio externos e não inclui uma trilha sonora própria.

## Nome e descrição sugeridos

**ZUMBI: Último Voo [HORDAS]**

“Seu avião caiu. A cidade está cercada. Junte até 6 sobreviventes, explore a igreja e a delegacia, restaure a energia e sobreviva a 15 hordas. Aprimore suas armas, enfrente o Comandante e corra para o último helicóptero. Você embarca ou fica para trás?”

O convite de amigos, recordes, chefes e o desfecho de extração criam oportunidades de partidas em grupo e clipes. Avalie duração, dificuldade e retorno dos jogadores em playtests; isso é uma hipótese de produto, não uma promessa de alcance ou receita.
