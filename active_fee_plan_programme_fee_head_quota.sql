-- Active fee plans by programme, installment sequence, fee head and quota
-- Programme + sequence + academic year come from fee_structure; fee heads + quotas + amount from fee_plan_structure
SELECT DISTINCT
    p.programme_name AS 'Programme Name',
    p.programme_code AS 'Programme Code',
    fp.name AS 'Fee Plan Name',
    fp.code AS 'Fee Plan Code',
    DATE(fp.created_timestamp) AS 'Fee Plan Created On',
    fs.academic_year AS 'Academic Year',
    fs.sequence AS 'Sequence',
    ft.name AS 'Fee Head Name',
    q.name AS 'Quota',
    fps.amount AS 'Amount'
FROM fee_plan fp
JOIN fee_structure fs ON fs.fee_plan_id = fp.id
JOIN programme p ON p.programme_id = fs.programme_id
JOIN fee_plan_structure fps ON fps.fee_plan_id = fp.id
JOIN fee_type ft ON ft.id = fps.fee_type_id
LEFT JOIN quota q ON q.id = fps.quota_id
WHERE fp.status = 'ACTIVE'
ORDER BY p.programme_name, fp.name, fs.academic_year, fs.sequence, ft.name, q.name;
