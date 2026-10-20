# Investigação do alerta do Windows Defender

**Status: pendente; distribuição suspensa.**

Foi relatada a detecção `Trojan:Script/Ulthar.A!ml` no download de `ZUMBI-ABRIR-NO-STUDIO.zip` hospedado neste repositório. O texto informado pelo Defender descreve execução de comandos por um invasor. Esse é o texto da detecção, não evidência independente de que comandos tenham sido executados no computador do usuário.

Não foi possível reproduzir o alerta com Windows Defender neste ambiente Linux. Não foi executado um scanner antivírus independente. A hipótese de falso positivo NÃO foi confirmada, e a revisão de código não permite certificar o arquivo como seguro.

## Preservação e retirada

- Cópias dos três arquivos originais foram preservadas fora do checkout para investigação, sem execução.
- Os arquivos de distribuição e seus links recomendados foram retirados da versão atual do repositório.
- O histórico Git não foi reescrito: commits anteriores e caches podem conservar cópias. Não as utilize como alternativa ao arquivo bloqueado.
- Nenhum arquivo foi renomeado ou reempacotado para contornar a detecção, e nenhum substituto foi liberado após o alerta.

| Arquivo original | Bytes | SHA-256 |
| --- | ---: | --- |
| ZUMBI-ABRIR-NO-STUDIO.zip | 30716 | `0a043e22c296210aab08f6910b1aabf2356b05f6b69c7982ad776143caf48194` |
| ZUMBI-Ultimo-Voo.rbxlx | 110519 | `f5934c26d00a98dbaa003a725d0ed140d50d042294d0cd2258d393a732296c84` |
| ZUMBI-Projeto.zip | 116514 | `ea6585dbf9d9e6180783dc9b7197afc7ae91a8d9d627e427d68526878064c938` |

## Verificações feitas

1. A cópia baixada do endereço público era idêntica, byte a byte, à cópia local produzida e enviada.
2. O ZIP sinalizado continha um único membro: `ZUMBI-Ultimo-Voo.rbxlx`.
3. O `.rbxlx` foi analisado como XML, sem executá-lo no Roblox Studio. Continha 11 scripts, cujos textos eram idênticos aos 11 arquivos-fonte de `src`.
4. A estrutura dos ZIPs foi verificada: sem caminhos de extração que escapassem da pasta, membros criptografados ou links simbólicos.
5. A inspeção dos scripts do jogo não identificou `loadstring`, importação por ID externo, código ofuscado ou chamadas HTTP que baixassem código. `HttpService` é usado para gerar o identificador de sessão com `GenerateGUID`.

Esses resultados estabelecem a composição e a correspondência com o código-fonte. Eles não eliminam a possibilidade de comportamento perigoso, erro na inspeção ou detecção válida.

## Próximos passos

Mantenha a quarentena e a proteção do Windows ativas. Não é necessário restaurar o arquivo para informar o nome da detecção, a versão das definições do Defender ou os detalhes do Histórico de proteção. Não compartilhe caminhos com dados pessoais.

A classificação precisa de análise adicional, preferencialmente pelo Microsoft Security Intelligence, por meio do portal oficial de submissão de arquivos: https://www.microsoft.com/en-us/wdsi/filesubmission . Nenhuma amostra foi enviada a terceiros a partir deste ambiente. O acesso ao portal e à documentação da Microsoft não pôde ser concluído pela rede deste ambiente.

Antes de qualquer nova distribuição, é necessário esclarecer a detecção, revisar as conclusões e validar o artefato correspondente. Sucesso de compilação, testes de jogo ou mudança de extensão não substituem essa validação.
