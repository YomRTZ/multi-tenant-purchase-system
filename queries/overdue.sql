SELECT
  c.id AS customer_id,
  c.name,
  SUM(CASE WHEN ct.type='debit' THEN ct.amount ELSE -ct.amount END) AS unpaid_balance,
  MIN(ct.created_at) AS oldest_unpaid_date
FROM customers c
JOIN credit_transactions ct ON ct.customer_id = c.id
WHERE ct.business_id = (SELECT business_id FROM profiles WHERE id = auth.uid())
GROUP BY c.id, c.name
HAVING SUM(CASE WHEN ct.type='debit' THEN ct.amount ELSE -ct.amount END) > 0
   AND MIN(ct.created_at) <= NOW() - INTERVAL '30 days';
