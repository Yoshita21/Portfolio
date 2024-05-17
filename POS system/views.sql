use pos;

-- view for the customer name
CREATE OR REPLACE VIEW v_CustomerNames AS
Select lastName as "LN", firstName as "FN"
from customer
order by lastName, firstName;


-- view for customers details joined with few city details 
CREATE OR REPLACE VIEW v_Customers AS
select customer.ID as customer_number,
customer.firstName as first_name,
customer.lastName as last_name,
customer.address1 as street1,
customer.address2 as street2,
city.city as city,
city.state as state,
city.zip as zip_code,
customer.email as email
FROM customer
INNER JOIN city
ON customer.zip = city.zip;

-- view to see products and who bought it
CREATE OR REPLACE VIEW v_ProductBuyers AS
Select pro.ID as productID, pro.name as productName,
group_concat(distinct cu.ID," ",cu.firstName," ",cu.lastName order by cu.ID) as customers
from product pro
left outer join orderLine ol on pro.ID = ol.productID
left outer join `order` o on ol.orderID = o.ID
left outer join customer cu on o.customerID = cu.ID
group by pro.ID;


-- view to see all the products that customer has purchased
CREATE OR REPLACE VIEW v_CustomerPurchases AS
Select cu.ID, cu.firstName, cu.lastName,
group_concat(distinct pro.ID," ",pro.name  order by pro.ID separator '|') as products
from  customer cu
left join `order` o on  cu.ID = o.customerID
left join orderLine ol on o.ID = ol.orderID
left join  product pro on ol.productID = pro.ID
group by cu.ID;

-- materialized view for customerpurchases
CREATE TABLE mv_CustomerPurchases as select * from v_CustomerPurchases;

-- materialized views for product buyers
CREATE TABLE mv_ProductBuyers as select * from v_ProductBuyers;

--index for customer email
CREATE OR REPLACE INDEX idx_CustomerEmail ON customer (email);

--index for product name
CREATE OR REPLACE INDEX idx_ProductName ON product (name);
