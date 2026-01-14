CREATE OR REPLACE FUNCTION purchase_on_credit(
  p_customer_id UUID,
  p_product_id UUID,
  p_quantity INT
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
  v_business_id UUID;
  v_stock INT;
  v_price NUMERIC;
  v_credit NUMERIC;
  v_limit NUMERIC;
  v_order_id UUID;
BEGIN
  -- Get business
  SELECT business_id INTO v_business_id
  FROM profiles
  WHERE id = auth.uid();

  -- Lock product
  SELECT stock_quantity, price
  INTO v_stock, v_price
  FROM products
  WHERE id = p_product_id
    AND business_id = v_business_id
  FOR UPDATE;

  IF v_stock < p_quantity THEN
    RAISE EXCEPTION 'Insufficient stock';
  END IF;

  -- Lock customer
  SELECT current_credit, credit_limit
  INTO v_credit, v_limit
  FROM customers
  WHERE id = p_customer_id
    AND business_id = v_business_id
  FOR UPDATE;

  IF v_credit + (v_price * p_quantity) > v_limit THEN
    RAISE EXCEPTION 'Credit limit exceeded';
  END IF;

  -- Create order
  INSERT INTO orders (business_id, customer_id, total_amount)
  VALUES (v_business_id, p_customer_id, v_price * p_quantity)
  RETURNING id INTO v_order_id;

  -- Order item
  INSERT INTO order_items (order_id, product_id, quantity, price)
  VALUES (v_order_id, p_product_id, p_quantity, v_price);

  -- Update stock
  UPDATE products
  SET stock_quantity = stock_quantity - p_quantity
  WHERE id = p_product_id;

  -- Update credit
  UPDATE customers
  SET current_credit = current_credit + (v_price * p_quantity)
  WHERE id = p_customer_id;

  -- Ledger
  INSERT INTO credit_transactions (
    business_id, customer_id, amount, type, reference
  )
  VALUES (
    v_business_id,
    p_customer_id,
    v_price * p_quantity,
    'debit',
    v_order_id
  );

  RETURN v_order_id;
END;
$$;
