# Подготовка к загркзке таблиц

CREATE DATABASE final_project_Vlassenko_A;
UPDATE customers SET Gender = NULL WHERE Gender = '';
UPDATE customers SET Age = NULL WHERE Age = '';
ALTER TABLE customers MODIFY Age INT NULL;

SELECT * FROM customers;

CREATE TABLE transactions
(date_new DATE,
Id_check INT,
ID_client INT,
Count_products DECIMAL (10, 3),
Sum_payment DECIMAL (10, 2)
);

SHOW VARIABLES LIKE 'secure_file_priv';

LOAD DATA INFILE "C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\transactions.csv"
INTO TABLE transactions
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

# Решение заданий
#1. Вывести список клиентов с непрерывной историей за год, то есть каждый месяц на регулярной основе 
#без пропусков за указанный годовой период, средний чек за период с 01.06.2015 по 01.06.2016, 
#средняя сумма покупок за месяц, количество всех операций по клиенту за период.

USE  final_project_Vlassenko_A; # переключение на нашу базу
SELECT * FROM customers; # просмотр таблицы customers

# использую with cte в рамках одного запроса вместо временной таблицы для экономия пространства

WITH  monthly AS(
SELECT ID_client, date_format(date_new, '%Y-%m') AS month # вытаскиваем месяц
FROM transactions
WHERE date_new BETWEEN "2015-06-01" AND "2016-06-01"  
GROUP BY ID_client, month
), 
regular_customers AS (
SELECT ID_client FROM monthly # все постоянные клиенты за год
GROUP BY ID_client
HAVING COUNT(distinct month) = 12 
),
customer_statistics AS (
SELECT ID_client, COUNT(Id_check) AS total_operations, 
SUM(Sum_payment) AS total_expens, 
AVG(Sum_payment) AS avg_check_year
FROM transactions 
WHERE date_new BETWEEN "2015-06-01" AND "2016-06-01"  
GROUP BY ID_client
)
SELECT r.ID_client,
cs.total_operations, 
cs.total_expens / 12 AS avg_monthly_expens, # cредняя сумма покупок за месяц
cs.avg_check_year  # cредний чек за год
FROM regular_customers r
JOIN customer_statistics cs ON r.ID_client = cs.ID_client
ORDER BY avg_monthly_expens DESC;

# 2.информацию в разрезе месяцев:
# q)средняя сумма чека в месяц;
# b)среднее количество операций в месяц;
# c)среднее количество клиентов, которые совершали операции;
# d)долю от общего количества операций за год и долю в месяц от общей суммы операций;
# e)вывести % соотношение M/F/NA в каждом месяце с их долей затрат;

# a) средняя сумма чека в месяц
SELECT date_format(date_new, '%Y-%m') AS month, 
		AVG(Sum_payment) AS avg_check_month
FROM transactions
GROUP BY month
ORDER BY month ASC;

# b)среднее количество операций в месяц;
SELECT date_format(date_new, '%Y-%m') AS month, 
		COUNT(Id_check) AS avg_operations 
FROM transactions
GROUP BY month
ORDER BY month;

# c)среднее количество клиентов, которые совершали операции
SELECT date_format(date_new, '%Y-%m') AS month,
		COUNT(distinct ID_client) AS avg_clients 
FROM transactions
GROUP BY month
ORDER BY month;

# d) долю от общего количества операций за год и долю в месяц от общей суммы операций
# использую with cte в рамках одного запроса
WITH total_values AS (
SELECT COUNT(Id_check) AS total_oper, 
SUM(Sum_payment) AS total_sum FROM transactions
)
SELECT date_format(date_new, '%Y-%m') AS month, 
	COUNT(t.Id_check) / (select total_oper from total_values)*100 AS part_percent,
	SUM(t.Sum_payment) /(select total_sum from total_values) *100 AS sum_part_percent
FROM transactions t
GROUP BY month
ORDER BY month;

 # e.вывести % соотношение M/F/NA в каждом месяце с их долей затрат
 # использую with cte в рамках одного запроса
WITH gender_data AS (
SELECT date_format(date_new, '%Y-%m') AS month, 
c.Gender, 
COUNT(t.Id_check) AS transaction_count, 
SUM(t.Sum_payment) AS total_expens
FROM transactions t
LEFT JOIN customers c ON t.ID_client = c.Id_client
GROUP BY month, c.Gender
)
SELECT 
    g.month, 
    g.Gender, 
    g.transaction_count, 
    g.total_expens,
    g.transaction_count / SUM(g.transaction_count) OVER (PARTITION BY  g.month)*100 AS transaction_percent,
    g.total_expens / SUM(g.total_expens) OVER (PARTITION BY g.month)*100 AS spending_percent
FROM gender_data g
ORDER BY g.month, g.Gender;

# 3. возрастные группы клиентов с шагом 10 лет и отдельно клиентов, у которых нет данной информации, 
# с параметрами сумма и количество операций за весь период, и поквартально - средние показатели и %.

# просмотр таблиц
SELECT * FROM customers; 
SELECT * FROM transactions; 

WITH age_groups AS (
SELECT c.ID_client,
CASE
WHEN c.Age BETWEEN 0  AND 10 THEN "0-10 лет"
WHEN c.Age BETWEEN 11 AND 20 THEN "10-20 лет"
WHEN c.Age BETWEEN 21 AND 30 THEN "20-30 лет"
WHEN c.Age BETWEEN 31 AND 40 THEN "30-40 лет" 
WHEN c.Age BETWEEN 41 AND 50 THEN "40-50 лет" 
WHEN c.Age BETWEEN 51 AND 60 THEN "50-60 лет"
WHEN c.Age BETWEEN 61 AND 70 THEN "60-70 лет"
WHEN c.Age BETWEEN 71 AND 80 THEN "70-80 лет"
WHEN c.Age >= 81 THEN "80+ лет"
WHEN c.Age IS NULL THEN "Возраст не указан"
END AS age_group,
t.Sum_payment,
t.Id_check,
YEAR(t.date_new) AS year, 
QUARTER(t.date_new) AS quarter
FROM transactions t
LEFT JOIN customers c
ON c.Id_client = t.Id_client
),

total_stats AS (
SELECT age_group, COUNT(Id_check) AS total_operations,
SUM(Sum_payment) AS total_spent
FROM age_groups
GROUP BY age_group
),

quarterly_stats AS (
SELECT age_group, year, quarter,
COUNT(Id_check) AS operations_count,
SUM(Sum_payment) AS total_spent,
AVG(Sum_payment) AS avg_check
FROM age_groups
GROUP BY age_group, year, quarter
),

percent AS (
SELECT q.age_group, q.year, q.quarter, q.operations_count,
q.total_spent, q.avg_check, q.operations_count / (SELECT SUM(operations_count) FROM quarterly_stats 
WHERE year = q.year AND quarter = q.quarter) * 100 AS operations_share,
q.total_spent / (SELECT SUM(total_spent) FROM quarterly_stats 
WHERE year = q.year AND quarter = q.quarter) * 100 AS spent_share
FROM quarterly_stats q
)
SELECT * FROM percent
ORDER BY year, quarter, age_group;









