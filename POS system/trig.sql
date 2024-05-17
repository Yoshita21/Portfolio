use pos;
call proc_FillUnitPrice ();
call proc_FillOrderTotal ();
call proc_FillMVCustomerPurchases ();
----2
----creating the priceChangeLog table
CREATE table priceChangeLog (
    ID INT unsigned auto_increment PRIMARY KEY ,
    oldPrice DECIMAL(6,2),
    newPrice DECIMAL(6,2),
    changeTimestamp TIMESTAMP,
    productid INT references product(ID)
);

----3
---- trigger to insert a new row to the above table created whenever a product's price is updated.
---- compare if old and new price are =
DELIMITER //
CREATE or replace trigger tr_price 
AFTER UPDATE  
ON product FOR EACH ROW
BEGIN
IF old.currentPrice <> new.currentPrice
THEN
insert into priceChangeLog (oldPrice,newPrice,productid) values(old.currentPrice,new.currentPrice,old.ID);
end if;

If old.name <> new.name
THEN 
UPDATE mv_ProductBuyers SET productName = new.name where productID=old.ID;
end if;
END
//
DELIMITER ;

     --check
     --update product set currentPrice='222.00' where ID='993';
     -- select * from priceChangeLog;

----4
----trigger to set unitPrice from the currentprice

----
DELIMITER //
CREATE or replace trigger tr_unitpricei 
BEFORE INSERT 
ON orderLine FOR EACH ROW 
BEGIN 
select currentPrice into @newUnitPrice from product where product.ID = new.productID;
set new.unitPrice=@newUnitPrice;
END
//
DELIMITER ;



DELIMITER //
CREATE or replace trigger tr_unitpriceu
BEFORE UPDATE
ON orderLine FOR EACH ROW 
BEGIN 
if old.quantity <> new.quantity and old.productID <> new.productID THEN
select currentPrice into @newUnitPrice from product where product.ID = new.productID;
elseif old.quantity <> new.quantity THEN
select currentPrice into @newUnitPrice from product where product.ID = new.productID;
elseif old.productID <> new.productID THEN
select currentPrice into @newUnitPrice from product where product.ID = new.productID;
set new.unitPrice=@newUnitPrice;
end if;
END
//
DELIMITER ;

-- select * from product limit 10;
-- update product set currentPrice='' where ID='1';
-- select * from orderLine limit 10;
-- update orderLine set productId='0' where orderID='' and productId='';


----------5
--run procs here, not anywhereeee
DELIMITER //
CREATE OR replace trigger tr_ordertotalu 
AFTER UPDATE
ON orderLine FOR EACH ROW
BEGIN
UPDATE `order` SET orderTotal = (select sum(lineTotal) from orderLine where orderID = `order`.ID);
END; 
//
DELIMITER ;

DELIMITER //
CREATE OR replace trigger tr_ordertotali 
AFTER INSERT
ON orderLine FOR EACH ROW
BEGIN 
UPDATE `order` SET orderTotal = (select sum(lineTotal) from orderLine where orderID = `order`.ID);
END; 
//
DELIMITER ;

DELIMITER //
CREATE OR replace trigger tr_ordertotald 
AFTER DELETE
ON orderLine FOR EACH ROW
BEGIN 
UPDATE `order` SET orderTotal = (select sum(lineTotal) from orderLine where orderID = `order`.ID);
END; 
//
DELIMITER ;

-------------------6
---- creating the customerpurchases proc to update and insert into customerpurchases mv and passing the customer id as input

DELIMITER //
CREATE OR REPLACE PROCEDURE proc_CustomerPurchasesu (IN custID INT) 
BEGIN 
UPDATE mv_CustomerPurchases 
SET products = (select group_concat(pro.ID," ",pro.name  order by pro.ID separator '|')
from customer cu
left outer join `order` o on  cu.ID = o.customerID
left outer join orderLine ol on o.ID = ol.orderID
left outer join  product pro on ol.productID = pro.ID
where mv_CustomerPurchases.ID = cu.ID)
where mv_CustomerPurchases.ID = custID;
END; 
//
DELIMITER ;


DELIMITER //
CREATE OR REPLACE PROCEDURE proc_CustomerPurchasesi (IN custID INT)
BEGIN 
INSERT into mv_CustomerPurchases 
select cu.ID, cu.firstName, cu.lastName,
group_concat(distinct pro.ID," ",pro.name  order by pro.ID separator '|') as products
from customer cu
left outer join `order` o on  cu.ID = o.customerID
left outer join orderLine ol on o.ID = ol.orderID
left outer join  product pro on ol.productID = pro.ID
where cu.ID = custID;
END; 
//
DELIMITER ;

----creating the productbuyers proc to update and insert into productbuyers mv and passing the product id as input

DELIMITER //
CREATE OR REPLACE PROCEDURE proc_ProductBuyersu (IN prodID INT)
BEGIN 
UPDATE mv_ProductBuyers 
SET customers = (select group_concat(distinct cu.ID," ",cu.firstName," ",cu.lastName order by cu.ID)
from product pro
left outer join orderLine ol on pro.ID = ol.productID
left outer join `order` o on ol.orderID = o.ID
left outer join customer cu on o.customerID = cu.ID
where mv_ProductBuyers.productID = pro.ID)
where mv_ProductBuyers.productID = prodID;
END;
//
DELIMITER ;


DELIMITER //
CREATE OR REPLACE PROCEDURE proc_ProductBuyersi (IN prodID INT)
BEGIN 
INSERT INTO mv_ProductBuyers
select product.ID as productID, product.name as productName,
group_concat(distinct cu.ID," ",cu.firstName," ",cu.lastName order by cu.ID)as customers
from product pro
left outer join orderLine ol on pro.ID = ol.productID
left outer join `order` o on ol.orderID = o.ID
left outer join customer cu on o.customerID = cu.ID
where pro.ID = prodID;
END; 
//
DELIMITER ;


---- trigger for update of mv

DELIMITER //
CREATE OR REPLACE TRIGGER tr_mv_orderLineu 
AFTER UPDATE
ON orderLine for each row
BEGIN 
DECLARE custID INT;
DECLARE oldProdID INT;
DECLARE newProdID INT;
select distinct customer.ID 
from customer
join `order` on customer.ID = order.customerID
join orderLine on order.ID = new.orderID
INTO custID;
IF EXISTS
(select ID from mv_CustomerPurchases where ID=custID) 
THEN call proc_CustomerPurchasesu (custID);
ELSE call proc_CustomerPurchasesi (custID);
END IF;
select new.productID INTO newProdID;
select old.productID INTO oldProdID;
IF EXISTS
(select productID from mv_ProductBuyers where productID=newProdID)
THEN call proc_ProductBuyersu  (newProdID);
call proc_ProductBuyersu (oldProdID);
ELSE call proc_ProductBuyersi (newProdID);
END IF;
END; 
//
DELIMITER ;

---- trigger for insertion of mv
DELIMITER //
CREATE OR REPLACE TRIGGER tr_mv_orderLinei 
AFTER INSERT
ON orderLine for each row
BEGIN DECLARE custID INT;
DECLARE newProdID INT;
select distinct customer.ID 
from customer
join `order` on customer.ID = order.customerID
join orderLine on order.ID = new.orderID
INTO custID;
IF EXISTS(select ID from mv_CustomerPurchases where ID=custID) 
THEN call proc_CustomerPurchasesu(custID);
ELSE call proc_CustomerPurchasesi(custID);
END IF;
select new.productID INTO newProdID;
IF EXISTS(select productID from mv_ProductBuyers where productID=newProdID)
THEN call proc_ProductBuyersu (newProdID);
ELSE call proc_ProductBuyersi (newProdID);
END IF;
END;
//
DELIMITER ;


---- trigger for deletion of mv
DELIMITER //
CREATE OR REPLACE TRIGGER tr_mv_orderLined 
AFTER DELETE
ON orderLine for each row
BEGIN DECLARE custID INT;
select distinct customer.ID 
from customer
join `order` on customer.ID = order.customerID
join orderLine on order.ID = old.orderID
INTO custID;
call proc_CustomerPurchasesu (custID);
call proc_ProductBuyersu (old.productID);
END;
//
DELIMITER ;


-------------7
---- trigger for updating orderline

DELIMITER //
CREATE OR REPLACE TRIGGER tr_orderLineu
BEFORE UPDATE
ON orderLine for each row
BEGIN 
DECLARE newQuantity INT;
DECLARE qtyAvl INT;
DECLARE qtyDiff INT;
IF
new.quantity is NULL 
THEN SET new.quantity =1;
END IF;
select new.quantity INTO newQuantity;
select qtyOnHand from product where product.ID = new.productID INTO qtyAvl;
IF 
old.productID <> new.productID AND old.quantity <> new.quantity 
THEN
IF (new.quantity <= qtyAvl)
THEN UPDATE product
SET qtyOnHand = qtyOnHand - new.quantity 
where product.ID = new.productID;
UPDATE product
SET qtyOnHand = qtyOnHand + old.quantity 
where product.ID = old.productID;
ELSE
signal sqlstate '45000' set message_text = 'Error Message';
END IF;
elseif old.quantity <> new.quantity
THEN
SET qtyDiff = new.quantity - old.quantity;
IF (qtyDiff <= qtyAvl)
THEN UPDATE product
SET qtyOnHand = qtyOnHand - qtyDiff 
where product.ID = new.productID;
ELSE 
signal sqlstate '45000' set message_text = 'Error Message';
END IF;
elseif old.productID <> new.productID
THEN
IF (old.quantity <= qtyAvl)
THEN UPDATE product
SET qtyOnHand = qtyOnHand - old.quantity 
where product.ID = new.productID;
UPDATE product
SET qtyOnHand = qtyOnHand + old.quantity 
where product.ID = old.productID;
ELSE
signal sqlstate '45000' set message_text = 'Error Message';
END IF;
END IF;
END;
//
DELIMITER ;


----trigger for inserting before (orderline)

DELIMITER //
CREATE OR REPLACE TRIGGER tr_orderLinebi
BEFORE INSERT
ON orderLine for each row
BEGIN IF new.quantity is NULL
THEN SET new.quantity =1;
END IF;
END; 
//
DELIMITER ;

---- trigger for inserting after (orderline)
DELIMITER //
CREATE OR REPLACE TRIGGER tr_orderLineai
AFTER INSERT
ON orderLine for each row
BEGIN 
DECLARE newQuantity INT;
DECLARE qtyAvl INT;
select new.quantity INTO newQuantity;
select qtyOnHand from product where product.ID = new.productID INTO qtyAvl;
IF (newQuantity <= qtyAvl)
THEN UPDATE product
SET qtyOnHand = qtyOnHand - newQuantity 
where product.ID = new.productID;
ELSE signal sqlstate '45000' set message_text = 'Error Message';
END IF;
END; 
//
DELIMITER ;

----trigger for deleting orderline
DELIMITER //
CREATE OR REPLACE TRIGGER tr_orderLined
BEFORE DELETE
ON orderLine for each row
BEGIN 
UPDATE product
SET qtyOnHand = qtyOnHand + old.quantity 
where product.ID = old.productid;
END; 
//
DELIMITER ;
