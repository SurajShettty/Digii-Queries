-- Structure Course Report
-- Lists the latest default version of every course with its department, total credits,
-- and a per-component credit breakdown (e.g. Lecture/Tutorial/Practical via course_component_type).
-- The subquery limits results to the most recent default version of each course.
select cv.id,c.course_id as course_id,c.course_code,cv.version,cv.course_name,cv.course_credits as total_course_credits,d.department_name,cct.name,cc.course_credits as component_credits from course_version cv  left join course c on cv.course_id = c.course_id left join course_component cc on cc.course_version_id = cv.id left join course_component_type cct on cct.id = cc.course_component_type_id left join department d on d.department_id = c.department_id where cv.id in
(select max(id) from course_version where is_default = 1 group by course_id)
order by c.course_id;

-- programme_section:
-- Lists all programme sections with their batch year, owning programme, default flag,
-- and the department the programme belongs to.
select programme_section_id,programme_section_name,batch_year,p.programme_name,is_default,d.department_name from programme_section ps left join programme p on p.programme_id = ps.programme_id left join department d on d.department_id = p.department_id;

-- programme_specialisation:
-- Maps each programme to its specialisations, showing when the specialisation starts,
-- its type and CGPA/SGPA rule, plus both the programme's department and the
-- specialisation's department. Excludes soft-deleted mappings and specialisations.
select p.programme_name,ps.name as specialisation_name,starts_from,specialisation_type,cgpa_sgpa_rule,d.department_name as programme_department,d2.department_name as specialisation_department from programme_specialisation_mapping psm left join specialisation ps on ps.id = psm.specialisation_id left join programme p on p.programme_id = psm.programme_id left join department d on d.department_id = p.department_id left join department d2 on d2.department_id = ps.department_id where psm.is_deleted = 0 and ps.is_deleted = 0;

-- programme_intake
-- Lists programme batch intakes with their intake name, programme, batch year, department,
-- and the intake's duration window (duration_from / duration_to).
select pbi.name as intake_name,p.programme_name,pbi.batch_year,d.department_name,pbi.duration_from,pbi.duration_to from programme_batch_intake pbi left join programme p on p.programme_id = pbi.programme_id left join department d on d.department_id = p.department_id;

-- programme_dept mapping
-- Lists active programmes with their code, name, owning department, duration, start year,
-- credit system, programme type, and academic system. Excludes soft-deleted programmes.
select programme_code,programme_name,department_name,duration,year_of_start,credit_system,pt.name as programme_type,p.system from programme p left join department d on d.department_id = p.department_id left join programme_types pt on pt.id = p.programme_type_id where is_deleted = 0;

-- Returns all columns for every row in the programme table (raw dump for inspection).
select * from programme;

-- Institution Calendar Report
-- Lists all institution calendar events with their name, the event-type code, a decoded
-- label, and the event's date range (date_start to date_end), ordered chronologically.
-- NOTE: only event_type = 6 (HOLIDAY) is confirmed from existing reports; the other
-- CASE labels are placeholders — verify the full event_type code list against the live
-- schema (e.g. the calendar event-type lookup table) before relying on them.
select
    cal.id            as calendar_id,
    cal.name          as event_name,
    cal.event_type    as event_type_code,
    case cal.event_type
        when 6 then 'HOLIDAY'
        else concat('TYPE_', cal.event_type)
    end               as event_type,
    cal.date_start,
    cal.date_end,
    datediff(cal.date_end, cal.date_start) + 1 as duration_days
from calendar cal
order by cal.date_start, cal.id;