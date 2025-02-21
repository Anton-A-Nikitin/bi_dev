USE RetailAnalytics_dev;

--DATES
--CREATE
USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_turnover_cte_dates;

CREATE TABLE dbo.stock_turnover_cte_dates (
        datevalue DATE NULL,
        date_id INT NULL,
        month_id INT NULL
);

--LOGIC
with cte_numbers as (
    -- generate a sequence of numbers
    select top (datediff(day, dateadd(year, -3, dateadd(year, datediff(year, 0, getdate()), 0)), getdate()))
        row_number() over (order by (select null)) - 1 as n
    from master.dbo.spt_values
),

cte_dates_prep as (
    -- generate the dates based on the numbers
    select 
        dateadd(day, -n, cast(dateadd(day, -1, getdate()) as date)) as datevalue
    from cte_numbers
),

cte_dates as (
	select
    datevalue,
    cast(format(datevalue, 'yyyyMMdd') as int) as date_id,
    floor(cast(format(datevalue, 'yyyyMMdd') as int)/100) as month_id
from cte_dates_prep
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_turnover_cte_dates
select * from cte_dates;

-----------------------------------------------------------------

--CHARACTERISTIC
--CREATE
USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_turnover_cte_characteristic_info;

CREATE TABLE dbo.stock_turnover_cte_characteristic_info (
	characteristic_id int NULL,
	characteristic_season nvarchar(20) NULL,
	characteristic_old_from INT null,
	characteristic_group nvarchar(20) null,
	item_id int null,
	item_color_id nvarchar(50) NULL,
);

--LOGIC
with cte_characteristic_info as (
	select
		a.characteristic_id,
		a.characteristic_season,
		case 
			when (a.characteristic_season like 'FW%') and TRY_CAST(SUBSTRING(a.characteristic_season,3,2) AS INT) is not null then 20000001 + (cast(SUBSTRING(a.characteristic_season,3,2) AS INT)+1)*10000 + 300
			when (a.characteristic_season like 'SS%') and TRY_CAST(SUBSTRING(a.characteristic_season,3,2) AS INT) is not null then 20000001 + (cast(SUBSTRING(a.characteristic_season,3,2) AS INT))*10000 + 900
			when a.characteristic_season like '%BNOS' then CAST(FORMAT(DATEADD(DAY, 1 - DAY(DATEADD(DAY, +2000, GETDATE())), DATEADD(DAY, +2000, GETDATE())), 'yyyyMMdd') AS INT)
		else CAST(FORMAT(DATEADD(DAY, 1 - DAY(DATEADD(DAY, -2000, GETDATE())), DATEADD(DAY, -2000, GETDATE())), 'yyyyMMdd') AS INT)
		end as characteristic_old_from,
		case 
			when a.characteristic_season like '%BNOS' then 'BNOS'
			when a.characteristic_season like '% OS' then 'OS'
			else 'REG'
		end as characteristic_group,
		a.item_id,
		cast(a.item_id as nvarchar(20)) + '_' + a.characteristic_colorNumber as item_color_id
	from RetailAnalytics.dbo.dim_Characteristic a
	left join RetailAnalytics.dbo.dim_Item b
		on a.item_id = b.item_id
	where lower(cast(b.item_type as nvarchar(50)))
		in (N'аксессуары маркируемые (розница)',N'аксессуары немаркируемые (розница)',N'обувь маркируемая (розница)',N'одежда маркируемая (розница)',N'одежда немаркируемая (розница)')
)


--UPDATE
insert into RetailAnalytics_dev.dbo.stock_turnover_cte_characteristic_info
select * from cte_characteristic_info;

------------------------------------------------------------------------------------------------

--GROUPING SALES CHANNEL
--CREATE
USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_turnover_cte_sales_channel_mapping;

CREATE TABLE dbo.stock_turnover_cte_sales_channel_mapping (
    sales_channel_id int NULL,
    channel nvarchar(20) NULL,
    "type" nvarchar(20) null,
    pos nvarchar(50) null,
    channel_group nvarchar(20) null,
    distr_cluster nvarchar(20) null,
    store_name_short nvarchar(20) null
);

--LOGIC
with cte_sales_channel_mapping as (
	select
		a.sales_channels_id as sales_channel_id,
    	a.channel,
    	a."type",
    	a.pos,
		case 
			when lower(a."type") in ('marketplaces') then UPPER(a.pos)
			when a.sales_channels_id in (4,5) then 'OTHER_SELLING'
			when lower(a."type") in ('tsvetnoy') then 'FULLPRICE'
			when lower(a."type") in (N'Н/Д') then 'SERVICE'
			else REPLACE(UPPER(a."TYPE"),'OTHER','SERVICE')
		end as channel_group, -- only for distributing
		case 
			when lower(a."type") in ('marketplaces') and lower(a.pos) in ('ozon','wildberries') then 'old'
			when lower(a."TYPE") in ('outlet') then 'old'
			when lower(a."type") in ('marketplaces') and lower(a.pos) in ('lamoda') then 'new'
			when lower(a."TYPE") in ('fullprice','ecom') then 'new'
			when lower(a."type") in ('tsvetnoy') then 'new'
			else 'other'
		end as distr_cluster,
		case 
			when a.sales_channels_id in (7) then 'MSK_AFI'
			when a.sales_channels_id in (8) then 'MSK_MTS'
			when a.sales_channels_id in (9) then 'MSK_MET'
			when a.sales_channels_id in (10) then 'MSK_EVR'
			when a.sales_channels_id in (11) then 'MSK_NEG'
			when a.sales_channels_id in (12) then 'MSK_CAP'
			when a.sales_channels_id in (13) then 'SPB_GRC'
			when a.sales_channels_id in (14) then 'SPB_GAL'
			when a.sales_channels_id in (15) then 'EKB_GRE'
			when a.sales_channels_id in (16) then 'KRA_KRP'
			when a.sales_channels_id in (17) then 'MSK_KIE'
			
			when a.sales_channels_id in (18) then 'MSK_ARK'
			when a.sales_channels_id in (19) then 'MSK_FSH'
			when a.sales_channels_id in (20) then 'SPB_RUM'
			when a.sales_channels_id in (21) then 'MSK_ORD'
			when a.sales_channels_id in (22) then 'SPB_PUL'
			when a.sales_channels_id in (23) then 'EKA_BRO'
			when a.sales_channels_id in (24) then 'MSK_MBD'
			when a.sales_channels_id in (25) then 'MSK_VNU'
			when a.sales_channels_id in (26) then 'MSK_XLO'
			when a.sales_channels_id in (27) then 'MOS_TSV'
			
			when a.sales_channels_id in (28) then 'SUR_AUR'
			when a.sales_channels_id in (29) then 'EKB_POP_GRE'
			when a.sales_channels_id in (30) then 'RND_GOR'
			when a.sales_channels_id in (31) then 'NSK_GAL'
			when a.sales_channels_id in (32) then 'MSC_RIG'
			when a.sales_channels_id in (33) then 'MSC_POP_SAV'
			when a.sales_channels_id in (34) then 'SPB_POP_FH'
			when a.sales_channels_id in (36) then 'PER_PLA'
			when a.sales_channels_id in (37) then 'NEW_1'
			when a.sales_channels_id in (38) then 'NEW_2'
			
			when a.sales_channels_id in (41) then 'SOC_MOR'
			when a.sales_channels_id in (42) then 'MSC_COL'
			when a.sales_channels_id in (43) then 'MSC_PAV'
			when a.sales_channels_id in (44) then 'EKB_MEG'
			when a.sales_channels_id in (45) then 'MSC_OKE'
			
			else 'OTH_OTH'
		end as store_name_short
	from RetailAnalytics.dbo.olap_dim_sales_channels a
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_turnover_cte_sales_channel_mapping
select * from cte_sales_channel_mapping;

------------------------------------------------------------------------------------------------

--MAPPING WH SALES ID
--CREATE
USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_turnover_cte_wh_id_sales_channel_id_mapping;

CREATE TABLE dbo.stock_turnover_cte_wh_id_sales_channel_id_mapping (
	sales_channel_id int null,
    warehouse_id int NULL,
   	channel_group nvarchar(20) null,
   	distr_cluster nvarchar(20) null,
   	wh_group_high  nvarchar(20) null,
   	wh_group_low  nvarchar(20) null
);

--LOGIC
with cte_wh_id_sales_channel_id_combinations as (
select distinct sales_channel_id, warehouse_id from RetailAnalytics.dbo.olap_fct_sales
union
select distinct sales_channels_id as sales_channel_id, warehouse_id from RetailAnalytics.dbo.olap_fct_movements
),

cte_wh_id_sales_channel_id_mapping as (
	select distinct
		a.sales_channel_id,
		a.warehouse_id, 
		coalesce(b.channel_group,'UNKNOWN') as channel_group,
		coalesce(b.distr_cluster,'UNKNOWN') as distr_cluster,
		case
			when a.warehouse_id in (31,39366,46) then 'SERVICE' --MEZZO
			when a.warehouse_id in (32,39356) then 'SERVICE' --BOX
			when a.warehouse_id in (36,39359) then 'SERVICE' --RETURN
			when a.warehouse_id in (5138,44,39365,10126,17216) then 'LAMODA'
			when a.warehouse_id in (2614,41465,45,39369) then 'WILDBERRIES'
			when a.warehouse_id in (2,43,6845,39358,39364,8830,39360) then 'WHOLESALE'
			when a.warehouse_id in (57,14337) then 'OTHER_SELLING' --rendez-vous, no one
			when a.warehouse_id in (4458) then 'OZON'
			when a.warehouse_id in (2104,8192,10,24,21690,45806,52,45217) then 'FULLPRICE' --Tsvetony, Mega, Rostov, Kolumbus
			when a.warehouse_id in (33,39374,56) then 'SERVICE' -- DEFECT
			when a.warehouse_id in (6905,10859,45663,45675,14826,39371) then 'SERVICE' -- LOSS
			when a.warehouse_id in (42674,19187,35) then 'ECOM'
			when a.warehouse_id in (42) then 'SERVICE' -- TRANSIT
			when a.warehouse_id in (46075) then 'OUTLET' --neutec reserve
			when a.warehouse_id in (40,47,54) then 'SERVICE' --SHOWROOM, MARKETING WH, KIEVSKY
			when a.warehouse_id in (10127,39361,9370) then 'SERVICE' --cert
			when a.warehouse_id in (48) then 'SERVICE' --marking
			when a.warehouse_id in (14766) then 'SERVICE' --import
			when a.warehouse_id in (1) then 'SERVICE' --main
			when a.warehouse_id in (3,34,39367,-1) then 'SERVICE' --office materials and equipment
			when (lower(cast(coalesce(c.warehouse_group,'NA') as nvarchar(50))) = N'розничный магазин' or lower(cast(coalesce(c.warehouse_accountingMethod,'NA') as nvarchar(50))) = N'магазин') then coalesce(b.channel_group, 'STORE_UNKNOWN')
			when lower(cast(coalesce(c.warehouse_type_name,'NA') as nvarchar(50))) = N'партнер' then 'SERVICE'
			else 'UNKNOWN'
		end as wh_group_high,
		case
			when a.warehouse_id in (31,39366,46) then 'DISTR_MEZZO' --MEZZO
			when a.warehouse_id in (32,39356) then 'DISTR_BOX' --BOX
			when a.warehouse_id in (36,39359) then 'DISTR_RETURN' --RETURN
			when a.warehouse_id in (5138,44,39365,10126,17216) then 'LAMODA'
			when a.warehouse_id in (2614,41465,45,39369) then 'WILDBERRIES'
			when a.warehouse_id in (2,43,6845,39358,39364,8830,39360) then 'WHOLESALE'
			when a.warehouse_id in (57,14337) then 'OTHER_SELLING' --rendez-vous, no one
			when a.warehouse_id in (4458) then 'OZON'
			when a.warehouse_id in (2104,8192,10,24,21690,45806,52,45217) then 'FULLPRICE' --Tsvetony, Mega, Rostov, Kolumbus
			when a.warehouse_id in (33,39374,56) then 'SERVICE_DEFECT' -- DEFECT
			when a.warehouse_id in (6905,10859,45663,45675,14826,39371) then 'SERVICE_LOSS' -- LOSS
			when a.warehouse_id in (42674,19187,35) then 'ECOM'
			when a.warehouse_id in (42) then 'SERVICE_TRANSIT' -- TRANSIT
			when a.warehouse_id in (46075) then 'DISTR_RESERVE' --neutec reserve
			when a.warehouse_id in (40,47,54) then 'SERVICE_OTHER' --SHOWROOM, MARKETING WH, KIEVSKY
			when a.warehouse_id in (10127,39361,9370) then 'SERVICE_CERT' --cert
			when a.warehouse_id in (48) then 'SERVICE_MARKING' --marking
			when a.warehouse_id in (14766) then 'SERVICE_IMPORT' --import
			when a.warehouse_id in (1) then 'SERVICE_MAIN' --main
			when a.warehouse_id in (3,34,39367,-1) then 'SERVICE_EQUIP' --office materials and equipment
			when (lower(cast(coalesce(c.warehouse_group,'NA') as nvarchar(50))) = N'розничный магазин' or lower(cast(coalesce(c.warehouse_accountingMethod,'NA') as nvarchar(50))) = N'магазин') then coalesce(b.channel_group, 'STORE_UNKNOWN')
			when lower(cast(coalesce(c.warehouse_type_name,'NA') as nvarchar(50))) = N'партнер' then 'PARTNER'
			else 'UNKNOWN'
		end as wh_group_low,
		row_number() over (partition by a.warehouse_id, a.sales_channel_id order by a.warehouse_id, a.sales_channel_id) as rn
	from cte_wh_id_sales_channel_id_combinations a
	left join RetailAnalytics_dev.dbo.stock_turnover_cte_sales_channel_mapping b
		on a.sales_channel_id = b.sales_channel_id
	left join RetailAnalytics.dbo.olap_dim_Warehouse c
		on a.warehouse_id = c.warehouse_id	
)

insert into RetailAnalytics_dev.dbo.stock_turnover_cte_wh_id_sales_channel_id_mapping
select sales_channel_id, warehouse_id, channel_group, distr_cluster, wh_group_high, wh_group_low 
from cte_wh_id_sales_channel_id_mapping where rn=1;

--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------

-- SALES

--THE MOST RECENT 1C DATA FOR API CHANNELS
--CREATE
USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_turnover_cte_last_1c_lamoda_ozon_sales_months;

CREATE TABLE dbo.stock_turnover_cte_last_1c_lamoda_ozon_sales_months (
    sales_channel_id int NULL,
    max_month_id int NULL
);

--LOGIC
with cte_last_1c_lamoda_ozon_sales_months as (
select sales_channel_id, max(floor(date_id/100)) as max_month_id 
from RetailAnalytics.dbo.olap_fct_sales
where ((warehouse_id in (5138) and sales_channel_id in (3)) -- lamoda 
	or (warehouse_id in (4458) and sales_channel_id in (35))) -- ozon
	and cast(cast(date_id as varchar) as date) = EOMONTH(cast(cast(date_id as varchar) as date)) 
group by sales_channel_id
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_turnover_cte_last_1c_lamoda_ozon_sales_months
select * from cte_last_1c_lamoda_ozon_sales_months;

-----------------------------------------------------------------

--LAMODA SALES API
--CREATE

DROP TABLE IF EXISTS dbo.stock_turnover_cte_sales_lamoda_api;

CREATE TABLE dbo.stock_turnover_cte_sales_lamoda_api (
    date_id int NULL,
    warehouse_id int null,
    sales_channel_id int null,
    characteristic_id int null,
    month_id int null,
    sales_qty decimal(18,4) null,
    sales_rrp_net decimal(18,4) null,
	sales_current_net decimal(18,4) null,
	sales_cost_net decimal(18,4) null,
	sales_cost_adj decimal(18,4) null,
	lfl_flag int null,
	lfl_flag_ly int null
);

--LOGIC
with cte_sales_lamoda_api as (
	select 
		a.date_id, 
		5138 as warehouse_id, 
		a.sales_channel_id, 
		a.characteristic_id,
		d.month_id,
		cast(coalesce(a.qty,0) as decimal(18,4)) as sales_qty,
		cast(coalesce(a.sales_rrp_net,0) as decimal(18,4)) as sales_rrp_net,
		cast(coalesce(a.sale_net_price,0) as decimal(18,4)) as sales_current_net,
		cast(coalesce(a.cost_net,0) as decimal(18,4)) as sales_cost_net,
		cast(coalesce(a.sales_cost_adjusted,0) as decimal(18,4)) as sales_cost_adj,
		1 as lfl_flag,
		1 as lfl_flag_ly
	from RetailAnalytics.dbo.olap_fct_lamoda_sales a
	left join RetailAnalytics_dev.dbo.stock_turnover_cte_last_1c_lamoda_ozon_sales_months c
		on a.sales_channel_id = c.sales_channel_id
	left join RetailAnalytics_dev.dbo.stock_turnover_cte_dates d
		on d.date_id = a.date_id
	left join RetailAnalytics_dev.dbo.stock_turnover_cte_characteristic_info e
		on a.characteristic_id = e.characteristic_id
	where
		a.item_status_id = 6
		and d.date_id is not null
		and e.characteristic_id is not null
		and d.month_id > c.max_month_id
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_turnover_cte_sales_lamoda_api
select * from cte_sales_lamoda_api;

-----------------------------------------------------------------

--OZON SALES API
--CREATE
USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_turnover_cte_sales_ozon_api;

CREATE TABLE dbo.stock_turnover_cte_sales_ozon_api (
    date_id int NULL,
    warehouse_id int null,
    sales_channel_id int null,
    characteristic_id int null,
    month_id int null,
    sales_qty decimal(18,4) null,
    sales_rrp_net decimal(18,4) null,
	sales_current_net decimal(18,4) null,
	sales_cost_net decimal(18,4) null,
	sales_cost_adj decimal(18,4) null,
	lfl_flag int null,
	lfl_flag_ly int null
);

--LOGIC
with cte_sales_ozon_api as (
	select 
		a.date_id, 
		4458 as warehouse_id, 
		a.sales_channel_id,
		a.characteristic_id,
		d.month_id,
		cast(coalesce (a.sale_qty,0) as decimal(18,4)) as sales_qty,
		cast(coalesce (a.sales_rrp_net,0) as decimal(18,4)) as sales_rrp_net,
		cast(coalesce (a.sale_net,0) as decimal(18,4)) as sales_current_net,
		cast(coalesce (a.cost_net,0) as decimal(18,4)) as sales_cost_net,
		cast(coalesce (a.sales_cost_adjusted,0) as decimal(18,4)) as sales_cost_adj,
		1 as lfl_flag,
		1 as lfl_flag_ly
	from RetailAnalytics.dbo.olap_fct_ozon_sales a
	left join RetailAnalytics_dev.dbo.stock_turnover_cte_dates d
		on d.date_id = a.date_id
	left join RetailAnalytics_dev.dbo.stock_turnover_cte_characteristic_info e
		on a.characteristic_id = e.characteristic_id
	left join RetailAnalytics_dev.dbo.stock_turnover_cte_last_1c_lamoda_ozon_sales_months c
		on a.sales_channel_id = c.sales_channel_id
	where 
		d.date_id is not null
		and e.characteristic_id is not null
		and d.month_id > c.max_month_id
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_turnover_cte_sales_ozon_api
select * from cte_sales_ozon_api;

-----------------------------------------------------------------

--REGULAR SALES API
--CREATE
USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_turnover_cte_sales_regular;

CREATE TABLE dbo.stock_turnover_cte_sales_regular (
    date_id int NULL,
    warehouse_id int null,
    sales_channel_id int null,
    characteristic_id int null,
    month_id int null,
    sales_qty decimal(18,4) null,
    sales_rrp_net decimal(18,4) null,
	sales_current_net decimal(18,4) null,
	sales_cost_net decimal(18,4) null,
	sales_cost_adj decimal(18,4) null,
	lfl_flag int null,
	lfl_flag_ly int null
);

with cte_sales_regular as (
	select 
		a.date_id, 
		a.warehouse_id, 
		a.sales_channel_id, 
		a.characteristic_id,
		b.month_id,
		cast(coalesce (a.qty,0) as decimal(18,4)) as sales_qty,
		cast(coalesce (a.sales_rrp_net,0) as decimal(18,4)) as sales_rrp_net,
		cast(coalesce (a.amount_net,0) as decimal(18,4)) as sales_current_net,
		cast(coalesce (a.cost_net,0) as decimal(18,4)) as sales_cost_net,
		cast(coalesce (a.sales_cost_adjusted,0) as decimal(18,4)) as sales_cost_adj,
		cast(coalesce (a.lfl_sign_id,0) as int) as lfl_flag,
		cast(coalesce (a.lfl_sign_id_ly,0) as int) as lfl_flag_ly
	from RetailAnalytics.dbo.olap_fct_sales a
	left join RetailAnalytics_dev.dbo.stock_turnover_cte_dates b
		on a.date_id = b.date_id
	left join RetailAnalytics_dev.dbo.stock_turnover_cte_characteristic_info c
		on a.characteristic_id = c.characteristic_id
	where
		b.date_id is not null
		and c.characteristic_id is not null
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_turnover_cte_sales_regular
select * from cte_sales_regular;

-----------------------------------------------------------------

--SALES APIS
--CREATE
USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_turnover_cte_sales_ozon_lamoda_apis;

CREATE TABLE dbo.stock_turnover_cte_sales_ozon_lamoda_apis (
    date_id int NULL,
    warehouse_id int null,
    sales_channel_id int null,
    characteristic_id int null,
    month_id int null,
    sales_qty decimal(18,4) null,
    sales_rrp_net decimal(18,4) null,
	sales_current_net decimal(18,4) null,
	sales_cost_net decimal(18,4) null,
	sales_cost_adj decimal(18,4) null,
	lfl_flag int null,
	lfl_flag_ly int null
);

--LOGIC
with cte_sales_ozon_lamoda_apis as (
select * from RetailAnalytics_dev.dbo.stock_turnover_cte_sales_lamoda_api
union all
select * from RetailAnalytics_dev.dbo.stock_turnover_cte_sales_ozon_api
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_turnover_cte_sales_ozon_lamoda_apis
select * from cte_sales_ozon_lamoda_apis;

-----------------------------------------------------------------

--SALES FULL
--CREATE
USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_turnover_cte_sales_full;

CREATE TABLE dbo.stock_turnover_cte_sales_full (
    date_id int NULL,
    warehouse_id int null,
    sales_channel_id int null,
    characteristic_id int null,
    characteristic_old_from int null,
    characteristic_group nvarchar(20) null,
    month_id int null,
    sales_qty decimal(18,4) null,
    sales_rrp_net decimal(18,4) null,
	sales_current_net decimal(18,4) null,
	sales_cost_net decimal(18,4) null,
	sales_cost_adj decimal(18,4) null,
	lfl_flag int null,
	lfl_flag_ly int null,
	channel_group nvarchar(20) null,
	distr_cluster nvarchar(20) null,
	wh_group nvarchar(20) null
);

--LOGIC
with cte_sales_full as (
select * from RetailAnalytics_dev.dbo.stock_turnover_cte_sales_ozon_lamoda_apis
union all
select * from RetailAnalytics_dev.dbo.stock_turnover_cte_sales_regular
),

cte_sales_full_adj as (
	select 
		a.date_id,
	    a.warehouse_id,
	    a.sales_channel_id,
	    a.characteristic_id,
	    c.characteristic_old_from,
	    c.characteristic_group,
	    a.month_id,
	    coalesce (a.sales_qty,0) as sales_qty,
	    coalesce (a.sales_rrp_net,0) as sales_rrp_net,
		coalesce (a.sales_current_net,0) as sales_current_net,
		coalesce (a.sales_cost_net,0) as sales_cost_net,
		coalesce (a.sales_cost_adj,0) as sales_cost_adj,
		coalesce (a.lfl_flag,0) as lfl_flag,
		coalesce (a.lfl_flag_ly,0) as lfl_flag_ly,
		b.channel_group, -- only for distributing
		b.distr_cluster, -- only for distributing
		b.wh_group_high as wh_group -- core category
	from cte_sales_full a
	left join RetailAnalytics_dev.dbo.stock_turnover_cte_wh_id_sales_channel_id_mapping b
		on a.sales_channel_id = b.sales_channel_id
		and a.warehouse_id = b.warehouse_id
	left join RetailAnalytics_dev.dbo.stock_turnover_cte_characteristic_info c
		on a.characteristic_id = c.characteristic_id
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_turnover_cte_sales_full
select * from cte_sales_full_adj;

-----------------------------------------------------------------

--SHARES
--CREATE
USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_turnover_cte_distr_shares;

CREATE TABLE dbo.stock_turnover_cte_distr_shares (
    month_id int NULL,
    distr_cluster nvarchar(20) null,
	channel_group nvarchar(20) null,
	channel_group_l180d_total decimal(18,4) null,
	distr_cluster_l180d_total decimal(18,4) null,
	channel_group_distr_share float null
);

with cte_stat_prep as (
	select 	
		month_id,
		distr_cluster,
		channel_group,
		cast(sum(sales_qty) as decimal(18,4)) as sales_qty
	from RetailAnalytics_dev.dbo.stock_turnover_cte_sales_full
	where 
		distr_cluster not in ('other')
	group by
		month_id,
		distr_cluster,
		channel_group
),

cte_stat_prep_ext as (
	select a.*,b.*,c.month_id as month_id_key	
	from (select distinct month_id from RetailAnalytics_dev.dbo.stock_turnover_cte_dates) a
	left join (select distinct distr_cluster, channel_group from cte_stat_prep) b
		on 1=1
	left join (select distinct month_id from RetailAnalytics_dev.dbo.stock_turnover_cte_dates) c
		on 1=1
	where c.month_id <= CAST(FORMAT(DATEADD(MONTH, -1, CAST(LEFT(a.month_id, 4) + '-' + RIGHT(a.month_id, 2) + '-01' AS DATE)), 'yyyyMM') AS INT)
		and c.month_id >= CAST(FORMAT(DATEADD(MONTH, -6, CAST(LEFT(a.month_id, 4) + '-' + RIGHT(a.month_id, 2) + '-01' AS DATE)), 'yyyyMM') AS INT)
),

cte_shares_prep as (
select 
	a.month_id,
	a.distr_cluster,
	a.channel_group,
	sum(coalesce(b.sales_qty,0)) as channel_group_l180d_total
from cte_stat_prep_ext a
left join cte_stat_prep b
	on a.month_id_key = b.month_id
	and a.distr_cluster = b.distr_cluster
	and a.channel_group = b.channel_group
group by 	
	a.month_id,
	a.distr_cluster,
	a.channel_group
),

cte_distr_shares_prep as (
	select 
	*,
	sum(channel_group_l180d_total) over (partition by month_id,distr_cluster) as distr_cluster_l180d_total
	from cte_shares_prep
),

cte_distr_shares as (
	select 
		*,
		case when distr_cluster_l180d_total = 0 then 1 else channel_group_l180d_total/distr_cluster_l180d_total end as channel_group_distr_share
	from cte_distr_shares_prep
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_turnover_cte_distr_shares
select * from cte_distr_shares;

-----------------------------------------------------------------
-----------------------------------------------------------------

--STOCK
--CREATE
USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_turnover_cte_stock_ozon_lamoda_apis;

CREATE TABLE dbo.stock_turnover_cte_stock_ozon_lamoda_apis (
    date_id int NULL,
    warehouse_id int null,
    sales_channel_id int null,
    characteristic_id int null,
    characteristic_old_from int null,
    characteristic_group nvarchar(20) null,
    month_id int null,
    stock_qty decimal(18,4) null,
	stock_cost_net decimal(18,4) null,
	channel_group nvarchar(20) null,
	distr_cluster nvarchar(20) null,
	wh_group nvarchar(20) null,
	channel_group_l180d_total decimal(18,4) null,
	distr_cluster_l180d_total decimal(18,4) null,
	channel_group_distr_share float null
);

--LOGIC
with cte_stock_ozon_lamoda_apis as (
select 
	a.date_id,
	a.warehouse_id, 
	a.sales_channel_id,
	a.characteristic_id,
	d.characteristic_old_from,
	d.characteristic_group,
	a.month_id,
	cast(-1*coalesce(a.sales_qty,0) as decimal(18,4)) as stock_qty,
	cast(-1*coalesce(a.sales_cost_net,0) as decimal(18,4)) as stock_cost_net,
	b.channel_group,
	b.distr_cluster,
	b.wh_group_high as wh_group,
	null as channel_group_l180d_total,
	null as distr_cluster_l180d_total,
	null as channel_group_distr_share
from RetailAnalytics_dev.dbo.stock_turnover_cte_sales_ozon_lamoda_apis a
left join RetailAnalytics_dev.dbo.stock_turnover_cte_wh_id_sales_channel_id_mapping b
	on a.sales_channel_id = b.sales_channel_id
	and a.warehouse_id = b.warehouse_id
left join RetailAnalytics_dev.dbo.stock_turnover_cte_characteristic_info d
	on a.characteristic_id = d.characteristic_id
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_turnover_cte_stock_ozon_lamoda_apis
select * from cte_stock_ozon_lamoda_apis;

-----------------------------------------------------------------

--STOCK REGULAR
--CREATE
USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_turnover_cte_stock_direct;

CREATE TABLE dbo.stock_turnover_cte_stock_direct (
    date_id int NULL,
    warehouse_id int null,
    sales_channel_id int null,
    characteristic_id int null,
    characteristic_old_from int null,
    characteristic_group nvarchar(20) null,
    month_id int null,
    stock_qty decimal(18,4) null,
	stock_cost_net decimal(18,4) null,
	channel_group nvarchar(20) null,
	distr_cluster nvarchar(20) null,
	wh_group nvarchar(20) null,
	channel_group_l180d_total decimal(18,4) null,
	distr_cluster_l180d_total decimal(18,4) null,
	channel_group_distr_share float null
);

--LOGIC
with cte_stock_direct as (	
	select
		a.date_id, 
		a.warehouse_id, 
		a.sales_channels_id as sales_channel_id, 
		a.characteristic_id,
		b.characteristic_old_from,
		b.characteristic_group,
	  	e.month_id,
	  	cast(coalesce(a.qty_stock,0) as decimal(18,4)) as stock_qty,
	  	cast(coalesce(a.cost_net_stock,0) as decimal(18,4)) as stock_cost_net,
	  	c.channel_group,
		c.distr_cluster,
		c.wh_group_high as wh_group,
		null as channel_group_l180d_total,
		null as distr_cluster_l180d_total,
		null as channel_group_distr_share	
	from RetailAnalytics.dbo.olap_fct_movements a
	left join RetailAnalytics_dev.dbo.stock_turnover_cte_dates e
		on a.date_id = e.date_id
	left join RetailAnalytics_dev.dbo.stock_turnover_cte_characteristic_info b
		on a.characteristic_id = b.characteristic_id
	left join RetailAnalytics_dev.dbo.stock_turnover_cte_wh_id_sales_channel_id_mapping c
		on a.sales_channels_id = c.sales_channel_id
		and a.warehouse_id = c.warehouse_id
	where 
		e.date_id is not null
		and b.characteristic_id is not null
		and c.wh_group_low not in ('DISTR_MEZZO','DISTR_BOX','DISTR_RETURN') --not on mezz, box, return
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_turnover_cte_stock_direct
select * from cte_stock_direct;

-----------------------------------------------------------------
--SUPPORTING STOCK CLEAN WITH GROUP
--CREATE
USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_turnover_cte_stock_movement_cleaned;

CREATE TABLE dbo.stock_turnover_cte_stock_movement_cleaned (
    date_id int NULL,
    month_id int null,
    warehouse_id int null,
    sales_channel_id int null,
    characteristic_id int null,
    characteristic_old_from int null,
    characteristic_group nvarchar(20) null,
    wh_group_low nvarchar(20) null,
    qty_stock decimal(18,4) null,
	cost_net_stock decimal(18,4) null
);

--LOGIC
with cte_stock_movement_cleaned as (
	select 		
		a.date_id,
		e.month_id,
		a.warehouse_id, 
		a.sales_channels_id as sales_channel_id, 
		a.characteristic_id,
		c.characteristic_old_from,
		c.characteristic_group,
		f.wh_group_low,
		a.qty_stock,
	  	a.cost_net_stock
	from RetailAnalytics.dbo.olap_fct_movements a
	left join RetailAnalytics_dev.dbo.stock_turnover_cte_wh_id_sales_channel_id_mapping f
		on a.sales_channels_id = f.sales_channel_id
		and a.warehouse_id = f.warehouse_id
	left join RetailAnalytics_dev.dbo.stock_turnover_cte_characteristic_info c
		on c.characteristic_id = a.characteristic_id
	left join RetailAnalytics_dev.dbo.stock_turnover_cte_dates e
		on a.date_id = e.date_id
	where 
		e.date_id is not null
		and c.characteristic_id is not null
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_turnover_cte_stock_movement_cleaned
select * from cte_stock_movement_cleaned;

------------------------------------------------------------------------------

--MEZZO
--CREATE

USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_turnover_cte_stock_mezzo_not_os;

CREATE TABLE dbo.stock_turnover_cte_stock_mezzo_not_os (
    date_id int NULL,
    warehouse_id int null,
    sales_channel_id int null,
    characteristic_id int null,
    characteristic_old_from int null,
    characteristic_group nvarchar(20) null,
    month_id int null,
    stock_qty decimal(18,4) null,
	stock_cost_net decimal(18,4) null,
	channel_group nvarchar(20) null,
	distr_cluster nvarchar(20) null,
	wh_group nvarchar(20) null,
	channel_group_l180d_total decimal(18,4) null,
	distr_cluster_l180d_total decimal(18,4) null,
	channel_group_distr_share float null
);

with cte_stock_mezzo_prep as (	
	select
		date_id, 
		warehouse_id, 
		sales_channel_id, 
		characteristic_id,
		characteristic_old_from,
		characteristic_group,
	  	month_id,
	  	cast(coalesce(qty_stock,0) as decimal(18,4)) as stock_qty,
	  	cast(coalesce(cost_net_stock,0) as decimal(18,4)) as stock_cost_net,
	  	case
			when upper(characteristic_group) in ('BNOS') then 'new'
			when upper(characteristic_group) in ('OS') then 'os'
			when date_id >= characteristic_old_from  then 'old' 
			else 'new'
		end as distr_cluster
	from RetailAnalytics_dev.dbo.stock_turnover_cte_stock_movement_cleaned
	where
		upper(characteristic_group) not in ('OS')
		and wh_group_low in ('DISTR_MEZZO')
),

cte_stock_mezzo_not_os as (
select 
	a.date_id, 
	a.warehouse_id, 
	a.sales_channel_id, 
	a.characteristic_id,
	a.characteristic_old_from,
	a.characteristic_group,
	a.month_id,
	coalesce (a.stock_qty,0) * coalesce (b.channel_group_distr_share,0) as stock_qty,
	coalesce (a.stock_cost_net,0) * coalesce (b.channel_group_distr_share,0) as stock_cost_net,
	b.channel_group,
	a.distr_cluster,
	b.channel_group as wh_group, --exception as split
	b.channel_group_l180d_total,
	b.distr_cluster_l180d_total,
	b.channel_group_distr_share
from cte_stock_mezzo_prep a
left join RetailAnalytics_dev.dbo.stock_turnover_cte_distr_shares b
	on a.distr_cluster = b.distr_cluster
	and a.month_id = b.month_id
where b.channel_group is not null
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_turnover_cte_stock_mezzo_not_os
select * from cte_stock_mezzo_not_os;

-----------------------------------------------------------------

--RETURNS
--CREATE

USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_turnover_cte_stock_returns_not_os;

CREATE TABLE dbo.stock_turnover_cte_stock_returns_not_os (
    date_id int NULL,
    warehouse_id int null,
    sales_channel_id int null,
    characteristic_id int null,
    characteristic_old_from int null,
    characteristic_group nvarchar(20) null,
    month_id int null,
    stock_qty decimal(18,4) null,
	stock_cost_net decimal(18,4) null,
	channel_group nvarchar(20) null,
	distr_cluster nvarchar(20) null,
	wh_group nvarchar(20) null,
	channel_group_l180d_total decimal(18,4) null,
	distr_cluster_l180d_total decimal(18,4) null,
	channel_group_distr_share float null
);

with cte_stock_returns_prep as (	
	select
		date_id, 
		warehouse_id, 
		sales_channel_id, 
		characteristic_id,
		characteristic_old_from,
		characteristic_group,
	  	month_id,
	  	cast(coalesce (qty_stock,0) as decimal(18,4)) as stock_qty,
	  	cast(coalesce (cost_net_stock,0) as decimal(18,4)) as stock_cost_net,
	  	'old' as distr_cluster
	from RetailAnalytics_dev.dbo.stock_turnover_cte_stock_movement_cleaned
	where
		wh_group_low in ('DISTR_RETURN')
		and upper(characteristic_group) not in ('OS')
),

cte_stock_returns as (
select 
	a.date_id, 
	a.warehouse_id, 
	a.sales_channel_id, 
	a.characteristic_id,
	a.characteristic_old_from,
	a.characteristic_group,
	a.month_id,
	coalesce (a.stock_qty,0) * coalesce (b.channel_group_distr_share,0) as stock_qty,
	coalesce (a.stock_cost_net,0) * coalesce (b.channel_group_distr_share,0) as stock_cost_net,
	b.channel_group,
	a.distr_cluster,
	b.channel_group as wh_group, --exception as split
	b.channel_group_l180d_total,
	b.distr_cluster_l180d_total,
	b.channel_group_distr_share
from cte_stock_returns_prep a
left join RetailAnalytics_dev.dbo.stock_turnover_cte_distr_shares b
	on a.distr_cluster = b.distr_cluster
	and a.month_id = b.month_id
where b.channel_group is not null
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_turnover_cte_stock_returns_not_os
select * from cte_stock_returns;

-----------------------------------------------------------------

--OS
--CREATE

USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_turnover_cte_stock_outlet_specials;

CREATE TABLE dbo.stock_turnover_cte_stock_outlet_specials (
    date_id int NULL,
    warehouse_id int null,
    sales_channel_id int null,
    characteristic_id int null,
    characteristic_old_from int null,
    characteristic_group nvarchar(20) null,
    month_id int null,
    stock_qty decimal(18,4) null,
	stock_cost_net decimal(18,4) null,
	channel_group nvarchar(20) null,
	distr_cluster nvarchar(20) null,
	wh_group nvarchar(20) null,
	channel_group_l180d_total decimal(18,4) null,
	distr_cluster_l180d_total decimal(18,4) null,
	channel_group_distr_share float null
);

--LOGIC
with cte_stock_outlet_specials as (	
	select
		date_id, 
		warehouse_id, 
		sales_channel_id, 
		characteristic_id,
		characteristic_old_from,
		characteristic_group,
	  	month_id,
	  	cast(coalesce (qty_stock,0) as decimal(18,4)) as stock_qty,
	  	cast(coalesce (cost_net_stock,0) as decimal(18,4)) as stock_cost_net,
	  	'OUTLET' as channel_group,
	  	'os' as distr_cluster,
	  	'OUTLET' as wh_group,
	  	null as channel_group_l180d_total,
		null as distr_cluster_l180d_total,
		null as channel_group_distr_share
	from RetailAnalytics_dev.dbo.stock_turnover_cte_stock_movement_cleaned
	where
		wh_group_low in ('DISTR_MEZZO','DISTR_BOX','DISTR_RETURN')
		and UPPER(characteristic_group) in ('OS')
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_turnover_cte_stock_outlet_specials
select * from cte_stock_outlet_specials;

-----------------------------------------------------------------

--BOX
--CREATE

USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_turnover_cte_stock_box_not_os;

CREATE TABLE dbo.stock_turnover_cte_stock_box_not_os (
    date_id int NULL,
    warehouse_id int null,
    sales_channel_id int null,
    characteristic_id int null,
    characteristic_old_from int null,
    characteristic_group nvarchar(20) null,
    month_id int null,
    stock_qty decimal(18,4) null,
	stock_cost_net decimal(18,4) null,
	channel_group nvarchar(20) null,
	distr_cluster nvarchar(20) null,
	wh_group nvarchar(20) null,
	channel_group_l180d_total decimal(18,4) null,
	distr_cluster_l180d_total decimal(18,4) null,
	channel_group_distr_share float null
);

--LOGIC
with cte_stock_box as (	
	select
		date_id, 
		warehouse_id, 
		sales_channel_id, 
		characteristic_id,
		characteristic_old_from,
		characteristic_group,
	  	month_id,
	  	cast(coalesce (qty_stock,0) as decimal(18,4)) as stock_qty,
	  	cast(coalesce (cost_net_stock,0) as decimal(18,4)) as stock_cost_net,
	  	case
			when upper(characteristic_group) in ('BNOS') then 'FULLPRICE'
			when date_id >= characteristic_old_from  then 'OUTLET' 
			else 'FULLPRICE'
		end as channel_group,
	  	case
			when upper(characteristic_group) in ('BNOS') then 'new'
			when upper(characteristic_group) in ('OS') then 'os'
			when date_id >= characteristic_old_from  then 'old' 
			else 'new' 
		end as distr_cluster,
		case
			when upper(characteristic_group) in ('BNOS') then 'FULLPRICE'
			when date_id >= characteristic_old_from  then 'OUTLET' 
			else 'FULLPRICE'
		end as wh_group, -- exeption as split
		null as channel_group_l180d_total,
		null as distr_cluster_l180d_total,
		null as channel_group_distr_share
	from RetailAnalytics_dev.dbo.stock_turnover_cte_stock_movement_cleaned
	where
		wh_group_low in ('DISTR_BOX')
		and upper(characteristic_group) not in ('OS')
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_turnover_cte_stock_box_not_os
select * from cte_stock_box;

-----------------------------------------------------------------

--FULL STOCK
--CREATE

USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_turnover_cte_stock_full;

CREATE TABLE dbo.stock_turnover_cte_stock_full (
    date_id int NULL,
    warehouse_id int null,
    sales_channel_id int null,
    characteristic_id int null,
    characteristic_old_from int null,
    characteristic_group nvarchar(20) null,
    month_id int null,
    stock_qty decimal(18,4) null,
	stock_cost_net decimal(18,4) null,
	channel_group nvarchar(20) null,
	distr_cluster nvarchar(20) null,
	wh_group nvarchar(20) null,
	channel_group_l180d_total decimal(18,4) null,
	distr_cluster_l180d_total decimal(18,4) null,
	channel_group_distr_share float null
);

with cte_stock_full as (	
	select * from RetailAnalytics_dev.dbo.stock_turnover_cte_stock_direct
	union all
	select * from RetailAnalytics_dev.dbo.stock_turnover_cte_stock_mezzo_not_os
	union all
	select * from RetailAnalytics_dev.dbo.stock_turnover_cte_stock_returns_not_os
	union all
	select * from RetailAnalytics_dev.dbo.stock_turnover_cte_stock_outlet_specials
	union all
	select * from RetailAnalytics_dev.dbo.stock_turnover_cte_stock_box_not_os
	union all 
	select * from RetailAnalytics_dev.dbo.stock_turnover_cte_stock_ozon_lamoda_apis
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_turnover_cte_stock_full
select * from cte_stock_full;

-----------------------------------------------------------------
-----------------------------------------------------------------

--FULL STOCK
--CREATE

USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_turnover_cte_stock_balance_wh_group;

CREATE TABLE dbo.stock_turnover_cte_stock_balance_wh_group (
    date_id int NULL,
    wh_group nvarchar(20) null,
    month_id int null,
    stock_qty decimal(18,4) null,
	stock_cost_net decimal(18,4) null
);

with cte_stock_full_wh_group as (	
	select 
		b.date_id,
	    b.wh_group,
	    b.month_id,
	    sum(coalesce(b.stock_qty,0)) as stock_qty,
		sum(coalesce(b.stock_cost_net,0)) as stock_cost_net
	from RetailAnalytics_dev.dbo.stock_turnover_cte_stock_full b
	group by
		b.date_id,
	    b.wh_group,
	    b.month_id
),

cte_stock_balance_wh_group as (	
	select 
		a.date_id,
	    b.wh_group,
	    a.month_id,
	    sum(coalesce(b.stock_qty,0)) as stock_qty,
		sum(coalesce(b.stock_cost_net,0)) as stock_cost_net
	from RetailAnalytics_dev.dbo.stock_turnover_cte_dates a
	left join cte_stock_full_wh_group b
		on a.month_id = b.month_id
	where a.date_id >= b.date_id
	group by
		a.date_id,
	    b.wh_group,
	    a.month_id
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_turnover_cte_stock_balance_wh_group
select * from cte_stock_balance_wh_group;

-----------------------------------------------------------------

--FULL STOCK
--CREATE

USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_turnover_cte_stock_balance_wh_group_stores;

CREATE TABLE dbo.stock_turnover_cte_stock_balance_wh_group_stores (
    date_id int NULL,
    wh_group nvarchar(20) null,
    store_name_short_adj nvarchar(20) null,
    month_id int null,
    stock_qty decimal(18,4) null,
	stock_cost_net decimal(18,4) null
);

with cte_stock_full_wh_group as (	
	select 
		b.date_id,
	    b.wh_group,
		case 
			when d.store_name_short not in ('OTH_OTH') then d.store_name_short
			when c.channel_group = 'SERVICE' then c.wh_group_low
			else 'DEFINE'
		end as store_name_short_adj,
	    b.month_id,
	    sum(coalesce(b.stock_qty,0)) as stock_qty,
		sum(coalesce(b.stock_cost_net,0)) as stock_cost_net
	from RetailAnalytics_dev.dbo.stock_turnover_cte_stock_full b
	left join RetailAnalytics_dev.dbo.stock_turnover_cte_wh_id_sales_channel_id_mapping c
		on b.warehouse_id = c.warehouse_id
		and b.sales_channel_id = c.sales_channel_id
	left join RetailAnalytics_dev.dbo.stock_turnover_cte_sales_channel_mapping d
		on c.sales_channel_id = d.sales_channel_id
	where b.wh_group in ('OUTLET','FULLPRICE')
	group by
		b.date_id,
	    b.wh_group,
	    b.month_id,
	    case 
			when d.store_name_short not in ('OTH_OTH') then d.store_name_short
			when c.channel_group = 'SERVICE' then c.wh_group_low
			else 'DEFINE'
		end
),

cte_stock_balance_wh_group_stores as (	
	select 
		a.date_id,
	    b.wh_group,
	    b.store_name_short_adj,
	    a.month_id,
	    sum(coalesce(b.stock_qty,0)) as stock_qty,
		sum(coalesce(b.stock_cost_net,0)) as stock_cost_net
	from RetailAnalytics_dev.dbo.stock_turnover_cte_dates a
	left join cte_stock_full_wh_group b
		on a.month_id = b.month_id
	where 
		a.date_id >= b.date_id
	group by
		a.date_id,
	    b.wh_group,
	    b.store_name_short_adj,
	    a.month_id
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_turnover_cte_stock_balance_wh_group_stores
select * from cte_stock_balance_wh_group_stores;

-----------------------------------------------------------------

--FULL SALES and STOCK
--CREATE

--XXXNULL
USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_turnover_cte_sales_and_stock_full;

CREATE TABLE dbo.stock_turnover_cte_sales_and_stock_full (
    date_id int NULL,
    warehouse_id int null,
    sales_channel_id int null,
    characteristic_id int null,
    characteristic_old_from int null,
    characteristic_group nvarchar(20) null,
    month_id int null,
    channel_group nvarchar(20) null,
    wh_group nvarchar(20) null,
    
    sales_qty decimal(18,4) null,
    sales_rrp_net decimal(18,4) null,
	sales_current_net decimal(18,4) null,
	sales_cost_net decimal(18,4) null,
	sales_cost_adj decimal(18,4) null,
	lfl_flag int null,
	lfl_flag_ly int null,
	sales_distr_cluster nvarchar(20) null,
	
    stock_qty decimal(18,4) null,
	stock_cost_net decimal(18,4) null,
	
	stock_distr_cluster nvarchar(20) null,
	channel_group_l180d_total decimal(18,4) null,
	distr_cluster_l180d_total decimal(18,4) null,
	channel_group_distr_share float null
);

--LOGIC
with cte_sales_grouped_for_full as (
	select
		a.date_id,
		a.warehouse_id,
		a.sales_channel_id,
		a.characteristic_id,
		a.characteristic_old_from,
		a.characteristic_group,
		a.month_id,
		a.channel_group,
		a.wh_group,
		sum(a.sales_qty) as sales_qty,
	    sum(a.sales_rrp_net) as sales_rrp_net,
		sum(a.sales_current_net) as sales_current_net,
		sum(a.sales_cost_net) as sales_cost_net,
		sum(a.sales_cost_adj) as sales_cost_adj,
		max(a.lfl_flag) as lfl_flag,
		max(a.lfl_flag_ly) as lfl_flag_ly,
		a.distr_cluster
		--sum(b.stock_qty) as stock_qty,
	    --sum(b.stock_rrp_net) as stock_rrp_net,
		--sum(b.stock_current_net) as stock_current_net,
		--sum(b.stock_cost_net) as stock_cost_net,
		--b.distr_cluster as stock_distr_cluster,
		--b.channel_group_l180d_total,
		--b.distr_cluster_l180d_total,
		--b.channel_group_distr_share
	from RetailAnalytics_dev.dbo.stock_turnover_cte_sales_full a
	group by
		a.date_id
		,a.warehouse_id
		,a.sales_channel_id
		,a.characteristic_id
		,a.characteristic_old_from
		,a.characteristic_group
		,a.month_id
		,a.channel_group
		,a.wh_group
		,a.distr_cluster
),

cte_stock_grouped_for_full as (
	select
		b.date_id,
		b.warehouse_id,
		b.sales_channel_id,
		b.characteristic_id,
		b.characteristic_old_from,
		b.characteristic_group,
		b.month_id,
		b.channel_group,
		b.wh_group,
		--sum(a.sales_qty) as sales_qty,
	    --sum(a.sales_rrp_net) as sales_rrp_net,
		--sum(a.sales_current_net) as sales_current_net,
		--sum(a.sales_cost_net) as sales_cost_net,
		--a.distr_cluster as sales_distr_cluster,
		sum(b.stock_qty) as stock_qty,
		sum(b.stock_cost_net) as stock_cost_net,
		b.distr_cluster,
		max(b.channel_group_l180d_total) as channel_group_l180d_total,
		max(b.distr_cluster_l180d_total) as distr_cluster_l180d_total,
		max(b.channel_group_distr_share) as channel_group_distr_share
	from RetailAnalytics_dev.dbo.stock_turnover_cte_stock_full b
	group by
		b.date_id,
		b.warehouse_id,
		b.sales_channel_id,
		b.characteristic_id,
		b.characteristic_old_from,
		b.characteristic_group,
		b.month_id,
		b.channel_group,
		b.wh_group,
		b.distr_cluster
),

cte_sales_and_stock_full as (
	select
		coalesce(a.date_id, b.date_id) as date_id,
		coalesce(a.warehouse_id,b.warehouse_id) as warehouse_id,
		coalesce(a.sales_channel_id,b.sales_channel_id) as sales_channel_id,
		coalesce(a.characteristic_id,b.characteristic_id) as characteristic_id,
		coalesce(a.characteristic_old_from,b.characteristic_old_from) as characteristic_old_from,
		coalesce(a.characteristic_group,b.characteristic_group) as characteristic_group,
		coalesce(a.month_id,b.month_id) as month_id,
		coalesce(a.channel_group, b.channel_group) as channel_group,
		coalesce(a.wh_group, b.wh_group) as wh_group,
		coalesce(a.sales_qty,0) as sales_qty,
	    coalesce(a.sales_rrp_net,0) as sales_rrp_net,
		coalesce(a.sales_current_net,0) as sales_current_net,
		coalesce(a.sales_cost_net,0) as sales_cost_net,
		coalesce(a.sales_cost_adj,0) as sales_cost_adj,
		coalesce(a.lfl_flag,0) as lfl_flag,
		coalesce(a.lfl_flag_ly,0) as lfl_flag_ly,
		a.distr_cluster as sales_distr_cluster,
		coalesce(b.stock_qty,0) as stock_qty,
		coalesce(b.stock_cost_net,0) as stock_cost_net,
		b.distr_cluster as stock_distr_cluster,
		b.channel_group_l180d_total,
		b.distr_cluster_l180d_total,
		b.channel_group_distr_share
	from cte_sales_grouped_for_full a
	FULL OUTER JOIN cte_stock_grouped_for_full b
		on a.date_id= b.date_id
		and a.warehouse_id= b.warehouse_id
		and a.sales_channel_id= b.sales_channel_id
		and a.characteristic_id= b.characteristic_id
		and a.characteristic_old_from= b.characteristic_old_from
		and a.characteristic_group= b.characteristic_group
		and a.month_id= b.month_id
		and a.channel_group= b.channel_group
		and a.wh_group= b.wh_group
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_turnover_cte_sales_and_stock_full
select * from cte_sales_and_stock_full;

-----------------------------------------------------------------

--FULL SALES and STOCK
--CREATE

--DATES INSTRUCTIONS
--CREATE
	
	
USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_turnover_cte_dates_input;

CREATE TABLE dbo.stock_turnover_cte_dates_input (
    period_type nvarchar(20) NULL,
    period_start int null,
    period_end int null,
    period_month_id int null
);
	
WITH ReferenceDates AS (
    -- Generate yesterday as the reference date for the current year and last 2 full years
    SELECT 
        DATEADD(DAY, -1, GETDATE()) AS RefDate, -- Yesterday for the current year
        YEAR(GETDATE()) AS YearNumber
    UNION ALL
    SELECT 
        DATEADD(DAY, -1, DATEADD(YEAR, -1, GETDATE())) AS RefDate, -- Yesterday for last year
        YEAR(GETDATE()) - 1 AS YearNumber
    UNION ALL
    SELECT 
        DATEADD(DAY, -1, DATEADD(YEAR, -2, GETDATE())) AS RefDate, -- Yesterday for 2 years ago
        YEAR(GETDATE()) - 2 AS YearNumber
),

cte_mtds as (
SELECT 
	-- Date ID of the beginning of the month of the reference date
    CAST(FORMAT(DATEADD(DAY, 1 - DAY(RefDate), RefDate), 'yyyyMMdd') AS INT) AS period_start, 
    
    -- Date ID of the reference date (yesterday)
    CAST(FORMAT(RefDate, 'yyyyMMdd') AS INT) AS period_end, 
    
    -- Date ID of the reference date minus 28 days
    CAST(FORMAT(DATEADD(DAY, -27, RefDate), 'yyyyMMdd') AS INT) AS minus_28, 
    
    -- Date ID of the reference date minus 365 days
    CAST(FORMAT(DATEADD(DAY, -364, RefDate), 'yyyyMMdd') AS INT) AS minus_365_sales
FROM ReferenceDates
),

AllMonths AS (
    -- Generate all months for the last 3 full years
    SELECT 
        DATEADD(MONTH, number, DATEADD(YEAR, -3, DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0))) AS MonthStart
    FROM master.dbo.spt_values
    WHERE type = 'P' 
      AND number <= DATEDIFF(MONTH, DATEADD(YEAR, -3, GETDATE()), GETDATE())
),
FilteredMonths AS (
    -- Exclude the month of yesterday
    SELECT 
        MonthStart
    FROM AllMonths
    --WHERE FORMAT(MonthStart, 'yyyyMM') <> FORMAT(DATEADD(DAY, -1, GETDATE()), 'yyyyMM')
),

cte_months as (
SELECT 
    -- Date ID of the beginning of the month
    CAST(FORMAT(MonthStart, 'yyyyMMdd') AS INT) AS period_start,
    
    -- Date ID of the end of the month
	CASE 
       WHEN EOMONTH(MonthStart) <= DATEADD(DAY, -1, GETDATE()) THEN CAST(FORMAT(EOMONTH(MonthStart), 'yyyyMMdd') AS INT)
       ELSE CAST(FORMAT(DATEADD(DAY, -1, GETDATE()), 'yyyyMMdd') AS INT)
    end AS period_end,
    
    CASE 
       WHEN EOMONTH(MonthStart) <= DATEADD(DAY, -1, GETDATE()) then CAST(FORMAT(DATEADD(DAY, -364, EOMONTH(MonthStart)), 'yyyyMMdd') AS INT)
       ELSE CAST(FORMAT(DATEADD(DAY, -364, DATEADD(DAY, -1, GETDATE())), 'yyyyMMdd') AS INT)
    end AS minus_365_sales
  
FROM FilteredMonths
),

cte_dates_input as (
select 
	'mtd' as period_type,
	period_start as period_start,
	period_end as period_end,
	floor(period_end/100) as period_month_id
from cte_mtds

union all

select 
	'mtd_l28d' as period_type,
	minus_28 as period_start,
	period_end as period_end,
	floor(period_end/100) as period_month_id
from cte_mtds

union all

select 
	'mtd_l365d' as period_type,
	minus_365_sales as period_start,
	period_end as period_end,
	floor(period_end/100) as period_month_id
from cte_mtds

union all

select 
	'month' as period_type,
	period_start as period_start,
	period_end as period_end,
	floor(period_end/100) as period_month_id
from cte_months

union all

select 
	'month_l365d' as period_type,
	minus_365_sales as period_start,
	period_end as period_end,
	floor(period_end/100) as period_month_id
from cte_months
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_turnover_cte_dates_input
select * from cte_dates_input;

---------------------------------------------------------------------
---------------------------------------------------------------------

--MAIN DATASET FOR GENERAL TURNOVER RATIO
--CREATE
	
USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_turnover_general;

CREATE TABLE dbo.stock_turnover_general (

    month_id int null,
    wh_group nvarchar(20) null,
	
	month_sales_qty decimal(18,4) null,
	month_sales_rrp_net decimal(18,4) null,
	month_sales_current_net decimal(18,4) null,
	month_sales_cost_net decimal(18,4) null,
	month_sales_cost_adj decimal(18,4) null,
	month_stock_qty decimal(18,4) null,
	month_stock_cost_net decimal(18,4) null,
	
	month_l365d_sales_qty decimal(18,4) null,
	month_l365d_sales_rrp_net decimal(18,4) null,
	month_l365d_sales_current_net decimal(18,4) null,
	month_l365d_sales_cost_net decimal(18,4) null,
	month_l365d_sales_cost_adj decimal(18,4) null,
	month_l365d_stock_count int null,
	month_l365d_stock_qty decimal(18,4) null,
	month_l365d_stock_cost_net decimal(18,4) null,
	
	mtd_sales_qty  decimal(18,4) null,
	mtd_sales_rrp_net  decimal(18,4) null,
	mtd_sales_current_net decimal(18,4) null,
	mtd_sales_cost_net decimal(18,4) null,
	mtd_sales_cost_adj decimal(18,4) null,
	mtd_stock_qty decimal(18,4) null,
	mtd_stock_cost_net decimal(18,4) null,
	
	mtd_l365d_sales_qty decimal(18,4) null,
	mtd_l365d_sales_rrp_net decimal(18,4) null,
	mtd_l365d_sales_current_net decimal(18,4) null,
	mtd_l365d_sales_cost_net decimal(18,4) null,
	mtd_l365d_sales_cost_adj decimal(18,4) null,
	mtd_l365d_stock_count decimal(18,4) null,
	mtd_l365d_stock_qty decimal(18,4) null,
	mtd_l365d_stock_cost_net decimal(18,4) null,
	
	mtd_l28d_sales_qty decimal(18,4) null,
	mtd_l28d_sales_rrp_net decimal(18,4) null,
	mtd_l28d_sales_current_net decimal(18,4) null,
	mtd_l28d_sales_cost_net decimal(18,4) null,
	mtd_l28d_sales_cost_adj decimal(18,4) null
);

--LOGIC
with cte_sales_grouped as (
select
	'sales' as data_type,
	a.period_type,
	a.period_start,
	a.period_end,
	a.period_month_id,
	b.wh_group,
	sum(coalesce(b.sales_qty,0)) as sales_qty,
	sum(coalesce(b.sales_rrp_net,0)) as sales_rrp_net,
	sum(coalesce(b.sales_current_net,0)) as sales_current_net,
	sum(coalesce(b.sales_cost_net,0)) as sales_cost_net,
	sum(coalesce(b.sales_cost_adj,0)) as sales_cost_adj
from RetailAnalytics_dev.dbo.stock_turnover_cte_dates_input a
left join RetailAnalytics_dev.dbo.stock_turnover_cte_sales_full b
	on 1=1
where b.date_id >= a.period_start
	and b.date_id <= a.period_end
group by
	a.period_type,
	a.period_start,
	a.period_end,
	a.period_month_id,
	b.wh_group
),

cte_stock_grouped_movement as (
select
	'stock' as data_type,
	a.period_type,
	a.period_start,
	a.period_end,
	a.period_month_id,
	b.month_id,
	b.wh_group,
	sum(coalesce(b.stock_qty,0)) as stock_qty,
	sum(coalesce(b.stock_cost_net,0)) as stock_cost_net
from RetailAnalytics_dev.dbo.stock_turnover_cte_dates_input a
left join RetailAnalytics_dev.dbo.stock_turnover_cte_stock_full b
	on 1=1
where b.date_id >= a.period_start
	and b.date_id <= a.period_end
group by
	a.period_type,
	a.period_start,
	a.period_end,
	a.period_month_id,
	b.wh_group,
	b.month_id
),
		
cte_stock_grouped_counted_movement as (
select
	'stock' as data_type,
	period_type,
	period_start,
	period_end,
	period_month_id,
	wh_group,
	sum(case when coalesce(stock_qty,0)<>0 then 1 else 0 end) as stock_months_count,
	sum(coalesce(stock_qty,0)) as stock_qty,
	sum(coalesce(stock_cost_net,0)) as stock_cost_net
from cte_stock_grouped_movement
group by
	period_type,
	period_start,
	period_end,
	period_month_id,
	wh_group
),

cte_types_in_column_movement as (
select
	coalesce (a.period_type , b.period_type) as period_type,
	coalesce (a.period_start, b.period_start) as period_start,
	coalesce (a.period_end , b.period_end) as period_end,
	coalesce (a.period_month_id , b.period_month_id) as period_month_id,
	coalesce (a.wh_group , b.wh_group) as wh_group,
	coalesce (a.sales_qty,0) as sales_qty,
	coalesce (a.sales_rrp_net,0) as sales_rrp_net,
	coalesce (a.sales_current_net,0) as sales_current_net,
	coalesce (a.sales_cost_net,0) as sales_cost_net,
	coalesce (a.sales_cost_adj,0) as sales_cost_adj,
	case when b.stock_months_count>12 then 12 else b.stock_months_count end as stock_months_count,
	coalesce (b.stock_qty,0) as stock_qty,
	coalesce (b.stock_cost_net,0) as stock_cost_net
	
from cte_sales_grouped a
full outer join cte_stock_grouped_counted_movement b
	on a.period_type = b.period_type
	and a.period_start = b.period_start
	and a.period_end = b.period_end
	and a.period_month_id = b.period_month_id
	and a.wh_group = b.wh_group
),

cte_stock_grouped_counted as (
select
	'stock' as data_type,
	a.period_type,
	a.period_start,
	a.period_end,
	a.period_month_id,
	b.wh_group,
	sum(case when coalesce(stock_qty,0)>0 then 1 else 0 end) as stock_count,
	sum(coalesce(b.stock_qty,0)) as stock_qty,
	sum(coalesce(b.stock_cost_net,0)) as stock_cost_net
from RetailAnalytics_dev.dbo.stock_turnover_cte_dates_input a
left join RetailAnalytics_dev.dbo.stock_turnover_cte_stock_balance_wh_group b
	on 1=1
where b.date_id >= a.period_start
	and b.date_id <= a.period_end
group by
	a.period_type,
	a.period_start,
	a.period_end,
	a.period_month_id,
	b.wh_group
),

cte_types_in_column as (
select
	coalesce (a.period_type , b.period_type) as period_type,
	coalesce (a.period_start, b.period_start) as period_start,
	coalesce (a.period_end , b.period_end) as period_end,
	coalesce (a.period_month_id , b.period_month_id) as period_month_id,
	coalesce (a.wh_group , b.wh_group) as wh_group,
	coalesce (a.sales_qty,0) as sales_qty,
	coalesce (a.sales_rrp_net,0) as sales_rrp_net,
	coalesce (a.sales_current_net,0) as sales_current_net,
	coalesce (a.sales_cost_net,0) as sales_cost_net,
	coalesce (a.sales_cost_adj,0) as sales_cost_adj,
	coalesce (b.stock_count,0) as stock_count,
	coalesce (b.stock_qty,0) as stock_qty,
	coalesce (b.stock_cost_net,0) as stock_cost_net
	
from cte_sales_grouped a
full outer join cte_stock_grouped_counted b
	on a.period_type = b.period_type
	and a.period_start = b.period_start
	and a.period_end = b.period_end
	and a.period_month_id = b.period_month_id
	and a.wh_group = b.wh_group
),

cte_merge_1 as (
select 
	coalesce (a.period_month_id , b.period_month_id) as period_month_id,
	coalesce (a.wh_group , b.wh_group) as wh_group,
	
	coalesce( a.sales_qty,0) as month_sales_qty,
	coalesce( a.sales_rrp_net,0) as month_sales_rrp_net,
	coalesce( a.sales_current_net,0) as month_sales_current_net,
	coalesce( a.sales_cost_net,0) as month_sales_cost_net,
	coalesce( a.sales_cost_adj,0) as month_sales_cost_adj,
	coalesce( a.stock_qty,0) as month_stock_qty,
	coalesce( a.stock_cost_net,0) as month_stock_cost_net,
	
	coalesce( b.sales_qty,0) as month_l365d_sales_qty,
	coalesce( b.sales_rrp_net,0) as month_l365d_sales_rrp_net,
	coalesce( b.sales_current_net,0) as month_l365d_sales_current_net,
	coalesce( b.sales_cost_net,0) as month_l365d_sales_cost_net,
	coalesce( b.sales_cost_adj,0) as month_l365d_sales_cost_adj,
	coalesce( b.stock_count,0) as month_l365d_stock_count,
	coalesce( b.stock_qty,0) as month_l365d_stock_qty,
	coalesce( b.stock_cost_net,0) as month_l365d_stock_cost_net
	
from (select * from cte_types_in_column_movement where period_type in ('month')) a
full outer join (select * from cte_types_in_column where period_type in ('month_l365d')) b
	on a.period_month_id = b.period_month_id
	and a.wh_group = b.wh_group
),

cte_merge_2 as (
select
	coalesce (a.period_month_id , b.period_month_id) as period_month_id,
	coalesce (a.wh_group , b.wh_group) as wh_group,
	
	coalesce( a.month_sales_qty,0) as month_sales_qty,
	coalesce( a.month_sales_rrp_net,0) as month_sales_rrp_net,
	coalesce( a.month_sales_current_net,0) as month_sales_current_net,
	coalesce( a.month_sales_cost_net,0) as month_sales_cost_net,
	coalesce( a.month_sales_cost_adj,0) as month_sales_cost_adj,
	coalesce( a.month_stock_qty,0) as month_stock_qty,
	coalesce( a.month_stock_cost_net,0) as month_stock_cost_net,
	
	coalesce( a.month_l365d_sales_qty,0) as month_l365d_sales_qty,
	coalesce( a.month_l365d_sales_rrp_net,0) as month_l365d_sales_rrp_net,
	coalesce( a.month_l365d_sales_current_net,0) as month_l365d_sales_current_net,
	coalesce( a.month_l365d_sales_cost_net,0) as month_l365d_sales_cost_net,
	coalesce( a.month_l365d_sales_cost_adj,0) as month_l365d_sales_cost_adj,
	coalesce( a.month_l365d_stock_count,0) as month_l365d_stock_count,
	coalesce( a.month_l365d_stock_qty,0) as month_l365d_stock_qty,
	coalesce( a.month_l365d_stock_cost_net,0) as month_l365d_stock_cost_net,
	
	coalesce( b.sales_qty,0) as mtd_l365d_sales_qty,
	coalesce( b.sales_rrp_net,0) as mtd_l365d_sales_rrp_net,
	coalesce( b.sales_current_net,0) as mtd_l365d_sales_current_net,
	coalesce( b.sales_cost_net,0) as mtd_l365d_sales_cost_net,
	coalesce( b.sales_cost_adj,0) as mtd_l365d_sales_cost_adj,
	coalesce( b.stock_count,0) as mtd_l365d_stock_count,
	coalesce( b.stock_qty,0) as mtd_l365d_stock_qty,
	coalesce( b.stock_cost_net,0) as mtd_l365d_stock_cost_net
	
from cte_merge_1 a
full outer join (select * from cte_types_in_column where period_type in ('mtd_l365d')) b
	on a.period_month_id = b.period_month_id
	and a.wh_group = b.wh_group
),

cte_merge_3 as (
select 
	coalesce (a.period_month_id , b.period_month_id) as period_month_id,
	coalesce (a.wh_group , b.wh_group) as wh_group,
	
	coalesce (a.month_sales_qty,0) as month_sales_qty,
	coalesce (a.month_sales_rrp_net,0) as month_sales_rrp_net,
	coalesce (a.month_sales_current_net,0) as month_sales_current_net,
	coalesce (a.month_sales_cost_net,0) as month_sales_cost_net,
	coalesce (a.month_sales_cost_adj,0) as month_sales_cost_adj,
	coalesce (a.month_stock_qty,0) as month_stock_qty,
	coalesce (a.month_stock_cost_net,0) as month_stock_cost_net,
	
	coalesce (a.month_l365d_sales_qty,0) as month_l365d_sales_qty,
	coalesce (a.month_l365d_sales_rrp_net,0) as month_l365d_sales_rrp_net,
	coalesce (a.month_l365d_sales_current_net,0) as month_l365d_sales_current_net,
	coalesce (a.month_l365d_sales_cost_net,0) as month_l365d_sales_cost_net,
	coalesce (a.month_l365d_sales_cost_adj,0) as month_l365d_sales_cost_adj,
	coalesce (a.month_l365d_stock_count,0) as month_l365d_stock_count,
	coalesce (a.month_l365d_stock_qty,0) as month_l365d_stock_qty,
	coalesce (a.month_l365d_stock_cost_net,0) as month_l365d_stock_cost_net,
	
	coalesce (b.sales_qty,0) as mtd_sales_qty,
	coalesce (b.sales_rrp_net,0) as mtd_sales_rrp_net,
	coalesce (b.sales_current_net,0) as mtd_sales_current_net,
	coalesce (b.sales_cost_net,0) as mtd_sales_cost_net,
	coalesce (b.sales_cost_adj,0) as mtd_sales_cost_adj,
	coalesce (b.stock_qty,0) as mtd_stock_qty,
	coalesce (b.stock_cost_net,0) as mtd_stock_cost_net,
	
	coalesce (a.mtd_l365d_sales_qty,0) as mtd_l365d_sales_qty,
	coalesce (a.mtd_l365d_sales_rrp_net,0) as mtd_l365d_sales_rrp_net,
	coalesce (a.mtd_l365d_sales_current_net,0) as mtd_l365d_sales_current_net,
	coalesce (a.mtd_l365d_sales_cost_net,0) as mtd_l365d_sales_cost_net,
	coalesce (a.mtd_l365d_sales_cost_adj,0) as mtd_l365d_sales_cost_adj,
	coalesce (a.mtd_l365d_stock_count,0) as mtd_l365d_stock_count,
	coalesce (a.mtd_l365d_stock_qty,0) as mtd_l365d_stock_qty,
	coalesce (a.mtd_l365d_stock_cost_net,0) as mtd_l365d_stock_cost_net
	
from cte_merge_2 a
full outer join (select * from cte_types_in_column_movement where period_type in ('mtd')) b
	on a.period_month_id = b.period_month_id
	and a.wh_group = b.wh_group
),

cte_merge_4 as (
select 
	coalesce (a.period_month_id , b.period_month_id) as month_id,
	coalesce (a.wh_group , b.wh_group) as wh_group,
	
	coalesce(a.month_sales_qty,0) as month_sales_qty,
	coalesce(a.month_sales_rrp_net,0) as month_sales_rrp_net,
	coalesce(a.month_sales_current_net,0) as month_sales_current_net,
	coalesce(a.month_sales_cost_net,0) as month_sales_cost_net,
	coalesce(a.month_sales_cost_adj,0) as month_sales_cost_adj,
	coalesce(a.month_stock_qty,0) as month_stock_qty,
	coalesce(a.month_stock_cost_net,0) as month_stock_cost_net,
	
	coalesce(a.month_l365d_sales_qty,0) as month_l365d_sales_qty,
	coalesce(a.month_l365d_sales_rrp_net,0) as month_l365d_sales_rrp_net,
	coalesce(a.month_l365d_sales_current_net,0) as month_l365d_sales_current_net,
	coalesce(a.month_l365d_sales_cost_net,0) as month_l365d_sales_cost_net,
	coalesce(a.month_l365d_sales_cost_adj,0) as month_l365d_sales_cost_adj,
	coalesce(a.month_l365d_stock_count,0) as month_l365d_stock_count,
	coalesce(a.month_l365d_stock_qty,0) as month_l365d_stock_qty,
	coalesce(a.month_l365d_stock_cost_net,0) as month_l365d_stock_cost_net,
	
	coalesce(a.mtd_sales_qty,0) as mtd_sales_qty,
	coalesce(a.mtd_sales_rrp_net,0) as mtd_sales_rrp_net,
	coalesce(a.mtd_sales_current_net,0) as mtd_sales_current_net,
	coalesce(a.mtd_sales_cost_net,0) as mtd_sales_cost_net,
	coalesce(a.mtd_sales_cost_adj,0) as mtd_sales_cost_adj,
	coalesce(a.mtd_stock_qty,0) as mtd_stock_qty,
	coalesce(a.mtd_stock_cost_net,0) as mtd_stock_cost_net,
	
	coalesce(a.mtd_l365d_sales_qty,0) as mtd_l365d_sales_qty,
	coalesce(a.mtd_l365d_sales_rrp_net,0) as mtd_l365d_sales_rrp_net,
	coalesce(a.mtd_l365d_sales_current_net,0) as mtd_l365d_sales_current_net,
	coalesce(a.mtd_l365d_sales_cost_net,0) as mtd_l365d_sales_cost_net,
	coalesce(a.mtd_l365d_sales_cost_adj,0) as mtd_l365d_sales_cost_adj,
	coalesce(a.mtd_l365d_stock_count,0) as mtd_l365d_stock_count,
	coalesce(a.mtd_l365d_stock_qty,0) as mtd_l365d_stock_qty,
	coalesce(a.mtd_l365d_stock_cost_net,0) as mtd_l365d_stock_cost_net,
	
	coalesce(b.sales_qty,0)  as mtd_l28d_sales_qty,
	coalesce(b.sales_rrp_net,0) as mtd_l28d_sales_rrp_net,
	coalesce(b.sales_current_net,0) as mtd_l28d_sales_current_net,
	coalesce(b.sales_cost_net,0) as mtd_l28d_sales_cost_net,
	coalesce(b.sales_cost_adj,0) as mtd_l28d_sales_cost_adj
	
from cte_merge_3 a
full outer join (select * from cte_types_in_column where period_type in ('mtd_l28d')) b
	on a.period_month_id = b.period_month_id
	and a.wh_group = b.wh_group
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_turnover_general
select * from cte_merge_4;

-----------------------------------------------------------------------------------------------------

--MAIN DATASET STORES TURNOVER RATIO WITH SERVICE
--CREATE
	
	
USE RetailAnalytics_dev;
DROP TABLE IF EXISTS dbo.stock_turnover_general_stores;

CREATE TABLE dbo.stock_turnover_general_stores (
	month_id int null,
    wh_group nvarchar(20) null,
    store_name_short_adj nvarchar(20) null,
	
	month_sales_qty decimal(18,4) null,
	month_sales_rrp_net decimal(18,4) null,
	month_sales_current_net decimal(18,4) null,
	month_sales_cost_net decimal(18,4) null,
	month_sales_cost_adj decimal(18,4) null,
	month_stock_qty decimal(18,4) null,
	month_stock_cost_net decimal(18,4) null,
	
	lfl_flag int null,
	lfl_flag_ly int null,
	
	month_l365d_sales_qty decimal(18,4) null,
	month_l365d_sales_rrp_net decimal(18,4) null,
	month_l365d_sales_current_net decimal(18,4) null,
	month_l365d_sales_cost_net decimal(18,4) null,
	month_l365d_sales_cost_adj decimal(18,4) null,
	month_l365d_stock_count int null,
	month_l365d_stock_qty decimal(18,4) null,
	month_l365d_stock_cost_net decimal(18,4) null,
	
	mtd_sales_qty  decimal(18,4) null,
	mtd_sales_rrp_net  decimal(18,4) null,
	mtd_sales_current_net decimal(18,4) null,
	mtd_sales_cost_net decimal(18,4) null,
	mtd_sales_cost_adj decimal(18,4) null,
	mtd_stock_qty decimal(18,4) null,
	mtd_stock_cost_net decimal(18,4) null,
	
	mtd_l365d_sales_qty decimal(18,4) null,
	mtd_l365d_sales_rrp_net decimal(18,4) null,
	mtd_l365d_sales_current_net decimal(18,4) null,
	mtd_l365d_sales_cost_net decimal(18,4) null,
	mtd_l365d_sales_cost_adj decimal(18,4) null,
	mtd_l365d_stock_count decimal(18,4) null,
	mtd_l365d_stock_qty decimal(18,4) null,
	mtd_l365d_stock_cost_net decimal(18,4) null,
	
	mtd_l28d_sales_qty decimal(18,4) null,
	mtd_l28d_sales_rrp_net decimal(18,4) null,
	mtd_l28d_sales_current_net decimal(18,4) null,
	mtd_l28d_sales_cost_net decimal(18,4) null,
	mtd_l28d_sales_cost_adj decimal(18,4) null
);

--LOGIC
with cte_sales_grouped as (
select
	'sales' as data_type,
	a.period_type,
	a.period_start,
	a.period_end,
	a.period_month_id,
	b.wh_group,
	case 
		when d.store_name_short not in ('OTH_OTH') then d.store_name_short
		when c.channel_group = 'SERVICE' then c.wh_group_low
		else 'DEFINE'
	end as store_name_short_adj, 
	sum(coalesce(b.sales_qty,0)) as sales_qty,
	sum(coalesce(b.sales_rrp_net,0)) as sales_rrp_net,
	sum(coalesce(b.sales_current_net,0)) as sales_current_net,
	sum(coalesce(b.sales_cost_net,0)) as sales_cost_net,
	sum(coalesce(b.sales_cost_adj,0)) as sales_cost_adj,
	max(coalesce(b.lfl_flag,0)) as lfl_flag,
	max(coalesce(b.lfl_flag_ly,0)) as lfl_flag_ly
from RetailAnalytics_dev.dbo.stock_turnover_cte_dates_input a
left join RetailAnalytics_dev.dbo.stock_turnover_cte_sales_full b
	on 1=1
left join RetailAnalytics_dev.dbo.stock_turnover_cte_wh_id_sales_channel_id_mapping c
	on b.warehouse_id = c.warehouse_id
	and b.sales_channel_id = c.sales_channel_id
left join RetailAnalytics_dev.dbo.stock_turnover_cte_sales_channel_mapping d
	on c.sales_channel_id = d.sales_channel_id
where b.date_id >= a.period_start
	and b.date_id <= a.period_end
	and b.wh_group in ('OUTLET','FULLPRICE')
group by
	a.period_type,
	a.period_start,
	a.period_end,
	a.period_month_id,
	b.wh_group,
	case 
		when d.store_name_short not in ('OTH_OTH') then d.store_name_short
		when c.channel_group = 'SERVICE' then c.wh_group_low
		else 'DEFINE'
	end
),

cte_stock_grouped_movement as (
select
	'stock' as data_type,
	a.period_type,
	a.period_start,
	a.period_end,
	a.period_month_id,
	b.month_id,
	b.wh_group,
	case 
		when d.store_name_short not in ('OTH_OTH') then d.store_name_short
		when c.channel_group = 'SERVICE' then c.wh_group_low
		else 'DEFINE'
	end as store_name_short_adj, 
	sum(coalesce(b.stock_qty,0)) as stock_qty,
	sum(coalesce(b.stock_cost_net,0)) as stock_cost_net
from RetailAnalytics_dev.dbo.stock_turnover_cte_dates_input a
left join RetailAnalytics_dev.dbo.stock_turnover_cte_stock_full b
	on 1=1
left join RetailAnalytics_dev.dbo.stock_turnover_cte_wh_id_sales_channel_id_mapping c
	on b.warehouse_id = c.warehouse_id
	and b.sales_channel_id = c.sales_channel_id
left join RetailAnalytics_dev.dbo.stock_turnover_cte_sales_channel_mapping d
	on c.sales_channel_id = d.sales_channel_id
where 
	b.date_id >= a.period_start
	and b.date_id <= a.period_end
	and b.wh_group in ('OUTLET','FULLPRICE')
group by
	a.period_type,
	a.period_start,
	a.period_end,
	a.period_month_id,
	b.wh_group,
	b.month_id,
	case 
		when d.store_name_short not in ('OTH_OTH') then d.store_name_short
		when c.channel_group = 'SERVICE' then c.wh_group_low
		else 'DEFINE'
	end
),

cte_stock_grouped_counted_movement as (
select
	'stock' as data_type,
	period_type,
	period_start,
	period_end,
	period_month_id,
	wh_group,
	store_name_short_adj,
	sum(case when coalesce(stock_qty,0)<>0 then 1 else 0 end) as stock_months_count,
	sum(coalesce(stock_qty,0)) as stock_qty,
	sum(coalesce(stock_cost_net,0)) as stock_cost_net
from cte_stock_grouped_movement
group by
	period_type,
	period_start,
	period_end,
	period_month_id,
	wh_group,
	store_name_short_adj
),

cte_types_in_column_movement as (
select
	coalesce (a.period_type , b.period_type) as period_type,
	coalesce (a.period_start, b.period_start) as period_start,
	coalesce (a.period_end , b.period_end) as period_end,
	coalesce (a.period_month_id , b.period_month_id) as period_month_id,
	coalesce (a.wh_group , b.wh_group) as wh_group,
	coalesce (a.store_name_short_adj , b.store_name_short_adj) as store_name_short_adj,
	coalesce (a.sales_qty,0) as sales_qty,
	coalesce (a.sales_rrp_net,0) as sales_rrp_net,
	coalesce (a.sales_current_net,0) as sales_current_net,
	coalesce (a.sales_cost_net,0) as sales_cost_net,
	coalesce (a.sales_cost_adj,0) as sales_cost_adj,
	coalesce (a.lfl_flag,0) as lfl_flag,
	coalesce (a.lfl_flag_ly,0) as lfl_flag_ly,
	case when b.stock_months_count>12 then 12 else b.stock_months_count end as stock_months_count,
	coalesce (b.stock_qty,0) as stock_qty,
	coalesce (b.stock_cost_net,0) as stock_cost_net
	
from cte_sales_grouped a
full outer join cte_stock_grouped_counted_movement b
	on a.period_type = b.period_type
	and a.period_start = b.period_start
	and a.period_end = b.period_end
	and a.period_month_id = b.period_month_id
	and a.wh_group = b.wh_group
	and a.store_name_short_adj = b.store_name_short_adj
),

cte_stock_grouped_counted as (
select
	'stock' as data_type,
	a.period_type,
	a.period_start,
	a.period_end,
	a.period_month_id,
	b.wh_group,
	b.store_name_short_adj,
	sum(case when coalesce(stock_qty,0)>0 then 1 else 0 end) as stock_count,
	sum(coalesce(b.stock_qty,0)) as stock_qty,
	sum(coalesce(b.stock_cost_net,0)) as stock_cost_net
from RetailAnalytics_dev.dbo.stock_turnover_cte_dates_input a
left join RetailAnalytics_dev.dbo.stock_turnover_cte_stock_balance_wh_group_stores b
	on 1=1
where b.date_id >= a.period_start
	and b.date_id <= a.period_end
group by
	a.period_type,
	a.period_start,
	a.period_end,
	a.period_month_id,
	b.wh_group,
	b.store_name_short_adj
),

cte_types_in_column as (
select
	coalesce (a.period_type , b.period_type) as period_type,
	coalesce (a.period_start, b.period_start) as period_start,
	coalesce (a.period_end , b.period_end) as period_end,
	coalesce (a.period_month_id , b.period_month_id) as period_month_id,
	coalesce (a.wh_group , b.wh_group) as wh_group,
	coalesce (a.store_name_short_adj , b.store_name_short_adj) as store_name_short_adj,
	coalesce (a.sales_qty,0) as sales_qty,
	coalesce (a.sales_rrp_net,0) as sales_rrp_net,
	coalesce (a.sales_current_net,0) as sales_current_net,
	coalesce (a.sales_cost_net,0) as sales_cost_net,
	coalesce (a.sales_cost_adj,0) as sales_cost_adj,
	coalesce (a.lfl_flag,0) as lfl_flag,
	coalesce (a.lfl_flag_ly,0) as lfl_flag_ly,
	coalesce (b.stock_count,0) as stock_count,
	coalesce (b.stock_qty,0) as stock_qty,
	coalesce (b.stock_cost_net,0) as stock_cost_net
	
from cte_sales_grouped a
full outer join cte_stock_grouped_counted b
	on a.period_type = b.period_type
	and a.period_start = b.period_start
	and a.period_end = b.period_end
	and a.period_month_id = b.period_month_id
	and a.wh_group = b.wh_group
	and a.store_name_short_adj = b.store_name_short_adj
),

cte_merge_1 as (
select 
	coalesce (a.period_month_id , b.period_month_id) as period_month_id,
	coalesce (a.wh_group , b.wh_group) as wh_group,
	coalesce (a.store_name_short_adj , b.store_name_short_adj) as store_name_short_adj,
	
	coalesce( a.sales_qty,0) as month_sales_qty,
	coalesce( a.sales_rrp_net,0) as month_sales_rrp_net,
	coalesce( a.sales_current_net,0) as month_sales_current_net,
	coalesce( a.sales_cost_net,0) as month_sales_cost_net,
	coalesce( a.sales_cost_adj,0) as month_sales_cost_adj,
	coalesce( a.stock_qty,0) as month_stock_qty,
	coalesce( a.stock_cost_net,0) as month_stock_cost_net,
	
	coalesce (a.lfl_flag,0) as lfl_flag,
	coalesce (a.lfl_flag_ly,0) as lfl_flag_ly,
	
	coalesce( b.sales_qty,0) as month_l365d_sales_qty,
	coalesce( b.sales_rrp_net,0) as month_l365d_sales_rrp_net,
	coalesce( b.sales_current_net,0) as month_l365d_sales_current_net,
	coalesce( b.sales_cost_net,0) as month_l365d_sales_cost_net,
	coalesce( b.sales_cost_adj,0) as month_l365d_sales_cost_adj,
	coalesce( b.stock_count,0) as month_l365d_stock_count,
	coalesce( b.stock_qty,0) as month_l365d_stock_qty,
	coalesce( b.stock_cost_net,0) as month_l365d_stock_cost_net
	
from (select * from cte_types_in_column_movement where period_type in ('month')) a
full outer join (select * from cte_types_in_column where period_type in ('month_l365d')) b
	on a.period_month_id = b.period_month_id
	and a.wh_group = b.wh_group
	and a.store_name_short_adj = b.store_name_short_adj
),

cte_merge_2 as (
select
	coalesce (a.period_month_id , b.period_month_id) as period_month_id,
	coalesce (a.wh_group , b.wh_group) as wh_group,
	coalesce (a.store_name_short_adj , b.store_name_short_adj) as store_name_short_adj,
	
	coalesce( a.month_sales_qty,0) as month_sales_qty,
	coalesce( a.month_sales_rrp_net,0) as month_sales_rrp_net,
	coalesce( a.month_sales_current_net,0) as month_sales_current_net,
	coalesce( a.month_sales_cost_net,0) as month_sales_cost_net,
	coalesce( a.month_sales_cost_adj,0) as month_sales_cost_adj,
	coalesce( a.month_stock_qty,0) as month_stock_qty,
	coalesce( a.month_stock_cost_net,0) as month_stock_cost_net,
	
	coalesce (a.lfl_flag,0) as lfl_flag,
	coalesce (a.lfl_flag_ly,0) as lfl_flag_ly,
	
	coalesce( a.month_l365d_sales_qty,0) as month_l365d_sales_qty,
	coalesce( a.month_l365d_sales_rrp_net,0) as month_l365d_sales_rrp_net,
	coalesce( a.month_l365d_sales_current_net,0) as month_l365d_sales_current_net,
	coalesce( a.month_l365d_sales_cost_net,0) as month_l365d_sales_cost_net,
	coalesce( a.month_l365d_sales_cost_adj,0) as month_l365d_sales_cost_adj,
	coalesce( a.month_l365d_stock_count,0) as month_l365d_stock_count,
	coalesce( a.month_l365d_stock_qty,0) as month_l365d_stock_qty,
	coalesce( a.month_l365d_stock_cost_net,0) as month_l365d_stock_cost_net,
	
	coalesce( b.sales_qty,0) as mtd_l365d_sales_qty,
	coalesce( b.sales_rrp_net,0) as mtd_l365d_sales_rrp_net,
	coalesce( b.sales_current_net,0) as mtd_l365d_sales_current_net,
	coalesce( b.sales_cost_net,0) as mtd_l365d_sales_cost_net,
	coalesce( b.sales_cost_adj,0) as mtd_l365d_sales_cost_adj,
	coalesce( b.stock_count,0) as mtd_l365d_stock_count,
	coalesce( b.stock_qty,0) as mtd_l365d_stock_qty,
	coalesce( b.stock_cost_net,0) as mtd_l365d_stock_cost_net
	
from cte_merge_1 a
full outer join (select * from cte_types_in_column where period_type in ('mtd_l365d')) b
	on a.period_month_id = b.period_month_id
	and a.wh_group = b.wh_group
	and a.store_name_short_adj = b.store_name_short_adj
),

cte_merge_3 as (
select 
	coalesce (a.period_month_id , b.period_month_id) as period_month_id,
	coalesce (a.wh_group , b.wh_group) as wh_group,
	coalesce (a.store_name_short_adj , b.store_name_short_adj) as store_name_short_adj,
	
	coalesce (a.month_sales_qty,0) as month_sales_qty,
	coalesce (a.month_sales_rrp_net,0) as month_sales_rrp_net,
	coalesce (a.month_sales_current_net,0) as month_sales_current_net,
	coalesce (a.month_sales_cost_net,0) as month_sales_cost_net,
	coalesce (a.month_sales_cost_adj,0) as month_sales_cost_adj,
	coalesce (a.month_stock_qty,0) as month_stock_qty,
	coalesce (a.month_stock_cost_net,0) as month_stock_cost_net,
	
	coalesce (a.lfl_flag,0) as lfl_flag,
	coalesce (a.lfl_flag_ly,0) as lfl_flag_ly,
	
	coalesce (a.month_l365d_sales_qty,0) as month_l365d_sales_qty,
	coalesce (a.month_l365d_sales_rrp_net,0) as month_l365d_sales_rrp_net,
	coalesce (a.month_l365d_sales_current_net,0) as month_l365d_sales_current_net,
	coalesce (a.month_l365d_sales_cost_net,0) as month_l365d_sales_cost_net,
	coalesce (a.month_l365d_sales_cost_adj,0) as month_l365d_sales_cost_adj,
	coalesce (a.month_l365d_stock_count,0) as month_l365d_stock_count,
	coalesce (a.month_l365d_stock_qty,0) as month_l365d_stock_qty,
	coalesce (a.month_l365d_stock_cost_net,0) as month_l365d_stock_cost_net,
	
	coalesce (b.sales_qty,0) as mtd_sales_qty,
	coalesce (b.sales_rrp_net,0) as mtd_sales_rrp_net,
	coalesce (b.sales_current_net,0) as mtd_sales_current_net,
	coalesce (b.sales_cost_net,0) as mtd_sales_cost_net,
	coalesce (b.sales_cost_adj,0) as mtd_sales_cost_adj,
	coalesce (b.stock_qty,0) as mtd_stock_qty,
	coalesce (b.stock_cost_net,0) as mtd_stock_cost_net,
	
	coalesce (a.mtd_l365d_sales_qty,0) as mtd_l365d_sales_qty,
	coalesce (a.mtd_l365d_sales_rrp_net,0) as mtd_l365d_sales_rrp_net,
	coalesce (a.mtd_l365d_sales_current_net,0) as mtd_l365d_sales_current_net,
	coalesce (a.mtd_l365d_sales_cost_net,0) as mtd_l365d_sales_cost_net,
	coalesce (a.mtd_l365d_sales_cost_adj,0) as mtd_l365d_sales_cost_adj,
	coalesce (a.mtd_l365d_stock_count,0) as mtd_l365d_stock_count,
	coalesce (a.mtd_l365d_stock_qty,0) as mtd_l365d_stock_qty,
	coalesce (a.mtd_l365d_stock_cost_net,0) as mtd_l365d_stock_cost_net
	
from cte_merge_2 a
full outer join (select * from cte_types_in_column_movement where period_type in ('mtd')) b
	on a.period_month_id = b.period_month_id
	and a.wh_group = b.wh_group
	and a.store_name_short_adj = b.store_name_short_adj
),

cte_merge_4 as (
select 
	coalesce (a.period_month_id , b.period_month_id) as month_id,
	coalesce (a.wh_group , b.wh_group) as wh_group,
	coalesce (a.store_name_short_adj , b.store_name_short_adj) as store_name_short_adj,

	coalesce(a.month_sales_qty,0) as month_sales_qty,
	coalesce(a.month_sales_rrp_net,0) as month_sales_rrp_net,
	coalesce(a.month_sales_current_net,0) as month_sales_current_net,
	coalesce(a.month_sales_cost_net,0) as month_sales_cost_net,
	coalesce(a.month_sales_cost_adj,0) as month_sales_cost_adj,
	coalesce(a.month_stock_qty,0) as month_stock_qty,
	coalesce(a.month_stock_cost_net,0) as month_stock_cost_net,
	
	coalesce (a.lfl_flag,0) as lfl_flag,
	coalesce (a.lfl_flag_ly,0) as lfl_flag_ly,
	
	coalesce(a.month_l365d_sales_qty,0) as month_l365d_sales_qty,
	coalesce(a.month_l365d_sales_rrp_net,0) as month_l365d_sales_rrp_net,
	coalesce(a.month_l365d_sales_current_net,0) as month_l365d_sales_current_net,
	coalesce(a.month_l365d_sales_cost_net,0) as month_l365d_sales_cost_net,
	coalesce(a.month_l365d_sales_cost_adj,0) as month_l365d_sales_cost_adj,
	coalesce(a.month_l365d_stock_count,0) as month_l365d_stock_count,
	coalesce(a.month_l365d_stock_qty,0) as month_l365d_stock_qty,
	coalesce(a.month_l365d_stock_cost_net,0) as month_l365d_stock_cost_net,
	
	coalesce(a.mtd_sales_qty,0) as mtd_sales_qty,
	coalesce(a.mtd_sales_rrp_net,0) as mtd_sales_rrp_net,
	coalesce(a.mtd_sales_current_net,0) as mtd_sales_current_net,
	coalesce(a.mtd_sales_cost_net,0) as mtd_sales_cost_net,
	coalesce(a.mtd_sales_cost_adj,0) as mtd_sales_cost_adj,
	coalesce(a.mtd_stock_qty,0) as mtd_stock_qty,
	coalesce(a.mtd_stock_cost_net,0) as mtd_stock_cost_net,
	
	coalesce(a.mtd_l365d_sales_qty,0) as mtd_l365d_sales_qty,
	coalesce(a.mtd_l365d_sales_rrp_net,0) as mtd_l365d_sales_rrp_net,
	coalesce(a.mtd_l365d_sales_current_net,0) as mtd_l365d_sales_current_net,
	coalesce(a.mtd_l365d_sales_cost_net,0) as mtd_l365d_sales_cost_net,
	coalesce(a.mtd_l365d_sales_cost_adj,0) as mtd_l365d_sales_cost_adj,
	coalesce(a.mtd_l365d_stock_count,0) as mtd_l365d_stock_count,
	coalesce(a.mtd_l365d_stock_qty,0) as mtd_l365d_stock_qty,
	coalesce(a.mtd_l365d_stock_cost_net,0) as mtd_l365d_stock_cost_net,
	
	coalesce(b.sales_qty,0)  as mtd_l28d_sales_qty,
	coalesce(b.sales_rrp_net,0) as mtd_l28d_sales_rrp_net,
	coalesce(b.sales_current_net,0) as mtd_l28d_sales_current_net,
	coalesce(b.sales_cost_net,0) as mtd_l28d_sales_cost_net,
	coalesce(b.sales_cost_adj,0) as mtd_l28d_sales_cost_adj
	
from cte_merge_3 a
full outer join (select * from cte_types_in_column where period_type in ('mtd_l28d')) b
	on a.period_month_id = b.period_month_id
	and a.wh_group = b.wh_group
	and a.store_name_short_adj = b.store_name_short_adj
)

--UPDATE
insert into RetailAnalytics_dev.dbo.stock_turnover_general_stores
select * from cte_merge_4;