# Arquivos para baixar

**Download recomendado:** [ZUMBI-ABRIR-NO-STUDIO.zip](https://raw.githubusercontent.com/medviniciusmbsantos/ZUMBI/refs/heads/main/releases/ZUMBI-ABRIR-NO-STUDIO.zip). Esse ZIP contém somente `ZUMBI-Ultimo-Voo.rbxlx`, na raiz. Extraia o ZIP e abra o arquivo no Studio. O ZIP é servido como `application/zip`; o `.rbxlx` avulso pode abrir como texto no navegador.

- `ZUMBI-Ultimo-Voo.rbxlx`: lugar Roblox, pronto para abrir no Studio e testar.
- `ZUMBI-Projeto.zip`: código-fonte, documentação, gerador do lugar e arquivos de jogo/teste.

No GitHub, abra o arquivo desejado e use **Download raw file** (botão de download). Você também pode usar os links de download no README da raiz.

No Roblox Studio: **File → Open from File → ZUMBI-Ultimo-Voo.rbxlx**, depois **Play (F5)**. No modo de edição, o lugar contém os scripts; o mapa aparece ao iniciar o teste.

Esta é uma implementação inicial. Ela ainda precisa de playtest no motor Roblox antes do lançamento. As ofertas com Robux estão desativadas até configurar os IDs em `src/shared/Config.luau` e gerar/publicar uma nova versão.

Para reconstruir o arquivo a partir do código-fonte:

```sh
python3 tools/build_place.py
```

O novo arquivo será gerado em `build/ZUMBI-Ultimo-Voo.rbxlx`.
