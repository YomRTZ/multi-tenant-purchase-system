import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
);
if (!customerId || !productId || quantity <= 0) {
  throw new Error('Invalid purchase parameters');
}
export async function purchaseOnCredit(customerId, productId, quantity) {
  const { data, error } = await supabase.rpc('purchase_on_credit', {
    p_customer_id: customerId,
    p_product_id: productId,
    p_quantity: quantity
  });

  if (error) throw new Error(error.message);
  return data;
}
