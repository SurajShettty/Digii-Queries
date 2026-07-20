Select 
	ua.ukid, 
	registration_id, 
	concat( coalesce( ap.designation, fp.designation, '' ), ' ', ua.f_name, ' ', ua.l_name ) name, 
	udmc.display_name cluster_name, 
	udmce.order, 
	udmf.display_name field_name, 
	udmfv.value 
from user_details_master_cluster_entry_field_value udmfv 
left join user_details_master_cluster_entry udmce on udmfv.cluster_entry_id = udmce.id 
left join user_details_master_field udmf on udmfv.field_id = udmf.id 
left join user_details_master_cluster udmc on udmc.id = udmce.cluster_id 
left join user_attributes ua on ua.ukid = udmfv.ukid 
left join faculty_profile fp on fp.ukid = ua.ukid 
left join admin_profile ap on ap.ukid = ua.ukid
where udmc.display_name in ('Resume Details')
ORDER BY ua.created_timestamp desc;