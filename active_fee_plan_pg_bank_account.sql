-- Active fee plans with their payment gateway codes and income bank account
-- fee_plan.payment_gateway_id is unused; PG comes from payment_gateway_mapping,
-- bank account from accounting_module_default_account_mapping -> accounting_account
SELECT
    fp.name AS 'Fee Plan Name',
    fp.code AS 'Fee Plan Code',
    GROUP_CONCAT(DISTINCT pg.code ORDER BY pg.code SEPARATOR ', ') AS 'PG Code',
    GROUP_CONCAT(DISTINCT COALESCE(aa.display_name, aa.account_name) SEPARATOR ', ') AS 'Bank Account'
FROM fee_plan fp
LEFT JOIN payment_gateway_mapping pgm
    ON pgm.entity = 'fee_plan' AND pgm.entity_id = fp.id AND pgm.is_active = 1
LEFT JOIN payment_gateway pg ON pg.id = pgm.payment_gateway_id
LEFT JOIN accounting_module_default_account_mapping am
    ON am.module = 'academic_fee' AND am.entity = 'fee_plan_id' AND am.entity_id = fp.id
    AND am.transaction_type = 'INCOME' AND am.is_active = 1
LEFT JOIN accounting_account aa ON aa.id = am.account_id
WHERE fp.status = 'ACTIVE'
GROUP BY fp.id, fp.name, fp.code
ORDER BY fp.name;
