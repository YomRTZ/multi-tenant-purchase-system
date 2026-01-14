# Multi-Tenant Purchase-on-Credit System

This document explains the architecture, safety mechanisms, and business logic for a multi-tenant purchase-on-credit system built on Supabase (PostgreSQL) and Next.js.

---

## Core Problem (Business View)

A single customer purchase on credit must:

1. Reduce product stock  
2. Increase customer credit / debt  
3. Create an order record  
4. Log credit/ledger transactions  
5. Work safely under **concurrent requests**  
6. Ensure **multi-tenant isolation** — one business cannot affect another business’s data

---

## Architecture Overview

**Frontend:** Next.js (calls Supabase RPC functions)  
**Backend:** Supabase + PostgreSQL (RPC functions with transactions)  

**Purchase Flow:**

Client (Next.js)
   ↓
Supabase RPC function
   ↓
BEGIN TRANSACTION
   ↓
Lock product row
Lock customer row
   ↓
Validate stock
Validate credit limit
   ↓
Update stock
Update customer credit
Insert order
Insert order_items
Insert credit ledger
   ↓
COMMIT(success)
If anything fails → ROLLBACK
---

## Key Concepts

### Row Locking
- Ensures only **one transaction modifies a product or customer at a time**  
- this ensure purchase is applied without leaving inconsistent data
- Prevents negative stock or exceeding credit limits under concurrent requests  

### Transactions (Atomic)
- Either **all steps succeed** or **all are rolled back**  
- Guarantees data consistency: no partial updates  

### Credit Safety
- Credit check happens **inside the lock**  
- Prevents race conditions  
- Customer credit cannot exceed credit limit  

###  Multi-Tenant Data Isolation
- Each row has `business_id`  
- **RLS (Row-Level Security)** ensures one business cannot access another business’s data  

---

## Validation Layers 

| Layer                            | Responsibility                                                             |
|----------------------------------|----------------------------------------------------------------------------|
| Frontend                         | UX validation (quantity > 0, forms, etc.)                                  |
| API / RPC                        | Business rules (stock check, credit check)                                 |
| Database Constraints             | Hard safety (`CHECK (stock_quantity >= 0)`, `CHECK (current_credit >= 0)`) |
| RLS                              | Tenant isolation (ensure business A cannot see/write business B data)      |

---

## Database Constraints (Example)

```sql
ALTER TABLE products ADD CONSTRAINT chk_stock CHECK (stock_quantity >= 0);
ALTER TABLE customers ADD CONSTRAINT chk_credit CHECK (current_credit >= 0);

### Indexes for performance
CREATE INDEX idx_products_business ON products(business_id);
CREATE INDEX idx_customers_business ON customers(business_id);

### Prevent accidental deletes of financial data
REVOKE DELETE ON credit_transactions FROM authenticated;
# Multi-Tenant Purchase-on-Credit System — Concurrency & Safety



---

## Concurrency Example

When **two simultaneous purchase requests** occur:

| Request | Action                         | Outcome                       |
|---------|--------------------------------|-------------------------------|
| 1       | Locks product & customer rows  | Validates stock & credit      |
| 2       | Waits until 1 finishes         | Then validates stock & credit |

**Result:**
- Stock never goes negative  
- Credit limit never exceeded  

**Mechanism:** PostgreSQL `FOR UPDATE` row locking ensures only one transaction can modify a product or customer at a time.  

---

##  Multi-Tenant Safety

- Each **user → profile → business_id**  
- Every table row includes a `business_id`  
- All RPC functions filter by `business_id`  
- **RLS (Row-Level Security)** prevents cross-tenant access  
- Users can only act **within their business context**  

**Example:**  
A user from Business A cannot purchase products, view customers, or modify orders belonging to Business B.

---

##  Atomic Transactions 

- Purchases are **all-or-nothing**  
- Steps inside `BEGIN … COMMIT` transaction:
  1. Lock product & customer rows  
  2. Validate stock & credit  
  3. Insert order & order_items  
  4. Update stock & customer credit  
  5. Log credit ledger  

**If any step fails → ROLLBACK:**  
- No stock change  
- No credit change  
- No order created  

**Mechanism:** PostgreSQL transactions ensure **data consistency and integrity** under concurrent requests.

---


