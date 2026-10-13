/*
  PROJETO 3: Dependemos de poucos vendedores? (SQL Server 2025, banco "olist")

  Regras que valem para o arquivo todo:
   - Receita = soma de items.price (sem frete). Pedidos 'canceled' e 'unavailable' ficam de fora.
   - Rode o bloco "PREPARAÇÃO" primeiro. As tabelas #temporárias somem quando você fecha a janela.
   - Curva ABC: A = vendedores que, somados, chegam a 80% da receita; B = de 80% a 95%; C = o resto.
*/
USE olist;
GO

/* ===================== PREPARAÇÃO ===================== */

-- Receita e pedidos por vendedor
DROP TABLE IF EXISTS #rv;
SELECT i.seller_id,
       SUM(i.price)                AS receita,
       COUNT(DISTINCT i.order_id)  AS pedidos
INTO   #rv
FROM   dbo.items i
JOIN   dbo.orders o ON o.order_id = i.order_id
WHERE  o.order_status NOT IN ('canceled', 'unavailable')
GROUP  BY i.seller_id;

-- Ranking: posição, % da receita e % acumulado
DROP TABLE IF EXISTS #rank;
SELECT seller_id, receita, pedidos,
       ROW_NUMBER() OVER (ORDER BY receita DESC, seller_id)                   AS posicao,
       CAST(receita AS float) / SUM(CAST(receita AS float)) OVER ()           AS pct,
       SUM(CAST(receita AS float)) OVER (ORDER BY receita DESC, seller_id
                                         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
         / SUM(CAST(receita AS float)) OVER ()                                AS pct_acum
INTO   #rank
FROM   #rv;
GO

/* ===================== ANÁLISE ===================== */

-- C1. Panorama: quantos vendedores e quanta receita
SELECT COUNT(*) AS vendedores, ROUND(SUM(receita), 0) AS receita_total,
       ROUND(AVG(receita), 0) AS receita_media
FROM   #rv;

-- C2. Quanto os maiores pesam na receita?
SELECT t.k AS top_n,
       ROUND(100.0 * (SELECT SUM(r.pct) FROM #rank r WHERE r.posicao <= t.k), 1) AS pct_da_receita
FROM  (VALUES (1), (5), (10), (20), (50), (100), (300)) AS t(k);

-- C3. Quantos vendedores bastam para 50%, 80% e 95% da receita?
SELECT t.alvo_pct,
       (SELECT COUNT(*) + 1 FROM #rank r WHERE r.pct_acum < t.alvo_pct / 100.0) AS vendedores_necessarios
FROM  (VALUES (50), (80), (95)) AS t(alvo_pct);

-- C4. Mediana x média da receita por vendedor (a média engana quando poucos vendem muito)
SELECT DISTINCT
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY receita) OVER () AS mediana,
       AVG(receita) OVER ()                                          AS media
FROM   #rv;

-- C5. Desigualdade (coeficiente de Gini): 0 = todos vendem igual, 1 = um vendedor tem tudo
SELECT 2.0 * SUM(CAST(i AS float) * receita) / (COUNT(*) * SUM(receita))
       - (COUNT(*) + 1.0) / COUNT(*) AS gini
FROM  (SELECT receita, ROW_NUMBER() OVER (ORDER BY receita ASC) AS i FROM #rv) x;

-- C6. Curva ABC
SELECT classe,
       COUNT(*)                                                    AS vendedores,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)          AS pct_dos_vendedores,
       ROUND(SUM(receita), 0)                                      AS receita,
       ROUND(100.0 * SUM(receita) / SUM(SUM(receita)) OVER (), 1)  AS pct_da_receita
FROM (
    SELECT receita,
           CASE WHEN pct_acum - pct <= 0.80 THEN 'A'
                WHEN pct_acum - pct <= 0.95 THEN 'B'
                ELSE                             'C' END AS classe
    FROM   #rank) x
GROUP  BY classe
ORDER  BY classe;

-- C7. Cauda longa: vendedores com 5 pedidos ou menos
SELECT COUNT(*)                                                             AS vendedores,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM #rv), 1)              AS pct_dos_vendedores,
       ROUND(100.0 * SUM(receita) / (SELECT SUM(receita) FROM #rv), 1)      AS pct_da_receita
FROM   #rv
WHERE  pedidos <= 5;

-- C8. Os 10 maiores: receita, categoria principal e estado
SELECT TOP 10 r.posicao, LEFT(r.seller_id, 8) AS vendedor, ROUND(r.receita, 0) AS receita,
       ROUND(100.0 * r.pct, 2) AS pct_da_receita, r.pedidos,
       cp.categoria AS categoria_principal, s.seller_state AS uf
FROM   #rank r
JOIN   dbo.sellers s ON s.seller_id = r.seller_id
JOIN  (SELECT seller_id, categoria
       FROM (SELECT i.seller_id,
                    ISNULL(t.product_category_name_english, 'sem_categoria') AS categoria,
                    ROW_NUMBER() OVER (PARTITION BY i.seller_id ORDER BY SUM(i.price) DESC) AS rn
             FROM   dbo.items i
             JOIN   dbo.orders o ON o.order_id = i.order_id
             LEFT JOIN dbo.products   p ON p.product_id = i.product_id
             LEFT JOIN dbo.categories t ON t.product_category_name = p.product_category_name
             WHERE  o.order_status NOT IN ('canceled', 'unavailable')
             GROUP  BY i.seller_id, ISNULL(t.product_category_name_english, 'sem_categoria')) z
       WHERE rn = 1) cp ON cp.seller_id = r.seller_id
ORDER  BY r.posicao;

-- C9. Cenário: e se os 5 maiores saíssem? Perda por mês em 2018
SELECT FORMAT(o.order_purchase_timestamp, 'yyyy-MM')                                  AS mes,
       ROUND(SUM(i.price), 0)                                                         AS receita,
       ROUND(SUM(CASE WHEN r.posicao <= 5 THEN i.price ELSE 0 END), 0)                AS perda,
       ROUND(100.0 * SUM(CASE WHEN r.posicao <= 5 THEN i.price ELSE 0 END) / SUM(i.price), 1) AS pct_perda
FROM   dbo.items i
JOIN   dbo.orders o ON o.order_id = i.order_id
JOIN   #rank r      ON r.seller_id = i.seller_id
WHERE  o.order_status NOT IN ('canceled', 'unavailable')
  AND  o.order_purchase_timestamp >= '2018-01-01' AND o.order_purchase_timestamp < '2018-09-01'
GROUP  BY FORMAT(o.order_purchase_timestamp, 'yyyy-MM')
ORDER  BY mes;

-- C10. O risco está espalhado ou em categorias específicas? (peso dos 5 maiores em cada categoria)
SELECT TOP 6 ISNULL(t.product_category_name_english, 'sem_categoria') AS categoria,
       ROUND(SUM(i.price), 0)                                                              AS receita_categoria,
       ROUND(100.0 * SUM(CASE WHEN r.posicao <= 5 THEN i.price ELSE 0 END) / SUM(i.price), 1) AS pct_dos_5_maiores
FROM   dbo.items i
JOIN   dbo.orders o ON o.order_id = i.order_id
JOIN   #rank r      ON r.seller_id = i.seller_id
LEFT JOIN dbo.products   p ON p.product_id = i.product_id
LEFT JOIN dbo.categories t ON t.product_category_name = p.product_category_name
WHERE  o.order_status NOT IN ('canceled', 'unavailable')
GROUP  BY ISNULL(t.product_category_name_english, 'sem_categoria')
HAVING SUM(i.price) >= 20000
ORDER  BY pct_dos_5_maiores DESC;

-- C11. A concentração mudou? Mesmos meses (jan-ago) de 2017 e 2018
WITH por_ano AS (
    SELECT YEAR(o.order_purchase_timestamp) AS ano, i.seller_id, SUM(i.price) AS receita
    FROM   dbo.items i
    JOIN   dbo.orders o ON o.order_id = i.order_id
    WHERE  o.order_status NOT IN ('canceled', 'unavailable')
      AND  YEAR(o.order_purchase_timestamp) IN (2017, 2018)
      AND  MONTH(o.order_purchase_timestamp) <= 8
    GROUP  BY YEAR(o.order_purchase_timestamp), i.seller_id
), ranq AS (
    SELECT ano, receita,
           ROW_NUMBER() OVER (PARTITION BY ano ORDER BY receita DESC) AS pos,
           SUM(receita)  OVER (PARTITION BY ano)                      AS total
    FROM   por_ano
)
SELECT ano,
       COUNT(*)                                                                          AS vendedores_ativos,
       ROUND(100.0 * SUM(CASE WHEN pos <=  5 THEN receita ELSE 0 END) / MAX(total), 1)   AS top5_pct,
       ROUND(100.0 * SUM(CASE WHEN pos <= 10 THEN receita ELSE 0 END) / MAX(total), 1)   AS top10_pct
FROM   ranq
GROUP  BY ano
ORDER  BY ano;

-- C12. Os grandes vendem bem E entregam qualidade? Nota média: top 20 x 21-300 x resto
WITH aval AS (
    SELECT order_id, review_score AS nota
    FROM  (SELECT order_id, review_score,
                  ROW_NUMBER() OVER (PARTITION BY order_id
                                     ORDER BY review_answer_timestamp DESC, review_id) AS rn
           FROM dbo.reviews) r
    WHERE rn = 1
), pares AS (
    SELECT DISTINCT i.order_id, i.seller_id
    FROM   dbo.items i
    JOIN   dbo.orders o ON o.order_id = i.order_id
    WHERE  o.order_status NOT IN ('canceled', 'unavailable')
)
SELECT CASE WHEN r.posicao <= 20  THEN 'a) top 20'
            WHEN r.posicao <= 300 THEN 'b) 21 a 300'
            ELSE                       'c) resto' END  AS grupo,
       COUNT(*)                     AS avaliacoes,
       ROUND(AVG(1.0 * a.nota), 2)  AS nota_media
FROM   pares p
JOIN   aval  a ON a.order_id = p.order_id
JOIN   #rank r ON r.seller_id = p.seller_id
GROUP  BY CASE WHEN r.posicao <= 20  THEN 'a) top 20'
               WHEN r.posicao <= 300 THEN 'b) 21 a 300'
               ELSE                       'c) resto' END
ORDER  BY grupo;

-- C13. Nota dos 5 maiores, um a um
SELECT r.posicao, LEFT(r.seller_id, 8) AS vendedor, COUNT(*) AS avaliacoes,
       ROUND(AVG(1.0 * a.nota), 2) AS nota_media
FROM  (SELECT DISTINCT i.order_id, i.seller_id
       FROM   dbo.items i
       JOIN   dbo.orders o ON o.order_id = i.order_id
       WHERE  o.order_status NOT IN ('canceled', 'unavailable')) p
JOIN  (SELECT order_id, review_score AS nota
       FROM  (SELECT order_id, review_score,
                     ROW_NUMBER() OVER (PARTITION BY order_id
                                        ORDER BY review_answer_timestamp DESC, review_id) AS rn
              FROM dbo.reviews) q
       WHERE rn = 1) a ON a.order_id = p.order_id
JOIN   #rank r ON r.seller_id = p.seller_id
WHERE  r.posicao <= 5
GROUP  BY r.posicao, r.seller_id
ORDER  BY r.posicao;
