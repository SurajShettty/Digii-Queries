-- Structure Course Report
select cv.id,c.course_id as course_id,c.course_code,cv.version,cv.course_name,cv.course_credits as total_course_credits,d.department_name,cct.name,cc.course_credits as component_credits from course_version cv  left join course c on cv.course_id = c.course_id left join course_component cc on cc.course_version_id = cv.id left join course_component_type cct on cct.id = cc.course_component_type_id left join department d on d.department_id = c.department_id where cv.id in
(select max(id) from course_version where is_default = 1 group by course_id)
order by c.course_id;

-- programme_section:
select programme_section_id,programme_section_name,batch_year,p.programme_name,is_default,d.department_name from programme_section ps left join programme p on p.programme_id = ps.programme_id left join department d on d.department_id = p.department_id;

-- programme_specialisation:
select p.programme_name,ps.name as specialisation_name,starts_from,specialisation_type,cgpa_sgpa_rule,d.department_name as programme_department,d2.department_name as specialisation_department from programme_specialisation_mapping psm left join specialisation ps on ps.id = psm.specialisation_id left join programme p on p.programme_id = psm.programme_id left join department d on d.department_id = p.department_id left join department d2 on d2.department_id = ps.department_id where psm.is_deleted = 0 and ps.is_deleted = 0;

-- programme_intake
select pbi.name as intake_name,p.programme_name,pbi,batch_year,d.department_name,pbi.duration_from,pbi,duration_to from programme_batch_intake pbi left join programme p on p.programme_id = pbi.programme_id left join department d on d.department_id = p.department_id;

-- programme_dept mapping
select programme_code,programme_name,department_name,duration,year_of_start,credit_system,pt.name as programme_type,p.system from programme p left join department d on d.department_id = p.department_id left join programme_types pt on pt.id = p.programme_type_id where is_deleted = 0;
select * from programme