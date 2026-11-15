--
-- PostgreSQL database dump
--

-- Dumped from database version 17.2
-- Dumped by pg_dump version 17.0

-- Started on 2026-11-15 16:49:44

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 5 (class 2615 OID 16868)
-- Name: buldakov_food; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA buldakov_food;


ALTER SCHEMA buldakov_food OWNER TO postgres;

--
-- TOC entry 888 (class 1247 OID 16884)
-- Name: courier_status; Type: TYPE; Schema: buldakov_food; Owner: postgres
--

CREATE TYPE buldakov_food.courier_status AS ENUM (
    'свободен',
    'занят',
    'на_доставке',
    'уволен'
);


ALTER TYPE buldakov_food.courier_status OWNER TO postgres;

--
-- TOC entry 891 (class 1247 OID 16894)
-- Name: order_status; Type: TYPE; Schema: buldakov_food; Owner: postgres
--

CREATE TYPE buldakov_food.order_status AS ENUM (
    'создан',
    'готовится',
    'в_доставке',
    'доставлен',
    'отменён'
);


ALTER TYPE buldakov_food.order_status OWNER TO postgres;

--
-- TOC entry 903 (class 1247 OID 16906)
-- Name: pay_status; Type: TYPE; Schema: buldakov_food; Owner: postgres
--

CREATE TYPE buldakov_food.pay_status AS ENUM (
    'ожидает',
    'оплачен',
    'ошибка'
);


ALTER TYPE buldakov_food.pay_status OWNER TO postgres;

--
-- TOC entry 894 (class 1247 OID 16914)
-- Name: payment_status; Type: TYPE; Schema: buldakov_food; Owner: postgres
--

CREATE TYPE buldakov_food.payment_status AS ENUM (
    'успех',
    'ошибка',
    'в_обработке'
);


ALTER TYPE buldakov_food.payment_status OWNER TO postgres;

--
-- TOC entry 897 (class 1247 OID 16922)
-- Name: payment_type; Type: TYPE; Schema: buldakov_food; Owner: postgres
--

CREATE TYPE buldakov_food.payment_type AS ENUM (
    'карта',
    'наличные',
    'безнал'
);


ALTER TYPE buldakov_food.payment_type OWNER TO postgres;

--
-- TOC entry 906 (class 1247 OID 16876)
-- Name: product_status; Type: TYPE; Schema: buldakov_food; Owner: postgres
--

CREATE TYPE buldakov_food.product_status AS ENUM (
    'доступно',
    'нет_в_наличии',
    'архив'
);


ALTER TYPE buldakov_food.product_status OWNER TO postgres;

--
-- TOC entry 885 (class 1247 OID 16870)
-- Name: restaurant_status; Type: TYPE; Schema: buldakov_food; Owner: postgres
--

CREATE TYPE buldakov_food.restaurant_status AS ENUM (
    'активен',
    'неактивен'
);


ALTER TYPE buldakov_food.restaurant_status OWNER TO postgres;

--
-- TOC entry 900 (class 1247 OID 16930)
-- Name: review_entity_type; Type: TYPE; Schema: buldakov_food; Owner: postgres
--

CREATE TYPE buldakov_food.review_entity_type AS ENUM (
    'блюдо',
    'ресторан',
    'заказ'
);


ALTER TYPE buldakov_food.review_entity_type OWNER TO postgres;

--
-- TOC entry 261 (class 1255 OID 17148)
-- Name: add_product(character varying, uuid, numeric, uuid, text, numeric, buldakov_food.product_status, text); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.add_product(IN product_name character varying, IN product_category_id uuid, IN price numeric, IN restaurant_id uuid, IN photo_url text, IN rating numeric, IN status buldakov_food.product_status, IN description text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_product_id UUID;
BEGIN
	new_product_id := exts.uuid_generate_v4();
    insert into buldakov_food.product values(
		new_product_id,
		product_name,
		product_category_id,
		price,
		restaurant_id,
		photo_url,
		rating,
		status,
		description
	);
END;
$$;


ALTER PROCEDURE buldakov_food.add_product(IN product_name character varying, IN product_category_id uuid, IN price numeric, IN restaurant_id uuid, IN photo_url text, IN rating numeric, IN status buldakov_food.product_status, IN description text) OWNER TO postgres;

--
-- TOC entry 264 (class 1255 OID 17155)
-- Name: courier_salary(); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.courier_salary()
    LANGUAGE plpgsql
    AS $$
begin
	INSERT INTO buldakov_food.courier_pay
	SELECT
	    EXTRACT(YEAR FROM CURRENT_DATE)::INT,
	    EXTRACT(MONTH FROM CURRENT_DATE)::INT,
	    c.courier_id,
	    coalesce(cp.coefficient_used,c.coefficient) * COALESCE(SUM(o.commission), 0),
	    coalesce(cp.coefficient_used,c.coefficient)
	FROM buldakov_food.courier c
	LEFT JOIN buldakov_food."order" o
	    ON c.courier_id = o.courier_id
	    AND o.status = 'доставлен'
	    AND o.delivery_timestamp >= date_trunc('month', CURRENT_DATE)
	    AND o.delivery_timestamp < date_trunc('month', CURRENT_DATE) + INTERVAL '1 month'
	LEFT JOIN buldakov_food.courier_pay cp
	    ON c.courier_id = cp.courier_id
	    AND cp.year = EXTRACT(YEAR FROM CURRENT_DATE)::INT
	    AND cp.month = EXTRACT(MONTH FROM CURRENT_DATE)::INT
	GROUP BY c.courier_id, c.coefficient, cp.coefficient_used
	ON CONFLICT (year, month, courier_id)
	DO UPDATE SET
	    amount = EXCLUDED.amount,
	    coefficient_used = EXCLUDED.coefficient_used;
	update buldakov_food.courier c 
	set coefficient = CASE
		    WHEN stats.delivered_count <= 150 THEN 0.1
		    WHEN stats.delivered_count <= 250 THEN 0.2
		    WHEN stats.delivered_count <= 500 THEN 0.3
		    ELSE 0.5
		END
	FROM (
	    SELECT
	        c.courier_id,
	        COUNT(o.order_id) AS delivered_count
	    FROM buldakov_food.courier c
	    LEFT JOIN buldakov_food."order" o
	        ON o.courier_id = c.courier_id
	        AND o.status = 'доставлен'
	        AND o.delivery_timestamp >= date_trunc('month', CURRENT_DATE)
	        AND o.delivery_timestamp < date_trunc('month', CURRENT_DATE) + INTERVAL '1 month'
	    GROUP BY c.courier_id
	) stats
	WHERE c.courier_id = stats.courier_id
	  AND c.status <> 'уволен';
END;
$$;


ALTER PROCEDURE buldakov_food.courier_salary() OWNER TO postgres;

--
-- TOC entry 260 (class 1255 OID 17145)
-- Name: erase_test_data(); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.erase_test_data()
    LANGUAGE plpgsql
    AS $$
begin
	delete from buldakov_food.review;
	delete from buldakov_food.payment;
	delete from buldakov_food.order_structure;
	delete from buldakov_food.courier_pay;
	delete from buldakov_food."order";
	delete from buldakov_food.product;
	delete from buldakov_food.restaurant;
	delete from buldakov_food.client_address;
	delete from buldakov_food.address;
	delete from buldakov_food.courier;
	delete from buldakov_food.client;
	delete from buldakov_food.product_category;
end;
$$;


ALTER PROCEDURE buldakov_food.erase_test_data() OWNER TO postgres;

--
-- TOC entry 254 (class 1255 OID 17134)
-- Name: generate_addresses(integer, uuid[], uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.generate_addresses(IN p_value integer, INOUT restaurant_address_ids uuid[], INOUT client_address_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_address_id UUID;
    new_apartment VARCHAR(20);
BEGIN
    IF p_value <= 0 THEN
        RAISE EXCEPTION 'Значение должно быть больше нуля';
    END IF;
	restaurant_address_ids := ARRAY[]::UUID[];
    client_address_ids := ARRAY[]::UUID[];
	--
	--
	for i in 1..p_value*5 loop
    IF FLOOR(RANDOM() * 2)::INT = 1 THEN
        new_apartment := NULL;
    ELSE
        new_apartment := FLOOR(RANDOM() * 200 + 1)::text;
    END IF;
	-- айдишка адреса, потом для связи с ресторанами понадобится
	new_address_id := exts.uuid_generate_v4();
	insert into buldakov_food.address values 
	(	new_address_id,
		'street_' || exts.uuid_generate_v4()::text,
		FLOOR(RANDOM()*300 + 1)::text,
		new_apartment
	);
	if i <=p_value then
		restaurant_address_ids := array_append(
			restaurant_address_ids,
			new_address_id
		);
	else client_address_ids := array_append(
			client_address_ids,
			new_address_id
		);
	end if;
end loop;
end;
$$;


ALTER PROCEDURE buldakov_food.generate_addresses(IN p_value integer, INOUT restaurant_address_ids uuid[], INOUT client_address_ids uuid[]) OWNER TO postgres;

--
-- TOC entry 266 (class 1255 OID 17133)
-- Name: generate_base_data(integer, uuid[], uuid[], uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.generate_base_data(IN p_value integer, INOUT client_ids uuid[], INOUT courier_ids uuid[], INOUT product_category_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_client_id UUID;
    new_courier_id UUID;
    new_product_category_id UUID;

    new_phone VARCHAR(20);
    is_exists BOOLEAN;

    new_courier_status buldakov_food.courier_status;
    hire_date DATE;
    dismissal_date DATE;
BEGIN
RAISE NOTICE 'Передано значение: %', p_value;
	if p_value <=0 then
	RAISE EXCEPTION 'Значение должно быть больше нуля';
	end if;
    client_ids := ARRAY[]::UUID[];
    courier_ids := ARRAY[]::UUID[];
    product_category_ids := ARRAY[]::UUID[];

for i in 1..p_value loop
	--Генерация клиента
	--Генерация номера телефона
	loop
		new_phone := '+7' || LPAD(FLOOR(RANDOM() * 1000000000)::text, 10, '0');
		select exists(select 1 from buldakov_food.client where phone_number = new_phone) into is_exists;
		exit when not is_exists;
	end loop;
	--Генерация айдишки для последующей связи с адресами
	new_client_id := exts.uuid_generate_v4();
	client_ids := array_append(client_ids,new_client_id);
	insert into buldakov_food.client values 
	(	new_client_id,
		'client_' || exts.uuid_generate_v4()::text,
		md5(random()::text),
		new_phone
	);
	--Генерация курьера
	loop 
		new_phone := '7' || LPAD(FLOOR(RANDOM() * 1000000000)::text, 10, '0');
		select exists(select 1 from buldakov_food.courier where phone_number = new_phone) into is_exists;
		exit when not is_exists;
	end loop;
	--Статус курьеру выдаем, с проверкой что хотя бы 1 у нас не уволенный
	-- Хотя бы 1 курьер будет работать у нас
	if i = 1 then
		new_courier_status := 'свободен';
		hire_date := CURRENT_DATE-180;
		dismissal_date := NULL;
	else
		new_courier_status :=
		    (enum_range(NULL::buldakov_food.courier_status))
		    [floor(random() * 4 + 1)::INT];
		hire_date := CURRENT_DATE - floor(random()*180)::int;
		--Дата увольнения если он уволенный
		if new_courier_status = 'уволен' then
			dismissal_date := hire_date + floor(random() * (CURRENT_DATE- hire_date +1))::int;
		else dismissal_date := null;
		end if;
	end if;
	
	new_courier_id := exts.uuid_generate_v4();
	courier_ids = array_append(courier_ids, new_courier_id);
	insert into buldakov_food.courier(
		courier_id,
		phone_number,
		status,
		hire_date,
		dismissal_date,
		coefficient,
		last_name,
		first_name,
		middle_name
		) values 
	(	new_courier_id,
		new_phone,
		new_courier_status,
		hire_date,
		dismissal_date,
		0.1,
		'Фамилия_' || left(exts.uuid_generate_v4()::text, 5),
		'Имя' || left(exts.uuid_generate_v4()::text, 5),
		'Отчество' || left(exts.uuid_generate_v4()::text, 5)
	);
	--категории продуктов
	new_product_category_id := exts.uuid_generate_v4();
	product_category_ids :=
            array_append(product_category_ids, new_product_category_id);
	insert into buldakov_food.product_category values (
		new_product_category_id,
		'product_cat_' || exts.uuid_generate_v4()::text
	);
end loop;
end;
$$;


ALTER PROCEDURE buldakov_food.generate_base_data(IN p_value integer, INOUT client_ids uuid[], INOUT courier_ids uuid[], INOUT product_category_ids uuid[]) OWNER TO postgres;

--
-- TOC entry 257 (class 1255 OID 17136)
-- Name: generate_client_addresses(integer, uuid[], uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.generate_client_addresses(IN p_value integer, IN client_ids uuid[], IN client_address_ids uuid[])
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_value <= 0 THEN
        RAISE EXCEPTION 'Количество клиентов должно быть больше нуля';
    END IF;
    FOR i IN 1..p_value LOOP
        FOR j IN 1..4 LOOP
            INSERT INTO buldakov_food.client_address VALUES
            (
                client_ids[i],
                client_address_ids[(i-1)*4+j]
            );
        END LOOP;
    END LOOP;
    RAISE NOTICE 'Было создано: % связей клиента и адреса', p_value * 4;
END;
$$;


ALTER PROCEDURE buldakov_food.generate_client_addresses(IN p_value integer, IN client_ids uuid[], IN client_address_ids uuid[]) OWNER TO postgres;

--
-- TOC entry 267 (class 1255 OID 17142)
-- Name: generate_courier_pay(uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.generate_courier_pay(IN courier_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    current_courier_id UUID;

    current_coefficient NUMERIC;
    new_coefficient NUMERIC;

    current_dismissal_date DATE;
	current_hire_date DATE;
    month_start DATE;
    month_end DATE;

    delivered_orders_count INT;
    total_commission NUMERIC;
    payment_amount NUMERIC;

BEGIN

    -- Перебираем всех созданных курьеров
    FOREACH current_courier_id IN ARRAY courier_ids LOOP

        -- Получаем коэффициент и дату увольнения
        SELECT coefficient, hire_date, dismissal_date
        FROM buldakov_food.courier
        WHERE courier_id = current_courier_id
        INTO current_coefficient, current_hire_date, current_dismissal_date;

        -- Последние 6 месяцев
        FOR i IN 0..5 LOOP

            month_start :=
                (
                    DATE_TRUNC('month', CURRENT_DATE)
                    - (6 - i) * INTERVAL '1 month'
                )::DATE;

            month_end :=
                (month_start + INTERVAL '1 month')::DATE;
			if current_hire_date >= month_end then
				continue;
			end if;
			if current_dismissal_date is not null and current_dismissal_date < month_start
				then
					continue;
			end if;
            -- Количество доставленных заказов и сумма комиссий
            SELECT
                COUNT(*),
                COALESCE(SUM(commission), 0)
            FROM buldakov_food."order"
            WHERE courier_id = current_courier_id
                AND status = 'доставлен'
                AND delivery_timestamp >= month_start
                AND delivery_timestamp < month_end
            INTO delivered_orders_count, total_commission;

            -- Рассчитываем выплату
            payment_amount :=
                ROUND(total_commission * current_coefficient, 2);

            -- Сохраняем выплату
            INSERT INTO buldakov_food.courier_pay VALUES (
                EXTRACT(YEAR FROM month_start)::INT,
                EXTRACT(MONTH FROM month_start)::INT,
                current_courier_id,
                payment_amount,
                current_coefficient
            );

            -- Рассчитываем коэффициент на следующий месяц
            IF delivered_orders_count <= 150 THEN
                new_coefficient := 0.1;

            ELSIF delivered_orders_count <= 250 THEN
                new_coefficient := 0.2;

            ELSIF delivered_orders_count <= 500 THEN
                new_coefficient := 0.3;

            ELSE
                new_coefficient := 0.5;

            END IF;

            -- Обновляем коэффициент, если месяц завершён
            -- и курьер не был уволен в течение этого месяца
            IF month_end <= DATE_TRUNC('month', CURRENT_DATE)::DATE
                AND (
                    current_dismissal_date IS NULL
                    OR current_dismissal_date >= month_end
                )
            THEN

                current_coefficient := new_coefficient;

                UPDATE buldakov_food.courier
                SET coefficient = new_coefficient
                WHERE courier_id = current_courier_id;

            END IF;

        END LOOP;

    END LOOP;

END;
$$;


ALTER PROCEDURE buldakov_food.generate_courier_pay(IN courier_ids uuid[]) OWNER TO postgres;

--
-- TOC entry 256 (class 1255 OID 17143)
-- Name: generate_orders(integer, uuid[], uuid[], uuid[], uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.generate_orders(IN p_value integer, IN client_ids uuid[], IN courier_ids uuid[], IN restaurant_ids uuid[], INOUT order_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_order_id UUID;
    new_order_timestamp TIMESTAMP;
    new_order_client_id UUID;
    new_order_address_id UUID;
    new_order_restaurant_id UUID;
    new_order_courier_id UUID;

    order_product_count INT;
    order_product_ids UUID[];
    product_quantities NUMERIC[];

    new_order_amount NUMERIC;
    new_commission NUMERIC;
    new_total_amount NUMERIC;

    new_product_id UUID;
    new_product_price NUMERIC;
    new_quantity NUMERIC;

    first_product_id UUID;
    first_product_price NUMERIC;
    first_product_quantity NUMERIC;

    new_order_status buldakov_food.order_status;
    new_pay_status buldakov_food.pay_status;
    new_delivery_timestamp TIMESTAMP;

    status_roll INT;
BEGIN
	order_ids := ARRAY[]::UUID[];
    FOR i IN 1..p_value*5 LOOP

        -- Время заказа
        new_order_timestamp :=
            CURRENT_TIMESTAMP - RANDOM() * INTERVAL '180 days';

        -- ID заказа
        new_order_id := exts.uuid_generate_v4();

        -- ID клиента
        new_order_client_id :=
            client_ids[FLOOR(RANDOM()*p_value)::INT+1];

        -- ID адреса
        SELECT address_id
        FROM buldakov_food.client_address
        WHERE client_id = new_order_client_id
        ORDER BY RANDOM()
        LIMIT 1
        INTO new_order_address_id;

        -- ID ресторана
        new_order_restaurant_id :=
            restaurant_ids[FLOOR(RANDOM()*p_value)::INT+1];

        -- Подбор курьера
        SELECT courier_id
        FROM buldakov_food.courier
        WHERE (
            hire_date <= new_order_timestamp::DATE
            AND (
                dismissal_date IS NULL
                OR dismissal_date >= new_order_timestamp::DATE
            )
            AND courier_id = ANY(courier_ids)
        )
        ORDER BY RANDOM()
        LIMIT 1
        INTO new_order_courier_id;

        -- Подбираем товары для заказа
        order_product_count := FLOOR(RANDOM()*5)::INT + 1;

        SELECT ARRAY(
            SELECT product_id
            FROM buldakov_food.product
            WHERE restaurant_id = new_order_restaurant_id
				AND status = 'доступно'
            ORDER BY RANDOM()
            LIMIT order_product_count
        )
        INTO order_product_ids;

        new_order_amount := 0;
        first_product_id := NULL;
        product_quantities := ARRAY[]::NUMERIC[];

        FOREACH new_product_id IN ARRAY order_product_ids LOOP

            SELECT price
            FROM buldakov_food.product
            WHERE product_id = new_product_id
            INTO new_product_price;

            new_quantity := FLOOR(RANDOM() * 3 + 1);

            IF first_product_id IS NULL THEN
                first_product_id := new_product_id;
                first_product_price := new_product_price;
                first_product_quantity := new_quantity;
            END IF;

            product_quantities :=
                ARRAY_APPEND(product_quantities, new_quantity);

            new_order_amount :=
                new_order_amount + new_product_price * new_quantity;

        END LOOP;

        -- Сумма заказа до 1000 рублей
        WHILE new_order_amount < 1000 LOOP

            first_product_quantity := first_product_quantity + 1;

            new_order_amount :=
                new_order_amount + first_product_price;

        END LOOP;

        product_quantities[1] := first_product_quantity;

        -- Комиссия и итоговая сумма
        new_commission := new_order_amount * 0.1;
        new_total_amount := new_order_amount + new_commission;

        -- Статус заказа
        status_roll := FLOOR(RANDOM()*10)::INT + 1;

        IF status_roll <= 6 THEN
            new_order_status := 'доставлен';
            new_pay_status := 'оплачен';

            new_delivery_timestamp := least(
                new_order_timestamp + RANDOM() * INTERVAL '24 hours',
					CURRENT_TIMESTAMP
				);
        ELSIF status_roll = 7 THEN
            new_order_status := 'отменён';
            new_pay_status := 'ошибка';
            new_delivery_timestamp := NULL;

        ELSIF status_roll = 8 THEN
            new_order_status := 'создан';
            new_pay_status := 'ожидает';
            new_delivery_timestamp := NULL;

        ELSIF status_roll = 9 THEN
            new_order_status := 'готовится';
            new_pay_status := 'оплачен';
            new_delivery_timestamp := NULL;

        ELSE
            new_order_status := 'в_доставке';
            new_pay_status := 'ожидает';
            new_delivery_timestamp := NULL;

        END IF;

        -- Создаём заказ
        INSERT INTO buldakov_food."order" VALUES (
            new_order_id,
            new_order_courier_id,
            new_order_client_id,
            new_order_address_id,
            new_order_restaurant_id,
            new_order_timestamp,
            new_delivery_timestamp,
            new_order_amount,
            new_commission,
            new_total_amount,
            new_order_status,
            new_pay_status,
            'Тестовый заказ'
        );
		order_ids := ARRAY_APPEND(order_ids, new_order_id);
        -- Состав заказа
		order_product_count := CARDINALITY(order_product_ids);
        FOR j IN 1..order_product_count LOOP

            INSERT INTO buldakov_food.order_structure VALUES (
                new_order_id,
                order_product_ids[j],
                product_quantities[j]
            );

        END LOOP;

    END LOOP;

END;
$$;


ALTER PROCEDURE buldakov_food.generate_orders(IN p_value integer, IN client_ids uuid[], IN courier_ids uuid[], IN restaurant_ids uuid[], INOUT order_ids uuid[]) OWNER TO postgres;

--
-- TOC entry 262 (class 1255 OID 17141)
-- Name: generate_payments(uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.generate_payments(IN p_order_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    current_order_id UUID;

    new_payment_id UUID;
    new_payment_type buldakov_food.payment_type;
    new_payment_status buldakov_food.payment_status;

    new_payment_amount NUMERIC;
    new_payment_timestamp TIMESTAMP;
    new_transaction_id VARCHAR(255);

    current_order_timestamp TIMESTAMP;
    current_pay_status buldakov_food.pay_status;

BEGIN
    FOREACH current_order_id IN ARRAY p_order_ids LOOP
        -- Данные заказа
        SELECT total_amount, order_timestamp, pay_status
        FROM buldakov_food."order"
        WHERE order_id = current_order_id
        INTO
            new_payment_amount,
            current_order_timestamp,
            current_pay_status;
        -- ID платежа
        new_payment_id := exts.uuid_generate_v4();
        -- Тип платежа
		new_payment_type :=
			    (enum_range(NULL::buldakov_food.payment_type))
			    [floor(random() * 3 + 1)::INT];
        -- Статус платежа
        IF current_pay_status = 'оплачен' THEN
            new_payment_status := 'успех';
        ELSIF current_pay_status = 'ошибка' THEN
            new_payment_status := 'ошибка';
        ELSE
            new_payment_status := 'в_обработке';
        END IF;
        -- Время
        new_payment_timestamp := least(
            current_order_timestamp + RANDOM() * INTERVAL '1 hour',
			CURRENT_TIMESTAMP);
        -- ID транзакции
        new_transaction_id := exts.uuid_generate_v4()::TEXT;
        INSERT INTO buldakov_food.payment VALUES (
            new_payment_id,
            current_order_id,
            new_payment_type,
            new_payment_amount,
            new_transaction_id,
            new_payment_timestamp,
            new_payment_status
        );
    END LOOP;

END;
$$;


ALTER PROCEDURE buldakov_food.generate_payments(IN p_order_ids uuid[]) OWNER TO postgres;

--
-- TOC entry 255 (class 1255 OID 17137)
-- Name: generate_products(integer, uuid[], uuid[], uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.generate_products(IN p_value integer, IN restaurant_ids uuid[], IN product_category_ids uuid[], INOUT product_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_product_id UUID;
    new_product_status buldakov_food.product_status;
BEGIN
    IF p_value <= 0 THEN
        RAISE EXCEPTION 'Количество ресторанов должно быть больше нуля';
    END IF;

    product_ids := ARRAY[]::UUID[];

    FOR i IN 1..p_value LOOP
        FOR j IN 1..5 LOOP
            new_product_id := exts.uuid_generate_v4();
			if j = 1 then
				new_product_status := 'доступно';
			else
				new_product_status :=
			    	(enum_range(NULL::buldakov_food.product_status))
			    	[floor(random() * 3 + 1)::INT];
			end if;
            INSERT INTO buldakov_food.product VALUES (
                new_product_id,
                'Product_' || exts.uuid_generate_v4()::TEXT,
                product_category_ids[
                    FLOOR(RANDOM() * CARDINALITY(product_category_ids) + 1)::INT
                ],
                FLOOR(RANDOM() * 1000 + 1),
                restaurant_ids[i],
                NULL,
                NULL,
                new_product_status,
                'Какое-то описание продукта ' || exts.uuid_generate_v4()::TEXT
            );

            product_ids := ARRAY_APPEND(product_ids, new_product_id);
        END LOOP;
    END LOOP;

    RAISE NOTICE 'Было создано: % продуктов для % ресторанов', p_value * 5, p_value;
END;
$$;


ALTER PROCEDURE buldakov_food.generate_products(IN p_value integer, IN restaurant_ids uuid[], IN product_category_ids uuid[], INOUT product_ids uuid[]) OWNER TO postgres;

--
-- TOC entry 265 (class 1255 OID 17135)
-- Name: generate_restaurants(integer, uuid[], uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.generate_restaurants(IN p_value integer, IN restaurant_address_ids uuid[], INOUT restaurant_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_restaurant_id UUID;
    new_work_start TIME;
    new_work_end TIME;
	new_restaurant_status buldakov_food.restaurant_status;
BEGIN

    IF p_value <= 0 THEN
        RAISE EXCEPTION 'Значение должно быть больше нуля';
    END IF;
    restaurant_ids := ARRAY[]::UUID[];
    -- Создаём рестораны
    FOR i IN 1..p_value LOOP
        --Время открытия
		-- max start = 10:00
        new_work_start :=
            TIME '00:00' +
            FLOOR(RANDOM() * 600)::INT * INTERVAL '1 minute';
        --время закрытия
		--max close = max start + 10hours + 2 hours = 22:00
        new_work_end :=
            new_work_start +
            FLOOR(RANDOM() * 600)::INT * INTERVAL '1 minute' +
            INTERVAL '2 hours';
        new_restaurant_id := exts.uuid_generate_v4();
		new_restaurant_status :=
		    (enum_range(NULL::buldakov_food.restaurant_status))
		    [floor(random() * 2 + 1)::INT];
        INSERT INTO buldakov_food.restaurant(
			restaurant_id,
			restaurant_name,
			address_id,
			description,
			work_start,
			work_end,
			rating,
			status,
			inn,
			ogrn,
			bank_account
			) VALUES (
            new_restaurant_id,
            'restaurant_' || exts.uuid_generate_v4()::TEXT,
            restaurant_address_ids[i],
            'Описание ресторана ' ||
                FLOOR(i * RANDOM() * 1000)::TEXT,
            new_work_start,
            new_work_end,
            NULL,
            new_restaurant_status,
			lpad((FLOOR(RANDOM() * 1000000000000)::bigint)::text,12,'0'), -- 12 значный ИНН
			lpad((FLOOR(RANDOM() * 1000000000000)::bigint)::text,15,'0'), -- 15 значный огрн
			lpad(FLOOR(RANDOM() * 1000000000000)::bigint::text,20,'0') -- 20 значный рассчетный счет
        );
        restaurant_ids := ARRAY_APPEND(
            restaurant_ids,
            new_restaurant_id
        );
    END LOOP;
    RAISE NOTICE 'Было создано: % ресторанов', p_value;
END;
$$;


ALTER PROCEDURE buldakov_food.generate_restaurants(IN p_value integer, IN restaurant_address_ids uuid[], INOUT restaurant_ids uuid[]) OWNER TO postgres;

--
-- TOC entry 253 (class 1255 OID 17146)
-- Name: generate_reviews(uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.generate_reviews(IN p_order_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    i INT;

    new_review_id UUID;
    new_client_id UUID;
    new_order_id UUID;
    new_entity_id UUID;
    new_entity_type buldakov_food.review_entity_type;

    new_review_timestamp TIMESTAMP;
    new_description TEXT;
    new_rating NUMERIC;
BEGIN

    IF p_order_ids IS NULL OR CARDINALITY(p_order_ids) = 0 THEN
        RAISE EXCEPTION 'Массив заказов пуст';
    END IF;

    -- Отзыв = 1 заказ
    for i in 1..CARDINALITY(p_order_ids) LOOP
		loop
			--Забираем то на что у нас ревьюшка
			new_entity_type :=
			    (enum_range(NULL::buldakov_food.review_entity_type))
			    [floor(random() * 3 + 1)::INT];
			-- выбираем заказ персоны
			select order_id,client_id,order_timestamp from buldakov_food."order"
			where order_id = p_order_ids[i]
			order by random()
			limit 1 into new_order_id,new_client_id,new_review_timestamp;
			--теперь смотрим что выпало и в зависимости берем нужную айдишку
	
			if new_entity_type = 'заказ' then
				new_entity_id := new_order_id;
			elsif new_entity_type = 'ресторан' then
				select restaurant_id 
				from buldakov_food."order"
				where order_id = new_order_id into new_entity_id;
			else
				select product_id 
				from buldakov_food.order_structure
				where order_id = new_order_id
				order by random()
				limit 1 into new_entity_id;
			end if; 
			 
			if not exists (
				select 1 from buldakov_food.review
				where order_id = new_order_id
				and entity_type = new_entity_type
				and entity_id = new_entity_id
				) then exit;
			end if;
		end loop;

        -- Генерируем дату отзыва после создания заказа
        new_review_timestamp :=
            new_review_timestamp
            + RANDOM() * (CURRENT_TIMESTAMP - new_review_timestamp);

        new_review_id := exts.uuid_generate_v4();

        new_rating := FLOOR(RANDOM() * 5 + 1);

        new_description := (
            ARRAY[
                'Круто',
                'Все супер',
                'Not bad',
                'can be better',
                'Tasty'
            ]
        )[FLOOR(RANDOM() * 5 + 1)::INT];

        INSERT INTO buldakov_food.review VALUES (
            new_review_id,
            new_client_id,
            new_review_timestamp,
            new_entity_id,
            new_entity_type,
            new_order_id,
            new_description,
            NULL,
            new_rating
        );

    END LOOP;

    RAISE NOTICE 'Создано отзывов: %', CARDINALITY(p_order_ids);

END;
$$;


ALTER PROCEDURE buldakov_food.generate_reviews(IN p_order_ids uuid[]) OWNER TO postgres;

--
-- TOC entry 258 (class 1255 OID 17154)
-- Name: get_statistic(); Type: FUNCTION; Schema: buldakov_food; Owner: postgres
--

CREATE FUNCTION buldakov_food.get_statistic() RETURNS TABLE(restaurant_name character varying, best_product_name character varying, total_amount numeric, avg_amount numeric, best_user character varying)
    LANGUAGE sql
    AS $$
	with delivery_orders as (
		select order_id, restaurant_id, client_id, total_amount
		from buldakov_food."order"
		where status ='доставлен'
	),
	-- Чеки для ресторанов
	restaurant_stats as (
		select 
		restaurant_id, 
		sum(total_amount) as total_amount,
		avg(total_amount) as avg_amount
		from delivery_orders
		group by restaurant_id
	),
	-- Проданные блюда
	product_stats as (
		select d.restaurant_id,
		p.product_id,
		p.product_name,
		sum(os.quantity) as total_quantity
		from delivery_orders d
		join buldakov_food.order_structure os
			on d.order_id = os.order_id
		join buldakov_food.product p
			on os.product_id = p.product_id
		group by d.restaurant_id, p.product_id,p.product_name
		),
	-- Популярное блюдо
	popular_product as (
		select distinct on (restaurant_id)
		restaurant_id,
		product_name as best_product_name
		from product_stats
		order by restaurant_id, total_quantity desc
		),
	-- Заказы клиентоа
	user_stats as (
		select d.restaurant_id,
		c.client_id,
		c.login,
		count(*) as order_count
	 	from delivery_orders d
		join buldakov_food.client c 
			on c.client_id = d.client_id
		group by d.restaurant_id,c.client_id, c.login
	),
	best_user as (
		select distinct on (restaurant_id)
		restaurant_id,
		login as best_user
		from user_stats
		order by restaurant_id, order_count desc
	)
	select r.restaurant_name,
	pp.best_product_name,
	rs.total_amount,
	rs.avg_amount,
	bu.best_user
	from buldakov_food.restaurant r
	left join restaurant_stats rs
		on r.restaurant_id = rs.restaurant_id
	left join popular_product pp
		on r.restaurant_id = pp.restaurant_id
	left join best_user bu
		on r.restaurant_id = bu.restaurant_id
$$;


ALTER FUNCTION buldakov_food.get_statistic() OWNER TO postgres;

--
-- TOC entry 259 (class 1255 OID 17128)
-- Name: insert_test_data(integer); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.insert_test_data(IN value integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    client_ids UUID[];
    courier_ids UUID[];
    product_category_ids UUID[];
    restaurant_address_ids UUID[];
    client_address_ids UUID[];
    restaurant_ids UUID[];
    product_ids UUID[];
	order_ids UUID[];
BEGIN
RAISE NOTICE 'Передано значение: %', value;
	if value <=0 then
	RAISE EXCEPTION 'Значение должно быть больше нуля';
	end if;
--Благодаря рефакторингу кода все внутренний функции по созданию вынесены
--Создаем клиентов, курьеров и категории продуктов
call buldakov_food.generate_base_data(
	value,
	client_ids,
	courier_ids,
	product_category_ids
);
--Создаем адреса
call buldakov_food.generate_addresses(
	value,
	restaurant_address_ids,
	client_address_ids
);
--Создаем рестораны
call buldakov_food.generate_restaurants(
	value,
	restaurant_address_ids,
	restaurant_ids
);
--Ну тут связь адреса и клиента
call buldakov_food.generate_client_addresses(
	value,
	client_ids,
	client_address_ids
);
-- Продукты для ресторанов
call buldakov_food.generate_products(
	value,
	restaurant_ids,
	product_category_ids,
	product_ids
);

-- Делаем заказы и платежка к ним
call buldakov_food.generate_orders(
    value,
    client_ids,
    courier_ids,
    restaurant_ids,
    order_ids
);
call buldakov_food.generate_payments(order_ids);
-- Выплаты курьерам
call buldakov_food.generate_courier_pay(
    courier_ids
);
--Ревьюшка
call buldakov_food.generate_reviews(
    order_ids
);
END;
$$;


ALTER PROCEDURE buldakov_food.insert_test_data(IN value integer) OWNER TO postgres;

--
-- TOC entry 263 (class 1255 OID 17149)
-- Name: rating_change(); Type: FUNCTION; Schema: buldakov_food; Owner: postgres
--

CREATE FUNCTION buldakov_food.rating_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	if TG_OP = 'DELETE' or (
		TG_OP = 'UPDATE'
		and (
			(old.entity_type,old.entity_id)
				is distinct from (new.entity_type,new.entity_id)
				)
			) then
		if old.entity_type = 'блюдо' then
			update buldakov_food.product
				set rating = (
						select avg(r.rating) from buldakov_food.review r
						where r.entity_type = 'блюдо'
						and r.entity_id = OLD.entity_id
						)where product_id = OLD.entity_id;

		elsif old.entity_type = 'ресторан' then
			update buldakov_food.restaurant
				set rating = (
						select avg(r.rating) from buldakov_food.review r
						where r.entity_type = 'ресторан'
						and r.entity_id = OLD.entity_id
						)where restaurant_id = OLD.entity_id;
		end if;
	end if;
	if TG_OP = 'INSERT' or TG_OP = 'UPDATE' then
		if new.entity_type = 'блюдо' then
			update buldakov_food.product
				set rating = (
						select avg(r.rating) from buldakov_food.review r
						where r.entity_type = 'блюдо'
						and r.entity_id = new.entity_id
						)where product_id = new.entity_id;

		elsif new.entity_type = 'ресторан' then
			update buldakov_food.restaurant
				set rating = (
						select avg(r.rating) from buldakov_food.review r
						where r.entity_type = 'ресторан'
						and r.entity_id = new.entity_id
						)where restaurant_id = new.entity_id;
		end if;
	end if;
return null;
END;
$$;


ALTER FUNCTION buldakov_food.rating_change() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 221 (class 1259 OID 16947)
-- Name: address; Type: TABLE; Schema: buldakov_food; Owner: postgres
--

CREATE TABLE buldakov_food.address (
    address_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    street character varying(100) NOT NULL,
    house_number character varying(32) NOT NULL,
    apartment_office character varying(20)
);


ALTER TABLE buldakov_food.address OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 16937)
-- Name: client; Type: TABLE; Schema: buldakov_food; Owner: postgres
--

CREATE TABLE buldakov_food.client (
    client_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    login character varying(100) NOT NULL,
    password character varying(32) NOT NULL,
    phone_number character(12) NOT NULL
);


ALTER TABLE buldakov_food.client OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 16953)
-- Name: client_address; Type: TABLE; Schema: buldakov_food; Owner: postgres
--

CREATE TABLE buldakov_food.client_address (
    client_id uuid NOT NULL,
    address_id uuid NOT NULL
);


ALTER TABLE buldakov_food.client_address OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 16985)
-- Name: courier; Type: TABLE; Schema: buldakov_food; Owner: postgres
--

CREATE TABLE buldakov_food.courier (
    courier_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    phone_number character(11) NOT NULL,
    status buldakov_food.courier_status NOT NULL,
    hire_date date NOT NULL,
    dismissal_date date,
    coefficient numeric(2,1) DEFAULT 0.1 NOT NULL,
    last_name character varying(50) NOT NULL,
    first_name character varying(50) NOT NULL,
    middle_name character varying(50),
    CONSTRAINT courier_check CHECK (((dismissal_date IS NULL) OR (dismissal_date >= hire_date))),
    CONSTRAINT courier_coefficient_check CHECK (((coefficient >= 0.1) AND (coefficient <= 0.5)))
);


ALTER TABLE buldakov_food.courier OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 17056)
-- Name: courier_pay; Type: TABLE; Schema: buldakov_food; Owner: postgres
--

CREATE TABLE buldakov_food.courier_pay (
    year integer NOT NULL,
    month integer NOT NULL,
    courier_id uuid NOT NULL,
    amount numeric(12,2) NOT NULL,
    coefficient_used numeric(2,1) NOT NULL,
    CONSTRAINT courier_pay_amount_check CHECK ((amount >= (0)::numeric)),
    CONSTRAINT courier_pay_coefficient_used_check CHECK (((coefficient_used >= 0.1) AND (coefficient_used <= 0.5))),
    CONSTRAINT courier_pay_month_check CHECK (((month >= 1) AND (month <= 12)))
);


ALTER TABLE buldakov_food.courier_pay OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 17004)
-- Name: order; Type: TABLE; Schema: buldakov_food; Owner: postgres
--

CREATE TABLE buldakov_food."order" (
    order_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    courier_id uuid NOT NULL,
    client_id uuid NOT NULL,
    address_id uuid NOT NULL,
    restaurant_id uuid NOT NULL,
    order_timestamp timestamp without time zone NOT NULL,
    delivery_timestamp timestamp without time zone,
    order_amount numeric(12,2) NOT NULL,
    commission numeric(12,2) NOT NULL,
    total_amount numeric(12,2) NOT NULL,
    status buldakov_food.order_status NOT NULL,
    pay_status buldakov_food.pay_status NOT NULL,
    description text,
    CONSTRAINT order_check CHECK ((delivery_timestamp >= order_timestamp)),
    CONSTRAINT order_check1 CHECK (((commission > (0)::numeric) AND ((order_amount * 0.1) = commission))),
    CONSTRAINT order_check2 CHECK (((total_amount >= (1000)::numeric) AND ((order_amount + commission) = total_amount))),
    CONSTRAINT order_order_amount_check CHECK ((order_amount >= (0)::numeric))
);


ALTER TABLE buldakov_food."order" OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 17105)
-- Name: order_structure; Type: TABLE; Schema: buldakov_food; Owner: postgres
--

CREATE TABLE buldakov_food.order_structure (
    order_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity numeric(10,2) NOT NULL,
    CONSTRAINT order_structure_quantity_check CHECK ((quantity > (0)::numeric))
);


ALTER TABLE buldakov_food.order_structure OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 17092)
-- Name: payment; Type: TABLE; Schema: buldakov_food; Owner: postgres
--

CREATE TABLE buldakov_food.payment (
    payment_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    order_id uuid NOT NULL,
    payment_type buldakov_food.payment_type NOT NULL,
    amount numeric(12,2) NOT NULL,
    transaction_id character varying(255) NOT NULL,
    transaction_timestamp timestamp without time zone NOT NULL,
    status buldakov_food.payment_status NOT NULL
);


ALTER TABLE buldakov_food.payment OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 17036)
-- Name: product; Type: TABLE; Schema: buldakov_food; Owner: postgres
--

CREATE TABLE buldakov_food.product (
    product_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    product_name character varying(100) NOT NULL,
    product_category_id uuid NOT NULL,
    price numeric(12,2) NOT NULL,
    restaurant_id uuid NOT NULL,
    photo_url text,
    rating numeric(2,1),
    status buldakov_food.product_status NOT NULL,
    description text NOT NULL,
    CONSTRAINT product_price_check CHECK ((price >= (0)::numeric)),
    CONSTRAINT product_rating_check CHECK (((rating >= (0)::numeric) AND (rating <= (5)::numeric)))
);


ALTER TABLE buldakov_food.product OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 16998)
-- Name: product_category; Type: TABLE; Schema: buldakov_food; Owner: postgres
--

CREATE TABLE buldakov_food.product_category (
    product_category_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    product_category_name character varying(100) NOT NULL
);


ALTER TABLE buldakov_food.product_category OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 16968)
-- Name: restaurant; Type: TABLE; Schema: buldakov_food; Owner: postgres
--

CREATE TABLE buldakov_food.restaurant (
    restaurant_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    restaurant_name character varying(100) NOT NULL,
    address_id uuid NOT NULL,
    description text NOT NULL,
    work_start time without time zone NOT NULL,
    work_end time without time zone NOT NULL,
    rating numeric(2,1),
    status buldakov_food.restaurant_status NOT NULL,
    inn character varying(12) NOT NULL,
    ogrn character varying(15) NOT NULL,
    bank_account character varying(20) NOT NULL,
    CONSTRAINT restaurant_check CHECK ((work_end > work_start)),
    CONSTRAINT restaurant_rating_check CHECK (((rating >= (0)::numeric) AND (rating <= (5)::numeric)))
);


ALTER TABLE buldakov_food.restaurant OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 17071)
-- Name: review; Type: TABLE; Schema: buldakov_food; Owner: postgres
--

CREATE TABLE buldakov_food.review (
    review_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    client_id uuid NOT NULL,
    review_timestamp timestamp without time zone NOT NULL,
    entity_id uuid NOT NULL,
    entity_type buldakov_food.review_entity_type NOT NULL,
    order_id uuid NOT NULL,
    description text NOT NULL,
    photo_url text,
    rating numeric(2,1) NOT NULL,
    CONSTRAINT review_rating_check CHECK (((rating >= (1)::numeric) AND (rating <= (5)::numeric)))
);


ALTER TABLE buldakov_food.review OWNER TO postgres;

--
-- TOC entry 4960 (class 0 OID 16947)
-- Dependencies: 221
-- Data for Name: address; Type: TABLE DATA; Schema: buldakov_food; Owner: postgres
--

COPY buldakov_food.address (address_id, street, house_number, apartment_office) FROM stdin;
\.


--
-- TOC entry 4959 (class 0 OID 16937)
-- Dependencies: 220
-- Data for Name: client; Type: TABLE DATA; Schema: buldakov_food; Owner: postgres
--

COPY buldakov_food.client (client_id, login, password, phone_number) FROM stdin;
\.


--
-- TOC entry 4961 (class 0 OID 16953)
-- Dependencies: 222
-- Data for Name: client_address; Type: TABLE DATA; Schema: buldakov_food; Owner: postgres
--

COPY buldakov_food.client_address (client_id, address_id) FROM stdin;
\.


--
-- TOC entry 4963 (class 0 OID 16985)
-- Dependencies: 224
-- Data for Name: courier; Type: TABLE DATA; Schema: buldakov_food; Owner: postgres
--

COPY buldakov_food.courier (courier_id, phone_number, status, hire_date, dismissal_date, coefficient, last_name, first_name, middle_name) FROM stdin;
\.


--
-- TOC entry 4967 (class 0 OID 17056)
-- Dependencies: 228
-- Data for Name: courier_pay; Type: TABLE DATA; Schema: buldakov_food; Owner: postgres
--

COPY buldakov_food.courier_pay (year, month, courier_id, amount, coefficient_used) FROM stdin;
\.


--
-- TOC entry 4965 (class 0 OID 17004)
-- Dependencies: 226
-- Data for Name: order; Type: TABLE DATA; Schema: buldakov_food; Owner: postgres
--

COPY buldakov_food."order" (order_id, courier_id, client_id, address_id, restaurant_id, order_timestamp, delivery_timestamp, order_amount, commission, total_amount, status, pay_status, description) FROM stdin;
\.


--
-- TOC entry 4970 (class 0 OID 17105)
-- Dependencies: 231
-- Data for Name: order_structure; Type: TABLE DATA; Schema: buldakov_food; Owner: postgres
--

COPY buldakov_food.order_structure (order_id, product_id, quantity) FROM stdin;
\.


--
-- TOC entry 4969 (class 0 OID 17092)
-- Dependencies: 230
-- Data for Name: payment; Type: TABLE DATA; Schema: buldakov_food; Owner: postgres
--

COPY buldakov_food.payment (payment_id, order_id, payment_type, amount, transaction_id, transaction_timestamp, status) FROM stdin;
\.


--
-- TOC entry 4966 (class 0 OID 17036)
-- Dependencies: 227
-- Data for Name: product; Type: TABLE DATA; Schema: buldakov_food; Owner: postgres
--

COPY buldakov_food.product (product_id, product_name, product_category_id, price, restaurant_id, photo_url, rating, status, description) FROM stdin;
\.


--
-- TOC entry 4964 (class 0 OID 16998)
-- Dependencies: 225
-- Data for Name: product_category; Type: TABLE DATA; Schema: buldakov_food; Owner: postgres
--

COPY buldakov_food.product_category (product_category_id, product_category_name) FROM stdin;
\.


--
-- TOC entry 4962 (class 0 OID 16968)
-- Dependencies: 223
-- Data for Name: restaurant; Type: TABLE DATA; Schema: buldakov_food; Owner: postgres
--

COPY buldakov_food.restaurant (restaurant_id, restaurant_name, address_id, description, work_start, work_end, rating, status, inn, ogrn, bank_account) FROM stdin;
\.


--
-- TOC entry 4968 (class 0 OID 17071)
-- Dependencies: 229
-- Data for Name: review; Type: TABLE DATA; Schema: buldakov_food; Owner: postgres
--

COPY buldakov_food.review (review_id, client_id, review_timestamp, entity_id, entity_type, order_id, description, photo_url, rating) FROM stdin;
\.


--
-- TOC entry 4768 (class 2606 OID 16952)
-- Name: address address_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.address
    ADD CONSTRAINT address_pkey PRIMARY KEY (address_id);


--
-- TOC entry 4770 (class 2606 OID 16957)
-- Name: client_address client_address_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.client_address
    ADD CONSTRAINT client_address_pkey PRIMARY KEY (client_id, address_id);


--
-- TOC entry 4762 (class 2606 OID 16944)
-- Name: client client_login_key; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.client
    ADD CONSTRAINT client_login_key UNIQUE (login);


--
-- TOC entry 4764 (class 2606 OID 17903)
-- Name: client client_phone_number_key; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.client
    ADD CONSTRAINT client_phone_number_key UNIQUE (phone_number);


--
-- TOC entry 4766 (class 2606 OID 16942)
-- Name: client client_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.client
    ADD CONSTRAINT client_pkey PRIMARY KEY (client_id);


--
-- TOC entry 4786 (class 2606 OID 17065)
-- Name: courier_pay courier_pay_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.courier_pay
    ADD CONSTRAINT courier_pay_pkey PRIMARY KEY (year, month, courier_id);


--
-- TOC entry 4776 (class 2606 OID 16997)
-- Name: courier courier_phone_number_key; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.courier
    ADD CONSTRAINT courier_phone_number_key UNIQUE (phone_number);


--
-- TOC entry 4778 (class 2606 OID 16995)
-- Name: courier courier_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.courier
    ADD CONSTRAINT courier_pkey PRIMARY KEY (courier_id);


--
-- TOC entry 4782 (class 2606 OID 17015)
-- Name: order order_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food."order"
    ADD CONSTRAINT order_pkey PRIMARY KEY (order_id);


--
-- TOC entry 4796 (class 2606 OID 17112)
-- Name: order_structure order_structure_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.order_structure
    ADD CONSTRAINT order_structure_pkey PRIMARY KEY (order_id, product_id);


--
-- TOC entry 4792 (class 2606 OID 17097)
-- Name: payment payment_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.payment
    ADD CONSTRAINT payment_pkey PRIMARY KEY (payment_id);


--
-- TOC entry 4794 (class 2606 OID 17099)
-- Name: payment payment_transaction_id_key; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.payment
    ADD CONSTRAINT payment_transaction_id_key UNIQUE (transaction_id);


--
-- TOC entry 4780 (class 2606 OID 17003)
-- Name: product_category product_category_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.product_category
    ADD CONSTRAINT product_category_pkey PRIMARY KEY (product_category_id);


--
-- TOC entry 4784 (class 2606 OID 17045)
-- Name: product product_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.product
    ADD CONSTRAINT product_pkey PRIMARY KEY (product_id);


--
-- TOC entry 4772 (class 2606 OID 16979)
-- Name: restaurant restaurant_address_id_key; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.restaurant
    ADD CONSTRAINT restaurant_address_id_key UNIQUE (address_id);


--
-- TOC entry 4774 (class 2606 OID 16977)
-- Name: restaurant restaurant_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.restaurant
    ADD CONSTRAINT restaurant_pkey PRIMARY KEY (restaurant_id);


--
-- TOC entry 4788 (class 2606 OID 17081)
-- Name: review review_order_id_entity_type_entity_id_key; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.review
    ADD CONSTRAINT review_order_id_entity_type_entity_id_key UNIQUE (order_id, entity_type, entity_id);


--
-- TOC entry 4790 (class 2606 OID 17079)
-- Name: review review_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.review
    ADD CONSTRAINT review_pkey PRIMARY KEY (review_id);


--
-- TOC entry 4813 (class 2620 OID 17150)
-- Name: review review_rating_trigger; Type: TRIGGER; Schema: buldakov_food; Owner: postgres
--

CREATE TRIGGER review_rating_trigger AFTER INSERT OR DELETE OR UPDATE ON buldakov_food.review FOR EACH ROW EXECUTE FUNCTION buldakov_food.rating_change();


--
-- TOC entry 4797 (class 2606 OID 16963)
-- Name: client_address client_address_address_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.client_address
    ADD CONSTRAINT client_address_address_id_fkey FOREIGN KEY (address_id) REFERENCES buldakov_food.address(address_id);


--
-- TOC entry 4798 (class 2606 OID 16958)
-- Name: client_address client_address_client_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.client_address
    ADD CONSTRAINT client_address_client_id_fkey FOREIGN KEY (client_id) REFERENCES buldakov_food.client(client_id);


--
-- TOC entry 4807 (class 2606 OID 17066)
-- Name: courier_pay courier_pay_courier_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.courier_pay
    ADD CONSTRAINT courier_pay_courier_id_fkey FOREIGN KEY (courier_id) REFERENCES buldakov_food.courier(courier_id);


--
-- TOC entry 4800 (class 2606 OID 17026)
-- Name: order order_address_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food."order"
    ADD CONSTRAINT order_address_id_fkey FOREIGN KEY (address_id) REFERENCES buldakov_food.address(address_id);


--
-- TOC entry 4801 (class 2606 OID 17123)
-- Name: order order_client_address_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food."order"
    ADD CONSTRAINT order_client_address_fkey FOREIGN KEY (client_id, address_id) REFERENCES buldakov_food.client_address(client_id, address_id);


--
-- TOC entry 4802 (class 2606 OID 17021)
-- Name: order order_client_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food."order"
    ADD CONSTRAINT order_client_id_fkey FOREIGN KEY (client_id) REFERENCES buldakov_food.client(client_id);


--
-- TOC entry 4803 (class 2606 OID 17016)
-- Name: order order_courier_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food."order"
    ADD CONSTRAINT order_courier_id_fkey FOREIGN KEY (courier_id) REFERENCES buldakov_food.courier(courier_id);


--
-- TOC entry 4804 (class 2606 OID 17031)
-- Name: order order_restaurant_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food."order"
    ADD CONSTRAINT order_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES buldakov_food.restaurant(restaurant_id);


--
-- TOC entry 4811 (class 2606 OID 17113)
-- Name: order_structure order_structure_order_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.order_structure
    ADD CONSTRAINT order_structure_order_id_fkey FOREIGN KEY (order_id) REFERENCES buldakov_food."order"(order_id);


--
-- TOC entry 4812 (class 2606 OID 17118)
-- Name: order_structure order_structure_product_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.order_structure
    ADD CONSTRAINT order_structure_product_id_fkey FOREIGN KEY (product_id) REFERENCES buldakov_food.product(product_id);


--
-- TOC entry 4810 (class 2606 OID 17100)
-- Name: payment payment_order_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.payment
    ADD CONSTRAINT payment_order_id_fkey FOREIGN KEY (order_id) REFERENCES buldakov_food."order"(order_id);


--
-- TOC entry 4805 (class 2606 OID 17046)
-- Name: product product_product_category_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.product
    ADD CONSTRAINT product_product_category_id_fkey FOREIGN KEY (product_category_id) REFERENCES buldakov_food.product_category(product_category_id);


--
-- TOC entry 4806 (class 2606 OID 17051)
-- Name: product product_restaurant_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.product
    ADD CONSTRAINT product_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES buldakov_food.restaurant(restaurant_id);


--
-- TOC entry 4799 (class 2606 OID 16980)
-- Name: restaurant restaurant_address_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.restaurant
    ADD CONSTRAINT restaurant_address_id_fkey FOREIGN KEY (address_id) REFERENCES buldakov_food.address(address_id);


--
-- TOC entry 4808 (class 2606 OID 17082)
-- Name: review review_client_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.review
    ADD CONSTRAINT review_client_id_fkey FOREIGN KEY (client_id) REFERENCES buldakov_food.client(client_id);


--
-- TOC entry 4809 (class 2606 OID 17087)
-- Name: review review_order_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.review
    ADD CONSTRAINT review_order_id_fkey FOREIGN KEY (order_id) REFERENCES buldakov_food."order"(order_id);


--
-- TOC entry 4976 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA buldakov_food; Type: ACL; Schema: -; Owner: postgres
--

GRANT ALL ON SCHEMA buldakov_food TO inspector;


--
-- TOC entry 4977 (class 0 OID 0)
-- Dependencies: 261
-- Name: PROCEDURE add_product(IN product_name character varying, IN product_category_id uuid, IN price numeric, IN restaurant_id uuid, IN photo_url text, IN rating numeric, IN status buldakov_food.product_status, IN description text); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.add_product(IN product_name character varying, IN product_category_id uuid, IN price numeric, IN restaurant_id uuid, IN photo_url text, IN rating numeric, IN status buldakov_food.product_status, IN description text) TO inspector;


--
-- TOC entry 4978 (class 0 OID 0)
-- Dependencies: 264
-- Name: PROCEDURE courier_salary(); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.courier_salary() TO inspector;


--
-- TOC entry 4979 (class 0 OID 0)
-- Dependencies: 260
-- Name: PROCEDURE erase_test_data(); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.erase_test_data() TO inspector;


--
-- TOC entry 4980 (class 0 OID 0)
-- Dependencies: 254
-- Name: PROCEDURE generate_addresses(IN p_value integer, INOUT restaurant_address_ids uuid[], INOUT client_address_ids uuid[]); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.generate_addresses(IN p_value integer, INOUT restaurant_address_ids uuid[], INOUT client_address_ids uuid[]) TO inspector;


--
-- TOC entry 4981 (class 0 OID 0)
-- Dependencies: 266
-- Name: PROCEDURE generate_base_data(IN p_value integer, INOUT client_ids uuid[], INOUT courier_ids uuid[], INOUT product_category_ids uuid[]); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.generate_base_data(IN p_value integer, INOUT client_ids uuid[], INOUT courier_ids uuid[], INOUT product_category_ids uuid[]) TO inspector;


--
-- TOC entry 4982 (class 0 OID 0)
-- Dependencies: 257
-- Name: PROCEDURE generate_client_addresses(IN p_value integer, IN client_ids uuid[], IN client_address_ids uuid[]); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.generate_client_addresses(IN p_value integer, IN client_ids uuid[], IN client_address_ids uuid[]) TO inspector;


--
-- TOC entry 4983 (class 0 OID 0)
-- Dependencies: 267
-- Name: PROCEDURE generate_courier_pay(IN courier_ids uuid[]); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.generate_courier_pay(IN courier_ids uuid[]) TO inspector;


--
-- TOC entry 4984 (class 0 OID 0)
-- Dependencies: 256
-- Name: PROCEDURE generate_orders(IN p_value integer, IN client_ids uuid[], IN courier_ids uuid[], IN restaurant_ids uuid[], INOUT order_ids uuid[]); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.generate_orders(IN p_value integer, IN client_ids uuid[], IN courier_ids uuid[], IN restaurant_ids uuid[], INOUT order_ids uuid[]) TO inspector;


--
-- TOC entry 4985 (class 0 OID 0)
-- Dependencies: 262
-- Name: PROCEDURE generate_payments(IN p_order_ids uuid[]); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.generate_payments(IN p_order_ids uuid[]) TO inspector;


--
-- TOC entry 4986 (class 0 OID 0)
-- Dependencies: 255
-- Name: PROCEDURE generate_products(IN p_value integer, IN restaurant_ids uuid[], IN product_category_ids uuid[], INOUT product_ids uuid[]); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.generate_products(IN p_value integer, IN restaurant_ids uuid[], IN product_category_ids uuid[], INOUT product_ids uuid[]) TO inspector;


--
-- TOC entry 4987 (class 0 OID 0)
-- Dependencies: 265
-- Name: PROCEDURE generate_restaurants(IN p_value integer, IN restaurant_address_ids uuid[], INOUT restaurant_ids uuid[]); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.generate_restaurants(IN p_value integer, IN restaurant_address_ids uuid[], INOUT restaurant_ids uuid[]) TO inspector;


--
-- TOC entry 4988 (class 0 OID 0)
-- Dependencies: 253
-- Name: PROCEDURE generate_reviews(IN p_order_ids uuid[]); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.generate_reviews(IN p_order_ids uuid[]) TO inspector;


--
-- TOC entry 4989 (class 0 OID 0)
-- Dependencies: 258
-- Name: FUNCTION get_statistic(); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON FUNCTION buldakov_food.get_statistic() TO inspector;


--
-- TOC entry 4990 (class 0 OID 0)
-- Dependencies: 259
-- Name: PROCEDURE insert_test_data(IN value integer); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.insert_test_data(IN value integer) TO inspector;


--
-- TOC entry 4991 (class 0 OID 0)
-- Dependencies: 263
-- Name: FUNCTION rating_change(); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON FUNCTION buldakov_food.rating_change() TO inspector;


--
-- TOC entry 4992 (class 0 OID 0)
-- Dependencies: 221
-- Name: TABLE address; Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON TABLE buldakov_food.address TO inspector;


--
-- TOC entry 4993 (class 0 OID 0)
-- Dependencies: 220
-- Name: TABLE client; Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON TABLE buldakov_food.client TO inspector;


--
-- TOC entry 4994 (class 0 OID 0)
-- Dependencies: 222
-- Name: TABLE client_address; Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON TABLE buldakov_food.client_address TO inspector;


--
-- TOC entry 4995 (class 0 OID 0)
-- Dependencies: 224
-- Name: TABLE courier; Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON TABLE buldakov_food.courier TO inspector;


--
-- TOC entry 4996 (class 0 OID 0)
-- Dependencies: 228
-- Name: TABLE courier_pay; Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON TABLE buldakov_food.courier_pay TO inspector;


--
-- TOC entry 4997 (class 0 OID 0)
-- Dependencies: 226
-- Name: TABLE "order"; Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON TABLE buldakov_food."order" TO inspector;


--
-- TOC entry 4998 (class 0 OID 0)
-- Dependencies: 231
-- Name: TABLE order_structure; Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON TABLE buldakov_food.order_structure TO inspector;


--
-- TOC entry 4999 (class 0 OID 0)
-- Dependencies: 230
-- Name: TABLE payment; Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON TABLE buldakov_food.payment TO inspector;


--
-- TOC entry 5000 (class 0 OID 0)
-- Dependencies: 227
-- Name: TABLE product; Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON TABLE buldakov_food.product TO inspector;


--
-- TOC entry 5001 (class 0 OID 0)
-- Dependencies: 225
-- Name: TABLE product_category; Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON TABLE buldakov_food.product_category TO inspector;


--
-- TOC entry 5002 (class 0 OID 0)
-- Dependencies: 223
-- Name: TABLE restaurant; Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON TABLE buldakov_food.restaurant TO inspector;


--
-- TOC entry 5003 (class 0 OID 0)
-- Dependencies: 229
-- Name: TABLE review; Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON TABLE buldakov_food.review TO inspector;


-- Completed on 2026-11-15 16:49:44

--
-- PostgreSQL database dump complete
--

