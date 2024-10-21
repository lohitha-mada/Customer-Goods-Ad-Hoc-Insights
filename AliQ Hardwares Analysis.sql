-- 1.Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

SELECT 
	DISTINCT market 
FROM dim_customer 
	WHERE customer = 'Atliq Exclusive' AND region = 'APAC';

-- 2.What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields,
-- unique_products_2020
-- unique_products_2021
-- percentage_chg

WITH unique_counts AS (
	SELECT
        (SELECT COUNT(DISTINCT product_code) FROM fact_sales_monthly WHERE fiscal_year = 2020) AS unique_products_2020,
        (SELECT COUNT(DISTINCT product_code) FROM fact_sales_monthly WHERE fiscal_year = 2021) AS unique_products_2021
)
SELECT 'UNIQUE_PRODUCTS_2020' AS Product_Stats, unique_products_2020 AS VALUE
FROM unique_counts
UNION ALL
SELECT 'UNIQUE_PRODUCTS_2021' AS Product_Stats, unique_products_2021 AS VALUE
FROM unique_counts
UNION ALL
SELECT 'PERCENTAGE_CHG' AS Product_Stats, 
       ROUND(((unique_products_2021 - unique_products_2020) / unique_products_2020) * 100, 2) AS VALUE
FROM unique_counts;

-- 3.Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. 
-- The final output contains 2 fields, segment, product_count

SELECT 
	segment,COUNT(DISTINCT product_code) AS product_count
FROM dim_product 
	GROUP BY segment ORDER BY 2 DESC;

-- 4. Which segment had the most increase in unique products in 2021 vs 2020? The final output contains these fields,
-- segment, product_count_2020, product_count_2021 & difference

WITH CTE AS (
    SELECT 
        p.segment,fs.fiscal_year,COUNT(DISTINCT fs.product_code) as product_count_2020
	FROM dim_product AS p
	JOIN fact_sales_monthly as fs ON p.product_code = fs.product_code
	WHERE fiscal_year = 2020 GROUP BY segment
),
CTE1 AS(
	SELECT 
        p.segment,fs.fiscal_year,COUNT(DISTINCT fs.product_code) as product_count_2021
	FROM dim_product AS p
    JOIN fact_sales_monthly as fs ON p.product_code = fs.product_code
    WHERE fiscal_year = 2021 GROUP BY segment)
SELECT 
	CTE.segment, product_count_2020,product_count_2021, (product_count_2021 - product_count_2020) AS difference
FROM CTE 
JOIN CTE1 ON CTE.segment = CTE1.segment 
ORDER BY difference DESC;

-- 5. Get the products that have the highest and lowest manufacturing costs.The final output should contain these fields,
-- product_code, product, manufacturing_cost
WITH CTE AS (
    SELECT 
        p.product_code,p.product,m.manufacturing_cost,
        ROW_NUMBER() OVER (ORDER BY m.manufacturing_cost ASC) AS min_rank,
        ROW_NUMBER() OVER (ORDER BY m.manufacturing_cost DESC) AS max_rank
    FROM dim_product p
    JOIN fact_manufacturing_cost m ON p.product_code = m.product_code
)
SELECT 
    product_code,product,manufacturing_cost
FROM CTE
WHERE max_rank = 1 OR min_rank = 1;

-- 6. Generate a report which contains the top 5 customers who received an 
-- average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market. 
-- The final output contains these fields, customer_code, customer, average_discount_percentage

SELECT a.customer_code ,
       b.customer,
       CONCAT(ROUND(AVG(pre_invoice_discount_pct)*100,2),'%') AS avg_discount_pct
FROM fact_pre_invoice_deductions AS a
INNER JOIN 
dim_customer AS b
ON a.customer_code = b.customer_code
WHERE market = 'India'
AND fiscal_year = 2021
GROUP BY customer, customer_code
ORDER BY AVG(pre_invoice_discount_pct) DESC
LIMIT 5;


-- 7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month. 
-- This analysis helps to get an idea of low and high-performing months and take strategic decisions.
-- The final report contains these columns: Month, Year, Gross sales Amount
SELECT 
	MONTHNAME(fs.date) AS MONTH,
    YEAR(fs.date) AS YEAR,
    ROUND(SUM(fp.gross_price * fs.sold_quantity),2) AS Gross_Sales_Amount
FROM fact_gross_price fp 
	JOIN fact_sales_monthly fs ON fp.product_code = fs.product_code
    JOIN dim_customer c ON c.customer_code = fs.customer_code 
    WHERE c.customer = 'Atliq Exclusive' GROUP BY MONTH,YEAR;

-- 8. In which quarter of 2020, got the maximum total_sold_quantity? 
-- The final output contains these fields sorted by the total_sold_quantity, Quarter, total_sold_quantity
SELECT 
CASE
    WHEN date BETWEEN '2019-09-01' AND '2019-11-01' THEN 'Q1'  
    WHEN date BETWEEN '2019-12-01' AND '2020-02-01' THEN 'Q2'
    WHEN date BETWEEN '2020-03-01' AND '2020-05-01' THEN 'Q3'
    WHEN date BETWEEN '2020-06-01' AND '2020-08-01' THEN 'Q4'
    END AS Quarters,
    SUM(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly
WHERE fiscal_year = 2020
GROUP BY Quarters
ORDER BY total_sold_quantity DESC;

-- 9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? 
-- The final output contains these fields, channel, gross_sales_mln, percentage

WITH CTE AS (
	SELECT 
		C.channel,
        SUM(S.sold_quantity * G.gross_price) AS total_sales
	FROM fact_sales_monthly S
	JOIN fact_gross_price G ON S.product_code = G.product_code
	JOIN dim_customer C ON S.customer_code = C.customer_code
	WHERE S.fiscal_year= 2021 GROUP BY C.channel ORDER BY total_sales DESC)
SELECT 
  channel,
  CONCAT(ROUND(total_sales/1000000,1)," M") AS gross_sales_mln,
  CONCAT(ROUND(total_sales/(SUM(total_sales) OVER())*100,2),'%') AS percentage 
FROM CTE;

-- 10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
-- The final output contains these fields,division,product_code.

WITH RankedProducts AS (
    SELECT 
        P.division,FS.product_code,P.product, 
        SUM(FS.sold_quantity) AS Total_sold_quantity,
        RANK() OVER(PARTITION BY P.division ORDER BY SUM(FS.sold_quantity) DESC) AS Rank_Order
    FROM dim_product P 
    JOIN fact_sales_monthly FS ON P.product_code = FS.product_code
    WHERE FS.fiscal_year = 2021
    GROUP BY P.division, FS.product_code, P.product
)
SELECT 
    division,product_code,product,Total_sold_quantity,Rank_Order
FROM RankedProducts
WHERE Rank_Order IN (1, 2, 3); 