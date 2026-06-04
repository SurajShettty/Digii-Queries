-- Important Queries — cleaned report query library

-- Module: Staff Attendance — Monthly staff biometric attendance
-- Per-staff punch-in/punch-out times, working hours and status for a given month from biometric punch logs.
select sa.id, sa.ukid, concat(ua.f_name," ",ua.l_name), ua.registration_id ,attendance_for_date, coalesce(min(time(punched_timestamp)),'-') as Punch_in, coalesce(max(time(punched_timestamp)),'-') as Punch_out, coalesce(timediff(max(punched_timestamp),min(punched_timestamp)),'-') as Working_hours, coalesce(sas.status, '-') as Status
from staff_attendance sa
left join biometric_punch_log bpl on sa.ukid = bpl.ukid and sa.attendance_for_date = date(bpl.punched_timestamp)
left join staff_attendance_status sas on sa.status_id = sas.id
left join user_attributes ua on sa.ukid = ua.ukid
where month(attendance_for_date) = 5 group by ukid, attendance_for_date;

-- Module: Fee Management — Fee paid and dues (RIMT)
-- Latest active fee record per student with applicable fee, scholarship, waiver, penalty, paid and pending amounts for selected departments.

SELECT LOWER(CONCAT(t3.f_name, t3.m_name, ' ', t3.l_name)) AS "Student Name",
    t3.registration_id AS "Registration ID",
    t3.ukid,
    t5.programme_name AS "Programme Name",
    t2.year_of_joining AS "Batch Year",
    t7.sequence,
   t4.name AS "Quota Name",
   t8.name AS "Fee Plan Name",
    t1.applicable_fee AS "Applicable Fee",
    SUM(t6.scholarship) AS "scholarship",
    SUM(t6.waiver) AS "waiver",
    t1.carry_over,
    t1.penalty_amount AS "Penalty Amount",
    t1.initial_amount,
    t1.amount_paid AS "Paid Till Now",
    t1.amount_due AS Pending,
    t1.total_amount,
    t1.is_active,
    t9.latest_fee,
   t1.id
FROM student_fee t1
    LEFT JOIN student_profile t2 ON t1.ukid = t2.ukid
    LEFT JOIN user_attributes t3 ON t1.ukid = t3.ukid
    LEFT JOIN quota t4 ON t2.quota_id = t4.id
    LEFT JOIN programme t5 ON t2.programme_id = t5.programme_id
    LEFT JOIN student_fee_component t6 ON t1.id = t6.student_fee_id
    LEFT JOIN fee_structure t7 ON t7.id = t1.fee_structure_id
    LEFT JOIN fee_plan t8 ON t8.id = t7.fee_plan_id
    left join (
        select sf.ukid,
            max(sf.id) as latest_fee
        from student_fee sf
            left join fee_structure fs on fs.id = sf.fee_structure_id
            where sf.is_active = 0
    AND sf.invalidated = 0
        group by sf.ukid) as t9 on t9.ukid = t1.ukid
        where t9.latest_fee = t1.id
    and t1.is_active = 0
    AND invalidated = 0
    AND t2.department_id IN (92, 93, 94, 96, 98, 99, 100)
GROUP BY LOWER(CONCAT(t3.f_name, t3.m_name, ' ', t3.l_name)),
    t3.registration_id,
    t3.ukid,
    t5.programme_name,
    t2.year_of_joining,
    t7.sequence,
    t4.name,
    t8.name,
    t1.applicable_fee,
    t1.penalty_amount,
    t1.initial_amount,
    t1.amount_paid,
    t1.amount_due,
    t1.total_amount,
    t1.is_active,
    t1.id,
    t1.fee_structure_id,
    t1.carry_over,
        t9.latest_fee

-- Module: CHC (Campus Help Centre) — Service request field values
-- Form field values submitted for CHC service requests, resolving dropdown options to their labels (service id 8).

select ua.ukid, ua.registration_id, concat(f_name," ",m_name," ", l_name) as "userName", request_id as "Request ID",
cs.title as "Service Name",crff.name as "Field Name",
if(crff.element = 'dropdown', crffe.label, crfv.value) as "Field Value" FROM chc_request_form_field_value crfv
Left JOIN chc_request_form_field crff ON crff.id = crfv.field_id
LEFT JOIN chc_request cr ON cr.id = crfv.request_id
left join user_attributes ua on ua.ukid = cr.ukid
LEFT JOIN chc_service cs ON cs.id = cr.service_id

left join chc_request_form_field_element_option crffe on crfv.value = crffe.id
where cs.id in (8);

-- Module: Feedback — Student feedback responses
-- Student-wise feedback responses per course/faculty with question, selected option and section details.

select d.department_name,
	p.programme_name,
	t12.year_of_joining as Batch,
	t9.registration_id as Student_Registration_id,
	t5.student_ukid,
	concat(t9.f_name, ' ', t9.l_name) as Studnet_Name,
	t10.email,
	t10.phone,
	t8.course_name,
	session_student_template_status_id,
	t8.course_code,
	t6.faculty_ukid,
	concat(t11.f_name, ' ', t11.l_name) as Faculty_Name,
	t11.registration_id,
	fsr.question_id,
	ftsq.question_text,
	fsr.option_id,
	a3.option_text,
	t14.section_name, fsr.response_text
from feedback_student_response fsr
left join feedback_template_question_option a3 on a3.id = fsr.option_id
	left join feedback_template_section_question ftsq on ftsq.id = fsr.question_id
	left join feedback_template_question_option t3 on t3.feedback_question_id = fsr.question_id
	left join feedback_template_section t14 on ftsq.template_section_id=t14.id
	left join feedback_student_template_status t4 on t4.id = fsr.session_student_template_status_id
	left join feedback_session_student t5 on t5.id = t4.student_session_id
	left join feedback_course_faculty_template t6 on t6.id = t4.feedback_course_faculty_template_id
	left join class t7 on t7.id = t6.class_id
	left join course t8 on t8.course_id = t7.course_id
	left join (
    	select *
    	from user_attributes
    	where user_type = 'student'
	) t9 on t9.ukid = t5.student_ukid
	left join authenticator t10 on t10.ukid = t9.ukid
	left join (
    	select *
    	from user_attributes
    	where user_type = 'faculty'
	) t11 on t11.ukid = t6.faculty_ukid
	left join student_profile t12 on t12.ukid = t5.student_ukid
	left join faculty_profile t13 on t13.ukid = t6.faculty_ukid
	left join department d on d.department_id = t13.department_id
	left join programme p on p.programme_id = t12.programme_id
	left join class_student cs on cs.class_id = t6.class_id
	and cs.ukid = t5.student_ukid
   
group by d.department_name,
	p.programme_name,
	t12.year_of_joining,
	t9.registration_id,
	t5.student_ukid,
	concat(t9.f_name, ' ', t9.l_name),
	t10.email,
	t10.phone,
	t8.course_name,
	session_student_template_status_id,
	t8.course_code,
	t6.faculty_ukid,
	concat(t11.f_name, ' ', t11.l_name),
	t11.registration_id,
	fsr.question_id,
	ftsq.question_text,
	fsr.option_id,
	a3.option_text,
 	T14.section_name,fsr.response_text;


-- Module: Staff / Reporting — Reportee-to-reporter mapping
-- Maps each reportee to their reporting manager along with both parties' departments.

select t1.reportee_ukid, concat(t2.f_name, ' ',t2.l_name) as "Reportee Name", t2.registration_id as "Reportee Employee ID", t6.department_name as "Reportee Department", t1.reporter_ukid, concat(t3.f_name, ' ', t3.l_name) as "Reporter Name", t3.registration_id as "Reporter Department", t7.department_name as "Reporter Dept. Name" from reporting_manager_mapping t1
left join user_attributes t2 on t1.reportee_ukid = t2.ukid
left join user_attributes t3 on t3.ukid = t1.reporter_ukid
left join faculty_profile t4 on t4.ukid = t1.reportee_ukid
left join faculty_profile t5 on t5.ukid = t1.reporter_ukid
left join department t6 on t4.department_id = t6.department_id
left join department t7 on t5.department_id = t7.department_id;


-- Module: Fee Management — NSHM head-wise fee report
-- Component (fee head) wise demand per student for active fee plans, unioned with plan-level demand for inactive plans.

select t1.ukid, t10.department_name, t11.programme_name,
 t3.batch_year,
t7.name as "Quota",
 t9.user_type,
 t9.registration_id,
 concat(t9.f_name, ' ', t9.l_name) as "Student name",
 t12.email,
 if(t12.is_Active = 1, 'Active', 'Inactive') as User_status,
    t3.sequence,
t8.name as "Component head",
 t6.amount,
t4.status as "Fee plan status",
t3.due_date,
t2.date_of_joining
from student_fee t1
 left join student_profile t2 on t2.ukid = t1.ukid
 left join fee_structure t3 on t3.id = t1.fee_structure_id
 and t3.programme_id = t2.programme_id
 and t3.batch_year = t2.year_of_joining
 left join fee_plan t4 on t4.id = t3.fee_plan_id
 left join student_fee_component t5 on t5.student_fee_id = t1.id
 left join fee_plan_structure t6 on t6.fee_plan_id = t4.id
 and t6.quota_id = t2.quota_id
 left join quota t7 on t7.id = t2.quota_id
 left join fee_type t8 on t8.id = t6.fee_type_id
 left join user_attributes t9 on t9.ukid = t2.ukid
 left join department t10 on t10.department_id = t2.department_id
    left join programme t11 on t11.programme_id = t2.programme_id
    left join authenticator t12 on t12.ukid = t9.ukid
where t4.status = 'ACTIVE'
group by t10.department_name, t11.programme_name,
 t3.batch_year,
 t7.name,
 t9.user_type,
 t1.ukid,
 t9.registration_id,
 concat(t9.f_name, ' ', t9.l_name),
 t12.email,
 if(t12.is_Active = 1, 'Active', 'Inactive'),
 t8.name,
 t6.amount,
 t3.sequence,
 t4.status,
 t3.due_date,
 t2.date_of_joining
 
 union all
 
 select
 t4.ukid,
 t5."department_name",
 t6."programme_name",
 t1.batch_year,
q.name as "Quota",
 t7.user_type,
 t7."registration_id",
 concat(t7.f_name, ' ', t7.l_name) as "Student name",
    t11.email,
    if(t11.is_Active = 1, 'Active', 'Inactive') as User_status,
    t1.sequence,
   t13.name as "Component head" ,
    t3.amount,
    t2.status as "Fee plan status",
    t1.due_date,
    t4.date_of_joining
from fee_structure t1
 left join fee_plan t2 on t2.id = t1.fee_plan_id
 left join fee_plan_structure t3 on t3.fee_plan_id = t2.id
 left join student_profile t4 on t4.programme_id = t1.programme_id
 and t1.batch_year = t4.year_of_joining and t4.quota_id = t3.quota_id
 left join department t5 on t5.department_id = t4.department_id
 left join programme t6 on t6.programme_id = t4.programme_id
 left join user_attributes t7 on t7.ukid = t4.ukid
 left join authenticator t8 on t8.ukid = t4.ukid
 left join quota q on q.id = t4.quota_id
    left join authenticator t11 on t11.ukid = t4.ukid
    left join fee_type t13 on t13.id = t3.fee_type_id
    left join student_fee sf on sf.ukid = t4.ukid
where t2.status = 'IN_ACTIVE'
group by t1.id,
 t4.ukid,
 t5.department_name,
 t6.programme_name,
 t1.batch_year,
 --t10.name,
 t7.user_type,
 t7.registration_id,
 concat(t7.f_name, ' ', t7.l_name),
    t11.email,
    if(t11.is_Active = 1, 'Active', 'Inactive'),
    t1.sequence,
    t2.status,
    t3."amount",
    q.name,
    t13.name,
    t1.due_date,
    t4.date_of_joining
 
-- Module: Admission Management — All custom field values
-- All admission cluster/custom field values per prospective student (master fields unioned with programme-specific fields) for batch 2023.

select t1.ukid, ps.application_number as "Application Number", concat(ua.f_name,' ' ,ua.l_name) as "Student Name", a.email as "Email",a.phone as "Phone", ps.gender as "Gender",ps.year_of_joining as "Batch", p.programme_name as "Programme Name", d.department_name as "Department Name",
 t3.display_name as "Cluster Name",
 coalesce(t1.value,'-') as Value,
 t2.identifier,
 t2.display_name,
 t2.element
from user_details_master_field_value t1
 left join user_details_master_field t2 on t2.id = t1.field_id
 left join user_details_master_cluster t3 on t3.id = t2.cluster_id
 left join prospective_student ps on ps.ukid = t1.ukid
 left join programme p on p.programme_id = ps.programme_id
 left join user_attributes ua on ua.ukid = ps.ukid
 left join authenticator a on a.ukid = ua.ukid
 left join department d on d.department_id = p.department_id
where t1.ukid is not null
 and ps.year_of_joining = 2023
 
union all

select t2.ukid, ps.application_number as "Application Number", concat(ua.f_name,' ' ,ua.l_name) as "Student Name", a.email as "Email",a.phone as "Phone", ps.gender as "Gender",ps.year_of_joining as "Batch", p.programme_name as "Programme Name", d.department_name as "Department Name",
t3.name as "Cluster Name",
 coalesce(t2.value,'-') as Value,
 coalesce(t4.identifier,t1.name),
 t1.name,
 t1.element
from user_details_field t1
 left join user_details_field_value t2 on t1.id = t2.field_id
 left join user_details_field_cluster t3 on t3.id = t1.cluster_id
 left join user_details_master_field t4 on t4.id = t1.master_reference
 left join prospective_student ps on ps.ukid = t2.ukid
 left join programme p on p.programme_id = ps.programme_id
 left join user_attributes ua on ua.ukid = ps.ukid
 left join authenticator a on a.ukid = ua.ukid
 left join department d on d.department_id = p.department_id
where t2.ukid is not null
 and ps.year_of_joining = 2023;

-- Module: Admission Management — Admission fee dashboard
-- Per-applicant admission fee status: payable, paid, due, payment mode, scholarship and application status.

SELECT t1.ukid,
 concat(t7.f_name,' ',t7.l_name) as "Student Name",
    COALESCE(t7.registration_id, t14.application_number) as "Registration ID",
    t17.email,
    COALESCE(t12.programme_name, t15.programme_name) programme_name,
    COALESCE(t13.department_name, t16.department_name) department_name,
 t1.form_status,
    if(coalesce((t4.total_amount - coalesce(t18.amount_paidd,0)),"-") = t4.total_amount, "not_paid", fee_status) as "Fee Status",
    t1.fee_action_taken_timestamp as "Fee Initiated Date",
 t1.fee_action_taken_by,
    concat(t6.f_name,' ',t6.l_name) as "Fee Initiated by",
 t2.status_id,
 t3.display_name as "Application Status",
 coalesce(t4.total_amount,"-"),
 coalesce(t18.amount_paidd,0),
    coalesce(upper(t18.mode),"-") as "Payment Mode",
 coalesce((t4.total_amount - coalesce(t18.amount_paidd,0)),"-") AS Due,
   if(t9.id is null,"No","Yes") as "Scholarship availed",
   t9.name as "Scholarship Name",
    t10.applicable_amount,
    t10.approved_amount,
    t10.rejected_amount,
    t10.amount
FROM admission_student_status t1
 LEFT JOIN student_admission_form_status t2 ON t2.ukid = t1.ukid
 LEFT JOIN admission_form_status t3 ON t3.id = t2.status_id
 left join admission_student_fee t5 on t5.ukid = t1.ukid
 LEFT JOIN student_fee t4 ON t4.ukid = t1.ukid and t5.student_fee_id = t4.id
    left join user_attributes t7 on t7.ukid = t1.ukid
    left join user_attributes t6 on t6.ukid = t1.fee_action_taken_by
    left join student_scholarship t8 on t8.student_fee_id = t4.id
    left join scholarship t9 on t9.id = t8.scholarship_id
    left join student_scholarship_component t10 on t10.student_scholarship_id = t8.id
    left join student_profile t11 on t7.ukid = t11.ukid
    left join programme t12 on t12.programme_id = t11.programme_id
    left join department t13 on t13 .department_id = t12.department_id
    left join prospective_student t14 on t14.ukid = t1.ukid
    left join programme t15 on t15.programme_id = t14.programme_id
    left join department t16 on t16 .department_id = t15.department_id
    left join authenticator t17 on t17.ukid = t1.ukid
    left join (select ukid, student_fee_id, sum(amount) as amount_paidd ,mode from student_fee t1 left join student_fee_payment_log t2 on t1.id = t2.student_fee_id where status = "success" group by student_fee_id) t18 on t18.ukid = t4.ukid and t18.student_fee_id = t4.id
GROUP BY t1.ukid;


-- Module: Student Management — Basic student fields report
-- Core student profile fields (registration, contact, programme, department, batch, intake, quota, photo status).

select ua.registration_id, application_number, a.email, a.phone, d.department_name, p.programme_name, sp.year_of_joining, pbi.name, accommodation_type, sp.specialisation_id, academic_status, sp.year, sp.sequence_id, q.name, admission_type, ps.programme_section_name, sp.date_of_joining, sp.gender, if((ua.media_id is not null or ua.official_media_id is not null),'Photo Uploaded','Not Uploaded') 'photo_uploaded?' from user_attributes ua
left join student_profile sp on sp.ukid = ua.ukid
left join programme p on p.programme_id = sp.programme_id
left join department d on d.department_id = sp.department_id
left join authenticator a on a.ukid = ua.ukid
left join programme_batch_intake pbi on pbi.id = sp.intake_id
left join quota q on q.id = sp.quota_id
left join programme_section ps on ps.programme_section_id= sp.section_id;


-- Module: Booth Poll — Poll responses and lookups
-- Student-wise poll responses for selected questions, plus supporting booth/question/option lookups.

select * from booth where booth_id in ("2115");

select * from booth_question where booth_id in ("2115");

select * from question where question_id in ("1396","1397","1399","1400","1401");

select * from options where question_id in ("1396","1397","1399","1400","1401");
SELECT
	t3.registration_id,
	CONCAT(t3.f_name, ' ', t3.l_name) AS Name,
	t5.email,
	t5.phone,
	t7.programme_name,
	t8.name,
	t6.gender,
	t4.booth_name,
	t2.question_content,
	t1.response_content,
	response_time
FROM
	response t1 left
    	JOIN
	question t2 ON t2.question_id = t1.question_id left
    	JOIN
	user_attributes t3 ON t3.ukid = t1.ukid left
    	JOIN
	authenticator t5 ON t5.ukid = t3.ukid left
    	JOIN
	student_profile t6 ON t6.ukid = t3.ukid left
    	JOIN
	programme t7 ON t7.programme_id = t6.programme_id left
    	JOIN
	specialisation t8 ON t8.id = t6.specialisation_id left
    	JOIN
	booth t4 ON t4.booth_id = t1.booth_id
WHERE
	t1.question_id IN ("1396","1397","1399","1400","1401");


-- Module: Examination — GDGU grade sheet raw data
-- Consolidated per-student exam grade sheet (course-wise grades, marks, credits, CGPA/SGPA) aggregated into delimited columns. (Presto/Athena dialect.)

Select examination_name, student_ukid, registration_id, student, father, mother, programme_name, department_name, department_code, programme_code, year_of_joining, term_name, acad_year_start, sem_year_no, sum(if(is_failed = 1, 0, course_credits)) earned_credits, sum(course_credits) total_credits, cgpa, sgpa, ( sum(max_internal_marks) + sum(max_external_marks) ) maximum_mark, sum(marks) mark_obtained, array_join(array_agg(course_code), '/n') "course_code", array_join(array_agg(course_name), '/n') "course_name", array_join(array_agg(course_credits), '/n') "course_credits", array_join(array_agg(grade), '/n') "grade", array_join(array_agg(grade_point), '/n') "grade_point", array_join(array_agg(marks), '/n') "marks", array_join(array_agg(internal_marks), '/n') "internal_marks", array_join(array_agg(external_marks), '/n') "external_marks", array_join(array_agg(max_internal_marks), '/n') "max_internal_marks", array_join(array_agg(max_external_marks), '/n') "max_external_marks" from ( Select ee.name "examination_name", eesc.student_ukid, ua.registration_id, concat( ua.f_name, if( ua.m_name is not null, concat(' ', ua.m_name, ' '), ' ' ), ua.l_name ) "student", ud.father, ud.mother, p.programme_name, d.department_name, d.department_code, p.programme_code, sp.year_of_joining, course_code "course_code", course_name "course_name", course_credits "course_credits", grade "grade", grade_point "grade_point", marks "marks", eesm.internal_marks, eesm.external_marks, ees.max_internal_marks, ees.max_external_marks, t.acad_year_start, t.name term_name, if( eesc.is_failed + eesc.is_failed_for_re_exam >= 1, 1, 0 ) is_failed, cgpa.cgpa, sgpa.sgpa, ( ( (t.acad_year_start - sp."year_of_joining") * if( p."system" = 'semester', 2, if(p."system" = 'trimester', 3, 1) ) ) + t."sequence" ) "sem_year_no" FROM ems_student_programme_enrollment esp INNER JOIN ems_student_course_enrollment esc ON esc.student_programme_enrollment_id = esp.id INNER JOIN ems_examination ee ON ee.id = esp.exam_id INNER JOIN term_course tc ON tc.id = esc.term_course_id INNER JOIN ems_examination_course_schema ecs ON ( ecs.examination_id = ee.id AND ecs.course_id = tc.course_id ) INNER JOIN ems_examination_student_course_grade eesc ON ( eesc.term_course_id = tc.id AND eesc.student_ukid = esp.ukid ) LEFT JOIN ( Select student_ukid, term_course_id, label [ 'Internal' ] internal_marks, label [ 'External' ] external_marks from ( Select student_ukid, term_course_id, map_agg(label, marks) label from ( Select eect.name label, student_ukid, term_course_id, marks from ems_examination_student_marks eesm left join ems_examination_schema_composition eescon on eescon.id = eesm.exam_schema_composition_id left join ems_examination_schema_component eescot on eescon.schema_component_id = eescot.id left join ems_examination_component_type eect on eect.id = eescot.component_type_id group by eect.name, student_ukid, term_course_id, marks ) group by student_ukid, term_course_id ) ) eesm on eesm.student_ukid = eesc.student_ukid and eesm.term_course_id = eesc.term_course_id INNER JOIN ems_examination_course_schema eecs ON eecs.examination_id = eesc.examination_id AND eesc.course_id = eecs.course_id INNER JOIN ( Select examination_schema_id, label [ 'Internal' ] max_internal_marks, label [ 'External' ] max_external_marks from ( Select examination_schema_id, map_agg(label, weightage) label from ( Select examination_schema_id, eect.name label, sum((eescon.weightage * maximum_marks) / 100) weightage from ems_examination_schema_composition eescon left join ems_examination_schema_component eescot on eescon.schema_component_id = eescot.id left join ems_examination_component_type eect on eect.id = eescot.component_type_id group by examination_schema_id, eect.name ) group by examination_schema_id ) ) ees on ees.examination_schema_id = eecs.examination_schema_id INNER JOIN user_attributes ua on ua.ukid = eesc.student_ukid INNER JOIN student_profile sp on sp.ukid = ua.ukid INNER JOIN programme p on p.programme_id = sp.programme_id INNER JOIN department d on d.department_id = p.department_id INNER JOIN term t on t.id = ee.term_id LEFT JOIN ( Select ukid, field [ 'MOTHER_FIRST_NAME' ] "mother", field [ 'FATHER_FIRST_NAME' ] "father" from ( select t1.ukid, map_agg(t2.identifier, t1.value) field from user_details_master_field_value t1 left join user_details_master_field t2 on t1.field_id = t2.id where t2.identifier in ( 'FATHER_FIRST_NAME', 'FATHERS_TITLE', 'MOTHERS_TITLE', 'MOTHER_FIRST_NAME' ) group by t1.ukid ) ) ud on ud.ukid = ua.ukid LEFT JOIN ( Select t1.exam_id, t1.student_ukid, coalesce(re_exam_cgpa, cgpa) cgpa from ems_examination_student_cgpa t1 left join ( Select exam_id, student_ukid, max(id) max_id from ems_examination_student_cgpa group by exam_id, student_ukid ) t2 on t1.exam_id = t2.exam_id and t1.student_ukid = t2.student_ukid where t1.id = t2.max_id ) cgpa on cgpa.exam_id = ee.id and cgpa.student_ukid = eesc.student_ukid LEFT JOIN ( Select t1.exam_id, t1.student_ukid, coalesce(re_exam_sgpa, sgpa) sgpa from ems_examination_student_sgpa t1 left join ( Select exam_id, student_ukid, max(id) max_id from ems_examination_student_sgpa group by exam_id, student_ukid ) t2 on t1.exam_id = t2.exam_id and t1.student_ukid = t2.student_ukid where t1.id = t2.max_id ) sgpa on sgpa.exam_id = ee.id and sgpa.student_ukid = eesc.student_ukid where eesc.student_ukid = 487951 and ee.name = 'Odd Term Examination 22-23' group by ee.name, eesc.student_ukid, ua.registration_id, concat( ua.f_name, if( ua.m_name is not null, concat(' ', ua.m_name, ' '), ' ' ), ua.l_name ), ud.father, ud.mother, p.programme_name, d.department_name, course_code, course_name, course_credits, grade, grade_point, marks, eesm.internal_marks, eesm.external_marks, ees.max_internal_marks, ees.max_external_marks, t.acad_year_start, t.name, sgpa.sgpa, cgpa.cgpa, if( eesc.is_failed + eesc.is_failed_for_re_exam >= 1, 1, 0 ), d.department_code, p.programme_code, sp.year_of_joining, ( ( (t.acad_year_start - sp."year_of_joining") * if( p."system" = 'semester', 2, if(p."system" = 'trimester', 3, 1) ) ) + t."sequence" ) ) t1 group by examination_name, student_ukid, registration_id, student, father, mother, programme_name, department_name, term_name, acad_year_start, sgpa, cgpa, department_code, programme_code, year_of_joining, (max_internal_marks + max_external_marks), Sem_year_no;

-- Module: Examination — Basic exam grade data
-- Flat list of student exam grades, marks and statuses per examination/term/course.
select t2.name as examination_name,t.name as term, c.course_name, ua.registration_id, concat(ua.f_name," ",ua.l_name) as student_name,t1.grade,t1.grade_point,marks,enrollment_status,attendance_status,consider_for_sgpa_calculation,fairness_status,is_failed,generation_type FROM ems_examination_student_course_grade t1 left join ems_examination t2 on t2.id = t1.examination_id left join term t on t.id = t2.term_id left join course c on c.course_id = t1.course_id left join user_attributes ua on ua.ukid = t1.student_ukid;

-- Module: Course Registration (AMS) — GDGU daily registration status
-- Per-student course-registration and post-registration status with eligibility and settings-configured flag for selected sessions.

select concat(t5.ukid, ","),
    css.session_name,
    t5.registration_id,
    concat(t5.f_name, t5.l_name) as Student_Name,
    email,
    department_name,
    programme_name,
    batch_year,
    coalesce(registration_status, "NOT_STARTED") "Registration_status",
    coalesce(post_registration_status, "NOT_STARTED") "Post Registration_status",
    if(
   	 is_eligible_for_registration = 1,
   	 "Eligible",
   	 "Non Eligible"
    ) " Registration Eligibility Status",
    if(is_active = 1, "Active", "INactive") "Student Status",
    Settings_configured
from student_profile t3
    left join ams_course_registration_student t1 on t1.ukid = t3.ukid
    left join ams_course_registration_settings t2 on t2.programme_id = t3.programme_id
    and t2.batch_year = t3.year_of_joining
    and t1.ams_course_registration_setting_id = t2.id
    left join course_registration_session css on css.session_id = t2.session_id
    left join user_attributes t5 on t1.ukid = t5.ukid
    left join department d on t3.department_id = d.department_id
    left join programme p on t3.programme_id = p.programme_id
    left join authenticator a on t3.ukid = a.ukid
where a.is_active in (1)
    and t2.session_id in (3, 4);


-- Module: Fee Management — Consolidated fee & dues master
-- All fee and dues demands per user (student fee unioned with dues), with applicable/paid/due, scholarship, waiver and module tag.
SELECT IF(
ua.registration_id IS NULL,
ps.application_number,
ua.registration_id
) AS 'applicationNo/registrationId',
CONCAT(ua.f_name, ' ', ua.l_name) AS 'Name',
IF(
p1.programme_name IS NULL,
p2.programme_name,
p1.programme_name
) AS 'Programme',
IF(q1.name IS NULL, q2.name, q1.name) AS 'Quota',
IF(
sp.year_of_joining IS NULL,
ps.year_of_joining,
sp.year_of_joining
) AS 'Batch',
IF(
d1.department_name IS NULL,
d2.department_name,
d1.department_name
) AS 'Department',
IF(au.is_active = 1, 'Active', 'Deactive') AS 'is_active',
tab1.ukid,
COALESCE(applicable_fee, 0.00) AS applicable_fee,
COALESCE(carry_over, 0.00) AS carry_over,
COALESCE(penalty_amount, 0.00) AS penalty_amount,
COALESCE(total_amount, 0.00) AS total_amount,
type,
COALESCE(waiver, 0.00) AS waiver,
Fee_Plan,
Module,
coalesce(tab1.Scholarship, 0.0) Scholarship,
keyy,
tab1.id AS 'fee/due_id',
tab1.created_timestamp AS 'demandDate',
amount_paid,
tab1.due_amount
FROM (
SELECT s1.ukid,
applicable_fee,
carry_over,
penalty_amount,
total_amount,
type,
COALESCE(waiver, 0.0) AS waiver,
Fee_Plan,
Module,
Scholarship,
keyy,
id,
created_timestamp,
amount_paid,
due_amount
FROM (
(
SELECT t1.ukid,
sfc.student_fee_id AS 'fee_id',
applicable_fee,
sfc.waiver,
carry_over,
total_amount,
coalesce(
if (
sfc.scholarship = 0,
sum(distinct t5.approved_amount),
sfc.scholarship
),
0
) Scholarship,
t1.penalty_amount,
due_amount,
paid_amount,
'Student Fee' AS 'type',
t3.name AS 'Fee_Plan',
'Fee Management' AS 'Module',
CONCAT(t1.ukid, '-', t1.id, '-', 'fee_payment') AS 'keyy',
t1.id,
t1.created_timestamp,
t1.amount_paid
FROM student_fee t1
left join student_fee_component sfc on t1.id = sfc.student_fee_id
LEFT JOIN fee_structure t2 ON t1.fee_structure_id = t2.id
LEFT JOIN fee_plan t3 ON t2.fee_plan_id = t3.id
LEFT JOIN student_scholarship t4 ON t1.id = t4.student_fee_id
LEFT JOIN student_scholarship_component t5 ON t4.id = t5.student_scholarship_id
left join user_attributes ua on t1.ukid = ua.ukid
WHERE t1.invalidated = 0
AND t2.is_active = 1
group by ukid,
t1.id
) s1
)
UNION
DISTINCT
SELECT s1.ukid,
applicable_fee,
carry_over,
penalty_amount,
total_amount,
type,
COALESCE(waiver, 0.0) AS waiver,
Fee_Plan,
Module,
Scholarship,
keyy,
id,
created_timestamp,
amount_paid,
due_amount
FROM (
SELECT t4.ukid,
t4.id AS 'due_id',
t5.amount AS 'applicable_fee',
0 AS 'carry_over',
penalty_amount AS 'penalty_amount',
t5.amount AS 'total_amount',
CONCAT(t6.category, '-', t7.department_name) AS 'type',
waived_off_amount AS 'waiver',
t7.department_name AS 'Fee_Plan',
'Dues Management' AS 'Module',
0 AS 'Scholarship',
CONCAT(t4.ukid, '-', t4.id, '-', 'dues_payment') AS 'keyy',
t4.id,
t4.created_timestamp,
t5.paid_amount amount_paid,
due_amount
FROM dues t4
LEFT JOIN dues_finance t5 ON t4.id = t5.due_id
LEFT JOIN dues_category t6 ON t4.category_id = t6.id
LEFT JOIN department t7 ON t4.department_id = t7.department_id
) s1
) tab1
LEFT JOIN student_profile sp ON tab1.ukid = sp.ukid
LEFT JOIN user_attributes ua ON tab1.ukid = ua.ukid
LEFT JOIN programme p1 ON sp.programme_id = p1.programme_id
LEFT JOIN quota q1 ON sp.quota_id = q1.id
LEFT JOIN prospective_student ps ON tab1.ukid = ps.ukid
LEFT JOIN programme p2 ON ps.programme_id = p2.programme_id
LEFT JOIN quota q2 ON ps.quota_id = q2.id
LEFT JOIN authenticator au ON tab1.ukid = au.ukid
LEFT JOIN department d1 ON p1.department_id = d1.department_id
LEFT JOIN department d2 ON p2.department_id = d2.department_id
where au.ukid in ();


-- Module: Leave Management — Staff leave requests (Leave module)
-- Staff leave requests within a date range with leave type, status, reason and action-taken details.
SELECT
	t1.id,
	t1.ukid,
	concat(ua.f_name," ",ua.l_name) Name,
	ua.registration_id,
	t1.start_date,
	t1.end_date,
	t1.number_of_days,
	COALESCE(MAX(t1.reason), '-') as Reason,
	t1.status,
	t3.name "Leave type",
	t1.created_timestamp,
	concat(ua2.f_name," ",ua2.l_name) as "Action taken by",
	t4.action_taken_timestamp
FROM staff_leave_request t1
    	LEFT JOIN staff_leave_request_date t2 ON t1.id = t2.leave_request_id
    	LEFT JOIN leave_type t3 ON t3.id = t2.leave_type_id
    	LEFT JOIN staff_leave_request_date_approval_details t4 ON t4.staff_leave_request_date_id = t2.id
   	 left join user_attributes ua on ua.ukid = t1.ukid
    	left join user_attributes ua2 on ua2.ukid = t1.action_by
WHERE
	DATE(t1.start_date) BETWEEN '2023-07-15' AND '2023-09-05'
GROUP BY t1.id;

-- Module: CHC (Campus Help Centre) — Leave requests via CHC
-- Leave-related CHC service requests with field values, assignee, status and closure timestamp.

select ua.ukid, ua.registration_id, concat(ua.f_name," ",ua.m_name," ",ua.l_name) as "userName", cr.id as "Request ID", cr.service_id,
cs.title as "Service Name",crff.name as "Field Name",
if(crff.element = 'dropdown', crffe.label, crfv.value) as "Field Value", cr.created_on, cr.assignee, cr.status, concat(ua1.f_name," ",ua1.m_name," ",ua1.l_name), crl.created_on
 FROM chc_request_form_field_value crfv
Left JOIN chc_request_form_field crff ON crff.id = crfv.field_id
LEFT JOIN chc_request cr ON cr.id = crfv.request_id
left join user_attributes ua on ua.ukid = cr.ukid
left join user_attributes ua1 on ua1.ukid = cr.assignee
LEFT JOIN chc_service cs ON cs.id = cr.service_id
left join chc_request_form_field_element_option crffe on crfv.value = crffe.id
left join (select request_id, status, created_on from chc_request_log where status = 'closed') crl on crl.request_id = cr.id
where cr.id in ("");

-- Module: Classroom — Consolidated assignment report
-- Student-wise assignment submission and grade status per class/course/term.

SELECT
ua2.ukid,
ua2.registration_id,
au.email,
au.phone,
CONCAT(ua2.f_name, ' ', ua2.l_name) 'student name',
'Assignment' AS 'Type',
cl.id class_id,
batch,
a.id assignment_id,
a.name 'title',
t.name 'term',
cl.batch,
ps.programme_section_name,
d.department_name,
c.course_code,
course_name,
CONCAT(ua1.f_name, ' ', ua1.l_name) 'faculty name',
CONCAT(ua3.f_name, ' ', ua3.l_name) 'Published By',
coalesce(ab.status, 'NA') status ,
a.created_timestamp 'created on',
a.due_date 'dead line',
ab.modified_timestamp submitted_on,
aa.grade
FROM
class_student cs
LEFT JOIN
class cl ON cs.class_id = cl.id
LEFT JOIN
assignment a ON cl.id = a.class_id
left join (select asu.ukid, if(is_submitted = 1, "Submitted", "Not Submitted")status, asu.modified_timestamp, asu.assignment_id
from assignment_submission asu
where is_submitted = 1 ) ab on ab.assignment_id = a.id and cs.ukid = ab.ukid
LEFT JOIN
(SELECT
ag.ukid, ag.assignment_id, grade
FROM
assignment_grade ag
LEFT JOIN student_profile cs ON ag.ukid = cs.ukid) aa ON aa.ukid = cs.ukid
AND aa.assignment_id = a.id
LEFT JOIN
	 course c ON cl.course_id = c.course_id
LEFT JOIN
term t ON cl.term_id = t.id
LEFT JOIN
user_attributes ua1 ON a.creator_ukid = ua1.ukid
LEFT JOIN
user_attributes ua2 ON cs.ukid = ua2.ukid
LEFT JOIN
user_attributes ua3 ON a.publisher_ukid = ua3.ukid
LEFT JOIN
student_profile sp ON cs.ukid = sp.ukid
LEFT JOIN
department d ON sp.department_id = d.department_id
LEFT JOIN
programme_section ps ON sp.section_id = ps.programme_section_id
LEFT JOIN
authenticator au ON cs.ukid = au.ukid
WHERE
	a.id is not null and t.id in ('34')


-- Module: Classroom — Assignment counts (faculty level)
-- Per-assignment summary with faculty, course, total assignments and submission counts for a term.

SELECT
t1.id,
t1.name AS 'Name',
c.batch, t.name term,
t1.class_id, co.course_name, co.course_code,
t1.creator_ukid,
CONCAT(t2.f_name, ' ', t2.l_name) AS 'facultyName',
t2.registration_id,
t3.department_name,
ADDTIME(t1.created_timestamp, '05:30:00') AS 'created_timestamp',
count(t1.id) total_assignments,
COALESCE(numberOfSubmission, 0) AS 'numberOfSubmission'
FROM
assignment t1
left join class c on t1.class_id = c.id
left join term t on t.id = c.term_id
left join course co on c.course_id = co.course_id
LEFT JOIN
user_attributes t2 ON t1.creator_ukid = t2.ukid
LEFT JOIN
faculty_profile t0 ON t1.creator_ukid = t0.ukid
LEFT JOIN
department t3 ON t0.department_id = t3.department_id
LEFT JOIN
(SELECT
assignment_id, COUNT(id) AS 'numberOfSubmission'
FROM
assignment_submission where is_submitted =1
GROUP BY assignment_id) t5 ON t1.id = t5.assignment_id
WHERE
t1.class_id IN (SELECT
id
FROM
class
WHERE
term_id IN (SELECT
id
FROM
term
WHERE
term.id = 34))
group by t1.class_id
-- Module: Fee Management — Head-wise applicable, paid & due
-- Pivoted per-student fee summary by fee head (carry over, tuition, caution deposit, etc.) with applicable, paid and due totals.

SELECT DISTINCT
	t1.ukid,
	coalesce(ua.registration_id,'-') as registration_id,
	COALESCE(IF(ua.user_type = 'prospective_student',
            	ps.application_number,
            	sp.application_number),
        	'-') application_no,
	CONCAT(ua.f_name, ' ', ua.l_name) Name,
	au.email,
	au.phone,
	coalesce(d.department_name, d2.department_name) 'Department Name',
	coalesce(p.programme_name, p2.programme_name) 'Programme Name',
	coalesce(sp.year_of_joining, ps.year_of_joining) 'Batch Year',
	coalesce(q.name, q1.name) 'Quota',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'CARRY OVER' THEN t1.amount
        	END),
        	0) 'Carry Over Applicable',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'CARRY OVER' THEN t1.paid_amount
        	END),
        	0) 'Carry Over Paid',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'CARRY OVER' THEN t1.due_amount
        	END),
        	0) 'Carry Over Due',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'TUITION FEE' THEN t1.amount
        	END),
        	0) 'Tution Fee Applicable',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'TUITION FEE' THEN t1.paid_amount
        	END),
        	0) 'Tution Fee Paid',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'TUITION FEE' THEN t1.due_amount
        	END),
        	0) 'Tution Fee Due',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'CAUTION DEPOSIT' THEN t1.amount
        	END),
        	0) 'CAUTION DEPOSIT Applicable',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'CAUTION DEPOSIT' THEN t1.paid_amount
        	END),
        	0) 'CAUTION DEPOSIT Paid',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'CAUTION DEPOSIT' THEN t1.due_amount
        	END),
        	0) 'CAUTION DEPOSIT Due',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'INSURANCE FEE' THEN t1.amount
        	END),
        	0) 'INSURANCE FEE Applicable',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'INSURANCE FEE' THEN t1.paid_amount
        	END),
        	0) 'INSURANCE FEE Paid',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'INSURANCE FEE' THEN t1.due_amount
        	END),
        	0) 'INSURANCE FEE Due',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'JNTU FEE' THEN t1.amount
        	END),
        	0) 'JNTU FEE Applicable',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'JNTU FEE' THEN t1.paid_amount
        	END),
        	0) 'JNTU FEE Paid',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'JNTU FEE' THEN t1.due_amount
        	END),
        	0) 'JNTU FEE Due',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'STUDENT SERVICE FEE' THEN t1.amount
        	END),
        	0) 'STUDENT SERVICE FEE Applicable',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'STUDENT SERVICE FEE' THEN t1.paid_amount
        	END),
        	0) 'STUDENT SERVICE FEE Paid',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'STUDENT SERVICE FEE' THEN t1.due_amount
        	END),
        	0) 'STUDENT SERVICE FEE Due',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'ONE TIME ADMISSION FEE' THEN t1.amount
        	END),
        	0) 'ONE TIME ADMISSION FEE Applicable',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'ONE TIME ADMISSION FEE' THEN t1.paid_amount
        	END),
        	0) 'ONE TIME ADMISSION FEE Paid',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'ONE TIME ADMISSION FEE' THEN t1.due_amount
        	END),
        	0) 'ONE TIME ADMISSION FEE Due',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'ACCREDITATION FEE' THEN t1.amount
        	END),
        	0) 'ACCREDITATION FEE Applicable',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'ACCREDITATION FEE' THEN t1.paid_amount
        	END),
        	0) 'ACCREDITATION FEE Paid',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'ACCREDITATION FEE' THEN t1.due_amount
        	END),
        	0) 'ACCREDITATION FEE Due',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'GMRIT TO SRIKAKULAM' THEN t1.amount
        	END),
        	0) 'GMRIT TO SRIKAKULAM Applicable',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'GMRIT TO SRIKAKULAM' THEN t1.paid_amount
        	END),
        	0) 'GMRIT TO SRIKAKULAM Paid',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'GMRIT TO SRIKAKULAM' THEN t1.due_amount
        	END),
        	0) 'GMRIT TO SRIKAKULAM Due',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'GMRIT TO VIZIANAGARAM' THEN t1.amount
        	END),
        	0) 'GMRIT TO VIZIANAGARAM Applicable',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'GMRIT TO VIZIANAGARAM' THEN t1.paid_amount
        	END),
        	0) 'GMRIT TO VIZIANAGARAM Paid',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'GMRIT TO VIZIANAGARAM' THEN t1.due_amount
        	END),
        	0) 'GMRIT TO VIZIANAGARAM Due',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'GMRIT TO BOBBILLI' THEN t1.amount
        	END),
        	0) 'GMRIT TO BOBBILLI Applicable',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'GMRIT TO BOBBILLI' THEN t1.paid_amount
        	END),
        	0) 'GMRIT TO BOBBILLI Paid',
	COALESCE(SUM(CASE
            	WHEN t1.category = 'GMRIT TO BOBBILLI' THEN t1.due_amount
        	END),
        	0) 'GMRIT TO BOBBILLI Due',
	COALESCE(SUM(t1.amount), 0) 'Total Payable',
	COALESCE(SUM(t1.paid_amount), 0) 'Total Paid',
	COALESCE(SUM(t1.due_amount), 0) 'Total Pending',
	IF(au.is_active = 1,
    	'Active',
    	'Inactive') AS 'Student Type'
FROM
	((SELECT
    	t2.ukid,
        	t3.name category,
        	t1.initial_amount amount,
        	t1.paid_amount,
        	t1.due_amount
	FROM
    	student_fee_component t1
	INNER JOIN (SELECT
    	*
	FROM
    	student_fee t2
	WHERE
    	t2.invalidated = 0 AND t2.is_active = 1) t2 ON t1.student_fee_id = t2.id
	LEFT JOIN fee_type t3 ON t1.entity_id = t3.id
	WHERE
    	t1.type = 'FEE_TYPE ') UNION ALL (SELECT
    	t1.ukid,
        	'CARRY OVER ' category,
        	t1.carry_over amount,
        	(t1.carry_over - t2.due_amount) paid_amount,
        	t2.due_amount
	FROM
    	student_fee t1
	LEFT JOIN (SELECT
    	ukid, SUM(t2.due_amount) due_amount
	FROM
    	student_fee t1
	LEFT JOIN student_fee_component t2 ON t1.id = t2.student_fee_id
	WHERE
    	invalidated = 0
        	AND ((is_active = 0
        	AND type IN ('FEE_TYPE ' , 'CARRY_OVER '))
        	OR (is_active = 1
        	AND type IN ('CARRY_OVER ')))
	GROUP BY ukid) t2 ON t1.ukid = t2.ukid
	WHERE
    	t1.is_active = 1) UNION ALL (SELECT
    	t2.ukid,
        	t3.category,
        	t1.amount,
        	t1.paid_amount,
        	t1.due_amount
	FROM
    	dues_finance t1
	LEFT JOIN dues t2 ON t1.due_id = t2.id
	LEFT JOIN dues_category t3 ON t2.category_id = t3.id)) t1
    	LEFT JOIN
	user_attributes ua ON t1.ukid = ua.ukid
    	LEFT JOIN
	authenticator au ON t1.ukid = au.ukid
    	LEFT JOIN
	student_profile sp ON t1.ukid = sp.ukid
    	LEFT JOIN
	programme p ON sp.programme_id = p.programme_id
    	LEFT JOIN
	department d ON sp.department_id = d.department_id
    	LEFT JOIN
	quota q ON sp.quota_id = q.id
    	LEFT JOIN
	prospective_student ps ON ua.ukid = ps.ukid
   	 LEFT JOIN
    quota q1 ON q1.id = ps.quota_id
    	LEFT join
    programme p2 ON p2.programme_id = ps.programme_id
   	 left join
    department d2 on d2.department_id = p2.department_id
GROUP BY t1.ukid

-- Module: Hostel Management — Hostel allotment
-- Active hostel allotments per occupant with building, room, bed and student status for a given batch.
SELECT t1.id as allotment_id,t1.occupant_ukid,t1.status,t1.allotment_start_date,t1.allotment_end_date, CONCAT(t2.f_name, ' ', t2.l_name) AS Student_Name, t2.registration_id,sp.year_of_joining, a.email, inf.parent as Hostel_Building, inf.room_name as Room_name, inf2.room_name as Bed_no, if(a.is_active = 1,"Active","Inactive") as Student_Status FROM hostel_allotment t1 LEFT JOIN user_attributes t2 ON t2.ukid = t1.occupant_ukid left join(select i.id,i.name as room_name,i2.name as parent from infrastructure_version i left join infrastructure_version i2 on i2.id = i.parent_id) inf on inf.id = t1.infrastructure_id left join (select i.id,i.name as room_name,i2.name as parent from infrastructure_version i left join infrastructure_version i2 on i2.id = i.parent_id) inf2 on inf2.id = t1.child_infrastructure_id LEFT JOIN authenticator a ON a.ukid = t2.ukid left join student_profile sp on sp.ukid = t2.ukid where sp.year_of_joining = 2025;

-- Module: Classroom — Consolidated activity report (quiz/assignment/discussion)
-- Student-wise quiz, assignment and discussion-forum participation for the current term.

	select ua2.registration_id,
            	concat(ua2.f_name, ' ', ua2.l_name) "student name",
            	'Quiz' as "Type",
            	cq.id,
            	cq.title,
            	t.name "term",
            	cl.batch, ps.programme_section_name,
            	d.department_name,
            	c.course_code,
            	course_name,
            	concat(ua1.f_name, ' ', ua1.l_name) "faculty name",
            	concat(ua0.f_name, ' ', ua0.l_name) "Published By",
            	if(cq.is_graded = 1, 'Graded', 'Non Graded') "Graded Type",
            	if(
                	student_final_submission = 1,
                	'Submitted',
                	'Not Submitted'
            	) "Submission Status",
            	cq.created_timestamp "created on",
                	cq.deadline_datetime "dead line",
            	max_marks  "max_marks",
            	cqs.total_marks  "marks obtain", 'NA' 'remark'
        	from classroom_quiz_student cqs
            	left join classroom_quiz cq on cq.id = cqs.classroom_quiz_id
            	left join class cl on cq.class_id = cl.id
            	left join user_attributes ua1 on cq.creator_ukid = ua1.ukid
            	left join user_attributes ua0 on cq.published_by = ua0.ukid
            	left join course c on cl.course_id = c.course_id
            	left join user_attributes ua2 on cqs.student_ukid = ua2.ukid
            	left join term t on cl.term_id = t.id
            	left join student_profile sp on sp.ukid = cqs.student_ukid
            	left join department d on sp.department_id = d.department_id
            	left join programme_section ps on sp.section_id = ps.programme_section_id
            	where t.starts <= curdate() and t.ends >= curdate()
            	UNION
        	distinct (
                	SELECT
                	ua2.registration_id,
                	CONCAT(ua2.f_name, ' ', ua2.l_name) 'student name',
                	'Assignment' AS 'Type',
                	a.id,
                	a.name 'title',
                	t.name 'term',
                	cl.batch,
                	ps.programme_section_name,
                	d.department_name,
                	c.course_code,
                	course_name,
                	CONCAT(ua1.f_name, ' ', ua1.l_name) 'faculty name',
                	CONCAT(ua3.f_name, ' ', ua3.l_name) 'Published By',
                	'NA' AS 'Graded Type',
                	COALESCE(t0.status, 'Not Submitted') 'Submission Status',
                	a.created_timestamp 'created on',
                	a.due_date 'dead line',
                	'NA' AS max_marks,
                	'NA' AS 'marks obtain', aa.remark
            	FROM
                	class_student cs
                    	LEFT JOIN
                	class cl ON cs.class_id = cl.id
                    	LEFT JOIN
                	assignment a ON cl.id = a.class_id
            	left join (
                	SELECT cs.ukid,
                    	ag.assignment_id, remark
            	from class_student cs
                    	left join class c1 on cs.class_id = c1.id
                	inner join assignment a1 on c1.id = a1.class_id
                	inner join assignment_grade ag on cs.ukid = ag.ukid
                            	group by ag.assignment_id, ag.ukid ) aa on a.id = aa.assignment_id and aa.ukid = cs.ukid
                    	LEFT JOIN
                	(SELECT
                    	asu.*,
                        	IF(asu.is_submitted = 1, 'Submitted', 'Not Submitted') status
                	FROM
                    	class_student cs0
                    	left join assignment_submission asu ON asu.ukid = cs0.ukid
                    	WHERE
                    	is_submitted = 1) t0 ON a.id = t0.assignment_id and cs.ukid = t0.ukid
                    	LEFT JOIN
                	course c ON cl.course_id = c.course_id
                    	LEFT JOIN
                	term t ON cl.term_id = t.id
                    	LEFT JOIN
                	user_attributes ua1 ON a.creator_ukid = ua1.ukid
                    	LEFT JOIN
                	user_attributes ua2 ON cs.ukid = ua2.ukid
                    	LEFT JOIN
                	user_attributes ua3 ON a.publisher_ukid = ua3.ukid
                    	LEFT JOIN
                	student_profile sp ON cs.ukid = sp.ukid
                    	LEFT JOIN
                	department d ON sp.department_id = d.department_id
                    	LEFT JOIN
                	programme_section ps ON sp.section_id = ps.programme_section_id
                	where t.starts <= curdate() and t.ends >= curdate()
            	GROUP BY  a.id, cs.ukid
        	)
        	UNION
        	distinct (
        	select ua2.registration_id,
                	concat(ua2.f_name, ' ', ua2.l_name) "student name",
                	'Discussion Forum' as "Type",
                	cd.id,
                	cd.title "title",
                	t.name "term",
                	cl.batch, ps.programme_section_name,
                	d.department_name,
                	c.course_code,
                	course_name,
                	concat(ua1.f_name, ' ', ua1.l_name) "faculty name",
                	'NA' as "Published By",
                	if(graded = 1, 'Graded', 'Non Graded') as "Graded Type",
                	'NA' as "Submission Status",
                	cd.created_timestamp "created on",
                	cd.end_datetime "dead line",
                	'NA' as max_marks,
                	'NA' as "marks obtain", 'NA' as "remark"
            	from classroom_discussion cd
                	left join class_student cs on cd.class_id = cs.class_id
                	left join class cl on cd.class_id = cl.id
                	left join course c on cl.course_id = c.course_id
                	left join term t on cl.term_id = t.id
                	left join user_attributes ua1 on cd.created_by_ukid = ua1.ukid
                	left join user_attributes ua2 on cs.ukid = ua2.ukid
                	left join student_profile sp on cs.ukid = sp.ukid
                	left join department d on sp.department_id = d.department_id
                	left join programme_section ps on sp.section_id = ps.programme_section_id
                	where t.starts <= curdate() and t.ends >= curdate())


-- Module: Feedback — Subjective (text) responses
-- Student feedback responses limited to free-text answers per course/faculty.

select d.department_name, p.programme_name, t12.year_of_joining as Batch, t9.registration_id as Student_Registration_id, t5.student_ukid, concat(t9.f_name, ' ', t9.l_name) as Studnet_Name, t10.email, t10.phone, t8.course_name, session_student_template_status_id, t8.course_code, t6.faculty_ukid, concat(t11.f_name, ' ', t11.l_name) as Faculty_Name, t11.registration_id, fsr.question_id, ftsq.question_text, t14.section_name, fsr.response_text from feedback_student_response fsr left join feedback_template_question_option a3 on a3.id = fsr.option_id left join feedback_template_section_question ftsq on ftsq.id = fsr.question_id left join feedback_template_question_option t3 on t3.feedback_question_id = fsr.question_id left join feedback_template_section t14 on ftsq.template_section_id=t14.id left join feedback_student_template_status t4 on t4.id = fsr.session_student_template_status_id left join feedback_session_student t5 on t5.id = t4.student_session_id left join feedback_course_faculty_template t6 on t6.id = t4.feedback_course_faculty_template_id left join class t7 on t7.id = t6.class_id left join course t8 on t8.course_id = t7.course_id left join ( select * from user_attributes where user_type = 'student' ) t9 on t9.ukid = t5.student_ukid left join authenticator t10 on t10.ukid = t9.ukid left join ( select * from user_attributes where user_type = 'faculty' ) t11 on t11.ukid = t6.faculty_ukid left join student_profile t12 on t12.ukid = t5.student_ukid left join faculty_profile t13 on t13.ukid = t6.faculty_ukid left join department d on d.department_id = t13.department_id left join programme p on p.programme_id = t12.programme_id left join class_student cs on cs.class_id = t6.class_id and cs.ukid = t5.student_ukid where fsr.response_text is not null group by d.department_name, p.programme_name, t12.year_of_joining, t9.registration_id, t5.student_ukid, concat(t9.f_name, ' ', t9.l_name), t10.email, t10.phone, t8.course_name, session_student_template_status_id, t8.course_code, t6.faculty_ukid, concat(t11.f_name, ' ', t11.l_name), t11.registration_id, fsr.question_id, ftsq.question_text, t14.section_name,fsr.response_text; 


-- Module: User Management — Last login per user
-- Most recent login timestamp and device type per user.
select ld.ukid, concat(f_name," ",ua.l_name) as Name, a.email, ua.user_type, max(ld.timestamp) as Last_login, ld.device_type from login_details ld left join user_attributes ua on ua.ukid = ld.ukid left join authenticator a on a.ukid = ua.ukid group by ld.ukid


-- Module: Mess Management — Mess group membership
-- Hostel occupants eligible for mess coupon generation with mess-group membership status and profile details.

SELECT a.ukid, a.email, a.phone, ua.registration_id, CONCAT(ua.f_name, ' ', ua.m_name, ' ', ua.l_name) AS name, ua.user_type, m.media_location AS photo, IFNULL(umgs.status, 'ACTIVE') AS couponGenerationStatus, d.department_name, p.programme_name, ps.programme_section_name AS sectionName, IFNULL(sp.year_of_joining, IFNULL(fp.year_of_joining, ap.year_of_joining)) batchYear, (SELECT ukid FROM user_mess WHERE ukid = a.ukid) AS existingUkid FROM authenticator a INNER JOIN hostel_allotment ha ON ha.occupant_ukid = a.ukid INNER JOIN user_attributes ua ON a.ukid = ua.ukid INNER JOIN infrastructure i ON ha.infrastructure_id = i.id INNER JOIN user_mess_group_infrastructure umgi ON i.parent_id = umgi.infra_id LEFT JOIN media_object m ON ua.media_id = m.media_id LEFT JOIN faculty_profile fp ON ua.ukid = fp.ukid LEFT JOIN student_profile sp ON ua.ukid = sp.ukid LEFT JOIN admin_profile ap ON ua.ukid = ap.ukid LEFT JOIN department d ON d.department_id = fp.department_id OR d.department_id = ap.department_id OR d.department_id = sp.department_id LEFT JOIN programme p ON p.programme_id = sp.programme_id LEFT JOIN programme_section ps ON sp.section_id = ps.programme_section_id LEFT JOIN user_mess_group_member_status umgs ON umgs.ukid = ha.occupant_ukid;


-- Module: Infrastructure — Hostel bed/room mapping
-- Hostel bed infrastructure with its room, floor and building hierarchy.

select i.id as bed_infra_id, i.name as Bed_name, i.type, i2.id as room_infra_id, i2.name as Room_name, i2.type, ifr.name as floor, i3.name as Building from infrastructure i left join infrastructure i2 on i.parent_id = i2.id left join infrastructure_floor ifr on ifr.id = i2.floor_id left join infrastructure i3 on i3.id = i2.parent_id where i.type like 'Hostel Bed';


-- Module: Admin / Access Rights — Admin roles and rights
-- Admin role assignments per user with entity scope and who assigned them.

select concat(ua.f_name," ",ua.l_name) as Name, ua.registration_id,a.email, t2.desc as Role, t1.entity_name, concat(ua2.f_name," ",ua2.l_name) as Assigned_by  from admin_rights t1 left join UDC_04_ADMINROLE t2 on t2.code = t1.role left join user_attributes ua on ua.ukid = t1.ukid left join user_attributes ua2 on ua2.ukid = t1.assigned_by
Left join authenticator a on a.ukid = ua.ukid;



-- Module: Leave Management — Leave approval matrix
-- Approver hierarchy per staff member and leave type, with approval order and leave policy.
SELECT t1.ukid, CONCAT(ua.f_name, ' ', ua.l_name) AS approvee_name, ua.registration_id AS approvee_reg_id, COALESCE(d.department_name, d2.department_name) AS approvee_department, lt.name AS type, t1.approver_ukid, CONCAT(ua2.f_name, ' ', ua2.l_name) AS Approver_name, ua2.registration_id AS approver_reg_id, t1.approval_order, lp.name as leave_policy FROM staff_leave_approval_matrix t1 LEFT JOIN leave_type lt ON lt.id = t1.leave_type_id LEFT JOIN user_attributes ua ON ua.ukid = t1.ukid LEFT JOIN user_attributes ua2 ON ua2.ukid = t1.approver_ukid LEFT JOIN faculty_profile fp ON fp.ukid = t1.ukid LEFT JOIN admin_profile ap ON ap.ukid = t1.ukid LEFT JOIN department d ON d.department_id = fp.department_id LEFT JOIN department d2 ON d2.department_id = ap.department_id left join staff_leave_policy_mapping slpm on slpm.ukid = t1.ukid and slpm.leave_calendar_id = t1.leave_calendar_id left join leave_policy lp on lp.id = slpm.leave_policy_id where t1.leave_calendar_id = 2; 


-- Module: Examination — Exam enrollment report
-- Student exam-course enrolments with course, fee and dues details for a given term.

Select ua.registration_id,
concat(ua.f_name, ' ', ua.l_name) name,
email,
sp.sequence_id semseter,
sp.gender,
d.department_name,
p.programme_name,
tc.course_name,
tc.course_code,
tc.course_credits,
t1.type course_type,
t2.remarks,
t2.total_fee_amount,
t2.fee_paid,
t2.modified_timestamp, df.amount, df.paid_amount, df.due_amount
from ems_student_course_enrollment t1
left join ems_student_programme_enrollment t2 on t1.student_programme_enrollment_id = t2.id
left join term_course tc on t1.term_course_id = tc.id
left join term t on t.id = tc.term_id
left join ems_examination ee on ee.id = t2.exam_id
left join user_attributes ua on ua.ukid = t2.ukid
left join student_profile sp on sp.ukid = ua.ukid
left join authenticator a on a.ukid = t2.ukid
left join department d on d.department_id = sp.department_id
left join programme p on p.programme_id = sp.programme_id
left join ems_examination_type eet on eet.id = t2.exam_type_id
left join dues du on t2.ukid = du.ukid and du.id = t1.dues_id
left join dues_finance df on df.due_id = du.id
where t.name in ('PACE-Supplementary- 2022-23') and is_active = 1;


-- Module: Examination — Answer-sheet masking numbers
-- Masked answer-sheet numbers per examinee/course for a term.

select  t.name Term_Name,concat(ua.f_name," ",ua.l_name) as Name, ua.registration_id as "Registration ID",dp.department_name Department_Name,programme_name as Student_Program_Name,course_name,course_code,
 answer_sheet_number as "Answer Sheet Number"
from ems_assessment_answer_sheet aas
 left join user_attributes ua on aas.examinee_ukid = ua.ukid
 left join student_profile sp on sp.ukid = ua.ukid
 left join programme p on p.programme_id = sp.programme_id
 left join department dp on dp.department_id = p.department_id
 left join ems_assessment_question_paper eq on eq.id = aas.question_paper_id
 left join ems_assessment eaa on eaa.id = eq.assessment_id
 left join term_course tc on tc.id = eaa.term_course_id
 left join term t on t.id = tc.term_id
 -- dp.department_id in (119,118,125)
 
 -- question_paper_id=82;


-- Module: Curriculum — Mapping progress
-- Course counts per programme/specialisation/registration-type for selected batch-sequence combinations. (Presto/Athena dialect.)

Select p.programme_name, d.department_name, c.batch_year, s.name specialisation, crt.registration_type course_reg_type, cc.sequence, count(distinct cco.id) course_count from curriculum_course cco
left join curriculum_cluster_set ccs on cco.curriculum_cluster_set_id = ccs.id
left join curriculum_cluster cc on cc.id = ccs.curriculum_cluster_id
left join curriculum c on c.id = cc.curriculum_id
left join course_registration_type crt on crt.id = ccs.course_registration_type_id
left join programme p on p.programme_id = c.programme_id left join programme_specialisation_mapping psm on psm.id = c.programme_specialisation_mapping_id
left join specialisation s on psm.specialisation_id = s.id
left join department d on d.department_id = p.department_id
where concat( cast(c.batch_year as varchar), '-', cast(cc.sequence as varchar) ) in ('2023-2', '2022-4', '2021-6', '2020-8')
group by department_name, p.programme_name, c.batch_year, s.name, crt.registration_type, cc.sequence


-- Module: Fee Management — NSHM all fee demands
-- Head-wise fee demand per student across active/inactive/closed plans, unioned with plan-level demand.

select t1.ukid, t1.id as fee_id,
    t10.department_name,
    t11.programme_name,
    t3.batch_year,
    t7.name as "Quota",
    t9.user_type,
    t9.registration_id,
    concat(t9.f_name, ' ', t9.l_name) as "Student name",
    t12.email,
    if(t12.is_Active = 1, 'Active', 'Inactive') as User_status,
    t3.sequence,
    t1.applicable_fee, t1.penalty_amount, t1.invalidated,
    t8.name as "Component head",
    t6.amount, t4.name as fee_plan, t4.id as fee_plan_id,
    t4.status as "Fee plan status",
    date(t3.due_date) as due_date
	from student_fee t1
    left join student_profile t2 on t2.ukid = t1.ukid
    left join fee_structure t3 on t3.id = t1.fee_structure_id
    and t3.programme_id = t2.programme_id
    and t3.batch_year = t2.year_of_joining
    left join fee_plan t4 on t4.id = t3.fee_plan_id
    left join student_fee_component t5 on t5.student_fee_id = t1.id
    left join fee_plan_structure t6 on t6.fee_plan_id = t4.id
    and t6.quota_id = t2.quota_id
    left join quota t7 on t7.id = t2.quota_id
    left join fee_type t8 on t8.id = t6.fee_type_id
    left join user_attributes t9 on t9.ukid = t2.ukid
    left join department t10 on t10.department_id = t2.department_id
    left join programme t11 on t11.programme_id = t2.programme_id
    left join authenticator t12 on t12.ukid = t9.ukid
where t4.status in ('ACTIVE','IN_ACTIVE','CLOSED')
group by t10.department_name, t1.id,
    t11.programme_name,
    t3.batch_year,
    t7.name,
    t9.user_type,
    t1.ukid,
    t9.registration_id,
    concat(t9.f_name, ' ', t9.l_name),
    t12.email,t1.applicable_fee,
    if(t12.is_Active = 1, 'Active', 'Inactive'),
    t8.name,
    t6.amount,
    t3.sequence,
    t4.status,
    t3.due_date,
    t2.date_of_joining,t1.penalty_amount, t1.invalidated, t4.name,t4.id
    union all select t4.ukid, coalesce(0) as fee_id,
    t5."department_name",
    t6."programme_name",
    t1.batch_year,
    q.name as "Quota",
    t7.user_type,
    t7."registration_id",
    concat(t7.f_name, ' ', t7.l_name) as "Student name",
    t11.email,
    if(t11.is_Active = 1, 'Active', 'Inactive') as User_status,
    t1.sequence, coalesce(0) as applicable_fee,coalesce(0) as penalty_amount, sf.invalidated,
    t13.name as "Component head",
    t3.amount, t2.name as fee_plan,t2.id as fee_plan_id,
    t2.status as "Fee plan status",
    date(t1.due_date) as due_date
from fee_structure t1
    left join fee_plan t2 on t2.id = t1.fee_plan_id
    left join fee_plan_structure t3 on t3.fee_plan_id = t2.id
    left join student_profile t4 on t4.programme_id = t1.programme_id
    and t1.batch_year = t4.year_of_joining
    and t4.quota_id = t3.quota_id
    left join department t5 on t5.department_id = t4.department_id
    left join programme t6 on t6.programme_id = t4.programme_id
    left join user_attributes t7 on t7.ukid = t4.ukid
    left join authenticator t8 on t8.ukid = t4.ukid
    left join quota q on q.id = t4.quota_id
    left join authenticator t11 on t11.ukid = t4.ukid
    left join fee_type t13 on t13.id = t3.fee_type_id
    left join student_fee sf on sf.ukid = t4.ukid
where t2.status in ('IN_ACTIVE')
group by t1.id,
    t4.ukid,
    t5.department_name,
    t6.programme_name,
    t1.batch_year,
    -- t10.name,
    t7.user_type,
    t7.registration_id,
    concat(t7.f_name, ' ', t7.l_name),
    t11.email,
    if(t11.is_Active = 1, 'Active', 'Inactive'),
    t1.sequence,
    t2.status,
    t3."amount",
    q.name,
    t13.name,
    t1.due_date,
    T4.date_of_joining,sf.invalidated,t2.name,t2.id




-- Module: Class — Class group summary
-- Per class group: course, type, dates, lesson/student/faculty counts and faculty names.

select c.course_code, c.course_name, cl.type as class_type, cl.start_date as class_start, cl.end_date as class_end, cl.batch as class_name, cl.total_lessons, total_students, total_faculties, group_concat(ua.f_name," ",ua.l_name) as Faculty_names from class cl left join course c on c.course_id = cl.course_id left join class_faculty cf on cf.class_id = cl.id left join user_attributes ua on ua.ukid = cf.faculty_id group by cl.id;








-- Module: Programme Batch Intake — PBI listing
-- Programme batch intakes with batch year, programme and department.

SELECT pbi.name , pbi.batch_year , p.programme_name, d.department_name FROM programme_batch_intake pbi left join programme p on p.programme_id  = pbi.programme_id left join department d on d.department_id  = p.department_id ;


-- Module: Examination — Exam enrollment (by exam id)
-- Student exam-course enrolments with course, fee and dues details for selected exam ids.

Select ua.registration_id,
concat(ua.f_name, ' ', ua.l_name) name,
email,
sp.sequence_id semseter,
sp.gender,
d.department_name,
p.programme_name,
tc.course_name,
tc.course_code,
tc.course_credits,
t1.type course_type,
t2.remarks,
t2.total_fee_amount,
t2.fee_paid, ee.id as exam_id,
t2.modified_timestamp, df.amount, df.paid_amount, df.due_amount
from ems_student_course_enrollment t1
left join ems_student_programme_enrollment t2 on t1.student_programme_enrollment_id = t2.id
left join term_course tc on t1.term_course_id = tc.id
left join term t on t.id = tc.term_id
left join ems_examination ee on ee.id = t2.exam_id
left join user_attributes ua on ua.ukid = t2.ukid
left join student_profile sp on sp.ukid = ua.ukid
left join authenticator a on a.ukid = t2.ukid
left join department d on d.department_id = sp.department_id
left join programme p on p.programme_id = sp.programme_id
left join ems_examination_type eet on eet.id = t2.exam_type_id
left join dues du on   t2.ukid = du.ukid  and du.id = t1.dues_id
left join dues_finance df on df.due_id = du.id
where ee.id in (30,31,32) and  is_active = 1;




-- Module: Staff Attendance — Daily status (v2)
-- Per-staff daily attendance status with in/out entries for a date range (attendance v2).

select sa.ukid,concat(ua.f_name,ua.m_name,' ',ua.l_name) Name,ua.registration_id as Employee_id, sa.attendance_for_date,coalesce(sas.status,'-') as 'Attendnace Status',coalesce(sa.inside_entry,'-') 'in entry',coalesce(sa.outside_entry,'-') 'out entry' from staff_attendance_v2 sa left join staff_attendance_v2_status sas on sa.status_id=sas.id left join user_attributes ua on ua.ukid=sa.ukid where attendance_for_date >='2023-12-01' and attendance_for_date <= '2023-12-31' group by sa.ukid,sa.attendance_for_date;


-- Module: Fee Management — Active finance summary
-- Per-student active fee summary: applicable, scholarship, waiver, penalty, payable, paid, due and excess.

select sf.ukid,ua.registration_id, applicable_fee,coalesce(ssc.approved_amount,0)  as scholarship,coalesce(t1.waiver,0) as waiver_amount, penalty_amount,total_amount as total_payable, amount_paid, amount_due, coalesce(t0.initial_amount,0) as excess,if(is_instalments_active=1,"Yes","No") as is_installment_active from student_fee sf left join student_scholarship ss on sf.id = ss.student_fee_id
left join student_scholarship_component ssc on ssc.student_scholarship_id = ss.id left join student_fee_component sfc on sfc.student_fee_id = sf.id left join user_attributes ua on ua.ukid = sf.ukid
left join (select student_fee_id, initial_amount  from student_fee_component where type = "excess") t0 on t0.student_fee_id = sf.id
left join (select student_fee_id, sum(waiver) as waiver from student_fee_component group by student_fee_id) t1 on t1.student_fee_id = sf.id where sf.is_active = 1 and sf.invalidated = 0 group by sf.ukid;




-- Module: Fee Management — Instalment schedule
-- Per-student fee instalments with sequence, amounts and due dates.

select sf.ukid,ua.registration_id,t3.name, t1.instalment_sequence, t1.initial_amount,(t1.initial_amount + t1.instalment_fee) as instalment_total_amount, t1.instalment_fee, t1.due_date from student_fee_instalments t1 left join student_fee sf on sf.id = t1.student_fee_id left join instalment_plan t3 on t3.id = t1.instalment_plan_id left join user_attributes ua on ua.ukid = sf.ukid;


-- Module: Timetable — Lesson slot report
-- Lesson-wise timetable slots with course, faculty, date, time and attendance-taken flag for a term/date range.

select cl.id as class_id,cl.batch as class_name,c.course_name, c.course_code,cl.type,d.department_name,concat(ua.f_name," ",ua.l_name) as Faculty_name,ua.registration_id as faculty_id,a.email,date(l.start) as session_date,l.day_of_week,time(start) as start_time, time(end) as end_time, l.attendance_taken from lesson l left join class cl on cl.id = l.class_id left join course c on c.course_id = cl.course_id left join department d on d.department_id = c.department_id left join user_attributes ua on ua.ukid = l.faculty_id left join authenticator a on a.ukid = ua.ukid where cl.term_id = 2 and date(l.start) between "2023-11-01" and "2024-01-11";



-- Module: CHC (Campus Help Centre) — Response values with device
-- CHC service-request field values (service id 23) with IST-converted creation time and login device type.

select ua.ukid, ua.registration_id, concat(f_name," ",m_name," ", l_name) as "userName", request_id as "Request ID", cs.title as "Service Name",crff.name as "Field Name", if(crff.element = 'dropdown', crffe.label, crfv.value) as "Field Value",CONVERT_TZ(cr.created_on, '+00:00', '+05:30') as created_on, t1.device_type FROM chc_request_form_field_value crfv Left JOIN chc_request_form_field crff ON crff.id = crfv.field_id LEFT JOIN chc_request cr ON cr.id = crfv.request_id left join user_attributes ua on ua.ukid = cr.ukid LEFT JOIN chc_service cs ON cs.id = cr.service_id left join chc_request_form_field_element_option crffe on crfv.value = crffe.id left join (select ld.ukid, concat(f_name," ",ua.l_name) as Name, a.email, ua.user_type, max(ld.timestamp) as Last_login, ld.device_type from login_details ld left join user_attributes ua on ua.ukid = ld.ukid left join authenticator a on a.ukid = ua.ukid group by ld.ukid) t1 on t1.ukid = ua.ukid where cs.id = 23;


-- Module: Dues Management — UMU dues/payments report
-- Successful dues payments with payer, instrument details, receipt number and amounts from a given date.

SELECT po.ukid, IF(ua.registration_id IS NULL, ps.application_number, ua.registration_id) AS 'applicationNo/registrationId', CONCAT(ua.f_name, ' ', ua.l_name) AS 'Name', coalesce(sub.value,"-") as Father_name, IF(p1.programme_name IS NULL, p2.programme_name, p1.programme_name) AS 'Programme', IF(q1.name IS NULL, q2.name, q1.name) AS 'Quota', IF(sp.year_of_joining IS NULL, ps.year_of_joining, sp.year_of_joining) AS 'Batch', po.description AS 'Fee Plan', po.feeType, case when po.entity = 'dues_payment' then 'dues_payment' when po.entity = 'fee_refund' then 'fee_refund' else 'fee_payment' end as 'Module', po.idd as 'fee/due_id', po.mode, po.id payment_order_id, extra.mode as instrument_mode, extra.bank as instrument_bank , DATE_FORMAT(extra.date, '%d-%m-%Y') as instrument_date, extra.ref_no as ref_no, CONCAT(ua2.f_name, ' ', ua2.l_name) AS 'Paid By', COALESCE(po.gateway_transaction_id, ' ') 'Transaction Number', pr.id AS 'Receipt Number', po.amount,po.aamount as dues_payable,po.paid_amount, po.due_amount, po.status, po.remarks AS 'remarks', DATE_FORMAT(date(ADDTIME(po.created_timestamp, '05:30:00')), '%d-%m-%Y') AS 'Date', IF(au.is_active = 1, 'Active', 'De-active') AS 'User Status', po.gateway_transaction_id AS 'Transaction id', au.email FROM ( (SELECT t1.*,t4.id as idd,paid_amount,due_amount,df.amount as aamount, GROUP_CONCAT(t4.remarks) AS 'remarks', CONCAT(t6.category) AS 'feeType' FROM (SELECT * FROM payment_order WHERE entity = 'dues_payment') AS t1 LEFT JOIN dues_payment t2 ON t1.entity_id = t2.id LEFT JOIN dues_payment_mapping t3 ON t2.id = t3.dues_payment_id LEFT JOIN dues t4 ON t4.id = t3.dues_id LEFT JOIN dues_category t6 ON t4.category_id = t6.id left join dues_finance df on df.due_id = t4.id LEFT JOIN department t7 ON t4.department_id = t7.department_id GROUP BY t1.id)) AS po LEFT JOIN payment_receipt pr ON po.id = pr.order_id LEFT JOIN student_profile sp ON po.ukid = sp.ukid LEFT JOIN user_attributes ua ON po.ukid = ua.ukid LEFT JOIN user_attributes ua2 ON po.paid_by = ua2.ukid left join (select t1.ukid,t2.display_name,t1.value from user_details_master_field_value t1 left join user_details_master_field t2 on t1.field_id = t2.id where t2.id in (1)) sub on sub.ukid = sp.ukid LEFT JOIN programme p1 ON sp.programme_id = p1.programme_id LEFT JOIN quota q1 ON sp.quota_id = q1.id LEFT JOIN prospective_student ps ON po.ukid = ps.ukid LEFT JOIN programme p2 ON ps.programme_id = p2.programme_id LEFT JOIN quota q2 ON ps.quota_id = q2.id LEFT JOIN authenticator au ON po.ukid = au.ukid left join (SELECT id, ukid, IF(mode = 'online', online_payment_channel, mode) AS mode, COALESCE(cheque_date, neft_date, cash_date, imps_date, dd_date, rtgs_date,pos_date,upi_date, DATE(created_timestamp)) AS Date, COALESCE(cheque_bank, neft_acc_holder_bank, imps_acc_holder_bank, dd_bank, rtgs_acc_holder_bank,pos_bank, '-') AS Bank, COALESCE(CONCAT(cheque_number, '\''), CONCAT(neft_utr_id, '\''), CONCAT(gateway_transaction_id, '\''), CONCAT(imps_utr_id, '\''), CONCAT(dd_number, '\''), CONCAT(rtgs_utr_id, '\''), CONCAT(upi_utr_id, '\''),CONCAT(pos_card_number, '\''), '-') AS ref_no FROM payment_order WHERE status = 'success') extra on extra.id = po.id WHERE po.status = 'success' and date(processed_timestamp) >="2024-02-14"



-- Module: Analytics — Monthly active users
-- Distinct active users per user-type per month for 2023-2024, excluding a specific department.

select year(s.created_on),month(s.created_on),user_type,count( DISTINCT s.ukid) from session s left join user_attributes ua on ua.ukid = s.ukid left join authenticator a on ua.ukid = a.ukid 
left join faculty_profile fp on fp.ukid = ua.ukid 
left join admin_profile ap on ap.ukid = ua.ukid
left join student_profile sp on sp.ukid = ua.ukid 
left join prospective_student ps on ps.ukid = ua.ukid
left join programme p on p.programme_id  = ps.programme_id 
left join department d on d.department_id = COALESCE(fp.department_id,ap.department_id,sp.department_id,p.department_id) 
where  year(s.created_on) in (2023,2024) and d.department_id not in (95) 
group by ua.user_type,month(s.created_on),year(s.created_on)



-- Module: Fee Management — Programme-batch-quota demand
-- Fee-plan demand per programme/batch/sequence/quota with status and due date.

SELECT fs.programme_id, fs.batch_year, fs.sequence, fs.fee_plan_id, fp.name fee_plan, fp.quota_id, p.programme_name, d.department_name, quota_name, demand, fs.academic_year, fp.name,if(fs.is_active=1,"Active","Closed") status, DATE(fs.due_date) AS due_date FROM fee_structure fs LEFT JOIN (SELECT fee_plan_id, q.name quota_name, quota_id, SUM(amount) demand FROM fee_plan_structure fps LEFT JOIN quota q ON fps.quota_id = q.id GROUP BY fee_plan_id , quota_id) fp ON fp.fee_plan_id = fs.fee_plan_id LEFT JOIN fee_programme_batch fpb ON fpb.id = fs.fee_programme_batch_id LEFT JOIN fee_plan fp ON fp.id = fs.fee_plan_id LEFT JOIN programme p ON p.programme_id = fs.programme_id LEFT JOIN department d ON d.department_id = p.department_id WHERE fp.id IS NOT NULL;



-- Module: Timetable — Lesson check
-- Lessons for a specific class on a given date with faculty, cancellation and attendance-taken flags.

select l.id,c.id as class_id,t.name, c.batch, cc.course_name,cc.course_code, l.start,l.end, concat(ua.f_name," ",ua.l_name) as faculty_name, l.is_cancelled, l.attendance_taken from lesson l left join class c on c.id = l.class_id left join course cc on cc.course_id = c.course_id left join user_attributes ua on ua.ukid = l.faculty_id left join term t on t.id = c.term_id where  date(start) = "2024-03-22" and c.id = 119;


-- Module: Attendance — Student lesson attendance
-- Per-student lesson attendance with course, faculty and status for a given date.

select ca.ukid, concat(ua.f_name," ",ua.l_name) as student_name,ua.registration_id,a.email,p.programme_name,d.department_name,l.description as lesson,cc.course_code,cc.course_name,group_concat(ua2.f_name," ",ua2.l_name) as Faculty,l.start,l.end, t2.status from class_attendance ca left join lesson l on l.id = ca.lesson_id left join user_attributes ua on ua.ukid = ca.ukid left join UDC_09_USER_ATTENDANCE_STATUS t2 on t2.id = ca.status_id left join timetable_lesson_course_class t3 on t3.lesson_id = l.id left join course cc on cc.course_id = t3.course_id left join authenticator a on a.ukid = ua.ukid left join student_profile sp on sp.ukid = ua.ukid left join programme p on p.programme_id = sp.programme_id left join department d on d.department_id = p.department_id left join class_faculty cf on cf.class_id = t3.class_id left join user_attributes ua2 on ua2.ukid = cf.faculty_id where date(l.start) = '2024-04-03' group by ca.id;


-- Module: Examination — Class-work assessment (CWA) configuration
-- Per-class CWA component/assessment configuration status, marks and faculty for selected terms.

select department_name as "Department Name", course_name as "Course Name", course_code as "Course Code", course_credits as "Course Credits", t.name as "Term Name", c.id as Clas_Id, c.batch as Class_name, cc2.class_id, cc2.name Parent_Component, if(count(distinct ccc.id) = 0, "NA", max(cc2.maximum_marks)) CWA_Maximum_Marks, count(distinct cc.id) Component_Count, count(distinct ca.id) Assessment_Count, coalesce(sum(ccc.weightage / 100 * coalesce(cc.maximum_marks, 0)) + sum(ccc.weightage / 100 * coalesce(ca.maximum_marks, 0)), 'NA') Total_Marks_Component_Assessment, group_concat(distinct concat(ua3.f_name, ' ', ua3.l_name)) Faculty_Name, if(count(distinct ccc.id) = 0, "No Component/Assessment Configured", if( sum(ccc.weightage / 100 * coalesce(cc.maximum_marks, 0)) + sum(ccc.weightage / 100 * coalesce(ca.maximum_marks, 0)) in (0, NULL), "No Component/Assessment Configured", if( sum(ccc.weightage / 100 * coalesce(cc.maximum_marks, 0)) + sum(ccc.weightage / 100 * coalesce(ca.maximum_marks, 0)) < max(cc2.maximum_marks), "Partially Configured", "Configuration Done" ) )) as Configuration_Status from class c left join class_component cc2 on cc2.class_id = c.id left join class_component_composition ccc on cc2.id = ccc.parent_component_id left join class_component cc on cc.id = ccc.component_id left join class_assessment ca on ca.id = ccc.assessment_id left join course co on co.course_id = c.course_id left join term t on t.id = c.term_id left join class_faculty cf on cf.class_id = c.id left join user_attributes ua3 on ua3.ukid = cf.faculty_id left join department d on co.department_id = d.department_id where cc2.is_final_component = 1 and t.id in (28,32,90,91,92) group by cc2.class_id;



-- Module: Staff Attendance — Punch pivot (v2)
-- Per-staff daily week-day-type, punch-in and punch-out (pivoted) for selected staff and date range.

select t1.ukid,concat(ua.f_name," ",ua.l_name) as name,registration_id,a.email,d.department_name,attendance_for_date, MAX(CASE WHEN action = 'WEEK_DAY_TYPE' THEN punch_timestamp ELSE '-' END) AS 'WEEK_DAY_TYPE', MAX(CASE WHEN action = 'PUNCH_IN' THEN punch_timestamp ELSE '-' END) AS 'PUNCH_IN', MAX(CASE WHEN action = 'PUNCH_OUT' THEN punch_timestamp ELSE '-' END) AS 'PUNCH_OUT', t2.status from staff_attendance_v2 t1 left join staff_attendance_v2_status t2 on t1.status_id = t2.id left join user_attributes ua on ua.ukid = t1.ukid left join faculty_profile fp on fp.ukid = ua.ukid left join admin_profile ap on ap.ukid = ua.ukid left join department d on d.department_id = coalesce(fp.department_id,ap.department_id) left join authenticator a on a.ukid = ua.ukid left join staff_attendance_v2_calculation_log t3 on t3.ukid = t1.ukid and t3.date = t1.attendance_for_date where attendance_for_date between '2024-05-01' and '2024-05-23' and t1.ukid in (748541,912501,457053,479724,457056,549701) and t3.action in ('PUNCH_IN','PUNCH_OUT','WEEK_DAY_TYPE') group by attendance_for_date,t1.ukid order by t1.ukid,attendance_for_date;


-- Module: Feedback — Response status incl. not-responded (NSHM)
-- Per student-faculty-course feedback response status (Submitted / Attempted / Not Attempted) for a session.

SELECT f2.session_name, term.name AS term, c.course_name, c.course_code, c1.batch AS class_name, ua.registration_id AS faculty_id, CONCAT(ua.f_name, ' ', ua.l_name) AS faculty_name, ua2.registration_id AS student_reg_id,a.email as student_email, CONCAT(ua2.f_name, ' ', ua2.l_name) AS student_name,t0.year_of_joining as batch, p.programme_name,d.department_name, fsts.submitted, IF(COALESCE(fsts.submitted, - 1) = 1, 'Submitted', IF(COALESCE(fsts.submitted, - 1) = - 1, 'Not Attempted', 'Attempted(Not Submitted)')) response_status FROM class_student t1 LEFT JOIN user_attributes ua2 ON ua2.ukid = t1.ukid LEFT JOIN student_profile t0 ON t1.ukid = t0.ukid LEFT JOIN class_faculty t2 ON t1.class_id = t2.class_id LEFT JOIN user_attributes ua ON t2.faculty_id = ua.ukid left join authenticator a on a.ukid = ua.ukid LEFT JOIN programme p ON t0.programme_id = p.programme_id left join department d on d.department_id = p.department_id LEFT JOIN class c1 ON t1.class_id = c1.id LEFT JOIN course c ON c1.course_id = c.course_id LEFT JOIN term term ON term.id = c1.term_id LEFT JOIN feedback_session f2 ON f2.term_id = term.id LEFT JOIN feedback_course_faculty_template t3 ON t3.class_id = t2.class_id AND t3.faculty_ukid = t2.faculty_id AND f2.id = t3.session_id LEFT JOIN feedback_session_student f1 ON f1.student_ukid = t1.ukid AND f1.session_id = f2.id LEFT JOIN feedback_student_template_status fsts ON fsts.feedback_course_faculty_template_id = t3.id AND fsts.student_session_id = f1.id WHERE f2.id IN(8) AND t2.faculty_id IS NOT NULL;


-- Module: Attendance — Faculty attendance entries
-- Attendance entries recorded by a faculty for selected courses with IST timestamps.

select ca.id,c.course_code,c.course_name,cc.type,cc.batch,l.start as lesson_start,l.end as lesson_end,CONVERT_TZ(ca.attendance_timestamp, '+00:00', '+05:30') AS attendance_timestamp,ca.attendance_timestamp,concat(ua.f_name," ",ua.l_name) as faculty, ua.registration_id as faculty_id from class_attendance ca left join timetable_lesson_course_class t1 on t1.lesson_id = ca.lesson_id left join course c on c.course_id = t1.course_id left join timetable_lesson_slot_faculties t2 on t2.lesson_id = ca.lesson_id left join lesson l on l.id = ca.lesson_id left join class cc on t1.class_id = cc.id left join user_attributes ua on ua.ukid = t2.faculty_id where t2.faculty_id = '848036' and c.course_code in ('LAWS203','LAWS201','LAWS201')




-- Module: CHC (Campus Help Centre) — Form & work-centre configuration
-- Service form fields (with options/attachments) and work-centre actions for a service (id 55).

select service_name,form_name,field_name,element,Is_Mandatory,auto_fill,element_options from
(select t2.service_id,t3.title as service_name, t2.title as form_name,  t1.name as field_name,t1.element,if(t1.is_mandatory=1,'Mandatory','Non-Mandatory') as Is_Mandatory, coalesce(t1.user_field_identifier,'-') as auto_fill,coalesce(group_concat(t4.label),'-') as element_options from chc_request_form_field t1 left join chc_request_form t2 on t2.id = t1.form_id left join chc_service t3 on t3.id = t2.service_id left join chc_request_form_field_element_option t4 on t4.field_id = t1.id group by t1.id
union all
select t2.service_id,t3.title as service_name,t2.title as form_name, t1.attachment_label as field_name,'attachment' as element,if(t1.is_mandatory=1,'Mandatory','Non-Mandatory') as Is_Mandatory,'-' as auto_fill,'-' as element_options from chc_request_form_attachment t1 left join chc_request_form t2 on t1.form_id = t2.id left join chc_service t3 on t3.id = t2.service_id) t11 where t11.service_id = 55;

-- Work-centre actions and parent work-centre per service (id 55).
select t3.title as service_name,t2.title as workcenter_name,coalesce(t4.title,'-') as parent_workcenter, group_concat(concat(t1.name,'(',t1.is_termination_action,')')) as 'actions(is termination)'  from chc_work_centre_action t1 left join chc_work_centre t2 on t2.id = t1.work_centre_id left join chc_service t3 on t3.id = t2.service_id left join chc_work_centre t4 on t4.id = t2.parent_work_centre_id where t2.service_id = 55 group by t1.work_centre_id order by t2.service_id,t2.is_closure_work_centre,t2.parent_work_centre_id;


-- Module: Examination — Hall tickets generated
-- Generated hall tickets per student with hall-ticket number, programme and department for an enrolment session.

select t1.enrollment_session_id,ee.hall_ticket_id,t1.id,ee.hall_ticket_number,student_ukid,t1.media_id,generated_by_ukid,concat(ua.f_name," ",ua.l_name) as student_name,programme_name,department_name,sp.year_of_joining from ems_enrollment_session_student_hall_ticket t1 left join student_profile sp on sp.ukid = t1.student_ukid left join programme p on p.programme_id = sp.programme_id left join department d on d.department_id = p.department_id left join user_attributes ua on ua.ukid = sp.ukid left join ems_enrollment_session_student ee on ee.hall_ticket_id =t1.id where enrollment_session_id = 7 and hall_ticket_id is not null;

-- Module: Examination — CGPA report
-- Per-student CGPA (and re-exam CGPA) per examination/term with programme/department and generated-by details.

select exam_id,t2.name as exam_name,t.name as term_name,t1.student_ukid,ua.registration_id,concat(ua.f_name,' ',ua.l_name) as student_name,ex.programme_name,ex.department_name,t1.cgpa,coalesce(re_exam_cgpa,'-') as re_exam_cgpa, concat(ua2.f_name,' ',ua.l_name) as generated_by,date(generated_timestamp) as gererated_on from ems_examination_student_cgpa t1 left join ems_examination t2 on t2.id = t1.exam_id left join term t on t.id = t2.term_id left join user_attributes ua on ua.ukid = t1.student_ukid left join user_attributes ua2 on ua2.ukid = t1.generated_by 
left join (select sp.ukid,p.programme_name,d.department_name from student_profile sp left join programme p on p.programme_id = sp.programme_id left join department d on d.department_id = p.department_id) ex on ex.ukid = t1.student_ukid
 group by t1.student_ukid,t1.exam_id,t1.id;



-- Module: CHC (Campus Help Centre) — Leave approval matrix
-- Approver hierarchy per CHC leave service/work-centre with approver department for selected services.

select t2.service_id,t2.id as wc_id,t1.ukid as approvee_ukid,concat(ua2.f_name,' ',ua2.l_name) as approvee_name,ua2.registration_id as approvee_reg_id,ex.service_name,ex.workcenter_name,ex.approver_name,ex.registration_id as approver_reg_id,ex.approver_department from chc_service_user t1 left join chc_work_centre t2 on t2.service_id = t1.service_id left join (select t3.id as service_id,t3.title as service_name,t2.id as workcenter_id,t2.title as workcenter_name,concat(ua.f_name,' ',ua.l_name) as approver_name,ua.registration_id,d.department_name as approver_department,coalesce(t4.title,'-') as parent_workcenter, group_concat(concat(t1.name,'(',t1.is_termination_action,')')) as 'actions(is termination)'  from chc_work_centre_action t1 left join chc_work_centre t2 on t2.id = t1.work_centre_id left join chc_service t3 on t3.id = t2.service_id left join chc_work_centre t4 on t4.id = t2.parent_work_centre_id 
left join chc_work_centre_member cwcm on cwcm.work_centre_id = t2.id left join user_attributes ua on ua.ukid = cwcm.ukid left join faculty_profile fp on fp.ukid = ua.ukid left join admin_profile ap on ap.ukid = ua.ukid left join department d on d.department_id = coalesce(fp.department_id,ap.department_id)
where t2.service_id in (4,40,41,42,43,45,46,47) group by t1.work_centre_id order by t2.service_id,t2.is_closure_work_centre,t2.parent_work_centre_id) ex on ex.service_id = t2.service_id and ex.workcenter_id = t2.id 
left join user_attributes ua2 on ua2.ukid = t1.ukid
where t1.is_deleted = 0;


-- Module: Fee Management (v2) — Fee-head ledger summary
-- Per-student fee-head payable vs paid (from accounting ledger) with pending amount and fine days for selected fee heads.

SELECT sfv.id, sfv.ukid, p.programme_name, d.department_name, q.name, sp.year_of_joining AS 'Batch', sp.sequence_id, CONCAT(ua.f_name, ' ', ua.l_name) student_name, coalesce(sp.application_number,ps.application_number) as application_number, ua.registration_id,ua.user_type, IF(a.is_active = 1, 'Active', 'Deactive') Student_status, 'Fees Management' AS Module, fs.academic_year, ft.name AS 'Fee Head Name',t1.voucher_number, ROUND(COALESCE(aglei.amount, 0), 2) AS 'Payable Amount', ROUND(COALESCE(t1.paid, 0), 2) 'Paid Amount', ROUND(COALESCE(aglei.amount, 0), 2) - ROUND(COALESCE(t1.paid, 0), 2) Pending,t1.paid_on, DATE(sfv.created_timestamp) created_timestamp, fs.due_date,if(t1.paid_on > fs.due_date,datediff(curdate(),fs.due_date),0) fine_days FROM student_fee_v2 sfv LEFT JOIN accounting_general_ledger_entry agle ON sfv.ukid = agle.party_ukid LEFT JOIN accounting_general_ledger_entry_item aglei ON agle.voucher_number = aglei.parent_general_ledger_number LEFT JOIN accounting_account aa ON aa.id = aglei.debit_account_id LEFT JOIN fee_type ft ON ft.id = aa.entity_id LEFT JOIN user_attributes ua ON ua.ukid = sfv.ukid LEFT JOIN student_profile sp ON sp.ukid = sfv.ukid left join prospective_student ps on ps.ukid = ua.ukid LEFT JOIN programme p ON p.programme_id = coalesce(sp.programme_id,ps.programme_id) LEFT JOIN department d ON d.department_id = p.department_id LEFT JOIN authenticator a ON a.ukid = sfv.ukid LEFT JOIN fee_structure fs ON fs.id = sfv.fee_structure_id LEFT JOIN quota q ON q.id = sp.quota_id LEFT JOIN (SELECT t1.party_ukid AS ukid, ft.name NAMEk, sum(aglei.amount) paid, t1.entity_id, agleir.outstanding_amount_for_journal_entry_item, agleir.general_ledger_entry_item_voucher_number as voucher_number, max(CONVERT_TZ(aglei.transaction_date_time, '+00:00', '+05:30')) AS paid_on FROM accounting_general_ledger_entry t1 LEFT JOIN accounting_general_ledger_entry_item aglei ON t1.voucher_number = aglei.parent_general_ledger_number LEFT JOIN accounting_account aa ON aa.id = aglei.credit_account_id LEFT JOIN fee_type ft ON ft.id = aa.entity_id LEFT JOIN accounting_general_ledger_entry_item_reference agleir ON agleir.general_ledger_entry_item_voucher_number = aglei.voucher_number WHERE t1.module_action IN ('online_payment' , 'offline_payment') AND t1.is_reversed = 0 AND aglei.credit_account_id IN (SELECT id FROM accounting_account WHERE entity = 'fee_head_id') GROUP BY party_ukid , ft.name) t1 ON t1.ukid = sfv.ukid AND t1.NAMEk = ft.name WHERE agle.module_action IN ('due_creation' , 'opening_balance_due') and ft.name in ('CAUTION MONEY 2024-26','TUITION FEE 2024-26','E-BOOKS/STUDY MATERIAL 2024-26','EXAMINATION FEE 2024-26','IT INFRASTRUCTURE 2024-26','STUDENT WELFARE 2024-26','DEVELOPMENT FEE 2024-26','ALUMNI - LIFE MEMBERSHIP 2024-26') and sfv.ukid = 1005488 GROUP BY sfv.ukid , ft.name ,voucher_number;

-- Module: Fee Management (v2) — Overall fee report
-- Per-student v2 fee summary: applicable, carry-over, scholarship, waiver, payable, paid and pending amounts.

select ua.registration_id,concat(ua.f_name,' ',ua.l_name) as name,a.email,a.phone,p.programme_name,coalesce(sp.year_of_joining,ps.year_of_joining) year_of_joining,year,q.name as quota,sp.academic_status,sp.admission_type,sf.applicable_fee,carry_over,penalty_amount,total_sponsor_scholarship_amount_applied,total_waiver_scholarship_amount_applied,total_payable,paid_amount,pending_amount,if(a.is_active = 1,'Active','Inactive') as student_status from student_fee_v2 sf left join user_attributes ua on ua.ukid = sf.ukid left join authenticator a on a.ukid = ua.ukid left join student_profile sp on sp.ukid = sf.ukid left join prospective_student ps on ps.ukid = sf.ukid left join quota q on q.id = coalesce(sp.quota_id,ps.quota_id) left join programme p on p.programme_id = coalesce(sp.programme_id,ps.programme_id) where  sf.is_active = 1;
-- Raw active student_fee_v2 rows.
select * from student_fee_v2 where is_active = 1;


-- Module: Dues Management (v2) — Dues report
-- Per-student v2 dues with category, due/penalty/waiver/paid/pending amounts and status.

select t1.student_ukid,ua.registration_id,a.email,concat(ua.f_name,' ',ua.l_name) as student_name,p.programme_name,d.department_name,t1.due_type,t1.entity,t4.category,t2.due_amount,t2.penalty_amount,t2.waiver_amount,t2.total_amount,t2.paid_amount,t2.pending_amount,t1.remarks,t1.due_date,t1.status as category_status,t3.status as overall_status from dues_v2 t1 left join dues_finance_v2 t2 on t2.dues_id = t1.id left join dues_student_status_v2 t3 on t3.ukid = t1.student_ukid left join dues_category_v2 t4 on t4.id = t1.due_category_id left join student_profile sp on sp.ukid = t1.student_ukid left join user_attributes ua on ua.ukid = sp.ukid left join authenticator a on a.ukid = ua.ukid left join programme p on p.programme_id = sp.programme_id left join department d on d.department_id = sp.department_id;


-- Module: Fee Management (v2) — Detailed fee report
-- Per-student v2 fee detail with fee plan, sequence, waiver/scholarship, payable, paid, pending and carry-over.

select sf.ukid,concat(ua.f_name,' ',ua.l_name) as stduent_name,coalesce(ua.registration_id,'-') as registration_id,coalesce(spp.application_number,ps.application_number,'-') as application_no,coalesce(spp.year_of_joining,ps.year_of_joining) as Batch,a.email,ua.user_type, spp.year,p.programme_name,d.department_name,q.name as quota,fp.name as fee_plan ,fs.sequence,if(fs.is_active = 1,'Active','Inactive') as fee_plan_status,applicable_fee,total_waiver_scholarship_amount_applied,total_waiver_amount_applied,penalty_amount,sf.due_date,total_payable,paid_amount,pending_amount,carry_over,initiated_from from student_fee_v2 sf left join fee_structure fs on fs.id = sf.fee_structure_id left join fee_plan fp on fp.id = fs.fee_plan_id
left join student_profile spp on spp.ukid = sf.ukid left join prospective_student ps on ps.ukid = sf.ukid left join user_attributes ua on ua.ukid = coalesce(spp.ukid,ps.ukid) left join authenticator a on a.ukid = ua.ukid left join programme p on p.programme_id = coalesce(spp.programme_id,ps.programme_id) left join department d on d.department_id = p.department_id left join quota q on q.id = coalesce(spp.quota_id,ps.quota_id);

-- Module: Mess Management — Coupon usage report
-- Per-student mess coupon usage by date, meal and mess for a date range.

select date_format(ms.date,'%d-%m-%Y') as Date,t1.ukid,concat(ua.f_name,' ',ua.l_name) as Name,ua.registration_id 'Registration ID',t1.code as 'Availed Coupon',convert_tz(t1.applied_on,'+00:00','+05:30') 'Last Availed On',mm.name as 'Mess Name',m.name as 'Meal Name',a.email 'Admin Account',t1.meal_availed_count as 'Coupons Used' from user_mess_schedule t1 left join mess_schedule ms on ms.id = t1.mess_schedule_id left join meal m on m.id = ms.meal_id left join mess mm on mm.id = ms.mess_id left join user_attributes ua on ua.ukid = t1.ukid left join authenticator a on a.ukid = t1.applied_by where ms.date between '2024-07-01' and '2024-07-20' order by ms.date;

-- Module: Course Registration (AMS) — Cohort & timetable configuration
-- Per-course cohort/class-group counts and timetable-configuration status for selected terms, plus related registration/cohort breakdowns. (First query uses Presto/Athena dialect.)

SELECT t.name AS term_name, d.department_name, c.course_name, c.course_code, COUNT(t1.id) AS cohorts_classgroups_created, SUM(t1.lesson_configured) timetable_configured_for, CASE WHEN COUNT(t1.id) != SUM(t1.lesson_configured) THEN CONCAT('Time table not configured for class ids - ', COALESCE( CONCAT_WS(', ', ARRAY_JOIN( ARRAY_AGG( CASE WHEN t1.lesson_configured = 0 THEN CAST(t1.id AS VARCHAR) ELSE NULL END ), ', ' ) ), '') ) ELSE '' END AS remarks FROM ( Select id, course_id, term_id, if(total_lessons>0, 1, 0) lesson_configured from class ) t1 LEFT JOIN course c ON c.course_id = t1.course_id LEFT JOIN department d ON d.department_id = c.department_id LEFT JOIN term t ON t.id = t1.term_id WHERE term_id IN (86,85) GROUP BY t1.term_id , t1.course_id,t.name,d.department_name,c.course_name,c.course_code;

-- Per-student registration & post-registration status with fee-due eligibility for a session.
select t5.ukid as ukid, css.session_name, t5.registration_id, concat(t5.f_name, t5.l_name) as student_name, email, department_name, programme_name, batch_year, coalesce(registration_status, 'NOT_STARTED') registration_status, coalesce(post_registration_status, 'NOT_STARTED') post_registration_status, if( is_eligible_for_registration = 1, 'Eligible', 'Non Eligible' ) registration_eligibility_status, if(is_active = 1, 'Active', 'INactive') student_status, Settings_configured, coalesce(sum(ex.amount_due),0) as amount_due,CASE WHEN coalesce(sum(ex.amount_due),0) IS NOT NULL THEN CASE WHEN coalesce(sum(ex.amount_due),0) > 0 THEN 'Not Eligible' ELSE 'Eligible' END ELSE 'No due data found' END as fee_status, CASE WHEN CASE WHEN coalesce(sum(ex.amount_due),0) IS NOT NULL THEN CASE WHEN coalesce(sum(ex.amount_due),0) > 0 THEN 'Not Eligible' ELSE 'Eligible' END ELSE 'No due data found' END = 'Not Eligible' THEN 'Not Eligible' WHEN coalesce(registration_status, 'NOT_STARTED') = 'COMPLETED' OR coalesce(post_registration_status, 'NOT_STARTED') = 'COMPLETED' THEN 'Completed' ELSE 'Eligible' END as updated_status from student_profile t3 left join ams_course_registration_student t1 on t1.ukid = t3.ukid left join ams_course_registration_settings t2 on t2.programme_id = t3.programme_id and t2.batch_year = t3.year_of_joining and t1.ams_course_registration_setting_id = t2.id left join course_registration_session css on css.session_id = cast(t2.session_id as varchar) left join user_attributes t5 on t1.ukid = t5.ukid left join department d on t3.department_id = d.department_id left join programme p on t3.programme_id = p.programme_id left join authenticator a on t3.ukid = a.ukid left join (select ukid, amount_due from student_fee sf where is_active = 1 and amount_due > 0 union all select d.ukid,df.due_amount amount_due from dues_finance df left join dues d on d.id =df.due_id where df.due_amount > 0) ex on ex.ukid = t3.ukid where a.is_active in (1) and t2.session_id = 8 group by t5.ukid, css.session_name, t5.registration_id, concat(t5.f_name, t5.l_name), email, department_name, programme_name, batch_year, coalesce(registration_status, 'NOT_STARTED') , coalesce(post_registration_status, 'NOT_STARTED') , if( is_eligible_for_registration = 1, 'Eligible', 'Non Eligible' ) , if(is_active = 1, 'Active', 'INactive') , Settings_configured;

-- Per-course students-registered vs class-groups-created vs students-added counts for selected terms.
SELECT t9.programme_name, t11.department_name, t15.batch_year, t5.course_code, t5.course_name, t5.course_id,t.id as term_id, t.name term_name, count(distinct t3.ukid) as students_registered, count(distinct cl.id) as total_class_groups_created, count(distinct cs.ukid) as students_added_in_class_group FROM ams_registration_session_courses t5 LEFT JOIN course_registration_session crs ON crs.id = t5.session_id LEFT JOIN ams_registration_type_clusters t2 on t2.session_course_id = t5.id left join ams_course_registration_student_courses t1 ON t1.ams_registration_type_cluster_id = t2.id LEFT JOIN ams_course_registration_student t3 ON t1.ams_course_registration_student_id = t3.id LEFT JOIN ams_course_registration_settings acrs ON acrs.id = t3.ams_course_registration_setting_id LEFT JOIN ams_course_registration_student_session t4 ON t1.ams_course_registration_student_session_id = t4.id and t4.ams_course_registration_student_id = t3.id LEFT JOIN curriculum_cluster_set t6 ON t2.curriculum_cluster_set_id = t6.id LEFT JOIN course_registration_type t7 ON t6.course_registration_type_id = t7.id LEFT JOIN student_profile t8 ON t3.ukid = t8.ukid LEFT JOIN user_attributes t10 ON t10.ukid = t8.ukid LEFT JOIN programme_section t12 ON t8.section_id = t12.programme_section_id LEFT JOIN authenticator t13 ON t8.ukid = t13.ukid LEFT JOIN curriculum_cluster t14 ON t6.curriculum_cluster_id = t14.id LEFT JOIN curriculum t15 ON t14.curriculum_id = t15.id LEFT JOIN programme t9 ON t15.programme_id = t9.programme_id LEFT JOIN department t11 ON t11.department_id = t9.department_id LEFT JOIN programme_specialisation_mapping t16 ON t15.programme_specialisation_mapping_id = t16.id LEFT JOIN specialisation t17 ON t16.specialisation_id = t17.id LEFT JOIN term t ON t.id = crs.term_id left join class cl on cl.course_id = t5.course_id and cl.term_id = t.id left join class_student cs on cs.class_id = cl.id and cs.ukid = t3.ukid where (is_course_active = 1 or is_activated_from_curriculum = 1) and t.id in (85,86) group by t9.programme_name, t11.department_name, t15.batch_year, t5.course_code, t5.course_id,t.id, t5.course_name, t5.course_id, t.name order by t5.course_id

-- Cohort/class-group counts with timetable-not-configured class ids (MySQL variant).
SELECT t.name AS term_name, d.department_name, c.course_name, c.course_code, COUNT(t1.id) AS cohorts_classgroups_created, SUM(t1.lesson_configured) timetable_configured_for, if(count(t1.id)!=sum(t1.lesson_configured),concat('Time table not configured for classes ids - ',group_concat(if(lesson_configured = 0, concat(t1.id,','), '') separator '')),'') as remarks FROM ( Select id, course_id, term_id, if(total_lessons>0, 1, 0) lesson_configured from class ) t1 LEFT JOIN course c ON c.course_id = t1.course_id LEFT JOIN department d ON d.department_id = c.department_id LEFT JOIN term t ON t.id = t1.term_id WHERE term_id IN (86,85) GROUP BY t1.term_id , t1.course_id;

-- Per-course cohort, lesson, student and faculty totals for a term.
select t.name as term_name,d.department_name,c.course_name,c.course_code, count(t1.id) as cohorts,sum(t1.total_lessons) lessons,sum(t1.total_students) students,sum(t1.total_faculties) faculties from class t1 left join course c on c.course_id = t1.course_id left join department d on d.department_id = c.department_id left join term t on t.id = t1.term_id where term_id in (85)  group by t1.term_id, t1.course_id;
-- Per-course timetable lesson counts for a term.
select t.name as term,d.department_name,cc.course_code,count(l.id) from timetable_lesson_course_class l left join class c on c.id = l.class_id left join course cc on cc.course_id = c.course_id left join department d on d.department_id = cc.department_id left join term t on t.id = c.term_id where c.term_id in (86) group by c.term_id,cc.course_id;


-- Per-course students-registered vs class-groups vs students-added (alternate join path).
SELECT t9.programme_name, t11.department_name, t8.year_of_joining, t5.course_code, t5.course_name, t.name term_name,count(distinct t3.ukid) as students_registered, count(distinct cl.id) as total_class_groups_created,count(distinct cs.ukid) as students_added_in_class_group FROM ams_course_registration_student_courses t1 LEFT JOIN ams_registration_type_clusters t2 ON t1.ams_registration_type_cluster_id = t2.id LEFT JOIN ams_course_registration_student t3 ON t1.ams_course_registration_student_id = t3.id LEFT JOIN ams_course_registration_settings acrs ON acrs.id = t3.ams_course_registration_setting_id LEFT JOIN ams_course_registration_student_session t4 ON t1.ams_course_registration_student_session_id = t4.id LEFT JOIN ams_registration_session_courses t5 ON t2.session_course_id = t5.id LEFT JOIN curriculum_cluster_set t6 ON t2.curriculum_cluster_set_id = t6.id LEFT JOIN course_registration_type t7 ON t6.course_registration_type_id = t7.id LEFT JOIN student_profile t8 ON t3.ukid = t8.ukid LEFT JOIN user_attributes t10 ON t10.ukid = t8.ukid LEFT JOIN programme_section t12 ON t8.section_id = t12.programme_section_id LEFT JOIN authenticator t13 ON t8.ukid = t13.ukid LEFT JOIN curriculum_cluster t14 ON t6.curriculum_cluster_id = t14.id LEFT JOIN curriculum t15 ON t14.curriculum_id = t15.id LEFT JOIN programme t9 ON t15.programme_id = t9.programme_id LEFT JOIN department t11 ON t11.department_id = t9.department_id LEFT JOIN programme_specialisation_mapping t16 ON t15.programme_specialisation_mapping_id = t16.id LEFT JOIN specialisation t17 ON t16.specialisation_id = t17.id LEFT JOIN course_registration_session crs ON crs.id = acrs.session_id LEFT JOIN term t ON t.id = crs.term_id left join class cl on cl.course_id = t5.course_id and cl.term_id = t.id left join class_student cs on cs.class_id = cl.id and cs.ukid = t3.ukid WHERE t.id in (85,86) group by t9.programme_name, t11.department_name, t8.year_of_joining, t5.course_code, t5.course_name, t5.course_id, t.name order by t5.course_id


-- Module: Booth — Booth members report
-- Students who are members of student-category booths with programme, department and active status.

select b.booth_id,bc.category_name,b.booth_name,t1.ukid,ua.registration_id,a.email,concat(ua.f_name,' ',ua.l_name) as student_name,p.programme_name,d.department_name,pss.programme_section_name,ua.user_type,if(a.is_active=1,'Active','Inactive') as status from user_group_members t1 left join booth b on b.user_group_id = t1.group_id left join student_profile sp on sp.ukid = t1.ukid  left join user_attributes ua on ua.ukid = t1.ukid left join admin_profile ap on ap.ukid = t1.ukid left join faculty_profile fp on fp.ukid = t1.ukid left join department d on d.department_id = coalesce(ap.department_id,fp.department_id,sp.department_id) left join programme_section pss on pss.programme_section_id = sp.section_id left join programme p on p.programme_id = sp.programme_id left join authenticator a on a.ukid = t1.ukid left join booth_categories bc on bc.category_id = b.category where b.category = 7 and ua.user_type = 'student';


-- Module: Course Registration (AMS) — Cohort configuration status
-- Per-course cohort creation status (Created/Partially/Not) with count of unconfigured programme-batches for a session.

select session_name,t.name as term_name,course_id,course_code,course_name,department_name,coalesce(cohort_method,'-') cohort_method,if(ex.count>0,'Partially Created',if(cohort_status = 'CONFIGURED','Created','Not Created')) cohort_status,coalesce(ex.count,0) as 'Cohort not configured for' from ams_registration_session_courses t1 left join ams_cohort_configuration t2 on t1.id = t2.session_course_id left join department d on d.department_id = t1.department_id left join course_registration_session t3 on t3.id = t1.session_id left join term t on t.id = t3.term_id left join (select t1.session_course_id,count(registration_type_cluster_id) as count from (select registration_type_cluster_id,session_course_id from ams_registration_programme_batch t1 left join ams_registration_type_clusters t2 on t1.registration_type_cluster_id = t2.id and t2.is_deleted = 0) t1 left join (select programme_batch_id,session_course_id from ams_cohort_programme_batch_mapping t1 left join ams_cohort_configuration t2 on t2.id = t1.cohort_configuration_id ) t2 on t2.programme_batch_id = t1.registration_type_cluster_id and t1.session_course_id = t2.session_course_id where programme_batch_id is null group by session_course_id) ex on ex.session_course_id = t2.session_course_id where t1.session_id = 1 and (is_course_active =1 or is_activated_from_curriculum = 1) group by t1.id;

-- Module: Admission Management — All students (batch 2024)
-- Per-applicant admission summary: batch, programme, department, application no., form and application status for batch 2024.

SELECT t7.ukid, COALESCE(t11.year_of_joining, t14.year_of_joining) AS 'Batch', t7.user_type AS 'User Type', CONCAT(t7.f_name, ' ', t7.l_name) AS 'Student Name', COALESCE(t11.application_number, t14.application_number,'-') AS 'Application No.',coalesce(t7.registration_id,'-') as registration_id, t17.email AS Email, IF(COALESCE(t14.gender, t11.gender) LIKE 'male', 'Male', 'Female') AS Gender, COALESCE(t12.programme_name, t15.programme_name) Programme, COALESCE(t13.department_name, t16.department_name) Department, coalesce(t1.form_status,'-') 'Form Status', coalesce(t3.display_name,'-') AS 'Application Status', DATE(COALESCE(t14.created_timestamp, t11.created_timestamp)) AS created_on FROM user_attributes t7 left join admission_student_status t1 on t1.ukid = t7.ukid LEFT JOIN student_admission_form_status t2 ON t2.ukid = t1.ukid LEFT JOIN admission_form_status t3 ON t3.id = t2.status_id LEFT JOIN prospective_student t14 ON t14.ukid = t1.ukid LEFT JOIN student_profile t11 ON t7.ukid = t11.ukid LEFT JOIN programme t12 ON t12.programme_id = t11.programme_id LEFT JOIN department t13 ON t13.department_id = t12.department_id LEFT JOIN programme t15 ON t15.programme_id = t14.programme_id LEFT JOIN department t16 ON t16.department_id = t15.department_id LEFT JOIN authenticator t17 ON t17.ukid = coalesce(t14.ukid,t11.ukid) WHERE COALESCE(t11.year_of_joining, t14.year_of_joining) = 2024;


-- Module: Staff Management — Staff directory
-- Faculty and administrator directory with department, designation, gender and active status.

select ua.ukid,ua.user_type,ua.registration_id,concat(ua.f_name," ",ua.l_name) as name,a.email,coalesce(a.phone,'-') as phone,d.department_name,coalesce(fp.gender,ap.gender) as gender,coalesce(dg.name,'-') as designation,if(a.is_active=1,'Active','Inactive') as status  from user_attributes ua left join faculty_profile fp on fp.ukid = ua.ukid left join admin_profile ap on ap.ukid = ua.ukid left join department d on d.department_id = coalesce(fp.department_id,ap.department_id) left join authenticator a on a.ukid = ua.ukid left join designation dg on dg.id = coalesce(ap.designation_id,fp.designation_id) where ua.user_type in ('faculty','administrator')


-- Module: Timetable — Attendance summary report
-- Per-lesson timetable with faculty, students present and attendance percentage over the last six months.

SELECT DATE(l.start), CONCAT(ua.f_name, ' ', ua.l_name) AS faculty, t.name, c.course_code, c.course_name, cl.type, c.course_credits, cl.id AS class_id, cl.batch AS class_name, cll.total_students, IF(t11.attendance_taken IS NULL, 'No', 'Yes') AS attendance_taken,t11.attendance_status, ca.lesson_id,time(l.start) as lesson_start,time(l.end) lesson_end, COALESCE(l.title, '-') AS lesson_name, COALESCE(l.description, '-') AS lesson_description, tsp.stduents_present, ROUND(((tsp.stduents_present / cll.total_students) * 100), 2) AS percent_present FROM timetable_lesson_course_class t11 LEFT JOIN lesson l ON l.id = t11.lesson_id LEFT JOIN timetable_lesson_slot_faculties cf ON cf.lesson_id = t11.lesson_id LEFT JOIN class_attendance ca ON ca.lesson_id = t11.lesson_id LEFT JOIN user_attributes ua ON ua.ukid = cf.faculty_id LEFT JOIN class cl ON cl.id = t11.class_id LEFT JOIN term t ON t.id = cl.term_id LEFT JOIN course c ON c.course_id = cl.course_id LEFT JOIN (SELECT class_id, COUNT(*) AS total_students FROM class_student GROUP BY class_id) cll ON cll.class_id = cl.id LEFT JOIN (SELECT DATE(l.start), ll.lesson_id, COUNT(*) stduents_present FROM class_attendance ca LEFT JOIN timetable_lesson_course_class ll ON ll.lesson_id = ca.lesson_id LEFT JOIN lesson l ON l.id = ll.lesson_id WHERE ca.status_id = 1 AND requires_attendance = 1 AND is_cancelled = 0 GROUP BY DATE(l.start) , ll.lesson_id) tsp ON tsp.lesson_id = t11.lesson_id WHERE ca.status_id = 1 AND DATE(l.start) >= CURRENT_DATE - INTERVAL '6' MONTH GROUP BY DATE(attendance_timestamp) , lesson_id ORDER BY DATE(l.start) DESC;


-- Module: Classroom Resources — Resource listing
-- Classroom resources (media and URLs) per class with name, location, type and faculty.

SELECT cr.class_id,c.batch,cc.course_code,cc.course_name,group_concat(concat(ua.f_name," ",ua.l_name)) as 'Faculty/s', ex.name as 'Resourse name', ex.location, ex.type as 'Resourse Type', ex.added_on FROM (SELECT mo.media_id AS id, media_detail name, media_location location, media_type type, last_modified AS added_on FROM media_object mo LEFT JOIN classroom_resource cr ON cr.media_id = mo.media_id WHERE cr.media_id IS NOT NULL UNION ALL SELECT ur.id, url_name name, url AS location, 'URL' AS type, ur.created_timestamp AS added_on FROM weburl ur LEFT JOIN classroom_resource cr ON cr.url_id = ur.id WHERE cr.url_id IS NOT NULL) ex LEFT JOIN classroom_resource cr ON COALESCE(cr.media_id, cr.url_id) = ex.id left join class c on c.id = cr.class_id left join course cc on cc.course_id = c.course_id left join class_faculty cf on cf.class_id = c.id left join user_attributes ua on ua.ukid = cf.faculty_id group by ex.id ;


-- Module: Curriculum — Cluster-set course listing
-- Curriculum cluster-sets with programme, batch, sequence, registration type and mapped courses.

select ccs.id as curriculumClusterSetId,ccs.name as ccs_name,c.programme_id,p.programme_name,c.batch_year,cc.sequence,ccs.course_registration_type_id,crt.name as courseRegType, concat(c.programme_id,"-",c.batch_year,"-",sequence,"-",course_registration_type_id) keyy,ccc.course_code,ccc.course_name,ccc.course_credits from curriculum c left join curriculum_cluster cc on cc.curriculum_id = c.id left join curriculum_cluster_set ccs on ccs.curriculum_cluster_id = cc.id left join course_registration_type crt on crt.id = ccs.course_registration_type_id left join programme p on p.programme_id = c.programme_id left join curriculum_course ccc on ccc.curriculum_cluster_set_id = ccs.id where  sequence is not null and ccc.course_code is not null and ccc.is_deleted = 0;

-- Module: Curriculum — Course component breakdown
-- Curriculum courses with per-component (Lecture/Practical/Tutorial/Project/Workshop) credit breakdown and offering department.

SELECT ccs.id AS curriculumClusterSetId, ccs.name AS ccs_name, c.programme_id, p.programme_name, c.batch_year, cc.sequence, ccs.course_registration_type_id, crt.name AS courseRegType, CONCAT(c.programme_id, '-', c.batch_year, '-', sequence, '-', course_registration_type_id) keyy, ccc.course_code,ex.LECTURE,ex.PRACTICAL,ex.TUTORIAL,ex.PROJECT,ex.WORKSHOP, ccc.course_name,d.department_name as course_offered_by_dept, ccc.course_credits FROM curriculum c LEFT JOIN curriculum_cluster cc ON cc.curriculum_id = c.id LEFT JOIN curriculum_cluster_set ccs ON ccs.curriculum_cluster_id = cc.id LEFT JOIN course_registration_type crt ON crt.id = ccs.course_registration_type_id LEFT JOIN programme p ON p.programme_id = c.programme_id LEFT JOIN curriculum_course ccc ON ccc.curriculum_cluster_set_id = ccs.id left join course cccc on cccc.course_id = ccc.course_id left join department d on d.department_id = cccc.department_id left join (select cc.course_id,c.course_code, case when type = 'LECTURE' then cc.course_credits else '' end as LECTURE, case when type = 'PRACTICAL' then cc.course_credits else '' end as PRACTICAL, case when type = 'TUTORIAL' then cc.course_credits else '' end as TUTORIAL, case when type = 'PROJECT' then cc.course_credits else '' end as PROJECT, case when type = 'WORKSHOP' then cc.course_credits else '' end as WORKSHOP from course_component cc left join course c on cc.course_id = c.course_id group by cc.course_id) ex on ex.course_id = cccc.course_id WHERE sequence IS NOT NULL AND ccc.course_code IS NOT NULL;

-- Module: User Management — Acknowledgement report
-- Students with their latest acknowledgement timestamp, programme, quota and status.

SELECT a.ukid, concat(ua.f_name," ",ua.l_name) as "Student Name", a.email as Email, ua.registration_id as "Registration ID", sp.year_of_joining as "Batch",q.name as "Quota", p.programme_name as "Programme", d.department_name as "Department", upper(sp.gender) as Gender,sp.accommodation_type,if(a.is_active=1,"Active","Inactive") as Status,ex.acknowledgement_timestamp FROM authenticator a left join user_attributes ua on a.ukid = ua.ukid left join student_profile sp on a.ukid = sp.ukid left join programme p on sp.programme_id = p.programme_id left join quota q on q.id = sp.quota_id left join department d on sp.department_id = d.department_id left join (select a.ukid,registration_id,max(a.created_timestamp) as acknowledgement_timestamp from acknowledgement a left join user_attributes ua on ua.ukid = a.ukid group by a.ukid) ex on ex.ukid= ua.ukid where acknowledgement_timestamp is not null

-- Module: OBE — Course master report
-- Per-course OBE objectives, outcomes and syllabus modules with faculty, class and student counts.

SELECT t.name term_name, c.course_name, c.course_code, t1.code course_obj_code, t2.code CO_code, t2.description CO_desc, t2.difficulty_level_id BT_level, t3.module sylaabus_module_name, t3.title syllabus_title_name, cl.no_of_classes, c.course_credits, fac.faculty_name, stu.total_students FROM obe_course_objectives t1 LEFT JOIN obe_course_outcomes t2 ON t2.term_course_id = t1.term_course_id LEFT JOIN obe_course_syllabus t3 ON t3.term_course_id = t1.term_course_id LEFT JOIN term_course tc ON tc.id = t1.term_course_id LEFT JOIN term t ON t.id = tc.term_id LEFT JOIN course c ON c.course_id = tc.course_id LEFT JOIN department d ON d.department_id = c.department_id LEFT JOIN (SELECT term_course_id, CONCAT(ua.f_name, ' ', ua.l_name) AS faculty_name FROM term_course_faculty t1 LEFT JOIN user_attributes ua ON ua.ukid = t1.faculty_ukid WHERE is_deleted = 0) fac ON fac.term_course_id = tc.id LEFT JOIN (SELECT tc.id AS term_course_id, COUNT(*) no_of_classes, SUM(DISTINCT total_students) AS total_students FROM class c LEFT JOIN term_course tc ON tc.term_id = c.term_id AND tc.course_id = c.course_id GROUP BY tc.id) cl ON cl.term_course_id = tc.id LEFT JOIN (SELECT tc.id, COUNT(DISTINCT ukid) total_students FROM class_student cs LEFT JOIN class c ON c.id = cs.class_id LEFT JOIN term_course tc ON tc.term_id = c.term_id AND tc.course_id = c.course_id GROUP BY tc.id) stu ON stu.id = tc.id WHERE t1.is_deleted = 0 AND t2.is_deleted = 0 AND t3.is_deleted = 0 ORDER BY t1.id , t2.id , t3.id;

-- Module: Fee Management — Fee-plan to fee-type mapping
-- Fee-plan structure amounts per fee type and quota for each programme/batch/sequence.

SELECT fp.name AS fee_plan, p.programme_name, fs.batch_year, fs.sequence, ft.name AS fee_type_name, q.name AS quota, fps.amount, fp.status FROM fee_structure fs LEFT JOIN fee_plan fp ON fp.id = fs.fee_plan_id LEFT JOIN fee_plan_structure fps ON fps.fee_plan_id = fp.id LEFT JOIN fee_type ft ON ft.id = fps.fee_type_id LEFT JOIN quota q ON q.id = fps.quota_id LEFT JOIN programme p ON p.programme_id = fs.programme_id WHERE fp.id IS NOT NULL GROUP BY ft.id , q.id , fp.id;

-- Module: Classroom — Quiz master
-- Classroom quizzes with creator, course, marks, schedule and result-declaration timestamps.

select ua.registration_id,concat(ua.f_name," ",ua.l_name) created_by,c.batch,cc.course_code,cc.course_name,d.department_name,cq.title as quiz_title,cq.description,max_marks,quiz_start_time,quiz_end_time,quiz_duration,deadline_datetime,results_declared_datetime from classroom_quiz cq left join class c on c.id = cq.class_id left join user_attributes ua on ua.ukid = cq.creator_ukid left join course cc on cc.course_id = c.course_id left join department d on d.department_id = cc.department_id;

-- Module: Fee Management (v2) — Consolidated finance with excess
-- Per-student v2 fee summary including opening balance and excess (from accounting ledger) for active fees.

WITH RankedRows AS ( SELECT agle.party_ukid, ua.registration_id, aglei.amount, agleim.module_party_debit_account_balance, agleim.module_party_credit_account_balance, agle.module_action, aglei.debit_account_id, aglei.credit_account_id, agleim.created_timestamp, CASE WHEN aglei.debit_account_id = 20 THEN agleim.module_party_debit_account_balance WHEN aglei.credit_account_id = 20 THEN agleim.module_party_credit_account_balance END Excess, ROW_NUMBER() OVER (PARTITION BY agle.party_ukid ORDER BY agleim.created_timestamp DESC) AS row_numbe FROM accounting_general_ledger_entry_item_metadata agleim INNER JOIN accounting_general_ledger_entry_item aglei ON agleim.gl_entry_item_voucher_number = aglei.voucher_number INNER JOIN accounting_general_ledger_entry agle ON aglei.parent_general_ledger_number = agle.voucher_number LEFT JOIN user_attributes ua ON ua.ukid = agle.party_ukid WHERE aglei.debit_account_id = 20 OR aglei.credit_account_id = 20 ) SELECT ua.registration_id AS "Registration Id", ua.ukid, ps.application_number, CONCAT(ua.f_name, ' ', ua.l_name) student_name, a.email, COALESCE(d.department_name, d1.department_name) AS Department, COALESCE(p.programme_name, p1.programme_name) AS Program, COALESCE(sp.year_of_joining, ps.year_of_joining) AS Batch, IF(a.is_active = 1, 'Active', 'Deactive') AS Student_status, COALESCE(q.name, q1.name) Quota, 'Fee Management' AS Module, ROUND(sf.applicable_fee, 2) AS "Applicable Fee", ROUND(sf.total_sponsor_scholarship_amount_applied, 2) AS "Scholarship", ROUND(sf.total_waiver_amount_applied, 2) AS Waiver, ROUND(COALESCE(agl.Opening_balanace, 0), 2) AS "Opening Balance", ROUND(sf.carry_over, 2) AS "Carry Over", ROUND(sf.penalty_amount, 2) AS "Penalty Amount", ROUND(sf.total_payable, 2) AS "Total Payable", ROUND(sf.paid_amount, 2) AS "Paid Amount", ROUND(sf.pending_amount, 2) AS "Pending Amount", COALESCE (ROUND( RIGHT(big1.Excess, LENGTH(big1.Excess) - 1),2),0) Excess, DATE(sf.created_timestamp) AS created_timestamp FROM student_fee_v2 sf LEFT JOIN user_attributes ua ON ua.ukid = sf.ukid LEFT JOIN student_profile sp ON sf.ukid = sp.ukid LEFT JOIN programme p ON p.programme_id = sp.programme_id LEFT JOIN department d ON d.department_id = sp.department_id LEFT JOIN quota q ON q.id = sp.quota_id LEFT JOIN authenticator a ON a.ukid = sf.ukid LEFT JOIN prospective_student ps ON ps.ukid = ua.ukid LEFT JOIN programme p1 ON p1.programme_id = ps.programme_id LEFT JOIN department d1 ON d1.department_id = p1.department_id LEFT JOIN quota q1 ON q1.id = ps.quota_id LEFT JOIN (SELECT party_ukid, amount AS Opening_balanace FROM accounting_general_ledger_entry WHERE module_action = 'opening_balance_due' GROUP BY party_ukid, amount) agl ON agl.party_ukid = sf.ukid LEFT JOIN RankedRows big1 ON big1.party_ukid = sf.ukid AND big1.row_numbe = 1 WHERE sf.is_active = 1 


-- Module: Mentoring — Mentor-mentee mapping
-- Mentor and mentee details (contact, department, programme) for each mapping.

SELECT ua2.ukid AS mentor_ukid, ua2.registration_id AS mentor_reg_id, CONCAT(ua2.f_name, ' ', ua2.l_name) AS mentor_name, a2.email AS mentor_email, a2.phone AS mentor_phone, d.department_name mentor_dept_name , ua.ukid AS mentee_ukid, ua.registration_id AS mentee_reg_id, CONCAT(ua.f_name, ' ', ua.l_name) AS mentee_name, a.email AS mentee_email, a.phone AS mentee_phone, p.programme_name, d2.department_name mentee_dept_name FROM mentor_mapping m LEFT JOIN user_attributes ua ON ua.ukid = m.mentee_ukid LEFT JOIN user_attributes ua2 ON ua2.ukid = m.mentor_ukid LEFT JOIN authenticator a ON a.ukid = ua.ukid LEFT JOIN authenticator a2 ON a2.ukid = ua2.ukid LEFT JOIN faculty_profile fp ON fp.ukid = ua2.ukid LEFT JOIN department d ON d.department_id = fp.department_id LEFT JOIN student_profile sp ON sp.ukid = ua.ukid LEFT JOIN department d2 ON d2.department_id = sp.department_id LEFT JOIN programme p ON p.programme_id = sp.programme_id ORDER BY ua2.ukid 
-- Module: Classroom — Quiz questions & options
-- Quiz questions with options and correct-answer flag for selected quizzes.

select cq.class_id,t1.quiz_id,cq.title as quiz_title,t1.question_body,t1.type,t1.maximum_marks,cqo.option_body,cqo.is_correct from classroom_quiz_question t1 left join classroom_quiz cq on cq.id = t1.quiz_id left join classroom_quiz_option cqo on cqo.question_id = t1.id where cq.id in (58,59);

-- Module: Class — Class listing
-- Classes created after a date with course, term and faculty.

select t.name as term,c.id as class_id,c.batch as class_name,cc.course_name,cc.course_code,t.name as term_name,group_concat(ua.f_name," ",ua.l_name) as faculty_name,ua.registration_id as faculty_id,c.created_timestamp as class_created from class c left join course cc on cc.course_id = c.course_id left join term t on t.id = c.term_id left join class_faculty cf on cf.class_id = c.id left join user_attributes ua on ua.ukid = cf.faculty_id where date(c.created_timestamp) > '2024-01-01' group by c.id;

-- Module: Class — Class-student listing
-- Students enrolled in classes for a term with course and enrolment timestamp.

select cs.ukid,ua.registration_id,concat(ua.f_name," ",ua.l_name) as student_name,a.email,t.name as term,cc.batch as class_name,c.course_name,c.course_code,cs.created_timestamp from class_student cs left join class cc on cc.id = cs.class_id left join course c on c.course_id = cc.course_id left join term t on t.id = cc.term_id left join user_attributes ua on ua.ukid = cs.ukid left join authenticator a on a.ukid = ua.ukid left join student_profile sp on sp.ukid = ua.ukid left join programme p on p.programme_id = sp.programme_id left join department d on d.department_id = p.department_id where t.id = 12;

-- Module: Examination — Hall ticket detailed (generated / not generated)
-- Per-student exam course enrolments with hall-ticket generation status, parents' names and student/course details for a term.

SELECT ua.ukid, t.name Term_Name, ee.name Exam_Name, eet.name Exam_Type, ua.registration_id AS Regitration, a.email, IF(a.is_active = 1, 'Active', 'Inactive') AS is_active, CONCAT(ua.f_name, ' ', ua.l_name) Student_Name, d.department_name AS 'Department Name', p.programme_name AS 'Program Name',tc.course_name as "Course Name", tc.course_code as "Course Code", t1.type as "Course Type",t1.enrollment_status as "Enrollment Status", year_of_joining, COALESCE(UPPER(sp.gender), '-') Gender, q.name AS quota, academic_status, sp.year AS current_year, sequence_id AS semester, p.system AS programme_system, eee.hall_ticket_id, coalesce(eee.hall_ticket_number,'-') as hall_ticket_number, IF(eee.hall_ticket_number IS NOT NULL, 'Generated', 'Not Generated') is_hallticket_generated, coalesce(op.father,'-') as Father_Name, coalesce(op.mother,'-') as Mother_Name FROM ems_student_course_enrollment t1 left join ems_student_programme_enrollment t2 on t1.student_programme_enrollment_id = t2.id LEFT JOIN ems_examination ee ON ee.id = t2.exam_id left join term_course tc on tc.id = t1.term_course_id LEFT JOIN term t ON t.id = ee.term_id LEFT JOIN user_attributes ua ON ua.ukid = t2.ukid LEFT JOIN student_profile sp ON sp.ukid = ua.ukid LEFT JOIN department d ON d.department_id = sp.department_id LEFT JOIN programme p ON p.programme_id = sp.programme_id LEFT JOIN authenticator a ON a.ukid = sp.ukid LEFT JOIN quota q ON q.id = sp.quota_id LEFT JOIN ems_examination_type eet ON eet.id = t2.exam_type_id LEFT JOIN ems_enrollment_session ees ON ees.exam_id = ee.id LEFT JOIN ems_enrollment_session_student_hall_ticket t11 ON t11.student_ukid = sp.ukid AND t11.enrollment_session_id = ees.id LEFT JOIN ems_enrollment_session_student eee ON eee.hall_ticket_id = t11.id LEFT JOIN (SELECT ukid, MAX(CASE WHEN field_id = 1 THEN value END) AS father, MAX(CASE WHEN field_id = 12 THEN value END) AS mother FROM user_details_master_field_value WHERE field_id IN (1 , 12) AND value IS NOT NULL GROUP BY ukid) op ON op.ukid = sp.ukid WHERE t.id IN (73) GROUP BY sp.ukid , p.programme_id , sp.year_of_joining;


-- Module: User Management — Profile photo status
-- Per-student profile-photo updated/not-updated status with programme and batch.

SELECT ua.ukid, ua.registration_id, CONCAT(ua.f_name, ' ', ua.l_name) AS stduent_name, a.email, p.programme_name, sp.year_of_joining AS batch, IF(ua.media_id IS NULL, 'Not Updated', 'Updated') AS profile_photo_status, IF(a.is_active = 1, 'Active', 'Inactive') AS stduent_status FROM user_attributes ua LEFT JOIN authenticator a ON a.ukid = ua.ukid LEFT JOIN student_profile sp ON sp.ukid = ua.ukid LEFT JOIN programme p ON p.programme_id = sp.programme_id WHERE user_type = 'student' ;

-- Module: User Management — Extra student attributes (NAD)
-- Student-wise extra attributes (Aadhaar, ABC id, DOB, blood group, address, nationality, etc.) from custom fields.

select a.ukid,ad.value as aadhar,abc.value as abc,gen.gender,dob.value as dob,blood.value as blood,a.phone,a.email,fn.value as f_name,mn.value as m_name,blood.value as blood,addd.value as address,nat.value as nationality from authenticator a left join user_attributes ua on ua.ukid = a.ukid left join (select ukid,value from user_details_master_field_value where field_id = 48 and value is not null) ad on ad.ukid = a.ukid left join (select ukid,value from user_details_master_field_value where field_id = 1838 and value is not null) abc on abc.ukid = a.ukid left join (select ukid,gender from student_profile) gen on gen.ukid = a.ukid left join (select ukid,value from user_details_master_field_value where field_id = 39 and value is not null) dob on dob.ukid = a.ukid left join (select ukid,t2.name as value from user_details_master_field_value t1 left join (select id, name from user_details_master_field_list_item where field_id = 44) t2 on t2.id = t1.value where t1.field_id = 44 and value is not null) blood on blood.ukid = a.ukid left join (select ukid,value from user_details_master_field_value where field_id = 146 and value is not null) fn on fn.ukid = a.ukid left join (select ukid,value from user_details_master_field_value where field_id = 147 and value is not null) mn on mn.ukid = a.ukid left join (select ukid,value from user_details_master_field_value where field_id = 63 and value is not null) addd on addd.ukid = a.ukid left join (select ukid,value from user_details_master_field_value where field_id = 42 and value is not null) nat on nat.ukid = a.ukid where ua.user_type = 'student'


-- Module: Gate Pass — Gate pass audience
-- Active students in the gate-pass audience with free-pass and accommodation type.

select t1.ukid,concat(ua.f_name," ",ua.l_name) as name,ua.registration_id,t1.free_pass,t1.accommodation_type,t1.user_type from gate_pass_audience t1 left join authenticator a on a.ukid = t1.ukid left join user_attributes ua on ua.ukid = a.ukid where t1.user_type = 'student' and a.is_active = 1 


-- Module: OBE — Evaluator access
-- OBE dashboard access settings per faculty/term-course with evaluator details.

select t.name as term,c.course_code,c.course_name,d.department_name as course_dept_name,concat(ua.f_name," ",ua.l_name) as evaluator,ua.registration_id as evaluator_id,t1.* from obe_dashboard_access_settings t1 left join term_course tc on tc.id = t1.term_course_id left join term t on t.id = tc.term_id left join course c on c.course_id = tc.course_id left join user_attributes ua on ua.ukid = t1.faculty_ukid left join department d on d.department_id = c.department_id


-- Module: Dues Management — Dues report (v1)
-- Per-student dues by category with amount, paid and due.

SELECT t2.ukid,ua.registration_id,concat(ua.f_name," ",ua.l_name) as student_name,p.programme_name,d.department_name, t3.category, t1.amount, t1.paid_amount, t1.due_amount FROM dues_finance t1 LEFT JOIN dues t2 ON t1.due_id = t2.id LEFT JOIN dues_category t3 ON t2.category_id = t3.id LEFT JOIN user_attributes ua ON t2.ukid = ua.ukid LEFT JOIN authenticator au ON t2.ukid = au.ukid LEFT JOIN student_profile sp ON t2.ukid = sp.ukid LEFT JOIN programme p ON sp.programme_id = p.programme_id LEFT JOIN department d ON sp.department_id = d.department_id LEFT JOIN quota q ON sp.quota_id = q.id;


-- Module: Fee Management — Active academic fee (v1)
-- Latest active fee per student with scholarship, waiver, penalty, paid and due amounts.

select sf.created_timestamp,ua.ukid,ua.registration_id,concat(ua.f_name,' ',ua.l_name) as name,a.email,a.phone,p.programme_name,coalesce(sp.year_of_joining,ps.year_of_joining) year_of_joining,year,q.name as quota,sp.academic_status,sp.admission_type,applicable_fee,carry_over, coalesce(ssc.approved_amount,0)  as scholarship,
 coalesce(t1.waiver,0) as waiver_amount,
 -- coalesce(t0.initial_amount,0) as excess,
penalty_amount,amount_paid,amount_due,if(a.is_active = 1,'Active','Inactive') as student_status from student_fee sf left join user_attributes ua on ua.ukid = sf.ukid left join authenticator a on a.ukid = ua.ukid left join student_profile sp on sp.ukid = sf.ukid left join prospective_student ps on ps.ukid = sf.ukid left join quota q on q.id = coalesce(sp.quota_id,ps.quota_id) left join programme p on p.programme_id = coalesce(sp.programme_id,ps.programme_id)
left join student_scholarship ss on sf.id = ss.student_fee_id
left join student_scholarship_component ssc on ssc.student_scholarship_id = ss.id left join student_fee_component sfc on sfc.student_fee_id = sf.id
-- left join (select student_fee_id, initial_amount  from student_fee_component where type = "excess") t0 on t0.student_fee_id = sf.id
left join (select student_fee_id, sum(waiver) as waiver from student_fee_component group by student_fee_id) t1 on t1.student_fee_id = sf.id
  where invalidated = 0 and sf.id in (select max(id) from student_fee where invalidated = 0 group by ukid)
 group by sf.ukid,sf.id;


-- Module: Classroom Resources — Resource counts
-- Per-class resource counts by media type with faculty and course.

SELECT c.id, t.name AS term, c.batch AS class, CONCAT(ua.f_name, ' ', ua.l_name) AS faculty, course_code, course_name,media_type, COUNT(cr.id) AS count FROM classroom_resource cr LEFT JOIN class c ON c.id = cr.class_id LEFT JOIN class_faculty t2 ON c.id = t2.class_id LEFT JOIN term t ON t.id = c.term_id LEFT JOIN user_attributes ua ON ua.ukid = t2.faculty_id LEFT JOIN course cc ON cc.course_id = c.course_id left join media_object mo on mo.media_id = cr.media_id GROUP BY faculty_id , c.id, media_type;

-- Module: User Management — Student master
-- Student directory with programme, intake, quota, department, gender and status.

SELECT a.ukid, concat(ua.f_name,' ',ua.l_name) as "Student Name", a.email as Email, ua.registration_id as "Registration ID", sp.year_of_joining as "Batch",q.name as "Quota", p.programme_name as "Programme",pbi.name as intake_name, d.department_name as "Department", upper(sp.gender) as Gender,sp.accommodation_type,if(a.is_active=1,'Active','Inactive') as Status FROM authenticator a 
left join user_attributes ua on a.ukid = ua.ukid
left join student_profile sp on a.ukid = sp.ukid
left join programme p on sp.programme_id = p.programme_id
left join programme_batch_intake pbi on pbi.id = sp.intake_id
left join quota q on q.id = sp.quota_id
left join department d on sp.department_id = d.department_id where ua.user_type in ('student');


-- Module: CHC (Campus Help Centre) — Configuration lookups
-- Service form fields and work-centre form fields for selected forms/work-centres, plus raw configuration table dumps.

select crff.id as Form_field_id, crff.name as form_field, crff.element, crf.id as form_id, crf.title as form_name, cs.id as servive_id, cs.title as service_name, csd.id as service_desk_id, csd.title as service_desk_name from chc_service_desk csd left join chc_service cs on csd.id = cs.service_desk_id left join chc_request_form crf on cs.id = crf.service_id left join chc_request_form_field crff on crf.id = crff.form_id where crf.id = 36;

-- Work-centre action form fields for selected work-centres.
select cwc.title as workcenter_name, cwca.name as action_name, cwcff.name as wc_field_name, cwcff.is_mandatory from chc_work_centre_action cwca left join chc_work_centre_form cwcf on cwca.id = cwcf.action_id left join chc_work_centre cwc on cwc.id = cwca.work_centre_id left join chc_work_centre_form_field cwcff on cwcff.form_id = cwcf.id where work_centre_id in ("120","121");

-- Raw CHC configuration table dumps (schema exploration).
select * from chc_service_desk;

select * from chc_service; 
select * from chc_request_form; 
select * from chc_request_form_field; 
select * from chc_request_form_field_element_option; 
select * from chc_request_form_attachment; 
select * from chc_work_centre; 
select * from chc_work_centre_action; 
select * from chc_work_centre_form; 
select * from chc_work_centre_form_field; 
select * from chc_work_centre_form_attachment; 
select * from ivr_exotel_config iec ; 

-- Module: Fee Management — Last closed fee (v1)
-- Latest non-invalidated fee per student for a specific registration id with scholarship, waiver and amounts.

select sf.created_timestamp,ua.ukid,ua.registration_id,concat(ua.f_name,' ',ua.l_name) as name,a.email,a.phone,p.programme_name,coalesce(sp.year_of_joining,ps.year_of_joining) year_of_joining,year,q.name as quota,sp.academic_status,sp.admission_type,applicable_fee,carry_over, coalesce(ssc.approved_amount,0) as scholarship, coalesce(t1.waiver,0) as waiver_amount, penalty_amount,amount_paid,amount_due,if(a.is_active = 1,'Active','Inactive') as student_status from student_fee sf left join user_attributes ua on ua.ukid = sf.ukid left join authenticator a on a.ukid = ua.ukid left join student_profile sp on sp.ukid = sf.ukid left join prospective_student ps on ps.ukid = sf.ukid left join quota q on q.id = coalesce(sp.quota_id,ps.quota_id) left join programme p on p.programme_id = coalesce(sp.programme_id,ps.programme_id) left join student_scholarship ss on sf.id = ss.student_fee_id left join student_scholarship_component ssc on ssc.student_scholarship_id = ss.id left join student_fee_component sfc on sfc.student_fee_id = sf.id left join (select student_fee_id, sum(waiver) as waiver from student_fee_component group by student_fee_id) t1 on t1.student_fee_id = sf.id where invalidated = 0 and sf.id in (select max(id) from student_fee where invalidated = 0 group by ukid) and ua.registration_id in ('23273030377') group by sf.ukid,sf.id;


-- Module: User Management — Custom form field values
-- All custom field values (master and programme-specific) per user across student and staff management.

select * from 
(select t1.ukid,ua.user_type,display_name,t2.element,coalesce(t3.name,value) as value from user_details_master_field_value t1 left join user_details_master_field t2 on t1.field_id = t2.id left join user_details_master_field_list_item t3 on t3.id = t1.value left join user_attributes ua on ua.ukid = t1.ukid where t1.value is not null 
union all
select t1.ukid,ua.user_type,t2.name as display_name,t2.element,coalesce(t3.name,value) as value from user_details_field_value t1 left join user_details_field t2 on t1.field_id = t2.id left join user_details_field_list_item t3 on t3.id = t1.value left join user_attributes ua on ua.ukid = t1.ukid where t1.value is not null ) t1 limit 1000;


-- Module: Specialisation / EMS — Programme specialisation students
-- Students mapped to programme specialisations with section, batch and EMS course-registration details.

SELECT t1.ukid, ua.registration_id, t.name AS term, c.course_code,c.course_id, t2.programme_id, p.programme_name, t1.programme_section_id, ps.programme_section_name, ps.batch_year, sp.name FROM programme_specialisation_student t1 LEFT JOIN programme_specialisation_mapping t2 ON t2.id = t1.programme_specialisation_mapping_id LEFT JOIN specialisation sp ON sp.id = t2.specialisation_id LEFT JOIN programme_section ps ON ps.programme_section_id = t1.programme_section_id LEFT JOIN programme p ON p.programme_id = t2.programme_id LEFT JOIN user_attributes ua ON ua.ukid = t1.ukid LEFT JOIN ems_student_course_registration_details t4 ON t4.programme_specialisation_mapping_id = t2.id and t4.ukid = t1.ukid LEFT JOIN term_course tc ON tc.id = t4.term_course_id LEFT JOIN term t ON t.id = tc.term_id LEFT JOIN course c ON c.course_id = tc.course_id;


-- Module: Events — Event details & participants
-- Event information with seat/participant counts and organiser for a date; plus participant-level registration status.

SELECT ei.event_id, name, coalesce(venue,'-') as venue, coalesce(description,'-') description, coalesce(speaker,'-') speaker, coalesce(ei.no_of_seats,'0') noOfSeats,coalesce(ep.count,0) as noOfParticipants, start_datetime, end_datetime, IF(registration_required = 1, 'YES', 'NO') AS registration_required, last_registration_datetime, coalesce(cost,0) cost, concat(ua.f_name," ",ua.l_name) as organiser,date(ei.updated_timestamp) as created_timestamp FROM event_information ei left join user_attributes ua on ua.ukid = ei.organiser_ukid left join (select event_id,count(*) count from event_participant ep where status = 'SUCCESS' group by event_id) ep on ep.event_id = ei.event_id where date(ei.updated_timestamp) = '2025-01-30' order by id desc;

-- Participant-level event registration and status.
select event_id,name,email,phone,coalesce(ticket_id,'-') as ticket_id,ep.status,coalesce(eps.status,'-') as event_status from event_participant ep left join event_participation_status eps on eps.id = ep.participation_status_id;


-- Module: OBE — Course outcome mapping status
-- Per-term-course outcome-mapping status with course-outcome and class counts.

SELECT tc.id AS term_course_id,t.name as term,c.course_name,c.course_code,d.department_name,coalesce(faculty,'-') as 'faculty/s',if( COUNT(DISTINCT tco.id) >0,'Outcomes Mapped','Outcomes Not Mapped') outcome_status,COUNT(DISTINCT tco.id) AS no_of_course_outcomes,ex.class_count FROM term_course tc LEFT JOIN obe_course_outcomes tco ON tco.term_course_id = tc.id AND tco.is_deleted = 0 LEFT JOIN term t ON t.id = tc.term_id left join course c on c.course_id = tc.course_id left join department d on d.department_id = c.department_id left join( select cc.course_id,t.id,count(*) class_count from class cc left join course c on cc.course_id = c.course_id left join term t on t.id = cc.term_id group by cc.course_id,t.id) ex on ex.id = t.id and ex.course_id = c.course_id left join (select term_course_id,group_concat(ua.f_name," ",ua.l_name) as faculty from term_course_faculty tcf left join user_attributes ua on ua.ukid = tcf.faculty_ukid group by tcf.term_course_id) tcf on tcf.term_course_id = tc.id where ex.class_count is not null GROUP BY tc.id;



-- Module: Infrastructure — Infrastructure (new structure)
-- Infrastructure versions with type, capacity, parent hierarchy, floor and floor counts.

 SELECT iv.id AS infra_id, COALESCE(iv.code, '-') AS infra_code, iv.name AS infra_name, it.type, COALESCE(iv.capacity, '-') AS capacity, COALESCE(iv.parent_id, '-') AS parent_infra_id, COALESCE(iv2.code, '-') AS parent_infra_code, COALESCE(iv2.name, iv.parent_id, '-') AS parent_infra, COALESCE(iff.name, '-') AS floor, COALESCE(concat('G+',(iv.number_of_floors-1)), 0) number_of_floors, COALESCE(iv.number_of_floors_under, 0) number_of_floors_under FROM infrastructure_master im left join infrastructure_version iv on iv.id = im.infrastructure_version_id LEFT JOIN infrastructure_type it ON it.id = im.type_id LEFT JOIN infrastructure_version iv2 ON iv2.id = im.parent_id LEFT JOIN infrastructure_floor iff ON iff.id = iv.floor_id where im.archived = 0;

-- Module: Timetable / Attendance — Diagnostic counts
-- Count of scheduled lessons in the current term.
select count(*) from timetable_lesson_course_class tt left join lesson l on l.id = tt.lesson_id left join class c on c.id = tt.class_id left join term t on t.id = c.term_id where  curdate() between t.starts and t.ends and  date(l.start) <= curdate();

-- Count of lessons with attendance taken in the current term.
select count(*) from timetable_lesson_course_class tt left join lesson l on l.id = tt.lesson_id left join class c on c.id = tt.class_id left join term t on t.id = c.term_id where   date(l.start) <= curdate() and tt.attendance_taken is not null and curdate() between t.starts and t.ends ;
        
-- Count of class-attendance rows in the current term.
select count(*) from class_attendance ca left join class c on c.id =ca.class_id left join term t on t.id = c.term_id WHERE curdate() between t.starts and t.ends;

-- Module: CHC (Campus Help Centre) — Escalation matrix
-- Service escalation levels with assignee and escalation time (hours).
select t1.service_id,cs.title as service_name,round((t1.time/60)) as time_in_hours,concat(ua.f_name," ",ua.l_name) as assigneee,ua.registration_id from chc_service_escalation t1 left join chc_service cs on cs.id = t1.service_id left join user_attributes ua on ua.ukid = t1.assignee_ukid where t1.is_active  = 1 order by service_id,round((t1.time/60)) ;


-- Module: Attendance — Status before exception
-- Per-student lesson attendance status prior to an applied attendance exception.

select t1.ukid,concat(ua.f_name," ",ua.l_name) as student_name,ua.registration_id,date(l.start) lesson_date,l.start,l.end,cc.course_name,cc.course_code,previous_status_id,t2.status previous_status,t2.final_status previous_final_status from applied_attendance_exception_log t1 left join lesson l on l.id = t1.lesson_id left join class c on c.id = t1.class_id left join UDC_09_USER_ATTENDANCE_STATUS t2 on t2.id = t1.previous_status_id left join user_attributes ua on ua.ukid = t1.ukid left join course cc on cc.course_id = c.course_id where t1.ukid = 614092


-- Module: Feedback — Template check
-- Feedback sessions and templates used for submitted responses.

Select fs.session_name, ft.template_name, fcft.session_id, fcft.template_id from feedback_student_template_status fsts left join feedback_session_student fss on fsts.student_session_id = fss.id left join feedback_session fs on fs.id = fss.session_id left join feedback_course_faculty_template fcft on fcft.id = fsts.feedback_course_faculty_template_id left join feedback_template ft on ft.id = fcft.template_id where fs.session_order = 99 and fsts.submitted = 1 group by fs.session_name, ft.template_name;

-- Template section, question and option definitions for a template.
select t4.template_name,t3.section_name,t2.question_text,t2.question_type,t1.option_text,t1.option_score from feedback_template t4  left join feedback_template_section t3 on t3.feedback_template_id = t4.id left join feedback_template_section_question t2 on t2.template_section_id = t3.id left join feedback_template_question_option t1 on t1.feedback_question_id = t2.id where t4.template_name = 'Old_PGP Level 2 - Anchor_+ Teaching';


-- Module: Feedback — Masked student responses
-- Feedback responses with a hashed/masked student id per question and template for a session.

Select fs.session_name 'Session Name', cl.batch as 'Class Name', concat(ua.f_name, ' ', ua.l_name) 'Faculty Name', ua.registration_id 'Faculty Reg ID',  c.course_code 'Course Code', c.course_name 'Course Name', cl.type as 'Course Type', term.name as 'Term', ft.template_name 'Template Name',  fts.section_name 'Section Name', ftsq.question_text 'Question', CONCAT('S', LPAD(MOD(CRC32(CONCAT(sp.ukid, pr.programme_id, d.department_id)), 1000000), 6, '0')) 'Masked Student ID',pr.programme_name 'Student Programme', ftsq.question_type 'Question Type',coalesce(ftqo.option_text,fsr.response_text) as 'Response/Option', ftqo.option_score 'Option Score' from feedback_student_response fsr left join feedback_student_template_status fsts on fsts.id = fsr.session_student_template_status_id left join feedback_template_question_option ftqo on ftqo.id = fsr.option_id left join feedback_template_section_question ftsq on ftsq.id = fsr.question_id left join feedback_template_section fts on fts.id = ftsq.template_section_id left join feedback_session_student fss on fsts.student_session_id = fss.id left join feedback_session fs on fs.id = fss.session_id left join feedback_course_faculty_template fcft on fcft.id = fsts.feedback_course_faculty_template_id left join class cl on cl.id = fcft.class_id left join faculty_profile fp on fp.ukid = fcft.faculty_ukid left join user_attributes ua on fp.ukid = ua.ukid left join feedback_template ft on ft.id = fcft.template_id left join course c on c.course_id = cl.course_id left join student_profile sp on sp.ukid = fss.student_ukid left join programme pr on pr.programme_id = sp.programme_id left join department d on d.department_id = sp.department_id left join term on term.id = cl.term_id where fss.session_id = 2 and fsts.submitted = 1 group by question_id, fp.ukid, fs.session_name, ft.template_name, cl.batch, c.course_code, c.course_name, cl.type, student_ukid

-- Module: Attendance — Exception report
-- Applied attendance exceptions per student with previous status, reason and exception status/period.

select ua.ukid,ua.registration_id,concat(ua.f_name," ",ua.l_name) as student_name,t1.lesson_id,date(l.start) as lesson_date,l.start lesson_start,l.end as lesson_end,c.batch as class,cc.course_name,cc.course_code,udc.status as previous_status,t1.previously_marked_from,t1.attendance_percent,t1.exception_status,t1.reason,udc1.status as exception_status,t2.remark,t.name as term,concat(ua.f_name," ",ua.l_name) as performed_by,convert_tz(t2.applied_on,'+00:00','+05:30') as 'applied_on(IST)' from applied_attendance_exception_log t1 left join user_attributes ua on ua.ukid = t1.ukid left join UDC_09_USER_ATTENDANCE_STATUS udc on udc.id = t1.previous_status_id left join attendance_exception_logs t2 on t2.id = t1.attendance_exception_log_id left join UDC_09_USER_ATTENDANCE_STATUS udc1 on udc1.id = t2.status_id left join term t on t.id = t2.term_id left join user_attributes ua2 on ua2.ukid = t2.performed_by_ukid left join class c on c.id = t1.class_id left join lesson l on l.id = t1.lesson_id left join course cc on cc.course_id = c.course_id;


-- Attendance exceptions keyed from the exception log with start/end period.
select t2.ukid,ua.registration_id,concat(ua.f_name," ",ua.l_name) as student_name,t1.lesson_id,date(l.start) as lesson_date,l.start lesson_start,l.end as lesson_end,c.batch as class,cc.course_name,cc.course_code,udc.status as previous_status,t1.previously_marked_from,t1.attendance_percent,t1.exception_status,t1.reason,udc1.status as exception_status,t2.remark,t.name as term,concat(ua.f_name," ",ua.l_name) as performed_by,convert_tz(t2.applied_on,'+00:00','+05:30') as 'applied_on(IST)',concat(t2.start_date,' ',t2.start_time) as exception_start,concat(t2.end_date,' ',t2.end_time) as exception_end from attendance_exception_logs  t2 left join applied_attendance_exception_log t1 on t2.id = t1.attendance_exception_log_id left join user_attributes ua on ua.ukid = t2.ukid left join UDC_09_USER_ATTENDANCE_STATUS udc on udc.id = t1.previous_status_id  left join UDC_09_USER_ATTENDANCE_STATUS udc1 on udc1.id = t2.status_id left join term t on t.id = t2.term_id left join user_attributes ua2 on ua2.ukid = t2.performed_by_ukid left join class c on c.id = t1.class_id left join lesson l on l.id = t1.lesson_id left join course cc on cc.course_id = c.course_id;

-- Module: Institution Hierarchy — Department & layer hierarchy
-- Department-to-institution-entity hierarchy levels; plus institution-layer level listings (academic/non-academic).

SELECT d.college_id,d.department_id, d.department_name, d.category, COALESCE(l4.name, l3.name, l2.name, l1.name) AS level1, CASE WHEN l4.name IS NOT NULL THEN l3.name WHEN l3.name IS NOT NULL THEN l2.name WHEN l2.name IS NOT NULL THEN l1.name ELSE NULL END AS level2, CASE WHEN l4.name IS NOT NULL THEN l2.name WHEN l3.name IS NOT NULL THEN l1.name ELSE NULL END AS level3, CASE WHEN l4.name IS NOT NULL THEN l1.name ELSE NULL END AS level4 FROM department d LEFT JOIN institution_entity l1 ON l1.id = d.parent_entity_id LEFT JOIN institution_entity l2 ON l2.id = l1.parent_entity_id LEFT JOIN institution_entity l3 ON l3.id = l2.parent_entity_id LEFT JOIN institution_entity l4 ON l4.id = l3.parent_entity_id;


-- Institution layers by level (academic / non-academic), one row per layer.
SELECT CASE WHEN l1.is_academic = 1 THEN 'Academic' ELSE 'Non Academic' END AS 'Group',l1.name as level_name, 'Level 1' AS level FROM institution_layer l1 WHERE l1.parent_layer_id IS NULL UNION ALL SELECT CASE WHEN l1.is_academic = 1 THEN 'Academic' ELSE 'Non Academic' END,l2.name, 'Level 2' FROM institution_layer l1 LEFT JOIN institution_layer l2 ON l2.parent_layer_id = l1.id WHERE l1.parent_layer_id IS NULL UNION ALL SELECT CASE WHEN l1.is_academic = 1 THEN 'Academic' ELSE 'Non Academic' END,l3.name, 'Level 3' FROM institution_layer l1 LEFT JOIN institution_layer l2 ON l2.parent_layer_id = l1.id LEFT JOIN institution_layer l3 ON l3.parent_layer_id = l2.id WHERE l1.parent_layer_id IS NULL UNION ALL SELECT CASE WHEN l1.is_academic = 1 THEN 'Academic' ELSE 'Non Academic' END,l4.name, 'Level 4' FROM institution_layer l1 LEFT JOIN institution_layer l2 ON l2.parent_layer_id = l1.id LEFT JOIN institution_layer l3 ON l3.parent_layer_id = l2.id LEFT JOIN institution_layer l4 ON l4.parent_layer_id = l3.id WHERE l1.parent_layer_id IS NULL

-- Institution layers pivoted into academic vs non-academic columns per level.
SELECT level, MAX(CASE WHEN grp = 'Academic' THEN level_name END) AS Academic, MAX(CASE WHEN grp = 'Non Academic' THEN level_name END) AS Non_academic FROM( SELECT 'Layer 0' AS level, l1.name AS level_name, CASE WHEN l1.is_academic = 1 THEN 'Academic' ELSE 'Non Academic' END AS grp FROM institution_layer l1 WHERE l1.parent_layer_id IS NULL UNION ALL SELECT 'Layer 1', l2.name, CASE WHEN l1.is_academic = 1 THEN 'Academic' ELSE 'Non Academic' END FROM institution_layer l1 JOIN institution_layer l2 ON l2.parent_layer_id = l1.id WHERE l1.parent_layer_id IS NULL UNION ALL SELECT 'Layer 2', l3.name, CASE WHEN l1.is_academic = 1 THEN 'Academic' ELSE 'Non Academic' END FROM institution_layer l1 JOIN institution_layer l2 ON l2.parent_layer_id = l1.id JOIN institution_layer l3 ON l3.parent_layer_id = l2.id WHERE l1.parent_layer_id IS NULL UNION ALL SELECT 'Layer 3', l4.name, CASE WHEN l1.is_academic = 1 THEN 'Academic' ELSE 'Non Academic' END FROM institution_layer l1 JOIN institution_layer l2 ON l2.parent_layer_id = l1.id JOIN institution_layer l3 ON l3.parent_layer_id = l2.id JOIN institution_layer l4 ON l4.parent_layer_id = l3.id WHERE l1.parent_layer_id IS NULL) t GROUP BY level ORDER BY level; 



-- Module: EMS / Assessment — Assessment allocation overview
-- Per-assessment venue, invigilator and seating allocation status with course, slot and timing details for a term.

WITH allocation_summary AS( SELECT ea.id AS assessment_id, SUM(IF(eavm.student_count IS NULL, 0, eavm.student_count)) AS total_students_allocated, COUNT(ea.id) AS total_assessments, COUNT(DISTINCT eavm.assessment_venue_infrastructure_id) AS total_venues, COUNT(DISTINCT eaim.assessment_venue_infrastructure_id) AS total_invigilator_allocations, COUNT(eas.venue_seating_id) AS total_seating_allocations, CONCAT(uax.f_name, ' ', uax.m_name, ' ', uax.l_name) AS invigilator_name, a.email as invigilator_email, uax.registration_id as invigilator_registration_id, iv.name as venue FROM ems_assessment ea LEFT JOIN ems_assessment_venue_mapping eavm ON eavm.assessment_id = ea.id LEFT JOIN ems_assessment_venue_infrastructure eavii ON eavii.id = eavm.assessment_venue_infrastructure_id LEFT JOIN infrastructure_version iv ON iv.id = eavii.infrastructure_id LEFT JOIN ems_assessment_invigilator_mapping eaim ON eaim.assessment_venue_infrastructure_id = eavm.assessment_venue_infrastructure_id AND ea.slot_date_id = eaim.assessment_slot_date_id LEFT JOIN ems_assessment_student eas ON eas.assessment_id = ea.id LEFT JOIN user_attributes uax ON uax.ukid = eaim.faculty_ukid LEFT JOIN authenticator a ON uax.ukid = a.ukid GROUP BY ea.id) SELECT t.id AS term_id, t.name AS term_name, tc.id AS term_course_id, co.course_code, cov.course_name, eet.id AS exam_type_id, eet.name AS assessment_name, easg.group_name AS group_name, IF(ea.online = 1, 'online', 'offline') AS exam_type, DATE(ea.start_datetime) AS start_date, DAYNAME(ea.start_datetime) AS start_day_name, eass.slot_name, TIME(ea.start_datetime) AS start_time, TIME(ea.closing_datetime) AS end_time, ea.duration, CASE WHEN alloc.total_students_allocated >= alloc.total_assessments THEN 'FULLY_ALLOCATED' WHEN alloc.total_students_allocated > 0 AND alloc.total_students_allocated < alloc.total_assessments THEN 'PARTIALLY_ALLOCATED' ELSE 'NOT_ALLOCATED' END AS venue_status, alloc.venue, CASE WHEN alloc.total_venues = alloc.total_invigilator_allocations AND alloc.total_invigilator_allocations > 0 THEN 'FULLY_ALLOCATED' WHEN alloc.total_invigilator_allocations > 0 AND alloc.total_venues > alloc.total_invigilator_allocations THEN 'PARTIALLY_ALLOCATED' ELSE 'NOT_ALLOCATED' END AS invigilator_status, alloc.invigilator_name, alloc.invigilator_registration_id, alloc.invigilator_email, CASE WHEN alloc.total_assessments = alloc.total_seating_allocations THEN 'FULLY_ALLOCATED' WHEN alloc.total_seating_allocations > 0 AND alloc.total_assessments > alloc.total_seating_allocations THEN 'PARTIALLY_ALLOCATED' ELSE 'NOT_ALLOCATED' END AS seating_status FROM ems_assessment ea LEFT JOIN allocation_summary alloc ON alloc.assessment_id = ea.id LEFT JOIN term_course tc ON tc.id = ea.term_course_id LEFT JOIN course_version cov ON tc.course_version_id = cov.id LEFT JOIN course co ON co.course_id = cov.course_id LEFT JOIN term t ON t.id = tc.term_id LEFT JOIN ems_examination_type eet ON eet.id = ea.exam_type_id LEFT JOIN ems_assessment_schedule ascc ON ascc.id = ea.assessment_schedule_id LEFT JOIN ems_assessment_schedule_groups easg ON easg.id = ea.schedule_group_id LEFT JOIN ems_assessment_slot_dates easd ON easd.id = ea.slot_date_id LEFT JOIN ems_assessment_schedule_slots eass ON eass.id = easd.ems_assessment_slot_id WHERE t.id = 61 and DATE(ea.start_datetime) > "2026-05-07" and DATE(ea.start_datetime) < "2026-05-16" GROUP BY t.id, ea.term_course_id, co.course_code, assessment_name, eass.slot_name, ea.duration;


-- Module: Course — Course detail
-- Latest default course version with department and per-component credit breakdown.

select cv.id,c.course_id as course_id,c.course_code,cv.course_name,cv.course_credits as total_course_credits,d.department_name,cct.name,cc.course_credits as component_credits from course_version cv  left join course c on cv.course_id = c.course_id left join course_component cc on cc.course_version_id = cv.id left join course_component_type cct on cct.id = cc.course_component_type_id left join department d on d.department_id = c.department_id where cv.id in
(select max(id) from course_version where is_default = 1 group by course_id)
order by c.course_id

-- Module: Class — Class detail
-- Class with its component type and the underlying course version detail for a term.

select cl.id as class_id,cl.batch as class_name,cct.name as class_component,ex.* from class cl left join course_component_type cct on cct.id = cl.course_component_type_id left join
(select c.course_id,c.course_code,cv.course_name,cv.course_credits as course_credits,d.department_name from course_version cv  left join course c on cv.course_id = c.course_id  left join department d on d.department_id = c.department_id where cv.id in
(select max(id) from course_version where is_default = 1 group by course_id) 
order by c.course_id) ex on cl.course_id = ex.course_id where cl.term_id = 69;

