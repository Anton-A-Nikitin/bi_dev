USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_monitoring_cte_dates_set_stock;

CREATE TABLE dbo.stock_monitoring_cte_dates_set_stock (

	base_date_id int null,
	mtd_date_id int null,
);

WITH date_sequence AS (
    -- Generate the last 28 days prior to today
    SELECT 
        DATEADD(day, -n.number, CAST(convert(nvarchar(8),
        										(select max(date_id) from RetailAnalytics_dev.dbo.stock_turnover_cte_sales_and_stock_full),
        										112) AS DATE)) AS date_value,
        FORMAT(DATEADD(day, -n.number, CAST(convert(nvarchar(8),
        										(select max(date_id) from RetailAnalytics_dev.dbo.stock_turnover_cte_sales_and_stock_full),
        										112) AS DATE)), 'yyyyMMdd') AS date_id
    FROM master.dbo.spt_values n
    WHERE n.type = 'P' AND n.number BETWEEN 0 AND 27
),
mtd_dates AS (
    -- Generate MTD dates for each date in date_sequence
    SELECT 
        ds.date_id AS base_date_id,
        FORMAT(DATEADD(day, m.number, DATEFROMPARTS(YEAR(ds.date_value), MONTH(ds.date_value), 1)), 'yyyyMMdd') AS mtd_date_id
    FROM date_sequence ds
    JOIN master.dbo.spt_values m
        ON m.type = 'P'
       AND m.number BETWEEN 0 AND DATEDIFF(day, DATEFROMPARTS(YEAR(ds.date_value), MONTH(ds.date_value), 1), ds.date_value)
),

cte_dates_set_stock as (
SELECT 
    base_date_id, 
    mtd_date_id
FROM mtd_dates
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_monitoring_cte_dates_set_stock
select * from cte_dates_set_stock;

--CHECK
select * from RetailAnalytics_dev.dbo.stock_monitoring_cte_dates_set_stock

------------------------------------------------------------------------------------------------

USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_monitoring_cte_stock_l28d_daily;

CREATE TABLE dbo.stock_monitoring_cte_stock_l28d_daily (

	date_id int null, --for each of the dates inside l28d
	warehouse_id int null,
	sales_channel_id int null,
    wh_group nvarchar(20) null,
	characteristic_id int null,
	stock_qty decimal(18,4) null,
	stock_cost_net decimal(18,4) null
);

--LOGIC
with cte_stock_l28d_daily as (
	select
		b.base_date_id as date_id,
		a.warehouse_id,
		a.sales_channel_id,
    	a.wh_group,
		a.characteristic_id,
		sum(a.stock_qty) as stock_qty,
		sum(a.stock_cost_net) as stock_cost_net
	from RetailAnalytics_dev.dbo.stock_monitoring_cte_dates_set_stock b
	left join RetailAnalytics_dev.dbo.stock_turnover_cte_sales_and_stock_full a
		on a.date_id = b.mtd_date_id
	group by
		b.base_date_id,
		a.warehouse_id,
		a.sales_channel_id,
    	a.wh_group,
		a.characteristic_id
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_monitoring_cte_stock_l28d_daily
select * from cte_stock_l28d_daily;


--CHECK
--select * from RetailAnalytics_dev.dbo.stock_monitoring_cte_stock_l28d_daily

------------------------------------------------------------------------------------------------

USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_monitoring_cte_sales_and_stock_l28d_unstaged;

CREATE TABLE dbo.stock_monitoring_cte_sales_and_stock_l28d_unstaged (	
	date_id int null,
	warehouse_id int null,
	sales_channel_id int null,
   	wh_group nvarchar(20) null,
   	wh_group_low nvarchar(20) null,
   	channel_group nvarchar(20) null,
   	wh_type nvarchar(50) null,
   	characteristic_id int null,
	item_color_id nvarchar(20) null,
	sales_qty decimal(18,4) null,
    sales_rrp_net decimal(18,4) null,
	sales_current_net decimal(18,4) null,
	sales_cost_net decimal(18,4) null,
	stock_qty decimal(18,4) null,
	stock_rrp_net decimal(18,4) null,
	stock_current_net decimal(18,4) null,
	stock_cost_net decimal(18,4) null
);

with cte_sales_l28d_daily as (
	select
		a.date_id,
		a.warehouse_id,
		a.sales_channel_id,
    	a.wh_group,
		a.characteristic_id,
		sum(a.sales_qty) as sales_qty,
		sum(a.sales_rrp_net) as sales_rrp_net,
		sum(a.sales_current_net) as sales_current_net,
		sum(a.sales_cost_net) as sales_cost_net
	from RetailAnalytics_dev.dbo.stock_turnover_cte_sales_and_stock_full a
	left join (select distinct base_date_id from RetailAnalytics_dev.dbo.stock_monitoring_cte_dates_set_stock) b 
		on a.date_id = b.base_date_id
	where 
		b.base_date_id is not null
	group by
		a.date_id,
		a.warehouse_id,
		a.sales_channel_id,
    	a.wh_group,
		a.characteristic_id
),

cte_sales_and_stock_l28d_daily as (
	select 
		coalesce(a.date_id,b.date_id) as date_id,
		coalesce(a.warehouse_id,b.warehouse_id) as warehouse_id,
		coalesce(a.sales_channel_id,b.sales_channel_id) as sales_channel_id,
		coalesce(a.wh_group,b.wh_group) as wh_group,
		coalesce(a.characteristic_id,b.characteristic_id) as characteristic_id,
		a.sales_qty,
		a.sales_rrp_net,
		a.sales_current_net,
		a.sales_cost_net,
		b.stock_qty,
		b.stock_cost_net
	from cte_sales_l28d_daily a
	full outer join RetailAnalytics_dev.dbo.stock_monitoring_cte_stock_l28d_daily b
		on a.date_id = b.date_id
		and a.warehouse_id = b.warehouse_id
		and a.sales_channel_id = b.sales_channel_id
		and a.wh_group = b.wh_group
		and a.characteristic_id = b.characteristic_id
),

cte_sales_and_stock_l28d_daily_corr_price as (
	select 
		a.date_id,
		a.warehouse_id,
		a.sales_channel_id,
	   	a.wh_group,
	   	a.characteristic_id,
		ch.item_color_id,
		a.sales_qty,
	    a.sales_rrp_net,
		a.sales_current_net,
		a.sales_cost_net,
		a.stock_qty,
		COALESCE
		    (   
		     plc2.price_net / ((100 + di.item_vat_rate)/100) * a.stock_qty
		    ,plf.rrp_net / ((100 + di.item_vat_rate)/100) * a.stock_qty
		    ,0
		   	) as stock_rrp_net,
	    COALESCE
		    (   
		     plc.price_net / ((100 + di.item_vat_rate)/100) * a.stock_qty
		    ,plf.current_rrp_net / ((100 + di.item_vat_rate)/100) * a.stock_qty
		    ,0
		    ) as stock_current_net,
		a.stock_cost_net
	from cte_sales_and_stock_l28d_daily a
	left join (SELECT characteristic_id,date_id,end_date_id,price_net
			    FROM RetailAnalytics.dbo.fct_price_list 
			    WHERE price_type_id = 2) plc
		on  a.characteristic_id = plc.characteristic_id
		and a.date_id >= plc.date_id
		and a.date_id < plc.end_date_id
	left join (SELECT characteristic_id,date_id,end_date_id,price_net
			    FROM RetailAnalytics.dbo.fct_price_list 
			    WHERE price_type_id = 1) plc2
		on  a.characteristic_id = plc2.characteristic_id
		and a.date_id >= plc2.date_id
		and a.date_id < plc2.end_date_id
	left join RetailAnalytics.dbo.fct_price_list_first plf
		on plf.characteristic_id = a.characteristic_id
	left join RetailAnalytics_dev.dbo.stock_turnover_cte_characteristic_info ch
		on ch.characteristic_id = a.characteristic_id
	left join RetailAnalytics.dbo.dim_Item di
		on ch.item_id = di.item_id
),

cte_sales_and_stock_l28d_unstaged as (
select 
	a.date_id,
	a.warehouse_id,
	a.sales_channel_id,
   	a.wh_group,
   	c.wh_group_low,
   	d.channel_group,
   	case
	   	when c.wh_group_low = 'DISTR_RESERVE' then 'direct_distribution'
	   	when c.wh_group_low like 'DISTR%' then 'indirect_distribution'
	   	when d.channel_group in ('SERVICE') and a.wh_group not in ('SERVICE') then 'direct_distribution'
	   	when a.wh_group in ('SERVICE') then 'service'
    	else 'direct_selling'
	end as wh_type,
   	a.characteristic_id,
	a.item_color_id,
	a.sales_qty,
    a.sales_rrp_net,
	a.sales_current_net,
	a.sales_cost_net,
	a.stock_qty,
	a.stock_rrp_net,
	a.stock_current_net,
	a.stock_cost_net
from cte_sales_and_stock_l28d_daily_corr_price a
left join RetailAnalytics_dev.dbo.stock_turnover_cte_wh_id_sales_channel_id_mapping c
	on a.sales_channel_id = c.sales_channel_id
	and a.warehouse_id = c.warehouse_id
left join RetailAnalytics_dev.dbo.stock_turnover_cte_sales_channel_mapping d
	on a.sales_channel_id = d.sales_channel_id
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_monitoring_cte_sales_and_stock_l28d_unstaged
select * from cte_sales_and_stock_l28d_unstaged;

--CHECK
--select * from RetailAnalytics_dev.dbo.stock_monitoring_cte_sales_and_stock_l28d_unstaged

------------------------------------------------------------------------------------------------

USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_monitoring_cte_sales_and_stock_l28d_staged;

CREATE TABLE dbo.stock_monitoring_cte_sales_and_stock_l28d_staged (
	wh_group nvarchar(20) null,
	item_color_id nvarchar(20) null,
	sales_qty decimal(18,4) null,
    sales_rrp_net decimal(18,4) null,
	sales_current_net decimal(18,4) null,
	sales_cost_net decimal(18,4) null,
	stock_count_selling decimal(18,4) null,
	stock_qty_selling decimal(18,4) null,
	stock_cost_net_selling decimal(18,4) null,
	stock_count_dir_distr decimal(18,4) null,
	stock_qty_dir_distr decimal(18,4) null,
	stock_cost_net_dir_distr decimal(18,4) null,
	stock_count_indir_distr decimal(18,4) null,
	stock_qty_indir_distr_spec decimal(18,4) null,
	stock_cost_net_indir_distr_spec decimal(18,4) null,
	stock_qty_indir_distr_rest decimal(18,4) null,
	stock_cost_net_indir_distr_rest decimal(18,4) null,
	stock_count_serv decimal(18,4) null,
	stock_qty_serv decimal(18,4) null,
	stock_cost_net_serv decimal(18,4) null
);

with cte_cleaning as (
	select 
		item_color_id,
		sum(case when coalesce(sales_qty,0) <> 0 then 1 else 0 end) as sales_qty_nona,
		sum(case when coalesce(sales_rrp_net,0) <> 0 then 1 else 0 end) as sales_rrp_net_nona,
		sum(case when coalesce(sales_current_net,0) <> 0 then 1 else 0 end) as sales_current_net_nona,
		sum(case when coalesce(sales_cost_net,0) <> 0 then 1 else 0 end) as sales_cost_net_nona,
		sum(case when coalesce(stock_qty,0) <> 0 then 1 else 0 end) as stock_qty_nona,
		sum(case when coalesce(stock_rrp_net,0) <> 0 then 1 else 0 end) as stock_rrp_net_nona,
		sum(case when coalesce(stock_current_net,0) <> 0 then 1 else 0 end) as stock_current_net_nona,
		sum(case when coalesce(stock_cost_net,0) <> 0 then 1 else 0 end) as stock_cost_net_nona	
	from RetailAnalytics_dev.dbo.stock_monitoring_cte_sales_and_stock_l28d_unstaged	
	group by item_color_id
),

cte_sales_and_stock_l28d_unstaged_clean as (
select a.*
from RetailAnalytics_dev.dbo.stock_monitoring_cte_sales_and_stock_l28d_unstaged a
left join cte_cleaning b
	on a.item_color_id=b.item_color_id
where 	
	sales_qty_nona +
	--sales_rrp_net_nona +
	--sales_current_net_nona +
	--sales_cost_net_nona +
	--stock_rrp_net_nona +
	--stock_current_net_nona +
	--stock_cost_net_nona
	stock_qty_nona > 0
),

cte_all_item_color_ids as (
select distinct item_color_id
from cte_sales_and_stock_l28d_unstaged_clean
),

cte_all_wh_groups as (
select distinct wh_group
from cte_sales_and_stock_l28d_unstaged_clean
where wh_group not in ('SERVICE','WHOLESALE')
),

cte_all_combinations as (
	select * from cte_all_item_color_ids
	left join cte_all_wh_groups
	on 1=1
),

cte_all_wh_groups_days_grouped as (
	select 
		wh_group,
		wh_type,
		item_color_id,
		date_id,
		sum(stock_qty) as stock_qty,
		sum(stock_cost_net) as stock_cost_net
	from cte_sales_and_stock_l28d_unstaged_clean
	group by
		wh_group,
		wh_type,
		item_color_id,
		date_id
),

cte_all_wh_groups_days_grouped_now as (
	select 
		a.wh_group,
		a.wh_type,
		a.item_color_id,
		sum(case when a.stock_qty>0 then 1 else 0 end) as stock_count,
		sum(case when b.now_date_id is not null then a.stock_qty else 0 end) as stock_qty,
		sum(case when b.now_date_id is not null then a.stock_cost_net else 0 end) as stock_cost_net
	from cte_all_wh_groups_days_grouped a
	left join (select distinct max(base_date_id) as now_date_id from RetailAnalytics_dev.dbo.stock_monitoring_cte_dates_set_stock) b 
		on a.date_id = b.now_date_id
	group by
		a.wh_group,
		a.wh_type,
		a.item_color_id
),

cte_all_wh_types_days_grouped as (
select
	wh_type,
	item_color_id,
	date_id,
	sum(stock_qty) as stock_qty,
	sum(stock_cost_net) as stock_cost_net
from cte_sales_and_stock_l28d_unstaged_clean
group by
	wh_type,
	item_color_id,
	date_id
),

cte_all_wh_types_days_grouped_now as (
	select 
		a.wh_type,
		a.item_color_id,
		sum(case when a.stock_qty>0 then 1 else 0 end) as stock_count,
		sum(case when b.now_date_id is not null then a.stock_qty else 0 end) as stock_qty,
		sum(case when b.now_date_id is not null then a.stock_cost_net else 0 end) as stock_cost_net
	from cte_all_wh_types_days_grouped a
	left join (select distinct max(base_date_id) as now_date_id from RetailAnalytics_dev.dbo.stock_monitoring_cte_dates_set_stock) b 
		on a.date_id = b.now_date_id
	group by
		a.wh_type,
		a.item_color_id
),

cte_sales_l28d as (
	select
	   	a.wh_group,
		a.item_color_id,
		sum(b.sales_qty) as sales_qty,
	    sum(b.sales_rrp_net) as sales_rrp_net,
		sum(b.sales_current_net) as sales_current_net,
		sum(b.sales_cost_net) as sales_cost_net
	from cte_all_combinations a
	left join cte_sales_and_stock_l28d_unstaged_clean b
		on a.item_color_id = b.item_color_id
		and a.wh_group = b.wh_group
	group by
	   	a.wh_group,
		a.item_color_id
),

cte_stock_selling_now as (
	select
	   	a.wh_group,
		a.item_color_id,
		coalesce(b.stock_count,0) as stock_count,
		coalesce(b.stock_qty,0) as stock_qty,
	    coalesce(b.stock_cost_net,0) as stock_cost_net
	from cte_all_combinations a
	left join (select * from cte_all_wh_groups_days_grouped_now where wh_type in ('direct_selling')) b
		on a.item_color_id = b.item_color_id
		and a.wh_group = b.wh_group
),

cte_stock_dir_distr_now as (
	select
	   	a.wh_group,
		a.item_color_id,
		coalesce(b.stock_count,0) as stock_count,
		coalesce(b.stock_qty,0) as stock_qty,
	    coalesce(b.stock_cost_net,0) as stock_cost_net
	from cte_all_combinations a
	left join (select * from cte_all_wh_groups_days_grouped_now where wh_type in ('direct_distribution')) b
		on a.item_color_id = b.item_color_id
		and a.wh_group = b.wh_group
),

cte_stock_indir_distr_spec_now as (
	select
	   	a.wh_group,
		a.item_color_id,
		coalesce(b.stock_count,0) as stock_count,
		coalesce(b.stock_qty,0) as stock_qty,
	    coalesce(b.stock_cost_net,0) as stock_cost_net
	from cte_all_combinations a
	left join (select * from cte_all_wh_groups_days_grouped_now where wh_type in ('indirect_distribution')) b
		on a.item_color_id = b.item_color_id
		and a.wh_group = b.wh_group
),

cte_stock_indir_distr_total_now as (
	select
		a.wh_group,
		a.item_color_id,
		coalesce(b.stock_count,0) as stock_count,
		coalesce(b.stock_qty,0) as stock_qty,
	    coalesce(b.stock_cost_net,0) as stock_cost_net
	from cte_all_combinations a
	left join (select * from cte_all_wh_types_days_grouped_now where wh_type in ('indirect_distribution')) b
		on a.item_color_id = b.item_color_id
),

cte_stock_service_total_now as (
	select
		a.wh_group,
		a.item_color_id,
		coalesce(b.stock_count,0) as stock_count,
		coalesce(b.stock_qty,0) as stock_qty,
	    coalesce(b.stock_cost_net,0) as stock_cost_net
	from cte_all_combinations a
	left join (select * from cte_all_wh_types_days_grouped_now where wh_type in ('service')) b
		on a.item_color_id = b.item_color_id
),

cte_sales_and_stock_l28d_staged as (
select 
		a.wh_group,
		a.item_color_id,
		a.sales_qty,
		a.sales_rrp_net,
		a.sales_current_net,
		a.sales_cost_net,
		case when coalesce(b.stock_count,0)=0 and coalesce(a.sales_qty,0)>0 then 1 else b.stock_count end as stock_count_selling,
		b.stock_qty as stock_qty_selling,
		b.stock_cost_net stock_cost_net_selling,
		c.stock_count as stock_count_dir_distr,
		c.stock_qty as stock_qty_dir_distr,
		c.stock_cost_net stock_cost_net_dir_distr,
		d.stock_count as stock_count_indir_distr,
		d.stock_qty as stock_qty_indir_distr_spec,
		d.stock_cost_net stock_cost_net_indir_distr_spec,
		e.stock_qty - d.stock_qty as stock_qty_indir_distr_rest,
		e.stock_cost_net - d.stock_cost_net as stock_cost_net_indir_distr_rest,
		f.stock_count as stock_count_serv,
		f.stock_qty as stock_qty_serv,
		f.stock_cost_net stock_cost_net_serv
	from cte_sales_l28d a
	left join cte_stock_selling_now b
		on a.wh_group = b.wh_group
		and a.item_color_id = b.item_color_id
	left join cte_stock_dir_distr_now c
		on a.wh_group = c.wh_group
		and a.item_color_id = c.item_color_id
	left join cte_stock_indir_distr_spec_now d
		on a.wh_group = d.wh_group
		and a.item_color_id = d.item_color_id
	left join cte_stock_indir_distr_total_now e
		on a.wh_group = e.wh_group
		and a.item_color_id = e.item_color_id
	left join cte_stock_service_total_now f
		on a.wh_group = f.wh_group
		and a.item_color_id = f.item_color_id
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_monitoring_cte_sales_and_stock_l28d_staged
select * from cte_sales_and_stock_l28d_staged;

--CALCULATE CLUSTER BASED ON ROS NOT SALES!!!

--CHECK
--select wh_group ,sum(stock_qty_selling) as stc 
--from RetailAnalytics_dev.dbo.stock_monitoring_cte_sales_and_stock_l28d_staged
--group by wh_group

--select * from RetailAnalytics_dev.dbo.stock_monitoring_cte_sales_and_stock_l28d_unstaged 
--where 
	--item_color_id in ('37639032_898') 
	--and date_id in (20250210)
	--and wh_type in ('direct_distribution')

------------------------------------------------------------------------------------------------

USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_monitoring_cte_clustering;

CREATE TABLE dbo.stock_monitoring_cte_clustering (
	wh_group nvarchar(20) null,
    item_color_id nvarchar(20) null,
    sales_qty int null,
    stock_count_selling int null,
    ros decimal(18,4) null,
	cluster int null
);

WITH cte_ros_calc AS (
    SELECT 
        wh_group, 
        item_color_id, 
        sales_qty,
        stock_count_selling,
        case 
        	when sales_qty/stock_count_selling*7.0>7.0 and stock_count_selling<7.0 then 7.0 
        	else sales_qty/stock_count_selling*7.0	
        end as ros
    FROM RetailAnalytics_dev.dbo.stock_monitoring_cte_sales_and_stock_l28d_staged
   	where sales_qty>0 and stock_count_selling>0
),

cte_clustering AS (
    SELECT 
        a.wh_group, 
        a.item_color_id, 
        b.ros,
        case
	        when coalesce(a.sales_qty,0) = 0 and coalesce(a.stock_count_selling,0) = 0 and coalesce(a.stock_qty_selling,0)=0 then 'ELSWHERE'
	        when coalesce(a.sales_qty,0) = 0 and coalesce(a.stock_qty_selling,0)<=0 then 'REMOVED'
	        when coalesce(a.sales_qty,0) = 0 and coalesce(a.stock_count_selling,0) > 0 then 'DEAD'
        	when coalesce(a.sales_qty,0) < 0 then 'RETURN'
        	when b.ros = 0.25 then 'ROS=0.25'
        	when b.ros <=1 then 'ROS<=1.0'
        	when b.ros >1 then 'ROS>1.0'
        end as cluster,
        
        a.sales_qty,
		a.sales_rrp_net,
		a.sales_current_net,
		a.sales_cost_net,
		a.stock_count_selling,
		case 
	        when coalesce(a.stock_qty_selling,0)>0 then 'ON_STOCK' else 'OUT_OF_STOCK' 
        end on_stock,
        a.stock_qty_selling,
		a.stock_cost_net_selling,
		a.stock_count_dir_distr,
		a.stock_qty_dir_distr,
		a.stock_cost_net_dir_distr,
		a.stock_count_indir_distr,
		a.stock_qty_indir_distr_spec,
		a.stock_cost_net_indir_distr_spec,
		a.stock_qty_indir_distr_rest,
		a.stock_cost_net_indir_distr_rest,
		a.stock_count_serv,
		a.stock_qty_serv,
		a.stock_cost_net_serv,
		
		a.stock_qty_selling - coalesce(b.ros,0)*4 as stock_qty_remains_after_selling,
		a.stock_qty_selling + a.stock_qty_dir_distr - coalesce(b.ros,0)*4 as stock_qty_remains_after_dir_distr,
		a.stock_qty_selling + a.stock_qty_dir_distr + a.stock_qty_indir_distr_spec - coalesce(b.ros,0)*4 as stock_qty_remains_after_indir_distr_spec,
		a.stock_qty_selling + a.stock_qty_dir_distr + a.stock_qty_indir_distr_spec + a.stock_qty_indir_distr_rest - coalesce(b.ros,0)*4 as stock_qty_remains_after_indir_distr_rest,
		a.stock_qty_selling + a.stock_qty_dir_distr + a.stock_qty_indir_distr_spec + a.stock_qty_indir_distr_rest + a.stock_qty_serv - coalesce(b.ros,0)*4 as stock_qty_remains_after_serv
		
    FROM RetailAnalytics_dev.dbo.stock_monitoring_cte_sales_and_stock_l28d_staged a
   	left join cte_ros_calc b
   		on a.wh_group = b.wh_group
   		and a.item_color_id = b.item_color_id
),

cte_final as (
select 
	wh_group, 
    item_color_id,
    ros,
    cluster,
    
    sales_qty,
	sales_rrp_net,
	sales_current_net,
	sales_cost_net,
	stock_count_selling,
	on_stock,
    stock_qty_selling,
	stock_cost_net_selling,
	stock_count_dir_distr,
	stock_qty_dir_distr,
	stock_cost_net_dir_distr,
	stock_count_indir_distr,
	stock_qty_indir_distr_spec,
	stock_cost_net_indir_distr_spec,
	stock_qty_indir_distr_rest,
	stock_cost_net_indir_distr_rest,
	stock_count_serv,
	stock_qty_serv,
	stock_cost_net_serv,
	
	case 
		when stock_qty_remains_after_selling<0 then stock_qty_selling 
		else (case when stock_qty_selling < stock_qty_remains_after_selling then 0 else stock_qty_selling - stock_qty_remains_after_selling end) 
	end as stock_qty_consumption_selling,
	
	case 
		when stock_qty_remains_after_dir_distr < 0 then stock_qty_dir_distr
		else (case when stock_qty_dir_distr < stock_qty_remains_after_dir_distr then 0 else stock_qty_dir_distr - stock_qty_remains_after_dir_distr end) 
	end as stock_qty_consumption_dir_distr,
	
	case 
		when stock_qty_remains_after_indir_distr_spec < 0 then stock_qty_indir_distr_spec
		else (case when stock_qty_indir_distr_spec < stock_qty_remains_after_indir_distr_spec then 0 else stock_qty_indir_distr_spec - stock_qty_remains_after_indir_distr_spec end) 
	end as stock_qty_consumption_indir_distr_spec,
	
	case 
		when stock_qty_remains_after_indir_distr_rest < 0 then stock_qty_indir_distr_rest
		else (case when stock_qty_indir_distr_rest < stock_qty_remains_after_indir_distr_rest then 0 else stock_qty_indir_distr_rest - stock_qty_remains_after_indir_distr_rest end) 
	end as stock_qty_consumption_indir_distr_rest,
	
	case 
		when stock_qty_remains_after_serv < 0 then stock_qty_serv
		else (case when stock_qty_serv < stock_qty_remains_after_serv then 0 else stock_qty_serv - stock_qty_remains_after_serv end) 
	end as stock_qty_consumption_serv
	
from cte_clustering
)

select 
	*,
	ros * 4 as demand,
	stock_qty_selling - stock_qty_consumption_selling as stock_qty_remain_selling,
	stock_qty_dir_distr - stock_qty_consumption_dir_distr as stock_qty_remain_dir_distr,
	stock_qty_indir_distr_spec - stock_qty_consumption_indir_distr_spec as stock_qty_remain_indir_distr_spec,
	stock_qty_indir_distr_rest - stock_qty_consumption_indir_distr_rest as stock_qty_remain_indir_distr_rest,
	stock_qty_serv - stock_qty_consumption_serv as stock_qty_remain_serv,
	case 
		when (stock_qty_indir_distr_spec+stock_qty_indir_distr_rest) - (sum(stock_qty_consumption_indir_distr_spec+stock_qty_consumption_indir_distr_rest) over (partition by item_color_id)) < 0 
		then (stock_qty_indir_distr_spec+stock_qty_indir_distr_rest) - (sum(stock_qty_consumption_indir_distr_spec+stock_qty_consumption_indir_distr_rest) over (partition by item_color_id)) 
		else 0 
	end	as indirect_distr_danger,
	case 
		when (stock_qty_serv) - (sum(stock_qty_consumption_serv) over (partition by item_color_id))<0 
		then (stock_qty_serv) - (sum(stock_qty_consumption_serv) over (partition by item_color_id))
		else 0
	end
	 as serv_danger
from cte_final



--UPDATE
insert into RetailAnalytics_dev.dbo.stock_monitoring_cte_clustering
select * from cte_clustering;

