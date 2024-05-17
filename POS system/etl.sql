
/*check database and drop if it already exists*/

Drop database if exists pos;
create database pos;
use pos;

--creating the main tables
--creating the city table
create table pos.city(zip DECIMAL(5) ZEROFILL PRIMARY KEY,city VARCHAR(32),state VARCHAR(4));

--creating the customer table
create table pos.customer(ID INT PRIMARY KEY,firstName VARCHAR(64),lastName VARCHAR(32),
email VARCHAR(128),address1 VARCHAR(128),address2 VARCHAR(128),phone VARCHAR(32),birthDate Date,
zip DECIMAL(5) ZEROFILL REFERENCES pos.city(zip));

--creating the product table
create table pos.product( ID int PRIMARY KEY, name varchar(128), currentPrice DECIMAL(6,2), qtyOnHand int);

--creating the status table
create TABLE pos.status(status TINYINT PRIMARY KEY, description VARCHAR(12));

--creating the order table
create table pos.order (
    ID INT primary key,
    datePlaced DATE,
    dateShipped DATE,
    status TINYINT REFERENCES pos.status(status),
    customerID INT references pos.customer(ID));

--creating the orderLine table
create TABLE pos.orderLine(
    orderID INT,
    productID int,
    quantity int,
    PRIMARY KEY(orderID, productID),
    FOREIGN KEY(orderID) REFERENCES pos.order(ID),
    FOREIGN KEY(productID) references pos.product(ID));

--creating the temp tables
-- creating the product temp table
create table pos.product_temp_tl( ID int PRIMARY KEY, name varchar(128), currentPrice varchar(128), qtyOnHand int);

-- creating the order temp table
create table pos.order_temp_tl(
    OID INT ,
    CID INT );

-- creating the customer temp table
create table pos.cust_temp_tl(ID int, FN VARCHAR(128), LN VARCHAR(128), CT VARCHAR(128),ST VARCHAR(128),ZP VARCHAR(128), S1 VARCHAR(128),S2 varchar(128),EM varchar(128),BD VARCHAR(128));

-- creating the orderline temp table
create table pos.ol_temp_tl(OID int, PID int);

--loading into temp tables and manipulation of data	, inserting back to main tables.

--loading the data into customer temp table and transforming the birthdate

LOAD DATA LOCAL INFILE '/home/dgomillion/customers.csv'
INTO TABLE cust_temp_tl
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(ID,FN,LN,CT,ST,ZP,S1,S2,EM,@BD)
SET BD=STR_TO_DATE(@BD,"%m/%d/%Y");

UPDATE pos.cust_temp_tl SET BD = NULL where BD = '0000-00-00' or BD = '';
UPDATE pos.cust_temp_tl SET S2 = NULL where S2 = '';

-- inserting details into city table and then into customer (putting it here as customer and city are dependent)

INSERT INTO city(zip,city,state) SELECT DISTINCT ZP,CT,ST from cust_temp_tl group by ZP;
INSERT INTO customer(ID,firstName,lastName,email,address1,address2,birthDate,zip) SELECT ID,FN,LN,EM,S1,S2,BD,ZP from cust_temp_tl;

--loading the data into products temp removing $ and , and inserting into to product table
LOAD DATA LOCAL INFILE '/home/dgomillion/products.csv'
INTO TABLE pos.product_temp_tl
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(ID,name,@currentPrice,qtyOnHand)
set currentPrice = REPLACE(REPLACE(@currentPrice, "$",""),",","");

INSERT into pos.product(Select * from pos.product_temp_tl);


--loading the data into order temp and inserting into to order table
LOAD DATA LOCAL INFILE '/home/dgomillion/orders.csv'
INTO TABLE pos.order_temp_tl
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

INSERT into `order`(ID,customerID) Select OID,CID from pos.order_temp_tl;


--loading the data into orderline temp and inserting into to orderline table
LOAD DATA LOCAL INFILE '/home/dgomillion/orderlines.csv'
INTO TABLE ol_temp_tl
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(OID,PID);

INSERT INTO pos.orderLine (Select OID,PID,count(*) as quantity from ol_temp_tl group by OID,PID);


--dropping all the temp tables
Drop table cust_temp_tl;
Drop table ol_temp_tl;
Drop table order_temp_tl;
Drop table product_temp_tl;