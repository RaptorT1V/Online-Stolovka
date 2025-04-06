    -- - ! - - - - - - | Блок DROP'ов | - - - - - - ! - --
DROP TABLE IF EXISTS TimeVarying_prices CASCADE;
DROP TABLE IF EXISTS Available_dishes CASCADE;
DROP TABLE IF EXISTS Customers CASCADE;
DROP TABLE IF EXISTS Diet CASCADE;
DROP TABLE IF EXISTS Order_details CASCADE;
DROP TABLE IF EXISTS Orders CASCADE;
DROP TABLE IF EXISTS Products CASCADE;
DROP TABLE IF EXISTS Schedule CASCADE;

DROP TYPE IF EXISTS Categories CASCADE;
DROP TYPE IF EXISTS Days_of_week CASCADE;
DROP TYPE IF EXISTS Statuses CASCADE;
DROP TYPE IF EXISTS Titles CASCADE;

DROP FUNCTION IF EXISTS hash_password() CASCADE;
DROP FUNCTION IF EXISTS add_plus_to_phone() CASCADE;
DROP FUNCTION IF EXISTS set_price_date() CASCADE;
DROP FUNCTION IF EXISTS track_customers_registration() CASCADE;
DROP FUNCTION IF EXISTS track_order_creation() CASCADE;
DROP FUNCTION IF EXISTS update_valid_unit_price() CASCADE;

DROP TRIGGER IF EXISTS hash_password_trigger ON Customers;     
DROP TRIGGER IF EXISTS add_plus_to_phone_trigger ON Customers;
DROP TRIGGER IF EXISTS set_price_date_trigger ON TimeVarying_Prices;
DROP TRIGGER IF EXISTS track_customers_registration_trigger ON Customers;
DROP TRIGGER IF EXISTS track_order_creation_trigger ON Orders;

DROP VIEW IF EXISTS Products_TotalWeight;
DROP VIEW IF EXISTS Products_RealWeight;

DROP EXTENSION IF EXISTS pgcrypto;

-- - - - - - - - - | Подключение расширений | - - - - - - - - --
CREATE EXTENSION IF NOT EXISTS pgcrypto;
-- - - - - - - - - | Создание перечислений | - - - - - - - - --
CREATE TYPE Categories AS ENUM ('Первое блюдо', 'Второе блюдо', 'Гарнир', 'Салат', 'Напитки', 'Дополнительное', 'Магазинное'); -- для т. Products
CREATE TYPE Days_of_week AS ENUM ('Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота'); -- для т. Weekly_Menu
CREATE TYPE Statuses AS ENUM ('Completed', 'Waiting', 'Canceled'); -- для т. Orders
CREATE TYPE Titles AS ENUM ('Студент', 'Преподаватель', 'Сотрудник'); -- для т. Customers

    -- - ! - - - - - - | Создание таблиц (+ Primary Key) | - - - - - - ! - --
CREATE TABLE Available_dishes ( -- т. доступных блюд, исходя из расписания
  Schedule_ID  int NOT NULL, 
  Product_ID   int NOT NULL,
  PRIMARY KEY(Schedule_ID, Product_ID)	-- they're UNIQUE and can't be NULL
);

CREATE TABLE Customers ( -- т. зарегистрированных клиентов
  Customer_ID   int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  First_name    varchar(20) NOT NULL, 
  Last_name     varchar(30) NOT NULL, 
  Father_name   varchar(20), 
  Title         Titles NOT NULL,  -- перечисление "Titles"
  E_mail        varchar(50) DEFAULT NULL, 
  Phone_number  char(12) DEFAULT NULL, 
  Cust_password varchar(255) NOT NULL,
  Registered    timestamp NOT NULL
);

CREATE TABLE Diet ( -- т. диет
  Diet_ID          int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  Diet_type        varchar(45) NOT NULL, 
  Diet_description text
);

CREATE TABLE Order_details ( -- т. деталей заказов
  Order_ID       int NOT NULL, 
  Product_ID     int NOT NULL, 
  Quantity       int NOT NULL, 
  Price          int NOT NULL, -- quantity * unit_price FROM корзина
  PRIMARY KEY (Order_ID, Product_ID) -- Определение композитного первичного ключа
);

CREATE TABLE Orders ( -- т. с заказами
  Order_ID    int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  Order_date  timestamp NOT NULL, 
  Customer_ID int NOT NULL, 
  Total_price float8 NOT NULL, -- sum of order_details 
  Short_ID    varchar(4) NOT NULL, -- random generated
  Status      Statuses DEFAULT 'Waiting' NOT NULL -- | Изменяется на 1C терминале кассиршей |
);

CREATE TABLE Products ( -- т. существующих блюд
  Product_ID       	   int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  Product_name     	   varchar(60) UNIQUE NOT NULL,
  Category         	   Categories NOT NULL, 	
  Product_description  text,	
  Units_in_stock   	   int NOT NULL, -- | постоянно изменяется (с каждым заказом уменьшается) |
  Valid_unit_price 	   int NOT NULL, -- это единственная меняющаяся колонка?
  Weight_g             int NOT NULL,
  Additional_weight_g  int,
  Value_kcal		   float4 NOT NULL,	
  Diet_ID          	   int
);

CREATE TABLE Schedule ( -- т. с расписанием (имеются только 2 недели, которые чередуются)
  Schedule_ID  int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  Week_number  int NOT NULL, -- 1 или 2
  Day_of_week  Days_of_week NOT NULL
);

CREATE TABLE TimeVarying_prices ( -- т. меняющихся со временем цен
  Product_ID  int NOT NULL, 
  Price_date  timestamp NOT NULL, 
  Unit_price  float8 NOT NULL,
  PRIMARY KEY (Product_ID, Price_date) -- Определение композитного первичного ключа
);

    -- - ! - - - - - - | Создание ограничений: Foreign Key, Check | - - - - - - ! - --
ALTER TABLE Available_dishes ADD CONSTRAINT FKAvailable_di224378 FOREIGN KEY (Product_ID) REFERENCES Products (Product_ID);
ALTER TABLE Available_dishes ADD CONSTRAINT FKAvailable_di531707 FOREIGN KEY (Schedule_ID) REFERENCES Schedule (Schedule_ID);
ALTER TABLE Order_details ADD CONSTRAINT FKOrder_deta483927 FOREIGN KEY (Product_ID) REFERENCES Products (Product_ID);
ALTER TABLE Order_details ADD CONSTRAINT FKOrder_deta385431 FOREIGN KEY (Order_ID) REFERENCES Orders (Order_ID);
ALTER TABLE Orders ADD CONSTRAINT FKOrders240764 FOREIGN KEY (Customer_ID) REFERENCES Customers (Customer_ID);
ALTER TABLE Products ADD CONSTRAINT FKProducts234923 FOREIGN KEY (Diet_ID) REFERENCES Diet (Diet_ID);
ALTER TABLE TimeVarying_prices ADD CONSTRAINT FKTimeVar_pri343218 FOREIGN KEY (Product_ID) REFERENCES Products (Product_ID);
-- - - -
CREATE UNIQUE INDEX unique_email_or_phone_index ON Customers (COALESCE(e_mail, ''), COALESCE(phone_number, ''));

ALTER TABLE Customers
ADD CONSTRAINT unique_email_or_phone_constraint -- Пара значений e-mail, phone_number должна быть уникальна относительно других строк
UNIQUE (e_mail, phone_number);

ALTER TABLE Customers
ADD CONSTRAINT check_email_mask -- Проверка маски e-mail и запрещённых символов
CHECK (E_mail ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$');

ALTER TABLE Customers
ADD CONSTRAINT check_password_english_chars -- Проверка: пароль мб только на английском
CHECK (Cust_password ~ '^[a-zA-Z0-9!$^&()-_+=,.{}]+$');

ALTER TABLE Products
ADD CONSTRAINT check_weight_positive -- Вес (г) > 0
CHECK (Weight_g > 0);

ALTER TABLE Products
ADD CONSTRAINT check_additional_weight_null_or_positive -- Дополнительный вес (г) либо > 0 либо NULL 
CHECK (Additional_weight_g > 0 OR Additional_weight_g IS NULL);

ALTER TABLE Products
ADD CONSTRAINT check_value_kcal_positive -- ККал > 0
CHECK (Value_kcal > 0);

ALTER TABLE Schedule
ADD CONSTRAINT check_value_of_week_number -- Только 1-ая или 2-ая неделя
CHECK (Week_number = 1 OR Week_number = 2);

ALTER TABLE Schedule
ADD CONSTRAINT unique_week_day_and_number -- Пара значений Week_number, Day_of_week должна быть уникальна относительно других строк
UNIQUE (Week_number, Day_of_week);

ALTER TABLE TimeVarying_prices
ADD CONSTRAINT check_unit_price_positive -- Unit_price мб только положительный
CHECK (Unit_price > 0);

    -- - ! - - - - - - | Создание триггеров | - - - - - - ! - --
 -- - Триггер для хэширования новых паролей 
CREATE OR REPLACE FUNCTION hash_password() RETURNS TRIGGER AS $$
BEGIN
  NEW.Cust_password := crypt(NEW.Cust_password, gen_salt('bf'));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER hash_password_trigger
BEFORE INSERT ON Customers
FOR EACH ROW
EXECUTE FUNCTION hash_password();
 -- - Триггер для помещения знака "+" перед номером телефона 
CREATE OR REPLACE FUNCTION add_plus_to_phone()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.Phone_number IS NOT NULL AND LEFT(NEW.Phone_number, 1) != '+' THEN
    NEW.Phone_number = '+' || NEW.Phone_number;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER add_plus_to_phone_trigger 
BEFORE INSERT ON Customers
FOR EACH ROW
EXECUTE FUNCTION add_plus_to_phone();
 -- - Триггер для фиксирования даты регистрации пользователя 
CREATE OR REPLACE FUNCTION track_customers_registration() RETURNS trigger AS $$
BEGIN
	NEW.Registered = now();
	RETURN NEW;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER track_customers_registration_trigger
BEFORE INSERT ON Customers
FOR EACH ROW
EXECUTE FUNCTION track_customers_registration();
-- - Триггер для автоматического фиксирования даты создания заказа
CREATE OR REPLACE FUNCTION track_order_creation() RETURNS trigger AS $$
BEGIN
	NEW.Order_date = now();
	RETURN NEW;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER track_order_creation_trigger
BEFORE INSERT ON Orders
FOR EACH ROW
EXECUTE FUNCTION track_order_creation();
 -- - Триггер для автоматической установки price_date при заполнении таблицы TimeVarying_Prices
CREATE OR REPLACE FUNCTION set_price_date() RETURNS TRIGGER AS $$
BEGIN
  NEW.Price_date = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER set_price_date_trigger
BEFORE INSERT ON TimeVarying_prices
FOR EACH ROW
EXECUTE FUNCTION set_price_date();

    -- - ! - - - - - - | Создание функций | - - - - - - ! - --
 -- - Функция для обновления актуальных цен в таблице Products на основе записей из TimeVarying_prices 
CREATE OR REPLACE FUNCTION update_valid_unit_price() RETURNS VOID AS $$
DECLARE
  temp_product_id int;
BEGIN
  temp_product_id := 1;
  WHILE EXISTS (SELECT 1 FROM Products WHERE Product_ID = temp_product_id) LOOP
    UPDATE Products
    SET Valid_unit_price = (
      SELECT Unit_price
      FROM TimeVarying_Prices
      WHERE Product_ID = temp_product_id
      AND Price_date = (
        SELECT GREATEST(Price_date)
        FROM TimeVarying_Prices
        WHERE Product_ID = temp_product_id
		ORDER BY Price_date DESC
		LIMIT 1
      )
    )
    WHERE Product_ID = temp_product_id;
    temp_product_id := temp_product_id + 1;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

    -- - ! - - - - - - | Создание представлений (view'шек) | - - - - - - ! - --
CREATE VIEW Products_TotalWeight AS -- Таблица Products как в расписании (с делимитром "/" в "Выходе блюд")
SELECT
    Product_ID,
    Product_name,
    Category,
    Product_description,
    Units_in_stock,
    Valid_unit_price,
    Weight_g || COALESCE('/' || Additional_weight_g, '') AS Total_weight_g,
    Value_kcal,
    Diet_ID
FROM
    Products;
-- - - - - - -
CREATE VIEW Products_RealWeight AS -- Таблица Products с суммарным весом блюда, если Additional_weight_g не пустой
SELECT
    Product_ID,
    Product_name,
    Category,
    Product_description,
    Units_in_stock,
    Valid_unit_price,
    COALESCE(Weight_g::int, 0) + COALESCE(Additional_weight_g, 0) AS Real_weight_g,
    Value_kcal,
    Diet_ID
FROM
    Products;

		-- - ! - ! - - - - | | | Вставка данных | | | - - - - ! - ! - --
 -- - - - Заполняется админом - - - --
INSERT INTO Schedule (week_number, day_of_week) VALUES
	(1, 'Понедельник'), (1, 'Вторник'), (1, 'Среда'), (1, 'Четверг'), (1, 'Пятница'),
	(2, 'Понедельник'), (2, 'Вторник'), (2, 'Среда'), (2, 'Четверг'), (2, 'Пятница');
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
INSERT INTO Products (product_name, category, product_description, units_in_stock, valid_unit_price, weight_g, additional_weight_g, value_kcal) VALUES
	('Салат из белокочанной капусты', 'Салат', NULL,  5, 17, 100, NULL, 98),
	('Салат из моркови острый', 'Салат', NULL, 4, 38, 100, NULL, 239),
	('Салат "Немецкий"', 'Салат', 'колбаса п/к, картофель, огурцы, морковь, горошек конс., яйцо, майонез', 3, 48, 100, NULL, 128.34),
	('Винегрет овощной с зелёным горошком', 'Салат', NULL, 4, 32, 100, 10, 153), 
	('Салат из белокочанной капусты с яйцом', 'Салат', NULL, 5, 22, 100, NULL, 118),
	('Салат из крабовых палочек', 'Салат', 'краб. палочки, кукуруза конс., рис отварн., яйцо, майонез', 3, 37, 100, NULL, 227),
	('Салат из белокочанной капусты с яблоком', 'Салат', NULL, 5, 20, 100, NULL, 101),
	('Морковь по-корейски', 'Салат', NULL, 4, 30, 100, NULL, 177),
	('Салат "Оливье по-домашнему"', 'Салат', 'картошка., огурец. конс., лук репч., морковь, колбаса вар., горошек конс., яйцо, майонез', 3, 40, 100, NULL, 229),
	('Салат из белокочанной капусты с кукурузой', 'Салат', NULL, 5, 22, 100, 10, 112), 
	('Салат из свёклы с сыром и чесноком', 'Салат', NULL, 4, 38, 100, NULL, 198),
	('Салат "Сюрприз"', 'Салат', 'краб. палочки, кукуруза конс., огурец свежий, яйцо, майонез', 3, 40, 100, NULL, 210),
	('Салат из белокочанной капусты с огурцом (свежим)', 'Салат', NULL, 5, 20, 100, NULL, 108),
	('Салат "Мясной"', 'Салат', NULL, 4, 36, 100, NULL, 269),
	('Салат "Лолита"', 'Салат', NULL, 3, 40, 100, NULL, 208),
	('Салат из белокочанной капусты с зелёным горошком', 'Салат', NULL, 5, 22, 100, NULL, 104);

INSERT INTO Products (product_name, category, product_description, units_in_stock, valid_unit_price, weight_g, additional_weight_g, value_kcal) VALUES
	('Щи из свежей капусты со сметаной', 'Первое блюдо', 'капуста б/к, картофель, лук.реп., морковь, томатная паста, сметана',  6, 24, 250, 10, 132), 
	('Суп картофельный с горохом', 'Первое блюдо', NULL,  6, 20, 250, NULL, 187),
	('Борщ с фасолью и картофелем со сметаной', 'Первое блюдо', NULL,  6, 25, 250, 10, 170), 
	('Рассольник "Ленинградский"', 'Первое блюдо', NULL,  6, 30, 250, 10, 188), 
	('Суп-лапша домашняя с куриным филе', 'Первое блюдо', NULL,  6, 25, 250, 10, 211), 
	('Борщ из свежей капусты со сметаной', 'Первое блюдо', 'бульон, свекла, капуста б/к, картофель, морковь, лук репч., паста томатн., масло растит.',  6, 25, 250, 10, 142),
	('Суп томатный с рисом', 'Первое блюдо', NULL,  6, 20, 250, 10, 195);

INSERT INTO Products (product_name, category, product_description, units_in_stock, valid_unit_price, weight_g, additional_weight_g, value_kcal) VALUES
	('Минтай жареный', 'Второе блюдо', NULL, 8, 35, 75, NULL, 167),
	('Котлета отбивная "Загорская"', 'Второе блюдо', NULL, 8, 60, 70, NULL, 281),
	('Тефтели с рисом', 'Второе блюдо', NULL, 8, 54, 60, 50, 210), 
	('Свинина в сырной шубке', 'Второе блюдо', 'свинина, яйцо, морковь, сыр, мука, масло раст.', 8, 88, 75, NULL, 446),
	('Окорочка жареные', 'Второе блюдо', NULL, 8, 65, 80, NULL, 329),
	('Котлеты рубленые из мяса', 'Второе блюдо', NULL, 8, 54, 75, NULL, 246),
	('Филе птицы, запечённое с овощами', 'Второе блюдо', 'лук, морковь', 8, 65, 90, NULL, 178.33),
	('Котлета по-деревенски', 'Второе блюдо', NULL, 8, 54, 75, NULL, 316),
	('Птица по-домашнему', 'Второе блюдо', NULL, 8, 65, 75, NULL, 347),
	('Шницель рубленый из мяса', 'Второе блюдо', NULL, 8, 54, 75, NULL, 246),
	('Филе минтая, жаренное в яйце', 'Второе блюдо', NULL, 8, 50, 75, NULL, 190),
	('Плов из окорочков', 'Второе блюдо', NULL, 8, 78, 50, 200, 720), 
	('Биточки рубленые из птицы', 'Второе блюдо', NULL, 8, 54, 75, NULL, 303),
	('Окорочка отварные', 'Второе блюдо', NULL, 8, 65, 80, NULL, 286),
	('Котлета отбивная из филе грудки', 'Второе блюдо', NULL, 8, 65, 80, NULL, 268);

INSERT INTO Products (product_name, category, product_description, units_in_stock, valid_unit_price, weight_g, value_kcal) VALUES
	('Макаронные изделия отварные', 'Гарнир', NULL,  11, 15, 150, 252),
	('Каша гречневая', 'Гарнир', NULL,  11, 18, 150, 253),
	('Картофель (отварной)', 'Гарнир', NULL,  11, 30, 150, 232),
	('Рис отварной', 'Гарнир', NULL,  11, 16, 150, 222),
	('Капуста тушёная', 'Гарнир', NULL,  11, 25, 150, 140),
	('Картофельное пюре', 'Гарнир', NULL,  11, 25, 150, 212),
	('Каша пшеничная, рассыпчатая', 'Гарнир', NULL,  11, 12, 150, 234),
	('Картофель (запечённый)', 'Гарнир', NULL,  11, 34, 150, 265);

INSERT INTO Products (product_name, category, product_description, units_in_stock, valid_unit_price, weight_g, value_kcal) VALUES
	('Хлеб "Кишинёвский"', 'Дополнительное', NULL,  19, 3, 30, 89.61),
	('Хлеб "Дарнецкий"', 'Дополнительное', NULL,  19, 3, 30, 59.43);
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
INSERT INTO Available_Dishes VALUES
    (1, 1), (1, 2), (1, 3), (1, 17), (1, 24), (1, 25), (1, 26), (1, 39), (1, 40), (1, 47), (1, 48),
    (2, 4), (2, 5), (2, 6), (2, 18), (2, 27), (2, 28), (2, 29), (2, 41), (2, 42), (2, 47), (2, 48),
    (3, 7), (3, 8), (3, 9), (3, 19), (3, 24), (3, 30), (3, 31), (3, 43), (3, 44), (3, 47), (3, 48),
    (4, 10), (4, 11), (4, 12), (4, 20), (4, 32), (4,27), (4, 33), (4, 39), (4, 45), (4, 47), (4, 48),
    (5, 13), (5, 14), (5, 15), (5, 21), (5, 34), (5, 35), (5, 36), (5, 46), (5, 39), (5, 47), (5, 48), -- ПЕРВАЯ НЕДЕЛЯ ЗАКОНЧ.
    (6, 10), (6, 11), (6, 9), (6, 22), (6, 37), (6, 27), (6, 36), (6, 39), (6, 42), (6, 47), (6, 48),
    (7, 16), (7, 8), (7, 12), (7, 23), (7, 32), (7, 24), (7, 31), (7, 43), (7, 44), (7, 47), (7, 48),
    (8, 5), (8, 4), (8, 3), (8, 21), (8, 34), (8, 38), (8, 26), (8, 41), (8, 45), (8, 47), (8, 48),
    (9, 13), (9, 2), (9, 14), (9, 17), (9, 28), (9, 30), (9, 29), (9, 46), (9, 39), (9, 47), (9, 48),
    (10, 1), (10, 9), (10, 6), (10, 18), (10, 24), (10, 25), (10, 33), (10, 44), (10, 40), (10, 47), (10, 48); -- ВТОРАЯ НЕДЕЛЯ ЗАКОНЧ.
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
INSERT INTO TimeVarying_Prices (product_id, unit_price) VALUES
  (1, 17), (2, 38), (3, 48), (4, 32), (5, 22), (6, 37), (7, 20), (8, 30), (9, 40), (10, 22), (11, 38), (12, 40), (13, 20), (14, 36), (15, 40), (16, 22), -- Салат
  (17, 24), (18, 20), (19, 25), (20, 30), (21, 25), (22, 25), (23, 20), -- Первое
  (24, 35), (25, 60), (26, 54), (27, 88), (28, 65), (29, 54), (30, 65), (31, 54), (32, 65), (33, 54), (34, 50), (35, 78), (36, 54), (37, 65), (38, 65), -- Второе
  (39, 15), (40, 18), (41, 30), (42, 16), (43, 25), (44, 25), (45, 12), (46, 34), -- Гарнир
  (47, 3), (48, 3); -- Доп

 -- - - - Заполняется пользователями - - - --
INSERT INTO Customers (first_name, last_name, father_name, title, e_mail, phone_number, cust_password) VALUES
	('Татьяна', 'Филоненко', 'Павловна', 'Преподаватель', NULL, '79121234567', 'mathmistress314'),
	('Евгений', 'Смирнов', NULL, 'Студент', NULL, '+79877654321', 'evgsmirn777'),
	('Вова', 'Алексеев', NULL, 'Студент', 'gigant_misli@mail.ru', NULL, 'dota2onelove'),
	('Александр', 'Корсик', 'Сергеевич', 'Сотрудник', 'ITguru@yandex.com', NULL, 'misisthebest');
 
 -- - - - Заполняется системой (автоматически) - - - --

			-- - - - - - - | – | – | Роли, юзеры и гранты | – | – | - - - - - - --
	--- Удаление всех ролей и всех прав ---
-- DROP POLICY *policy_name* ON *table_name* <– дропнуть политики, если будут
DROP FUNCTION IF EXISTS revoke_and_drop_role(role_name VARCHAR(255));
CREATE OR REPLACE FUNCTION revoke_and_drop_role(role_name VARCHAR(255))
RETURNS VOID AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = role_name) THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM ' || role_name;
        EXECUTE 'REVOKE ALL ON DATABASE online_stolovka FROM ' || role_name;
        EXECUTE 'REVOKE ALL ON SCHEMA public FROM ' || role_name;
        EXECUTE 'DROP ROLE ' || role_name;
    END IF;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS revoke_and_drop_user(user_name VARCHAR(255));
CREATE OR REPLACE FUNCTION revoke_and_drop_user(user_name VARCHAR(255))
RETURNS VOID AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = user_name) THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM ' || user_name;
        EXECUTE 'REVOKE ALL ON DATABASE online_stolovka FROM ' || user_name;
        EXECUTE 'REVOKE ALL ON SCHEMA public FROM ' || user_name;
        EXECUTE 'DROP ROLE ' || user_name;
    END IF;
END;
$$ LANGUAGE plpgsql;

SELECT revoke_and_drop_role('c1_terminal');
SELECT revoke_and_drop_role('stolovka_admins');
SELECT revoke_and_drop_role('typical_users');

SELECT revoke_and_drop_user('irina_cashier');
SELECT revoke_and_drop_user('ilya_admin');
SELECT revoke_and_drop_user('ivan_user');

REVOKE CREATE ON SCHEMA public FROM public;
REVOKE ALL ON DATABASE online_stolovka FROM public;
	--- Создание ролей и юзеров ---
CREATE ROLE c1_terminal;
CREATE ROLE stolovka_admins;
CREATE ROLE typical_users;
	
CREATE USER irina_cashier WITH PASSWORD 'misis';
CREATE USER ilya_admin WITH PASSWORD 'zxcvb';
CREATE USER ivan_user WITH PASSWORD 'qwerty';

GRANT irina_cashier TO c1_terminal;
GRANT ilya_admin TO stolovka_admins;
GRANT ivan_user TO typical_users;
	--- Уровень базы данных ---
GRANT CONNECT ON DATABASE online_stolovka TO c1_terminal;
GRANT CONNECT ON DATABASE online_stolovka TO stolovka_admins;
GRANT CONNECT ON DATABASE online_stolovka TO typical_users;

GRANT USAGE ON SCHEMA public TO c1_terminal;
GRANT USAGE ON SCHEMA public TO stolovka_admins;
GRANT USAGE ON SCHEMA public TO typical_users;

GRANT CREATE ON DATABASE online_stolovka TO stolovka_admins;
	--- Уровень таблиц и колонок ---
GRANT SELECT, INSERT, UPDATE 
ON TABLE public.timevarying_prices
TO c1_terminal;

GRANT SELECT, INSERT, UPDATE (product_name, category, product_description, units_in_stock, weight_g, additional_weight_g, value_kcal, diet_id)
ON products
TO c1_terminal;

GRANT SELECT (customer_id, first_name, last_name, father_name, title)
ON customers
TO c1_terminal;

GRANT SELECT 
ON TABLE public.available_dishes, public.orders, public.order_details, public.schedule
TO c1_terminal;
 --
GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES, TRIGGER
ON ALL TABLES IN SCHEMA public
TO stolovka_admins;
 --
GRANT SELECT
ON TABLE public.available_dishes, public.diet, public.products
TO typical_users;

SELECT 'Формирование базы данных "Онлайн-Столовка" окончено'