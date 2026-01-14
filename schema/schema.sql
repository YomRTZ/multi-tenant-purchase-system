CREATE TABLE businesses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT now()
);
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  business_id UUID REFERENCES businesses(id),
  role TEXT DEFAULT 'owner',
  created_at TIMESTAMP DEFAULT now()
);
CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses(id),
  name TEXT NOT NULL,
  credit_limit NUMERIC NOT NULL DEFAULT 0,
  current_credit NUMERIC NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT now(),

  CHECK (credit_limit >= 0),
  CHECK (current_credit >= 0)
);
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses(id),
  name TEXT NOT NULL,
  price NUMERIC NOT NULL,
  stock_quantity INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT now(),

  CHECK (price >= 0),
  CHECK (stock_quantity >= 0)
);
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses(id),
  customer_id UUID NOT NULL REFERENCES customers(id),
  total_amount NUMERIC NOT NULL,
  status TEXT DEFAULT 'completed',
  created_at TIMESTAMP DEFAULT now()
);
CREATE TABLE order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id),
  quantity INT NOT NULL,
  price NUMERIC NOT NULL,

  CHECK (quantity > 0),
  CHECK (price >= 0)
);
CREATE TABLE credit_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses(id),
  customer_id UUID NOT NULL REFERENCES customers(id),
  amount NUMERIC NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('debit', 'credit')),
  reference UUID,
  created_at TIMESTAMP DEFAULT now()
);
--Indexes
CREATE INDEX idx_products_business ON products(business_id);
CREATE INDEX idx_customers_business ON customers(business_id);

-- enable row level security(RLS)
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE credit_transactions ENABLE ROW LEVEL SECURITY;
-- RLS Policy (Business Isolation)
CREATE POLICY "customers_isolation"
ON customers
FOR ALL
USING (
  business_id = (
    SELECT business_id FROM profiles WHERE id = auth.uid()
  )
);
CREATE POLICY "products_isolation"
ON products
FOR ALL
USING (
  business_id = (
    SELECT business_id FROM profiles WHERE id = auth.uid()
  )
);
CREATE POLICY "orders_isolation"
ON orders
FOR ALL
USING (
  business_id = (
    SELECT business_id FROM profiles WHERE id = auth.uid()
  )
);
CREATE POLICY "credit_transactions_isolation"
ON credit_transactions
FOR ALL
USING (
  business_id = (
    SELECT business_id FROM profiles WHERE id = auth.uid()
  )
);
-- Prevent deletes
REVOKE DELETE ON credit_transactions FROM authenticated;

