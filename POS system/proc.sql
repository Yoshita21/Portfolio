use pos;
-- adding the orderline column 

ALTER TABLE orderLine add column if not exists (unitPrice DECIMAL(6,2));

-- adding a virtual column lineTotal 

ALTER TABLE orderLine add column if not exists (lineTotal DECIMAL(7,2) as (quantity*unitPrice) VIRTUAL);
-- adding the orderTotal column

ALTER TABLE `order` add column if not exists (orderTotal DECIMAL(8,2));

-- dropping phone number column from customer

ALTER TABLE customer drop column if exists phone;

--  removing fk constraint from order table
ALTER TABLE `order` drop constraint order_ibfk_1;
ALTER TABLE `order` drop constraint order_ibfk_2;

--dropping the status column
ALTER TABLE `order` drop column if exists status;
-- dropping the status table
DROP TABLE if exists status;


-- adding back one foreign key constraint
ALTER TABLE `order` ADD CONSTRAINT order_ibfk_1
FOREIGN KEY(customerID)
REFERENCES customer(ID);


-- creating the fillunitprice proc
DELIMITER //
CREATE OR REPLACE PROCEDURE proc_FillUnitPrice ()
BEGIN
UPDATE orderLine SET unitPrice = (select currentPrice from product where ID = orderLine.productID) 
where unitPrice IS NULL;
END; //
DELIMITER ;

-- set unitprice for one and verify by running the proc

-- creating the fillordertotal proc 
DELIMITER //
CREATE OR REPLACE PROCEDURE proc_FillOrderTotal ()
BEGIN
UPDATE `order` SET orderTotal = (select sum(lineTotal) from orderLine where orderID = `order`.ID);
END; //
DELIMITER ;

-- check if the values are updated accordingly after running the proc

-- creating the fillmvcustomerpurchases proc
DELIMITER //
CREATE OR REPLACE PROCEDURE proc_FillMVCustomerPurchases ()
BEGIN
DELETE FROM mv_CustomerPurchases;
INSERT INTO mv_CustomerPurchases select  * from v_CustomerPurchases;
END; //
DELIMITER ;

-- update a last name and check if its updating in the view then run proc and it gets updated in mv