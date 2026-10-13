# Projeto 3: Dependemos de poucos vendedores?

**Base:** Olist (3.053 vendedores com venda válida, receita de R$ 13,5 milhões). **Consultas:** `projeto3_dependencia_vendedores.sql` (C1 a C13).

## Resposta curta

**Não dependemos de poucos vendedores.** O maior tem 1,7% da receita. Os 5 maiores, 7,7%. Se os 5 saíssem, perderíamos cerca de 6% da receita mensal. O risco real está em **duas categorias** (computers e office_furniture), onde os 5 maiores pesam 75% e 63%.

## O que testei

| Hipótese | O que os dados mostram | Resultado |
|---|---|---|
| Poucos vendedores dominam | Top 1: 1,7%. Top 5: 7,7%. Top 10: 13,2%. Top 20: 21,2%. | Descartada |
| Vale a regra 80/20 | 540 vendedores (17,7%) geram 80% da receita. | Confirmada, quase exata |
| Perder os 5 maiores dói muito | 6,0% da receita de jan-ago/2018 (de 4,8% a 7,7% por mês). | Dói pouco no total |
| O risco é igual em todas as categorias | Peso dos 5 maiores: computers 75%, office_furniture 63%, home_confort 42%, watches_gifts 33%. | Descartada. Está concentrado |
| Os grandes são sempre os mesmos | 10 dos 20 maiores de 2017 seguem entre os 20 de 2018. O top 10 caiu de 17,0% para 13,0% (mesmos meses, jan-ago). | Em parte. O mercado se diversificou |
| Os grandes entregam qualidade | Nota média: top 20 = 4,06; resto = 4,11. Mas o #3 tem 3,81 e o #5 tem 3,48. | Misto |

## Curva ABC

| Classe | Vendedores | % dos vendedores | % da receita |
|---|---|---|---|
| A (até 80%) | 540 | 17,7% | 80,0% |
| B (80% a 95%) | 753 | 24,7% | 15,0% |
| C (resto) | 1.760 | 57,6% | 5,0% |

## Achados

- **A média engana.** Média de R$ 4.420 por vendedor, mediana de R$ 825. A maioria vende pouco.
- **Gini de 0,79:** desigualdade alta. Mas sem gigante: ninguém passa de 1,7%.
- **Cauda longa:** 1.411 vendedores (46%) têm 5 pedidos ou menos e somam só 5,4% da receita.
- **Mercado crescendo:** vendedores ativos em jan-ago foram de 1.212 (2017) para 2.354 (2018).
- **Perfil dos 10 maiores:** 9 são de SP (o #2 é da BA). Categorias: relógios/presentes, cama-mesa-banho, decoração, móveis de escritório, informática e cool_stuff.

## Recomendação

1. **Não gaste energia protegendo cada um dos 5 maiores.** Cada um vale cerca de 1,5%.
2. **Proteja a classe A como grupo.** São 540 vendedores com 80% da receita. Acompanhe quem diminui as vendas.
3. **Traga 2 ou 3 vendedores de peso para computers e office_furniture.** Hoje, se um grande sai, a categoria quase some.
4. **Olhe a qualidade dos grandes.** O #5 (móveis de escritório, R$ 188 mil) tem nota 3,48. Móveis de escritório já tinha a pior nota no projeto 2.

## O que ainda não dá para afirmar

- A perda de 6% **supõe que as vendas somem**. Na prática, parte iria para outros vendedores.
- Receita aqui é o **preço dos itens**. Não é lucro nem comissão da plataforma.
- Só vemos 2016 a 2018. Não sabemos se os grandes de hoje seguem ativos.

## Armadilhas que apareceram (aprenda com elas)

1. **Gini alto não quer dizer "poucos mandam".** Olhe também o tamanho do maior.
2. **Compare períodos iguais.** 2017 começa com poucos vendedores. Comparar o ano inteiro faria a concentração parecer maior. Usei jan-ago nos dois anos.
3. **Defina a receita antes.** Sem frete e sem pedidos cancelados ou indisponíveis. Outra regra, outro ranking.
4. **Média x mediana.** Sempre olhe os dois.
5. **No SQL Server, `COUNT(DISTINCT ...) OVER` não existe.** Use tabela temporária ou subconsulta.


## Arquivos

- `projeto3_dependencia_vendedores.sql`: as consultas, numeradas C1, C2, ...
- `docs/apresentacao.pdf`: slides curtos do caso.
- `docs/relatorio.pdf`: relatório de 3 páginas.
- `dados/`: scripts para baixar os dados e montar o banco.

## Como reproduzir

1. `python3 dados/baixar_csvs.py` baixa os dados reais do Olist e cria 8 CSVs na pasta `dados`.
2. Rode `dados/montar_sqlserver.sql` no SQL Server e ajuste o caminho na linha `DECLARE @pasta`.
3. Rode as consultas de `projeto3_dependencia_vendedores.sql` na ordem.

## Aviso

Os números foram recalculados de forma independente em pandas. As consultas em T-SQL tiveram a sintaxe validada, mas não foram executadas num SQL Server real na preparação. Rode e confira os resultados.

Autor: João Wellyngton
