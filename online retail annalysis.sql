create database ecomerce_analytics;
create table sales ;
drop table sales;
CREATE TABLE sales (
    InvoiceNo VARCHAR(20),
    StockCode VARCHAR(20),
    Description  VARCHAR(255),
    Quantity INT,
    InvoiceDate varchar(20),
    UnitPrice decimal(10,3),
    CustomerID VARCHAR(20),
    Country VARCHAR(100)
);
-- importing csv file into sql
load DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Online Retail Data Set.csv'
INTO TABLE sales
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- verifiying table rows using count
select * from sales;
select count(*) from sales;

# data cleanning
-- customer id is empty/no value 
-- lets make customer id to null so the analysis will be good
update sales set customerid=null where trim(customerid)= '';


set sql_safe_updates=0;



create table sales_cleaned as select * from sales where Quantity>0 and unitprice>0 and CustomerID is not null;
select * from sales_cleaned;

select count(*) from sales_cleaned;


create table sales_final as select invoiceno,stockcode,description,quantity,invoicedate,unitprice,customerid,
country,monthname(invoicedate) month from sales_cleaned;

select * from sales_final;

select count(*) from sales_final;
select * from sales_final where month='november';



-- changing datatype if invoicedate from string to datetime

UPDATE sales_cleaned 
SET invoicedate= STR_TO_DATE(invoicedate, '%d-%m-%Y %H:%i');




set sql_safe_updates=0;

alter table  sales_cleaned modify column invoicedate datetime;


-- daily revenue
select date(invoicedate) as date , count(invoiceno) as orders, sum(unitprice) as dailyrevenue ,
avg(unitprice) as avg_revenue from sales_final group by date order by date;

--- monthly revenue

select month(invoicedate) as month,count(distinct invoiceno) as orders, sum(unitprice) as monthlyrevenue ,
avg(unitprice) as avg_revenue from sales_final group by month(invoicedate) order by month;

--- top 20 products by revenue

select description as product,count(invoiceno) as orders,sum(unitprice) as revenue from sales_final
 group by product order by revenue desc limit 20;
 
 ---- revenue by country
 
select country , sum(unitprice) as total_revenue,count(invoiceno) as orders,round(sum(quantity),0) as quantity from sales_final
 group by country order by total_revenue desc;
 
--- customer segementation

select  customerid,country , count( distinct invoiceno) as purchasecount , sum(unitprice) as revenue ,
 avg(unitprice) as avg_revenue ,max(invoicedate) as last_purchase from sales_final group by customerid,country order by revenue desc;
 
-- top products by units and revenue

select description as product,stockcode,sum(quantity) as units_sold,sum(unitprice) as revenue ,avg(unitprice)
 as avg_revenue from sales_final group by product,stockcode order by revenue desc;
 
 -- transaction details
 
 CREATE TABLE sales_fact AS
SELECT 
    InvoiceNo,
    StockCode,
    Quantity,
    UnitPrice,
    (Quantity * UnitPrice) as TotalRevenue,
    CustomerID,
    DATE(InvoiceDate) as TransactionDate
FROM sales_final;
drop table sales_fact;
select * from sales_fact;
select count(*) from sales_fact;

-- product deatils
CREATE TABLE dim_products AS
SELECT DISTINCT
    StockCode,
    Description as ProductName,
    CASE 
        WHEN Description LIKE '%mug%' OR Description LIKE '%cup%' THEN 'Drinkware'
        WHEN Description LIKE '%towel%' OR Description LIKE '%cloth%' THEN 'Home & Textiles'
        WHEN Description LIKE '%light%' OR Description LIKE '%lamp%' THEN 'Lighting'
        WHEN Description LIKE '%decoration%' OR Description LIKE '%candle%' THEN 'Decor'
        WHEN Description LIKE '%gift%' OR Description LIKE '%box%' THEN 'Gift Items'
        ELSE 'Other'
    END as Category,
    CASE 
        WHEN UnitPrice < 5 THEN 'Budget'
        WHEN UnitPrice < 15 THEN 'Standard'
        WHEN UnitPrice < 30 THEN 'Premium'
        ELSE 'Luxury'
    END as PriceSegment
FROM sales_final
WHERE StockCode IS NOT NULL
ORDER BY StockCode;
select * from dim_products;
select count(*) from dim_products;


-- customer details

CREATE TABLE dim_customers AS
SELECT 
    CustomerID,
    Country,
    COUNT(DISTINCT InvoiceNo) as PurchaseCount,
    ROUND(SUM(unitprice), 2) as LifetimeValue,
    ROUND(AVG(unitprice), 2) as AvgOrderValue,
   
    CASE 
        WHEN COUNT(DISTINCT InvoiceNo) >= 10 THEN 'VIP'
        WHEN COUNT(DISTINCT InvoiceNo) >= 5 THEN 'Regular'
        ELSE 'Occasional'
    END as CustomerSegment
FROM sales_final
WHERE CustomerID IS NOT NULL
GROUP BY CustomerID, Country
ORDER BY LifetimeValue DESC;
select * from dim_customers;
select count(*) from dim_customers;

-- date details
CREATE TABLE dim_calendar AS
SELECT 
    DISTINCT DATE(InvoiceDate) as Date,
    EXTRACT(YEAR FROM InvoiceDate) as Year,
    EXTRACT(MONTH FROM InvoiceDate) as Month,
    EXTRACT(QUARTER FROM InvoiceDate) as Quarter,
    EXTRACT(WEEK FROM InvoiceDate) as Week,
    DAYNAME(InvoiceDate) as DayName,
    DAYOFWEEK(InvoiceDate) as DayOfWeek,
    CASE 
        WHEN EXTRACT(MONTH FROM InvoiceDate) IN (12,1,2) THEN 'Winter'
        WHEN EXTRACT(MONTH FROM InvoiceDate) IN (3,4,5) THEN 'Spring'
        WHEN EXTRACT(MONTH FROM InvoiceDate) IN (6,7,8) THEN 'Summer'
        ELSE 'Fall'
    END as Season,
    CASE 
        WHEN DAYOFWEEK(InvoiceDate) IN (1,7) THEN 'Weekend'
        ELSE 'Weekday'
    END as DayType,
    CONCAT(EXTRACT(YEAR FROM InvoiceDate), '-', 
           LPAD(EXTRACT(MONTH FROM InvoiceDate), 2, '0')) as YearMonth
FROM sales_final

ORDER BY Date;
select * from  dim_calendar;
select count(*) from dim_calendar;

SELECT 
    'sales_fact' as TableName,
    COUNT(*) as RowCount
FROM sales_fact
UNION ALL
SELECT 'dim_products', COUNT(*) FROM dim_products
UNION ALL
SELECT 'dim_customers', COUNT(*) FROM dim_customers
UNION ALL
SELECT 'dim_calendar', COUNT(*) FROM dim_calendar;



SELECT *
INTO OUTFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/sales_fact.csv'
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
FROM sales_fact;



SELECT *
INTO OUTFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Dim-customers.csv'
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
FROM dim_customers;

SELECT *
INTO OUTFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Dim_calender.csv'
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
FROM dim_calendar;





