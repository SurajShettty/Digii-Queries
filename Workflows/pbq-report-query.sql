SELECT
    sf.id student_fee_id, 
    sf.ukid, ua.registration_id, 
    p1.programme_name old_prog, 
    fs.batch_year old_batch, 
    fs.sequence, 
    p2.programme_name new_prog, 
    sp.year_of_joining new_batch
FROM 
    user_attributes ua 
    LEFT JOIN student_fee_v2 sf ON ua.ukid = sf.ukid 
    LEFT JOIN fee_structure fs ON fs.id = sf.fee_structure_id
    LEFT JOIN fee_programme_batch fpb ON fpb.id = fs.fee_programme_batch_id
    LEFT JOIN programme p1 ON p1.programme_id = fs.programme_id 
    LEFT JOIN student_profile sp ON sp.ukid = sf.ukid 
    LEFT JOIN programme p2 ON sp.programme_id = p2.programme_id;