# REQUETES THEME VENTE

USE toys_and_models;

-- A_1) Nb de produits vendus par mois et par catégorie

CREATE VIEW product_by_month AS (
SELECT products.productLine AS product_type, 
    DATE_FORMAT(orderDate, '%Y') AS year, 
    DATE_FORMAT(orderDate, '%M') AS month, 
    SUM(quantityOrdered) AS total_products
    FROM orders
INNER JOIN orderdetails ON orders.orderNumber = orderdetails.orderNumber
INNER JOIN products ON products.productCode = orderdetails.productCode
WHERE status = 'Shipped'
GROUP BY year, month, product_type
ORDER BY product_type);

SELECT * FROM product_by_month;

-- A_2) comparaison et tx d'évolution / N-1
-- Evolution 2021 - 2022

WITH year_21 AS 
    (SELECT product_type, year, month, total_products as total_21
    FROM product_by_month
    WHERE year = '2021'),
    year_22 AS
    (SELECT product_type, year, month, total_products as total_22
    FROM product_by_month
    WHERE year = '2022')
SELECT year_21.product_type, year_21.month, total_21, total_22, CONCAT(ROUND(((total_22 - total_21) / total_21) * 100, 1), '%') AS evolution 
FROM year_21
INNER JOIN year_22 ON year_21.month = year_22.month
AND year_22.product_type = year_21.product_type;

-- A_2) comparaison et tx d'évolution / N-1
-- Evolution 2022 - 2023

WITH year_22 AS
    (SELECT product_type, month, total_products as total_22
    FROM product_by_month
    WHERE year = '2022'),
    year_23 AS 
    (SELECT product_type, month, total_products as total_23
    FROM product_by_month
    WHERE year = '2023')
SELECT year_22.product_type, year_22.month, total_22, total_23, CONCAT(ROUND(((total_23 - total_22) / total_22) * 100, 1), '%') AS evolution 
FROM year_22
INNER JOIN year_23 ON year_22.month = year_23.month
AND year_22.product_type = year_23.product_type
ORDER BY product_type;

# REQUETES THEME FINANCE

-- B_1) CA des commandes des 2 derniers mois par pays

SELECT c.country, SUM(priceEach * quantityOrdered) AS CA_Total_des_2_derniers_mois
FROM orderdetails AS odd
JOIN orders ON orders.orderNumber = odd.orderNumber
JOIN customers AS c ON orders.customerNumber = c.customerNumber
WHERE orders.orderDate >= DATE_SUB(CURDATE(), INTERVAL 2 MONTH)
GROUP BY c.country
ORDER BY CA_Total_des_2_derniers_mois DESC;

-- B_2) Commandes impayées

CREATE VIEW montant_commandé AS (
    SELECT SUM(quantityOrdered * priceEach) AS montant_commandé, orderNumber
    FROM orderdetails
    GROUP BY orderNumber
);

CREATE VIEW montant_payé AS (
    SELECT SUM(amount) AS montant_payé, customerNumber
    FROM payments
    GROUP BY customerNumber
);

SELECT 
    orderdetails.orderNumber,
    customers.customerNumber,
    (montant_commandé.montant_commandé - montant_payé.montant_payé) AS différence
FROM 
    orderdetails
JOIN orders ON orderdetails.orderNumber = orders.orderNumber
JOIN customers ON orders.customerNumber = customers.customerNumber
JOIN montant_commandé ON orderdetails.orderNumber = montant_commandé.orderNumber
JOIN montant_payé ON customers.customerNumber = montant_payé.customerNumber
GROUP BY customerNumber, orderNumber
ORDER BY customers.customerNumber, orderdetails.orderNumber;
        
-- B_3.1) Top 5 produits les plus rentables à vendre

SELECT (MSRP / buyPrice) AS ratio_de_rentabilité, productName
FROM products
ORDER BY ratio_de_rentabilité DESC
LIMIT 5;

-- B_3.2) Flop 5 produits les moins rentables à vendre  

SELECT (MSRP / buyPrice) AS ratio_de_rentabilité, productName
FROM products
ORDER BY ratio_de_rentabilité ASC
LIMIT 5;

-- B_4.1) CA  global par bureau

SELECT  SUM(priceEach * quantityOrdered) AS CA_office, offices.city
	FROM orderdetails
    JOIN orders ON orderdetails.orderNumber = orders.orderNumber
	JOIN customers ON orders.customerNumber = customers.customerNumber
	JOIN employees ON customers.salesRepEmployeeNumber = employees.employeeNumber
	JOIN offices ON employees.officeCode = offices.officeCode
	GROUP BY offices.officeCode
	ORDER BY CA_office DESC;
    
-- B_4.2) CA par bureau sur les 2 derniers mois
    
  SELECT  SUM(priceEach * quantityOrdered) AS CA_office, offices.city
	FROM orderdetails
    JOIN orders ON orderdetails.orderNumber = orders.orderNumber
	JOIN customers ON orders.customerNumber = customers.customerNumber
	JOIN employees ON customers.salesRepEmployeeNumber = employees.employeeNumber
	JOIN offices ON employees.officeCode = offices.officeCode
    WHERE orders.orderDate >= DATE_SUB(NOW(), INTERVAL 2 MONTH)
	GROUP BY offices.officeCode
	ORDER BY CA_office DESC;

-- B_5) panier moyen
 
SELECT (SUM(quantityOrdered * priceEach) / COUNT(checkNumber)) AS Panier_moyen FROM orderdetails
INNER JOIN orders ON orders.orderNumber = orderdetails.orderNumber
INNER JOIN payments ON payments.customerNumber = orders.customerNumber
WHERE status = 'shipped' OR status = 'Resolved';

# REQUETES THEME LOGISTIQUE

-- C_1) stock des 5 produits les + commandés

USE toys_and_models;

SELECT prod.productName, prod.quantityInStock AS quantityMaxInStock, SUM(ordd.quantityOrdered) AS total_products
FROM products AS prod
INNER JOIN orderdetails AS ordd
ON prod.productCode = ordd.productCode
GROUP BY prod.productCode
ORDER BY total_products DESC
LIMIT 5;

-- C_2) stock des 5 produits les - commandés

SELECT prod.productName, prod.quantityInStock AS quantityMaxInStock, SUM(ordd.quantityOrdered) AS total_products
FROM products AS prod
INNER JOIN orderdetails AS ordd
ON prod.productCode = ordd.productCode
GROUP BY prod.productCode
ORDER BY total_products ASC
LIMIT 5;

-- C_3) produits Plus stockés  

SELECT prod.productName, prod.quantityInStock AS quantityMaxInStock
FROM products AS prod
ORDER BY prod.quantityInStock DESC
LIMIT 5;

# REQUETES THEME RH

-- D_1) chaque mois, les 2 vendeurs avec le plus gros CA

SELECT 
	employee,
	employeeNumber,
	month,    Total_CA,
	CASE
		WHEN classement = 1 THEN '1er'
        WHEN classement = 2 THEN '2ème'
        ELSE 'Autre'
       END AS classement
FROM (
    SELECT
        CONCAT(firstname, ' ', lastname) AS employee,
        employeeNumber,
        DATE_FORMAT(orderDate, '%Y-%m') AS month,
        SUM(priceEach * quantityOrdered) AS Total_CA,
        RANK() OVER (PARTITION BY DATE_FORMAT(orderDate, '%Y-%m') ORDER BY SUM(priceEach * quantityOrdered) DESC) AS classement
	FROM
        employees
        INNER JOIN customers ON employees.employeeNumber = customers.salesRepEmployeeNumber
        INNER JOIN orders ON customers.customerNumber = orders.customerNumber
        INNER JOIN orderdetails ON orderdetails.orderNumber = orders.orderNumber
	WHERE
        jobTitle = 'Sales Rep'
    GROUP BY
        DATE_FORMAT(orderDate, '%Y-%m'),
        employeeNumber
) AS subquery
WHERE classement <= 2
ORDER BY month DESC, Total_CA DESC;

-- D_2) chaque mois, les 2 magasins avec le plus gros CA (par rapport la date de la commande)

USE toys_and_models;

SELECT prod.productVendor AS Vendor, SUM(ordd.quantityOrdered * ordd.priceEach) AS salesRevenue, DATE_FORMAT(o.orderDate, '%Y-%m') AS currentMonth
FROM products AS prod
INNER JOIN orderdetails AS ordd
ON prod.productCode = ordd.productCode
INNER JOIN orders AS o
ON ordd.orderNumber = o.orderNumber
GROUP BY currentMonth, Vendor
ORDER BY currentMonth DESC, salesRevenue DESC
LIMIT 2;

-- D_3) chaque mois, les 2 magasins avec le moins gros CA (par rapport la date de la commande)

SELECT prod.productVendor AS Vendor, SUM(ordd.quantityOrdered * ordd.priceEach) AS salesRevenue, DATE_FORMAT(o.orderDate, '%Y-%m') AS currentMonth
FROM products AS prod
INNER JOIN orderdetails AS ordd
ON prod.productCode = ordd.productCode
INNER JOIN orders AS o
ON ordd.orderNumber = o.orderNumber
GROUP BY currentMonth, Vendor
ORDER BY currentMonth DESC, salesRevenue ASC
LIMIT 2;

-- C_4) produits Moins stockés  

SELECT prod.productName, prod.quantityInStock AS quantityMinInStock
FROM products AS prod
ORDER BY prod.quantityInStock ASC
LIMIT 5;
