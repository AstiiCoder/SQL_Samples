USE [CBTrade]
GO
/****** Object:  StoredProcedure [dbo].[PL_REPORT]    Script Date: 18.10.2021 16:27:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--------------------------------------------------------------------------------------------------------------------
-- Author:      A.Tsvetkov
-- Create date: 08.07.2019
-- Процедура получения наборов данных для построения "дополнительных" отчётов
-- Test:        exec PL_REPORT 1, '50::1::2019::1'
/*
   = Вызов без параметров выдаёт список всех отчётов
   = Вызов с одним параметром @ID (кодом отчёта) выдаёт список всех параметров, которые пользователь должен ввести
   = Вызов с двумя параметрами возвращает набор данных отчёта, где второй параметр @P1 представляет из себя набор тех значений, которые ввёл пользователь в качестве параметров, разделённых символами "::"

   Как добавить новый отчёт:
    - использовать свободный @ID, например, следующий по порядку
	- создать условие вывода параметров (@P1 is null) 
	  Пример: select 'Версия матрицы' as PARAM_NAME, (select max(ID_VER) from PL_VER where IS_ACTIVE = 1 and TYPE_GP = 1) as VER, '' as SQL_STR
	  здесь, если SQL_STR<>'', то у пользователя будет выпадающий список, если нет, то будет простое поле ввода значений 
	- создать условие вывода самого набора данных

*/
--------------------------------------------------------------------------------------------------------------------

ALTER procedure [dbo].[PL_REPORT]
	@ID int = null,                      -- код отчёта
	@P1 nvarchar(250) = null,            -- параметр
	@MAP nvarchar(1000) = null output    -- карта представления полей
as
	set nocount on


declare @NUM_YEAR int, @TYPE_GP int, @ID_VER int
declare @rank_A int, @rank_B int, @MONTH_DEPTH int, @TYPE_R varchar(5)
declare @R_A float, @R_B float, @Values1 float, @MON_DEPTH_PREV int, @MON_DEPTH_CUR int, @sql_2 varchar(1000), @FULL_SUM float, @ID_VER_PREV int

-- если вызов процедуры без параметров, то выведим список отчётов
if (@ID is null) and (@P1 is null)
	begin
		-- Список отчётов в формате: Наименование отчёта, Описание отчёта
		select 'Анализ показателей текущей ситуации' as ReportName, 'Отчёт для Отдела Маркетинга; создан на основе файла "Труднопродаваемый ассортимент".' as ReportDescription
		union all
		select 'Дельта по исполнению плана', 'Отчёт для коммерческого департамента. Объединяет данные по фактическим продажам и продажам, которые должны произойти по заказам, оформленным для отгрузки до конца месяца.'
		union all
		select 'ABC-анализ по брендам', 'Осуществляется ABC-анализ по критериям: фактические продажи в бутылках и по сумме. Глубина периода - это заданное количество целых месяцев, где последним является предыдущий закончившейся.'
		union all
		select 'ABC-анализ по доходности поставщиков', 'Осуществляется ABC-анализ по списку поставщиков. Доходность рассчитывается как разница продажных цен и среднезакупочных за реализованное количество. Глубина периода - это заданное количество целых месяцев, где последним является предыдущий закончившейся.'
		union all
		select 'Изменения планов по датам', 'Представлено кто и года менял плановое количество по артикулам брендов и датам. Глубина периода - это заданное количество дней от сегодняшнего.'
	end

-- Анализ показателей текущей ситуации ===================================================================== 
else if @ID=1 
  begin
    if @P1 is null
		begin
			-- набор запрашиваемых параметров, подготовительные действия
			declare @d1 smalldatetime, @d2 smalldatetime, @wd smallint, @pd smallint
			select @d1 = dateadd(day, 1-day(GetDate()), GetDate()), @d2 = dateadd(month,1,dateadd(day,1-day(GetDate()),GetDate()))-1
			select @wd=datediff(DAY,@d1,@d2)+1-(datediff(WEEK,@d1,@d2)*2+(case when (DATENAME(dw,@d1)='Sunday') then 1 else 0 end)+(case when (DATENAME(dw,@d2)='Saturday') then 1 else 0 end))
			select @d1 = dateadd(day, 1-day(GetDate()), GetDate()), @d2 = GetDate()-1
			select @pd=datediff(DAY,@d1,@d2)+1-(datediff(WEEK,@d1,@d2)*2+(case when (DATENAME(dw,@d1)='Sunday') then 1 else 0 end)+(case when (DATENAME(dw,@d2)='Saturday') then 1 else 0 end))
			-- набор данных для заполнения пользователем параметров отчёта
			select 'Версия матрицы' as PARAM_NAME, (select max(ID_VER) from PL_VER where IS_ACTIVE = 1 and TYPE_GP = 1) as VER, '' as SQL_STR
			union all select 'Тип поставки', 1, 'select 1, ''импортный'' union all select 2, ''привлечённый'' '
			union all select 'Год', YEAR(GetDate()), null
			union all select 'Номер месяца', MONTH(GetDate()), null
			union all select 'Всего рабочих дней', @wd, null
			union all select 'Отработано рабочих дней', @pd, null
		end
	else
		begin
			-- набор данных отчёта
			declare @NUM_MONTH int
			select @ID_VER=cast(dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) as int), @NUM_YEAR=cast(dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT) as int), @NUM_MONTH=cast(dbo.GET_PARAM_FROM_LIST(@P1, 4, DEFAULT) as int),
				@TYPE_GP=cast(dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT) as int)

			if object_id(N'tempdb..#pl_plan') is not null drop table #pl_plan
			if object_id(N'tempdb..#pl_fact') is not null drop table #pl_fact
			if object_id(N'tempdb..#t') is not null drop table #t
			if object_id(N'tempdb..#z') is not null drop table #z

			-- предполагается деление на ноль, даём спец. директивы
			SET ARITHABORT OFF
			SET ARITHIGNORE ON
			SET ANSI_WARNINGS OFF

			-- временная таблица с планом по департаменту, кроме регионов, поскольку, там разбивка по агентам  
			select null as ID_ROW, pp.ID_GP, pp.DEPART, 0 as AGENT,
				sum(pp.M1) as M1, sum(pp.M2) as M2, sum(pp.M3) as M3, sum(pp.M4) as M4, sum(pp.M5) as M5, sum(pp.M6) as M6, 
				sum(pp.M7) as M7, sum(pp.M8) as M8, sum(pp.M9) as M9, sum(pp.M10) as M10, sum(pp.M11) as M11, sum(pp.M12) as M12, 
				sum(pp.TOTAL_YEAR) as TOTAL_YEAR, avg(pp.CALC_PRICE) as CALC_PRICE 
			into #pl_plan
			from PL_PLAN pp 
			where pp.NUM_YEAR = @NUM_YEAR and pp.DEPART <> 10 
			group by pp.ID_GP, pp.DEPART
			-- добавляем план по регионам с группировкой по агентам
			insert into #pl_plan
			select null as ID_ROW, pp.ID_GP, pp.DEPART, pp.AGENT, 
				sum(pp.M1) as M1, sum(pp.M2) as M2, sum(pp.M3) as M3, sum(pp.M4) as M4, sum(pp.M5) as M5, sum(pp.M6) as M6, 
				sum(pp.M7) as M7, sum(pp.M8) as M8, sum(pp.M9) as M9, sum(pp.M10) as M10, sum(pp.M11) as M11, sum(pp.M12) as M12, 
				sum(pp.TOTAL_YEAR) as TOTAL_YEAR, avg(pp.CALC_PRICE) as CALC_PRICE 
			from PL_PLAN pp 
			where pp.NUM_YEAR = @NUM_YEAR and pp.DEPART = 10 
			group by pp.ID_GP, pp.DEPART, pp.AGENT
			-- временная таблица с фактом по департаментам, кроме регионов, поскольку, там разбивка по агентам 
			select pf.POS_NUM, pf.POS_CODE, pf.TYPE_GP, pf.DEPART, 0 as AGENT, 
				sum(pf.K1) as K1, sum(pf.A1) as A1, sum(pf.K2) as K2, sum(pf.A2) as A2, sum(pf.K3) as K3, sum(pf.A3) as A3, 
				sum(pf.K4) as K4, sum(pf.A4) as A4, sum(pf.K5) as K5, sum(pf.A5) as A5, sum(pf.K6) as K6, sum(pf.A6) as A6, 
				sum(pf.K7) as K7, sum(pf.A7) as A7, sum(pf.K8) as K8, sum(pf.A8) as A8, sum(pf.K9) as K9, sum(pf.A9) as A9, 
				sum(pf.K10) as K10, sum(pf.A10) as A10, sum(pf.K11) as K11, sum(pf.A11) as A11, sum(pf.K12) as K12, sum(pf.A12) as A12
			into #pl_fact
			from PL_FACT pf
			where pf.NUM_YEAR = @NUM_YEAR and pf.DEPART <> 10 
			group by pf.POS_NUM, pf.POS_CODE, pf.TYPE_GP, pf.DEPART
			-- добавляем факт по регионам с группировкой по агентам
			insert into #pl_fact
			select pf.POS_NUM, pf.POS_CODE, pf.TYPE_GP, pf.DEPART, pf.AGENT as AGENT, 
				sum(pf.K1) as K1, sum(pf.A1) as A1, sum(pf.K2) as K2, sum(pf.A2) as A2, sum(pf.K3) as K3, sum(pf.A3) as A3, 
				sum(pf.K4) as K4, sum(pf.A4) as A4, sum(pf.K5) as K5, sum(pf.A5) as A5, sum(pf.K6) as K6, sum(pf.A6) as A6, 
				sum(pf.K7) as K7, sum(pf.A7) as A7, sum(pf.K8) as K8, sum(pf.A8) as A8, sum(pf.K9) as K9, sum(pf.A9) as A9, 
				sum(pf.K10) as K10, sum(pf.A10) as A10, sum(pf.K11) as K11, sum(pf.A11) as A11, sum(pf.K12) as K12, sum(pf.A12) as A12
			from PL_FACT pf
			where pf.NUM_YEAR = @NUM_YEAR and pf.DEPART = 10 
			group by pf.POS_NUM, pf.POS_CODE, pf.TYPE_GP, pf.DEPART, pf.AGENT
					
			-- заготовка по всем департаментам, сразу select into #t в динамич. не срабатывает
			create table #t ([№] int, [Артикул бренда] varchar(7), [Наименование бренда] varchar(50), [Наименование поставщика] varchar(150), DEPART int, AGENT int, [план (бут)] int, [план (руб)] int, [факт (бут)] int, [факт (руб)] int)
			-- в заготовку помещаем данные за выбранный месяц
			declare @ins_sql nvarchar(max)
			set @ins_sql = 'insert into #t select m.POS_NUM as [№], m.POS_CODE as [Артикул бренда], m.POS_NAME as [Наименование бренда], sf.NAME_FIRM as [Наименование поставщика], p.DEPART as DEPART, p.AGENT as AGENT,
				sum(p.M' + cast(@NUM_MONTH as varchar(2)) + ') as [план (бут)], sum(p.M' + cast(@NUM_MONTH as varchar(2)) + ' * p.CALC_PRICE)  as [план (руб)], sum(f.K' + cast(@NUM_MONTH as varchar(2)) + ') as [факт (бут)], sum(f.A' + cast(@NUM_MONTH as varchar(2)) + ') as [факт (руб)]
			from PL_VER v 
				left join PL_MATRIX m on v.ID_VER = m.ID_VER
				left join #pl_plan p on m.ID_GP = p.ID_GP
				left join #pl_fact f on m.POS_CODE = f.POS_CODE and v.TYPE_GP = f.TYPE_GP and p.DEPART = f.DEPART and (p.AGENT = f.AGENT or (p.AGENT is null and f.AGENT is null)) 
				left join SP_GOOD_BRAND sgb on m.ID_GROUP = sgb.ID_GROUP 
			    left join SP_FIRM sf on sgb.ID_POST = sf.ID_FIRM
			where v.ID_VER = ' + cast(@ID_VER as varchar(3)) + ' group by m.POS_NUM, m.POS_CODE, m.POS_NAME, p.DEPART, p.AGENT, sf.NAME_FIRM'
			exec sp_executesql @ins_sql
			
			-- текущие актуальные остатки с учётом брони
			select IsNull(gb.CODE_GROUP, gb.ORDER_BY) as CODE_GROUP, gb.ID_GROUP, sum(sgr.KOL_GOOD_U + sgr.KOL_GOOD_R) as REST
			into #r
			from S_GOOD_REST sgr
			left join SP_GOOD_BRAND_LINKS sgbl on sgr.ID_GOOD = sgbl.ID_GOOD
			left join SP_GOOD_BRAND gb on sgbl.ID_GROUP = gb.ID_GROUP
			where sgr.ID_GOOD_STATUS=1 and (sgr.KOL_GOOD_U + sgr.KOL_GOOD_R) > 0 
			group by IsNull(gb.CODE_GROUP, gb.ORDER_BY), gb.ID_GROUP

			-- текущие остатки без учёта брони
			create table #good (CODE_GROUP varchar(7), ID_GOOD int)    
			-- все товары брендов выбранного типа поставки
			insert into #good        
			select IsNull(b.CODE_GROUP, convert(varchar(7), ORDER_BY) ), l.ID_GOOD        
			from SP_GOOD_BRAND b with (nolock)    
			join SP_GOOD_BRAND_LINKS l with (nolock) on b.ID_GROUP = l.ID_GROUP and b.ID_GROUP <> 344 -- коробки исключаем т.к.они никому не интересны    
			where b.IS_IMPORT =  2 - @TYPE_GP
			-- непосредственно, остатки без учёта брони
			select gr_good.CODE_GROUP, REST = sum(REST)
			into #r_br_free
			from     
				(select ID_GOOD = coalesce(R.ID_GOOD, P.ID_GOOD) ,               
						REST = ((isnull(R.REST_U, 0) + isnull(R.REST_R, 0)) - (isnull(R.RESERVE_U, 0) + isnull(P.PLAN_RETURN_U, 0) + isnull(R.RESERVE_R, 0) + isnull(P.PLAN_RETURN_R, 0)))  
				from (              
						(select ID_GOOD, REST_U, REST_R, RESERVE_U, RESERVE_R, REST_N, RESERVE_N               
						 from GET_REST_AND_R_RESERVE (0, null, 1)              
						) R              
				full outer join                
						(select ID_GOOD, PLAN_POST_U, PLAN_POST_R, PLAN_POST_N, PLAN_RETURN_U, PLAN_RETURN_R, PLAN_RETURN_N              
						 from GET_PLAN_P_AND_RETURN_P(0,null)              
						) P on R.ID_GOOD = P.ID_GOOD)  
				) S  
			join #good gr_good on S.ID_GOOD = gr_good.ID_GOOD  
			group by gr_good.CODE_GROUP
			having sum(REST)>0

			--- параметр визуального представления полей
		    set @MAP = '[Артикул бренда]:WIDTH=100;' 
			-- непосредственно, набор данных отчёта
			select t.[№], t.[Артикул бренда], t.[Наименование бренда], 
			    replace(t.[Наименование поставщика], '"', '') as [Наименование поставщика], 
				sum(case when t.DEPART in (1, 9, 11, 12, 15) then t.[план (бут)] else 0 end) as 'On+Корп, план (бут)',
				sum(case when t.DEPART in (1, 9, 11, 12, 15) then t.[факт (бут)] else 0 end) as 'On+Корп, факт (бут)',
				sum(case when t.DEPART in (1, 9, 11, 12, 15) then t.[план (руб)] else 0 end) as 'On+Корп, план (руб)',
				sum(case when t.DEPART in (1, 9, 11, 12, 15) then t.[факт (руб)] else 0 end) as 'On+Корп, факт (руб)',
				sum(case when t.DEPART in (1, 9, 11, 12, 15) then t.[факт (бут)]*1.0/t.[план (бут)]*100 else 0 end) as 'On+Корп, план/факт, (бут, %)',
				sum(case when t.DEPART in (1, 9, 11, 12, 15) then t.[факт (руб)]*1.0/t.[план (руб)]*100 else 0 end) as 'On+Корп, план/факт, (руб, %)',

				sum(case when t.DEPART in (13) then t.[план (бут)] else 0 end) as 'Off, план (бут)',
				sum(case when t.DEPART in (13) then t.[факт (бут)] else 0 end) as 'Off, факт (бут)',
				sum(case when t.DEPART in (13) then t.[план (руб)] else 0 end) as 'Off, план (руб)',
				sum(case when t.DEPART in (13) then t.[факт (руб)] else 0 end) as 'Off, факт (руб)',
				sum(case when t.DEPART in (13) then t.[факт (бут)]*1.0/t.[план (бут)]*100 else 0 end) as 'Off, план/факт, (бут, %)',
				sum(case when t.DEPART in (13) then t.[факт (руб)]*1.0/t.[план (руб)]*100 else 0 end) as 'Off, план/факт, (руб, %)',

				sum(case when t.DEPART in (2, 6) then t.[план (бут)] else 0 end) as 'Сети, план (бут)',
				sum(case when t.DEPART in (2, 6) then t.[факт (бут)] else 0 end) as 'Сети, факт (бут)',
				sum(case when t.DEPART in (2, 6) then t.[план (руб)] else 0 end) as 'Сети, план (руб)',
				sum(case when t.DEPART in (2, 6) then t.[факт (руб)] else 0 end) as 'Сети, факт (руб)',
				sum(case when t.DEPART in (2, 6) then t.[факт (бут)]*1.0/t.[план (бут)]*100 else 0 end) as 'Сети, план/факт, (бут, %)',
				sum(case when t.DEPART in (2, 6) then t.[факт (руб)]*1.0/t.[план (руб)]*100 else 0 end) as 'Сети, план/факт, (руб, %)',

				sum(case when t.DEPART=10 and t.AGENT=724 then t.[план (бут)] else 0 end) as 'Регионы, Прохорова, план (бут)',
				sum(case when t.DEPART=10 and t.AGENT=724 then t.[факт (бут)] else 0 end) as 'Регионы, Прохорова, факт (бут)',
				sum(case when t.DEPART=10 and t.AGENT=724 then t.[план (руб)] else 0 end) as 'Регионы, Прохорова, план (руб)',
				sum(case when t.DEPART=10 and t.AGENT=724 then t.[факт (руб)] else 0 end) as 'Регионы, Прохорова, факт (руб)',
				sum(case when t.DEPART=10 and t.AGENT=724 then t.[факт (бут)]*1.0/t.[план (бут)]*100 else 0 end) as 'Регионы, Прохорова, план/факт (бут, %)',
				sum(case when t.DEPART=10 and t.AGENT=724 then t.[факт (руб)]*1.0/t.[план (руб)]*100 else 0 end) as 'Регионы, Прохорова, план/факт (руб, %)',

				sum(case when t.DEPART=10 and t.AGENT=817 then t.[план (бут)] else 0 end) as 'Регионы, Кораблёв, план (бут)',
				sum(case when t.DEPART=10 and t.AGENT=817 then t.[факт (бут)] else 0 end) as 'Регионы, Кораблёв, факт (бут)',
				sum(case when t.DEPART=10 and t.AGENT=817 then t.[план (руб)] else 0 end) as 'Регионы, Кораблёв, план (руб)',
				sum(case when t.DEPART=10 and t.AGENT=817 then t.[факт (руб)] else 0 end) as 'Регионы, Кораблёв, факт (руб)',
				sum(case when t.DEPART=10 and t.AGENT=817 then t.[факт (бут)]*1.0/t.[план (бут)]*100 else 0 end) as 'Регионы, Кораблёв, план/факт (бут, %)',
				sum(case when t.DEPART=10 and t.AGENT=817 then t.[факт (руб)]*1.0/t.[план (руб)]*100 else 0 end) as 'Регионы, Кораблёв, план/факт (руб, %)',

				sum(case when t.DEPART=10 and t.AGENT=3644 then t.[план (бут)] else 0 end) as 'Регионы, Кузьмин, план (бут)',
				sum(case when t.DEPART=10 and t.AGENT=3644 then t.[факт (бут)] else 0 end) as 'Регионы, Кузьмин, факт (бут)',
				sum(case when t.DEPART=10 and t.AGENT=3644 then t.[план (руб)] else 0 end) as 'Регионы, Кузьмин, план (руб)',
				sum(case when t.DEPART=10 and t.AGENT=3644 then t.[факт (руб)] else 0 end) as 'Регионы, Кузьмин, факт (руб)',
				sum(case when t.DEPART=10 and t.AGENT=3644 then t.[факт (бут)]*1.0/t.[план (бут)]*100 else 0 end) as 'Регионы, Кузьмин, план/факт (бут, %)',
				sum(case when t.DEPART=10 and t.AGENT=3644 then t.[факт (руб)]*1.0/t.[план (руб)]*100 else 0 end) as 'Регионы, Кузьмин, план/факт (руб, %)',

				sum(t.[план (бут)]) as 'В ЦЕЛОМ ПО ЦБ, план (бут)',
				sum(t.[факт (бут)]) as 'В ЦЕЛОМ ПО ЦБ, факт (бут)',
				sum(t.[план (руб)]) as 'В ЦЕЛОМ ПО ЦБ, план (руб)',
				sum(t.[факт (руб)]) as 'В ЦЕЛОМ ПО ЦБ, факт (руб)',
				sum(t.[факт (бут)]*1.0/t.[план (бут)]*100) as 'В ЦЕЛОМ ПО ЦБ, план/факт (бут, %)',
				sum(t.[факт (руб)]*1.0/t.[план (руб)]*100) as 'В ЦЕЛОМ ПО ЦБ, план/факт (руб, %)',
				max(r.REST) as 'Текущее наличие с уч.бр. (бут)',
				max(IsNull(rbf.REST,0)) as 'Текущее наличие без уч.бр. (бут)'
			from #t t
			left join #r r on t.[Артикул бренда] = r.CODE_GROUP 
			left join #r_br_free rbf on t.[Артикул бренда] = rbf.CODE_GROUP 
			group by t.[№], t.[Артикул бренда], t.[Наименование бренда],  t.[Наименование поставщика]
			order by t.[№] 

			drop table #r
			drop table #good   
			drop table #r_br_free   
		end
  end

-- Дельта по исполнению плана ===================================================================== пример: exec PL_REPORT 2, '51::1::2020::01::null:null'
else if @ID=2 
  begin
    if @P1 is null
		begin
			-- набор данных для заполнения пользователем параметров отчёта
			select 'Версия матрицы', cast(max(ID_VER) as varchar(10)), '' from PL_VER where IS_ACTIVE = 1 and TYPE_GP = 1
			union all select 'Тип поставки', 1, 'select 1, ''импортный'' union all select 2, ''привлечённый'' '
			union all select 'Год', cast(YEAR(GetDate()) as varchar(10)), null
			union all select 'Номер месяца', cast(MONTH(GetDate()) as varchar(10)), null
			/*union all select 'Департамент', 'все', null
			union all select 'Агент', null, 'select ID_PERS,
												   LAST_NAME = LAST_NAME+'' '' +FIRST_NAME
											 from SP_PERS p
												 join SP_REL_PERS_ACTIVE a on p.ID_PERS = a.ID_PERS_AGENT
											 where PROF = ''агн''
											 order by LAST_NAME'*/
		end
	else
		begin
		  declare @agent_2 int, @NUM_YEAR_2 int, @ID_VER_2 int, @TYPE_GP_2 int
		  select @NUM_YEAR_2=dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT), @agent_2 = dbo.GET_PARAM_FROM_LIST(@P1, 6, DEFAULT), 
		    @ID_VER_2 = dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT), @TYPE_GP_2 = dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT) 
		  		  
		  select rhz.ID_AGENT,
			ID_GOOD = sg.GOOD_COD,
			NAME = sg.GOOD_NAME_SPB,
			KOL = sum(KOL_GOOD_U + KOL_GOOD_R),
			rhz.ID_MANAGER,
			SUMM = sum(STO_GOOD)
		  into #zak
		  from R_HD_ZAK rhz with (NOLOCK)
			join SP_SOST sps on rhz.ID_SOST=sps.ID_SOST
			join R_HD_NAKL rhn with (NOLOCK) on rhn.ID_HD_ZAK=rhz.ID_HD_ZAK
			join R_GOOD_NAKL rgn with (NOLOCK) on rhn.ID_HD_NAKL = rgn.ID_HD_NAKL
			join SP_FIRM sp with (NOLOCK) on rhn.ID_POST=sp.ID_FIRM
			join SP_GOOD sg with (NOLOCK) on rgn.ID_GOOD = sg.GOOD_COD
			join SP_TYPE_PAYMENT spt with (NOLOCK) on rhz.ID_F_OPL=spt.ID_TYPE_PAYMENT
		  where rhz.DAT_V_ZAK between GetDate() and GetDate()+30
			and rhz.ID_AGENT is not null
			and rhz.ID_SOST in (700, 800, 900, 850)
			--and rhz.ID_MANAGER = case when :men = 0 then rhz.ID_MANAGER else :men end
			--and rhz.ID_AGENT = case when cast(dbo.GET_PARAM_FROM_LIST(@P1, 6, DEFAULT) as int) = 0 then rhz.ID_AGENT else cast(dbo.GET_PARAM_FROM_LIST(@P1, 6, DEFAULT) as int) end
			and (rhz.ID_AGENT = @agent_2 or @agent_2 is null)
		  group by rhz.ID_AGENT, sg.GOOD_NAME_SPB, rhz.ID_MANAGER, sg.GOOD_COD

		  ---- параметр визуального представления полей
		  set @MAP = '[№]:WIDTH=50;[Артикул бренда]:WIDTH=100;' 
		  -- непосредственно, набор данных отчёта
		  select pm.POS_NUM as '№', pm.POS_CODE as 'Артикул бренда', pm.POS_NAME as 'Наименование бренда', sum(pp.TOTAL_YEAR) as 'План (бут)', sum(f.TOTAL_FACT) as 'Факт (бут)', sum(n.K) as 'Потенциальный факт (бут)',
			 sum(pp.TOTAL_YEAR - f.TOTAL_FACT - n.K) as 'Дельта (бут)'
		  from PL_MATRIX pm
			left join ( select pla.ID_GP, sum(pla.TOTAL_YEAR) as TOTAL_YEAR
			            from PL_PLAN pla
						where pla.NUM_YEAR = @NUM_YEAR_2
						group by pla.ID_GP ) pp on pm.ID_GP = pp.ID_GP
			left join ( select pf.POS_CODE, sum(IsNull(pf.K1, 0) + IsNull(pf.K2, 0) + IsNull(pf.K3, 0) + IsNull(pf.K4, 0) + IsNull(pf.K5, 0) + IsNull(pf.K6, 0) + 
							IsNull(pf.K7, 0) + IsNull(pf.K8, 0) + IsNull(pf.K9, 0) + IsNull(pf.K10, 0) + IsNull(pf.K11, 0) + IsNull(pf.K12, 0)) as TOTAL_FACT 
						from PL_FACT pf
						where pf.NUM_YEAR = @NUM_YEAR_2 and pf.TYPE_GP = @TYPE_GP_2
						group by pf.POS_CODE) f on pm.POS_CODE = f.POS_CODE 
			left join ( select  CODE_GROUP=IsNull(gb.CODE_GROUP, gb.ORDER_BY),
								sum(zz.KOL) as K
						from SP_REL_PERS_ACTIVE sp with (NOLOCK)
						join SP_PERS s on sp.ID_PERS_MAN=s.ID_PERS
						join N_SP_DEPART n on sp.ID_PERS_MAN=n.ID_MANAGER
						join SP_PERS ss on sp.ID_PERS_AGENT=ss.ID_PERS
						left join #zak z on s.ID_PERS=z.ID_AGENT
						left join #zak zz on ss.ID_PERS=zz.ID_AGENT
						left join SP_GOOD_BRAND_LINKS sgbl with (NOLOCK) on zz.ID_GOOD = sgbl.ID_GOOD
						left join SP_GOOD_BRAND gb with (NOLOCK) on sgbl.ID_GROUP = gb.ID_GROUP
						where s.PROF in ('мен')	and (zz.NAME is not null) and (ss.PROF in ('агн'))
						group by gb.CODE_GROUP, gb.ORDER_BY, gb.IS_IMPORT) n on pm.POS_CODE = n.CODE_GROUP 
		    where pm.ID_VER = @ID_VER_2 --and (pp.AGENT = @agent_2 or @agent_2 is null) 
			group by pm.POS_NUM, pm.POS_CODE, pm.POS_NAME
		    order by pm.POS_CODE
          
		  drop table #zak
		end
  end

-- ABC-анализ по брендам ===================================================================== пример: exec PL_REPORT 3, '6::1::1::75::95::null'  |  exec PL_REPORT 3, '6::1::3::75::95::null'
else if @ID=3 
  begin
    if @P1 is null
		begin
			-- набор данных для заполнения пользователем параметров отчёта
			select 'Глубина периода (мес)', 6, null
			union all select 'Тип поставки', 1, 'select 1, ''импортный'' union all select 2, ''привлечённый'' '						
			union all select 'Критерий', 1, 'select 1, ''бут'' union all select 2, ''руб'' union all select 3, ''доходность'' '
			union all select 'Ранг A (%)', 75, null
			union all select 'Ранг B (%)', 95, null
			union all select 'Ранг C (%)', 100, null
			union all select 'Департамент', 0, 'select 0 as ID_DEPART, ''(все)'' as NAME_AD_DEPART union all select ID_DEPART, NAME_AD_DEPART from PL_DEPART order by 2'
		end
	else
		begin						
			declare @DEPART_3 varchar(2) 
			select @MONTH_DEPTH = dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT), @TYPE_GP = dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT), 
				   @TYPE_R = dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT), 
				   @rank_A = dbo.GET_PARAM_FROM_LIST(@P1, 4, DEFAULT), @rank_B = dbo.GET_PARAM_FROM_LIST(@P1, 5, DEFAULT),
				   @DEPART_3 = dbo.GET_PARAM_FROM_LIST(@P1, 7, DEFAULT)  

			--declare @R_A float, @R_B float, @Values1 float, @MON_DEPTH_PREV int, @MON_DEPTH_CUR int, @sql_2 varchar(1000), @FULL_SUM float, @ID_VER_PREV int
			select @R_A = cast(@rank_A as float), @R_B = cast(@rank_B as float), @TYPE_R = case when (@TYPE_R='1') or (@TYPE_R='3') then 'K' when @TYPE_R = '2' then 'A' end, @NUM_YEAR=Year(GetDate())

			-- проверки адекватности параметров
			if @MONTH_DEPTH<1 or @MONTH_DEPTH>12 
				begin
					raiserror ('Глубина периода должна составлать от 1 до 12 месяцев!', 16, 1)
					return 50000
				end
			-- проверки адекватности параметров
			if @rank_A>@rank_B or @rank_A>98 or @rank_B>99
				begin
					raiserror ('Процент по рангу A не может превышать процент по рангу B!', 16, 1)
					return 50000
				end
			-- проверки адекватности параметров
			if (@rank_A+@rank_B)>197 
				begin
					raiserror ('Сумма процентов по рангам A и B не может быть больше 197!', 16, 1)
					return 50000
				end

			-- определяем какие версии матриц были в эти годы
			select @ID_VER_PREV = max(v.ID_VER)
			from PL_VER v
			left join PL_MATRIX pm on v.ID_VER = pm.ID_VER
			left join PL_PLAN pp on pm.ID_GP = pp.ID_GP 
			where pp.NUM_YEAR = @NUM_YEAR-1

			select @ID_VER = max(v.ID_VER)
			from PL_VER v
			left join PL_MATRIX pm on v.ID_VER = pm.ID_VER
			left join PL_PLAN pp on pm.ID_GP = pp.ID_GP 
			where pp.NUM_YEAR = @NUM_YEAR

			if object_id(N'tempdb..#fact') is not null drop table #fact
			set @sql_2 = ''

			create table #fact (POS_CODE varchar(10), TOTAL_FACT float)

			-- за предыдущий год, если глубина (кол-во месяцев в периоде ранжирования) выходит в прошлый год
			if Month(GetDate())<@MONTH_DEPTH 
				begin
					set @MON_DEPTH_PREV = 12 + Month(GetDate()) - @MONTH_DEPTH
				
					while @MON_DEPTH_PREV<=12
					  begin
						set @sql_2 = @sql_2 + '+ IsNull(pf.' + @TYPE_R + cast(@MON_DEPTH_PREV as varchar(2)) + ', 0)'
						set @MON_DEPTH_PREV = @MON_DEPTH_PREV + 1
					  end;

					set @sql_2 = 'select pf.POS_CODE, 
									sum('  + stuff(@sql_2, 1, 1, '') +') as TOTAL_FACT 	 	  	  
								  from PL_MATRIX pm
								  left join PL_FACT pf on pm.POS_CODE = pf.POS_CODE
								  where pf.NUM_YEAR = ' + cast(@NUM_YEAR-1 as varchar(4)) + ' and pf.TYPE_GP = ' + cast(@TYPE_GP as varchar(2)) + ' and pm.ID_VER = ' + cast(@ID_VER_PREV as varchar(2)) + ' 
									and (pf.DEPART = ' + @DEPART_3 + ' or ' + @DEPART_3 + '=0) ' + ' 
								  group by pm.POS_NUM, pm.POS_NAME, pf.POS_CODE, pf.POS_CODE'

					insert into #fact exec (@sql_2)
				end
			-- за текущий год
			if Month(GetDate())>1 
				begin
					set @MON_DEPTH_CUR = 1
					set @sql_2 = ''
				
					while @MON_DEPTH_CUR<Month(GetDate())
					  begin
						set @sql_2 = @sql_2 + '+ IsNull(pf.' + @TYPE_R + cast(@MON_DEPTH_CUR as varchar(2)) + ', 0)'
						set @MON_DEPTH_CUR = @MON_DEPTH_CUR + 1
					  end;

					set @sql_2 = 'select pf.POS_CODE, 
									sum('  + stuff(@sql_2, 1, 1, '') +') as TOTAL_FACT 	 	  	  
								  from PL_MATRIX pm
								  left join PL_FACT pf on pm.POS_CODE = pf.POS_CODE
								  where pf.NUM_YEAR = ' + cast(@NUM_YEAR as varchar(4)) + ' and pf.TYPE_GP = ' + cast(@TYPE_GP as varchar(2)) + ' and pm.ID_VER = ' + cast(@ID_VER as varchar(2)) + ' 
								  	and (pf.DEPART = ' + @DEPART_3 + ' or ' + @DEPART_3 + '=0) ' + ' 
								  group by pm.POS_NUM, pm.POS_NAME, pf.POS_CODE, pf.POS_CODE'
					insert into #fact exec (@sql_2)
				end 

		-- если по прибыли, то суммы тоже нужно, кроме количества, сформированного выше ============================================================================
		declare @orp varchar(10)
		set @orp = dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT)
		if @orp=3
			begin
				if object_id(N'tempdb..#fact3') is not null drop table #fact3
				create table #fact3 (POS_CODE varchar(10), TOTAL_FACT float)
				set @MON_DEPTH_CUR = 1
				set @sql_2 = ''
				-- за предыдущий год, если глубина (кол-во месяцев в периоде ранжирования) выходит в прошлый год
				if Month(GetDate())<@MONTH_DEPTH 
					begin
						set @MON_DEPTH_PREV = 12 + Month(GetDate()) - @MONTH_DEPTH
				
						while @MON_DEPTH_PREV<=12
							begin
							set @sql_2 = @sql_2 + '+ IsNull(pf.A' + cast(@MON_DEPTH_PREV as varchar(2)) + ', 0)'
							set @MON_DEPTH_PREV = @MON_DEPTH_PREV + 1
							end;

						set @sql_2 = 'select pf.POS_CODE, 
									  sum('  + stuff(@sql_2, 1, 1, '') +') as TOTAL_FACT 	 	  	  
									  from PL_MATRIX pm
									  left join PL_FACT pf on pm.POS_CODE = pf.POS_CODE
									  where pf.NUM_YEAR = ' + cast(@NUM_YEAR-1 as varchar(4)) + ' and pf.TYPE_GP = ' + cast(@TYPE_GP as varchar(2)) + ' and pm.ID_VER = ' + cast(@ID_VER_PREV as varchar(2)) + ' 
						   			  group by pm.POS_NUM, pm.POS_NAME, pf.POS_CODE, pf.POS_CODE'

						insert into #fact3 exec (@sql_2)
					end
				-- за текущий год
				if Month(GetDate())>1 
					begin
						set @MON_DEPTH_CUR = 1
						set @sql_2 = ''
				
						while @MON_DEPTH_CUR<Month(GetDate())
							begin
							set @sql_2 = @sql_2 + '+ IsNull(pf.A' + cast(@MON_DEPTH_CUR as varchar(2)) + ', 0)'
							set @MON_DEPTH_CUR = @MON_DEPTH_CUR + 1
							end;

						set @sql_2 = 'select pf.POS_CODE, 
									  sum('  + stuff(@sql_2, 1, 1, '') +') as TOTAL_FACT 	 	  	  
									  from PL_MATRIX pm
									  left join PL_FACT pf on pm.POS_CODE = pf.POS_CODE
									  where pf.NUM_YEAR = ' + cast(@NUM_YEAR as varchar(4)) + ' and pf.TYPE_GP = ' + cast(@TYPE_GP as varchar(2)) + ' and pm.ID_VER = ' + cast(@ID_VER as varchar(2)) + ' 
									  group by pm.POS_NUM, pm.POS_NAME, pf.POS_CODE, pf.POS_CODE'
						insert into #fact3 exec (@sql_2)
					end 

					--средние цены
					if object_id(N'tempdb..#prices') is not null drop table #prices
					select sgb.ID_GROUP, sgb.CODE_GROUP, avg(apfm.PRICE) as AVG_PRICE
					into #prices
					from SP_GOOD_BRAND sgb
					left join SP_GOOD_BRAND_LINKS sgbl on sgb.ID_GROUP = sgbl.ID_GROUP
					left join AVG_PRICES_FOR_MAG apfm on sgbl.ID_GOOD = apfm.ID_GOOD
					group by sgb.ID_GROUP, sgb.CODE_GROUP
		
					-- заготовка с расположенными по убыванию суммами
					if object_id(N'tempdb..#fact4') is not null drop table #fact4
			
					select t1.POS_CODE, 
						sum(t3.TOTAL_FACT - t1.TOTAL_FACT*pr.AVG_PRICE) as TOTAL_FACT, 
						cast(0 as float) as full_sum,
						cast(0 as float) as progressive_sum,
						'C' as rank
					into #fact4
					from #fact t1
					left join #fact3 t3 on t1.POS_CODE = t3.POS_CODE
					left join #prices pr on t1.POS_CODE = pr.CODE_GROUP
					group by t1.POS_CODE
					order by sum(t3.TOTAL_FACT - t1.TOTAL_FACT*pr.AVG_PRICE) desc

					select @FULL_SUM = sum(TOTAL_FACT) from #fact4
					update #fact4 set full_sum=@FULL_SUM where 1=1
			
					-- проставляем нарастающий итог
					update #fact4
					set 
						@Values1 = progressive_sum = CASE WHEN POS_CODE = (select top 1 POS_CODE from #fact4) THEN TOTAL_FACT
										  			 ELSE @Values1 + TOTAL_FACT + progressive_sum 
													 END

					-- определяем ранги A, B, C
					update #fact4
					set rank = CASE WHEN progressive_sum/full_sum<@R_A/100 THEN 'A' 
									WHEN progressive_sum/full_sum between @R_A/100 and @R_B/100 THEN 'B' 
									ELSE 'C' 
								end

					-- временная таблица с остатками на наст. момент
					if object_id(N'tempdb..#r3_2') is not null drop table #r3_2
					select IsNull(gb.CODE_GROUP, gb.ORDER_BY) as POS_CODE, sum(sgr.KOL_GOOD_U + sgr.KOL_GOOD_R) as REST
					into #r3_2
					from S_GOOD_REST sgr -- отсюда уходит после первой отгрузки; это таблица без учёта брони
					left join SP_GOOD_BRAND_LINKS sgbl on sgr.ID_GOOD = sgbl.ID_GOOD
					left join SP_GOOD_BRAND gb on sgbl.ID_GROUP = gb.ID_GROUP
					where sgr.ID_GOOD_STATUS=1 and (sgr.KOL_GOOD_U + sgr.KOL_GOOD_R) > 0 
					group by IsNull(gb.CODE_GROUP, gb.ORDER_BY)

					---- параметр визуального представления полей
					set @MAP = '[№]:WIDTH=50;[Артикул бренда]:WIDTH=100;' 
					-- основной набор данных
					select m.POS_NUM as '№', f.POS_CODE as 'Артикул бренда', m.POS_NAME as 'Наименование бренда',  
						cast(f.TOTAL_FACT as int) as 'Доходность, всего (руб)', cast(f.TOTAL_FACT/@MONTH_DEPTH as int) as 'Доходность, средн.мес.(руб)',    
						cast(r.REST as int) as 'Текущ.нал. без уч.брони (бут)',
						round(f.TOTAL_FACT/f.full_sum*100, 3) as 'Процент от общ.',
						f.rank as 'Ранг'
					from #fact4 f
					left join PL_MATRIX m on f.POS_CODE = m.POS_CODE
					left join #r3_2 r on f.POS_CODE = r.POS_CODE 
					where m.ID_VER = @ID_VER 
					order by TOTAL_FACT desc
					
					return
			end

			-- если не по прибыли, а по количеству или сумме =======================================================================================================

			-- заготовка с расположенными по убыванию суммами
			if object_id(N'tempdb..#fact2') is not null drop table #fact2
			select @FULL_SUM = sum(TOTAL_FACT) from #fact
			select t1.POS_CODE, 
				sum(t1.TOTAL_FACT) as TOTAL_FACT, 
				@FULL_SUM as full_sum,
				cast(0 as float) as progressive_sum,
				'C' as rank
			into #fact2
			from #fact t1
			group by t1.POS_CODE
			order by sum(t1.TOTAL_FACT) desc

			-- проставляем нарастающий итог
			update #fact2
			set 
			  @Values1 = progressive_sum = CASE WHEN POS_CODE = (select top 1 POS_CODE from #fact2) THEN TOTAL_FACT
										   ELSE @Values1 + TOTAL_FACT + progressive_sum 
										   END

			-- определяем ранги A, B, C
			update #fact2
			set rank = CASE WHEN progressive_sum/full_sum<@R_A/100 THEN 'A' 
							WHEN progressive_sum/full_sum between @R_A/100 and @R_B/100 THEN 'B' 
							ELSE 'C' 
					   END
			-- среднемесячные фактические продажи за весь прошлый год
			if object_id(N'tempdb..#fact_prev') is not null drop table #fact_prev
			create table #fact_prev (POS_CODE varchar(10), avg_prev float)
			if @TYPE_R='K'
			  begin
				insert into #fact_prev
				select POS_CODE, sum((K1+K2+K3+K4+K5+K6+K7+K8+K9+K10+K11+K12)/12) as avg_prev
				from PL_FACT 
				where NUM_YEAR = @NUM_YEAR-1 and TYPE_GP = @TYPE_GP and (DEPART = @DEPART_3 or @DEPART_3 = 0)  
				group by POS_CODE
			  end
			else if @TYPE_R='A'
			  begin
				insert into #fact_prev
				select POS_CODE, sum((A1+A2+A3+A4+A5+A6+A7+A8+A9+A10+A11+A12)/12) as avg_prev
				from PL_FACT 
				where NUM_YEAR = @NUM_YEAR-1 and TYPE_GP = @TYPE_GP and (DEPART = @DEPART_3 or @DEPART_3 = 0)  
				group by POS_CODE
			  end
			-- временная таблица с остатками на наст. момент
			if object_id(N'tempdb..#r3') is not null drop table #r3
			select IsNull(gb.CODE_GROUP, gb.ORDER_BY) as POS_CODE, sum(sgr.KOL_GOOD_U + sgr.KOL_GOOD_R) as REST
			into #r3
			from S_GOOD_REST sgr -- отсюда уходит после первой отгрузки; это таблица без учёта брони
			left join SP_GOOD_BRAND_LINKS sgbl on sgr.ID_GOOD = sgbl.ID_GOOD
			left join SP_GOOD_BRAND gb on sgbl.ID_GROUP = gb.ID_GROUP
			where sgr.ID_GOOD_STATUS=1 and (sgr.KOL_GOOD_U + sgr.KOL_GOOD_R) > 0 
			group by IsNull(gb.CODE_GROUP, gb.ORDER_BY)

			---- параметр визуального представления полей
		    set @MAP = '[№]:WIDTH=50;[Артикул бренда]:WIDTH=100;' 
			-- основной набор данных
			if @orp=1
				select m.POS_NUM as '№', f.POS_CODE as 'Артикул бренда', m.POS_NAME as 'Наименование бренда',  
				  cast(f.TOTAL_FACT as int) as 'Факт, всего', cast(f.TOTAL_FACT/@MONTH_DEPTH as int) as 'Факт, средн.мес.',    
				  cast(fp.avg_prev as int) as 'Факт пред.год средн.мес.',
				  cast(round(f.TOTAL_FACT/@MONTH_DEPTH - fp.avg_prev, 0) as int) as 'Изменение средн.мес.',
				  cast(r.REST as int) as 'Текущ.нал. без уч.брони',
				  case when (r.REST>0 and f.TOTAL_FACT>0) then round(r.REST/(f.TOTAL_FACT/@MONTH_DEPTH+0.000001), 1) else 0 end as 'Запас (мес)', 
				  round(f.TOTAL_FACT/f.full_sum*100, 3) as 'Процент от общ.',
				  f.rank as 'Ранг'
				from #fact2 f
				left join PL_MATRIX m on f.POS_CODE = m.POS_CODE
				left join #fact_prev fp on f.POS_CODE = fp.POS_CODE
				left join #r3 r on f.POS_CODE = r.POS_CODE 
				where m.ID_VER = @ID_VER 
				order by TOTAL_FACT desc
			else if @orp=2
				select m.POS_NUM as '№', f.POS_CODE as 'Артикул бренда', m.POS_NAME as 'Наименование бренда',  
				  cast(f.TOTAL_FACT as int) as 'Факт, всего', cast(f.TOTAL_FACT/@MONTH_DEPTH as int) as 'Факт, средн.мес.',    
				  cast(fp.avg_prev as int) as 'Факт пред.год средн.мес.',
				  cast(round(f.TOTAL_FACT/@MONTH_DEPTH - fp.avg_prev, 0) as int) as 'Изменение средн.мес.',
				  cast(r.REST as int) as 'Текущ.нал. без уч.брони',
				  round(f.TOTAL_FACT/f.full_sum*100, 3) as 'Процент от общ.',
				  f.rank as 'Ранг'
				from #fact2 f
				left join PL_MATRIX m on f.POS_CODE = m.POS_CODE
				left join #fact_prev fp on f.POS_CODE = fp.POS_CODE
				left join #r3 r on f.POS_CODE = r.POS_CODE 
				where m.ID_VER = @ID_VER 
				order by TOTAL_FACT desc
		  
		end
  end
  
-- ABC-анализ по доходности поставщиков ===================================================================== пример: exec PL_REPORT 3, '6::1::75::95::null'
else if @ID=4 
  begin
    if @P1 is null
		begin
			-- набор данных для заполнения пользователем параметров отчёта
			select 'Глубина периода (мес)', 6, null
			union all select 'Тип поставки', 1, 'select 1, ''импортный'' union all select 2, ''привлечённый'' '						
			union all select 'Ранг A (%)', 75, null
			union all select 'Ранг B (%)', 95, null
			union all select 'Ранг C (%)', 100, null
		end
	else
		begin
			select @MONTH_DEPTH = dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT), 
				@TYPE_GP = dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT), 
				@TYPE_R = 3, 
				@rank_A = dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT), @rank_B = dbo.GET_PARAM_FROM_LIST(@P1, 4, DEFAULT)

			select @R_A = cast(@rank_A as float), @R_B = cast(@rank_B as float), @TYPE_R = case when (@TYPE_R='1') or (@TYPE_R='3') then 'K' when @TYPE_R = '2' then 'A' end, @NUM_YEAR=Year(GetDate())

			-- проверки адекватности параметров
			if @MONTH_DEPTH<1 or @MONTH_DEPTH>12 
				begin
					raiserror ('Глубина периода должна составлать от 1 до 12 месяцев!', 16, 1)
					return 50000
				end
			-- проверки адекватности параметров
			if @rank_A>@rank_B or @rank_A>98 or @rank_B>99
				begin
					raiserror ('Процент по рангу A не может превышать процент по рангу B!', 16, 1)
					return 50000
				end
			-- проверки адекватности параметров
			if (@rank_A+@rank_B)>197 
				begin
					raiserror ('Сумма процентов по рангам A и B не может быть больше 197!', 16, 1)
					return 50000
				end 

			-- определяем какие версии матриц были в эти годы
			select @ID_VER_PREV = max(v.ID_VER)
			from PL_VER v
			left join PL_MATRIX pm on v.ID_VER = pm.ID_VER
			left join PL_PLAN pp on pm.ID_GP = pp.ID_GP 
			where pp.NUM_YEAR = @NUM_YEAR-1

			select @ID_VER = max(v.ID_VER)
			from PL_VER v
			left join PL_MATRIX pm on v.ID_VER = pm.ID_VER
			left join PL_PLAN pp on pm.ID_GP = pp.ID_GP 
			where pp.NUM_YEAR = @NUM_YEAR

			if object_id(N'tempdb..#prod') is not null drop table #prod
			set @sql_2 = ''

			create table #prod (POS_CODE varchar(10), TOTAL_FACT float)

			-- за предыдущий год, если глубина (кол-во месяцев в периоде ранжирования) выходит в прошлый год
			if Month(GetDate())<@MONTH_DEPTH 
				begin
					set @MON_DEPTH_PREV = 12 + Month(GetDate()) - @MONTH_DEPTH
				
					while @MON_DEPTH_PREV<=12
						begin
						set @sql_2 = @sql_2 + '+ IsNull(pf.' + @TYPE_R + cast(@MON_DEPTH_PREV as varchar(2)) + ', 0)'
						set @MON_DEPTH_PREV = @MON_DEPTH_PREV + 1
						end;

					set @sql_2 = 'select pf.POS_CODE, 
									sum('  + stuff(@sql_2, 1, 1, '') +') as TOTAL_FACT 	 	  	  
									from PL_MATRIX pm
									left join PL_FACT pf on pm.POS_CODE = pf.POS_CODE
									where pf.NUM_YEAR = ' + cast(@NUM_YEAR-1 as varchar(4)) + ' and pf.TYPE_GP = ' + cast(@TYPE_GP as varchar(2)) + ' and pm.ID_VER = ' + cast(@ID_VER_PREV as varchar(2)) + ' 
									group by pm.POS_NUM, pm.POS_NAME, pf.POS_CODE, pf.POS_CODE'

					insert into #prod exec (@sql_2)
				end
			-- за текущий год
			if Month(GetDate())>1 
				begin
					set @MON_DEPTH_CUR = 1
					set @sql_2 = ''
				
					while @MON_DEPTH_CUR<Month(GetDate())
						begin
						set @sql_2 = @sql_2 + '+ IsNull(pf.' + @TYPE_R + cast(@MON_DEPTH_CUR as varchar(2)) + ', 0)'
						set @MON_DEPTH_CUR = @MON_DEPTH_CUR + 1
						end;

					set @sql_2 = 'select pf.POS_CODE, 
									sum('  + stuff(@sql_2, 1, 1, '') +') as TOTAL_FACT 	 	  	  
									from PL_MATRIX pm
									left join PL_FACT pf on pm.POS_CODE = pf.POS_CODE
									where pf.NUM_YEAR = ' + cast(@NUM_YEAR as varchar(4)) + ' and pf.TYPE_GP = ' + cast(@TYPE_GP as varchar(2)) + ' and pm.ID_VER = ' + cast(@ID_VER as varchar(2)) + ' 
									group by pm.POS_NUM, pm.POS_NAME, pf.POS_CODE, pf.POS_CODE'
					insert into #prod exec (@sql_2)
				end 

			if object_id(N'tempdb..#prod3') is not null drop table #prod3
			create table #prod3 (POS_CODE varchar(10), TOTAL_FACT float)
			set @MON_DEPTH_CUR = 1
			set @sql_2 = ''
			-- за предыдущий год, если глубина (кол-во месяцев в периоде ранжирования) выходит в прошлый год
			if Month(GetDate())<@MONTH_DEPTH 
				begin
					set @MON_DEPTH_PREV = 12 + Month(GetDate()) - @MONTH_DEPTH
				
					while @MON_DEPTH_PREV<=12
						begin
						set @sql_2 = @sql_2 + '+ IsNull(pf.A' + cast(@MON_DEPTH_PREV as varchar(2)) + ', 0)'
						set @MON_DEPTH_PREV = @MON_DEPTH_PREV + 1
						end;

					set @sql_2 = 'select pf.POS_CODE, 
									sum('  + stuff(@sql_2, 1, 1, '') +') as TOTAL_FACT 	 	  	  
									from PL_MATRIX pm
									left join PL_FACT pf on pm.POS_CODE = pf.POS_CODE
									where pf.NUM_YEAR = ' + cast(@NUM_YEAR-1 as varchar(4)) + ' and pf.TYPE_GP = ' + cast(@TYPE_GP as varchar(2)) + ' and pm.ID_VER = ' + cast(@ID_VER_PREV as varchar(2)) + ' 
						   			group by pm.POS_NUM, pm.POS_NAME, pf.POS_CODE, pf.POS_CODE'

					insert into #prod3 exec (@sql_2)
					print @sql_2
				end
			-- за текущий год
			if Month(GetDate())>1 
				begin
					set @MON_DEPTH_CUR = 1
					set @sql_2 = ''
				
					while @MON_DEPTH_CUR<Month(GetDate())
						begin
						set @sql_2 = @sql_2 + '+ IsNull(pf.A' + cast(@MON_DEPTH_CUR as varchar(2)) + ', 0)'
						set @MON_DEPTH_CUR = @MON_DEPTH_CUR + 1
						end;

					set @sql_2 = 'select pf.POS_CODE, 
									sum('  + stuff(@sql_2, 1, 1, '') +') as TOTAL_FACT 	 	  	  
									from PL_MATRIX pm
									left join PL_FACT pf on pm.POS_CODE = pf.POS_CODE
									where pf.NUM_YEAR = ' + cast(@NUM_YEAR as varchar(4)) + ' and pf.TYPE_GP = ' + cast(@TYPE_GP as varchar(2)) + ' and pm.ID_VER = ' + cast(@ID_VER as varchar(2)) + ' 
									group by pm.POS_NUM, pm.POS_NAME, pf.POS_CODE, pf.POS_CODE'
					insert into #prod3 exec (@sql_2)
					print '2'
				end 

			--средние цены
			if object_id(N'tempdb..#prices4') is not null drop table #prices4
			select sgb.ID_GROUP, sgb.CODE_GROUP, avg(apfm.PRICE) as AVG_PRICE
			into #prices4
			from SP_GOOD_BRAND sgb
			left join SP_GOOD_BRAND_LINKS sgbl on sgb.ID_GROUP = sgbl.ID_GROUP
			left join AVG_PRICES_FOR_MAG apfm on sgbl.ID_GOOD = apfm.ID_GOOD
			group by sgb.ID_GROUP, sgb.CODE_GROUP
		
			-- заготовка с расположенными по убыванию суммами
			if object_id(N'tempdb..#prod4') is not null drop table #prod4
			
			select IsNull(replace(sf.NAME_FIRM_FACT, '"', ''), 'Ассортимент на вывод') as P_NAME, 
				sum(t3.TOTAL_FACT - t1.TOTAL_FACT*pr.AVG_PRICE) as TOTAL_FACT,
				avg((t3.TOTAL_FACT - t1.TOTAL_FACT*pr.AVG_PRICE)/IsNull(t1.TOTAL_FACT+1, 1)) as TOTAL_AVG,
				avg(pr.AVG_PRICE) as PRICE_AVG,
				sum(t1.TOTAL_FACT) as PROD_KOL,  
				cast(0 as float) as full_sum,
				cast(0 as float) as progressive_sum,
				'C' as rank
			into #prod4
			from #prod t1
			left join #prod3 t3 on t1.POS_CODE = t3.POS_CODE
			left join #prices4 pr on t1.POS_CODE = pr.CODE_GROUP
			left join SP_GOOD_BRAND sgb with (NOLOCK) on t1.POS_CODE = sgb.CODE_GROUP 
			left join SP_FIRM sf with (NOLOCK) on sgb.ID_POST = sf.ID_FIRM
			group by IsNull(replace(sf.NAME_FIRM_FACT, '"', ''), 'Ассортимент на вывод')
			order by sum(t3.TOTAL_FACT - t1.TOTAL_FACT*pr.AVG_PRICE) desc

			select @FULL_SUM = sum(TOTAL_FACT) from #prod4
			update #prod4 set full_sum=@FULL_SUM where 1=1

			
			-- проставляем нарастающий итог
			update #prod4
			set 
				@Values1 = progressive_sum = CASE WHEN P_NAME = (select top 1 P_NAME from #prod4) THEN TOTAL_FACT
										  		ELSE @Values1 + TOTAL_FACT + progressive_sum 
												END

			-- определяем ранги A, B, C
			update #prod4
			set rank = CASE WHEN progressive_sum/full_sum<@R_A/100 THEN 'A' 
							WHEN progressive_sum/full_sum between @R_A/100 and @R_B/100 THEN 'B' 
							ELSE 'C' 
						end

			
			---- параметр визуального представления полей
			set @MAP = '[Наименование поставщика]:WIDTH=120;' 
			-- основной набор данных
			select 
				f.P_NAME as 'Наименование поставщика',
				cast(f.TOTAL_FACT as int) as 'Доходность, всего (руб)', 
				cast(f.TOTAL_FACT/@MONTH_DEPTH as int) as 'Доходность, средн.мес.(руб)',
				round(cast(f.PRICE_AVG as float), 2) as 'Средняя закупка (руб)',
				round(cast(f.TOTAL_AVG as float), 2) as 'Средняя наценка (руб)',  
				round(cast(t.PROD_KOL as int), 2) as 'Факт (бут)',   
				round(f.TOTAL_FACT/f.full_sum*100, 3) as 'Процент от общ.',
				f.rank as 'Ранг'
			from #prod4 f
			left join ( select IsNull(replace(sf.NAME_FIRM_FACT, '"', ''), 'Ассортимент на вывод') as P_NAME, sum(prod.TOTAL_FACT) as PROD_KOL 
						from #prod prod
						left join SP_GOOD_BRAND sgb on prod.POS_CODE = sgb.CODE_GROUP
						left join SP_FIRM sf on sgb.ID_POST = sf.ID_FIRM
						group by IsNull(replace(sf.NAME_FIRM_FACT, '"', ''), 'Ассортимент на вывод')) t on f.P_NAME = t.P_NAME
			order by TOTAL_FACT desc
			
			-- дурацкая привычка чистить, а вдруг само не очистится
			drop table #prod
			drop table #prod4
			drop table #prices4  

		end
  end

-- Изменения планов по датам ===================================================================== пример: exec PL_REPORT 5, '30::1'
else if @ID=5 
  begin
    if @P1 is null
		begin
			-- набор данных для заполнения пользователем параметров отчёта
			select 'Глубина периода (дней)', 30, null
			union all select 'Тип поставки', 1, 'select 1, ''импортный'' union all select 2, ''привлечённый'' '	
			union all select 'Артикул бренда (не обязательно)', null, null
		end
	else
		begin
			declare @day_5 int, @type_gp_5 int, @pos_code_5 varchar(10)
			select @day_5 = cast(dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) as int) - 1, 
				   @type_gp_5 = cast(dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT) as int), 
				   @pos_code_5 = dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT)

			if len(@pos_code_5)<1 set @pos_code_5 = null
			if len(@NUM_YEAR)<1 set @NUM_YEAR = null   

			-- последние моменты обновлений
			select log.ID_ROW, 
			  coalesce(substring(p.CUSTOMERS, 1, 10), convert(varchar, p.AGENT), convert(varchar, p.DEPART)) as DIRECT,
			  max(log.UPDATE_MOMENT) as MAX_UPDATE,
			  log.NUM_MONTH, p.NUM_YEAR
			into #max_update
			from PL_LOG log 
			left join PL_PLAN p on log.ID_ROW = p.ID_ROW
			where log.UPDATE_MOMENT > GetDate() - @day_5 and log.NUM_MONTH<>13 
			group by log.ID_ROW, coalesce(substring(p.CUSTOMERS, 1, 10), convert(varchar, p.AGENT), convert(varchar, p.DEPART)), log.NUM_MONTH, p.NUM_YEAR

			-- сколько было до показываемого периода 
			select log.ID_ROW, 
			  coalesce(substring(p.CUSTOMERS, 1, 10), convert(varchar, p.AGENT), convert(varchar, p.DEPART)) as DIRECT,
			  max(log.UPDATE_MOMENT) as MAX_UPDATE,
			  log.NUM_MONTH, 
			  p.NUM_YEAR
			into #prev_update
			from PL_LOG log 
			left join PL_PLAN p on log.ID_ROW = p.ID_ROW
			where log.UPDATE_MOMENT <= GetDate() - @day_5 and log.NUM_MONTH<>13 
			group by log.ID_ROW, coalesce(substring(p.CUSTOMERS, 1, 10), convert(varchar, p.AGENT), convert(varchar, p.DEPART)), log.NUM_MONTH, p.NUM_YEAR 

			select distinct l.ID_ROW, l.VAL, l.UPDATE_MOMENT, pu.NUM_MONTH, pu.NUM_YEAR
			into #past_price
			from PL_LOG l 
			join #prev_update pu on l.ID_ROW = pu.ID_ROW and l.UPDATE_MOMENT = pu.MAX_UPDATE

			-- расшифровки справочника направлений
			declare @x_5 xml, @s_5 varchar(max)
			declare @spr_5 table (ID varchar(max), NAIM varchar(100)) 
			select @s_5 = isnull(@s_5 + ',' ,'')  + cast(pl.CUSTOMERSXML as varchar(1000)) from PL_LISTS pl where Not pl.CUSTOMERSXML is null
			set @x_5 = convert(xml, @s_5)

			insert into @spr_5 
			select ID   = x.t.value('@ID', 'varchar(1000)'),
				   NAIM = x.t.value('@NAIM', 'varchar(100)')
			from @x_5.nodes('Row') as x(t)

			insert into @spr_5 
			select distinct 
				   ID   = convert(varchar, IsNull(pa.AGENT, nsd.ID_DEPART)), 
				   NAIM = IsNull(sp.LAST_NAME, nsd.NAME_DEPART)
			from PL_AFFIX pa 
			left join SP_PERS sp on pa.AGENT=sp.ID_PERS
			left join N_SP_DEPART nsd on pa.DEPART = nsd.ID_DEPART

			-- параметр визуального представления полей
			set @MAP = '[Год]:WIDTH=80;[Месяц]:WIDTH=80;[Артикул бренда]:WIDTH=120;[Наименование бренда]:WIDTH=180;' 
			-- основной набор данных
			select m.POS_CODE as 'Артикул бренда', m.POS_NAME as 'Наименование бренда', p.NUM_YEAR as [Год], l.NUM_MONTH as [Месяц], l.USER_LOGIN as [Пользователь], 
				--coalesce(substring(p.CUSTOMERS, 1, 10), convert(varchar, p.AGENT), convert(varchar, p.DEPART)) as [Код направления],
				s.NAIM as [Направление],
				l.VAL, 
				prev.VAL as [Было], v.TYPE_GP, 
				cast(datepart(year, l.UPDATE_MOMENT) as varchar(4)) + '_'  + RIGHT('0'+convert(varchar(2), datepart(MONTH, l.UPDATE_MOMENT)), 2) + '_' + RIGHT('0'+convert(varchar(2), datepart(DAY, l.UPDATE_MOMENT)), 2) as UPDATE_DAY
			into #tmp
			from PL_LOG l 
			left join PL_PLAN p on l.ID_ROW = p.ID_ROW
			join #max_update mu on l.UPDATE_MOMENT = mu.MAX_UPDATE and l.NUM_MONTH = mu.NUM_MONTH and p.NUM_YEAR = mu.NUM_YEAR
			left join PL_MATRIX m on p.ID_GP = m.ID_GP
			left join PL_VER v on m.ID_VER = v.ID_VER
			left join #past_price prev on l.ID_ROW = prev.ID_ROW and l.NUM_MONTH = prev.NUM_MONTH and p.NUM_YEAR = prev.NUM_YEAR
			left join @spr_5 s on coalesce(p.CUSTOMERS, convert(varchar, p.AGENT), convert(varchar, p.DEPART)) = s.ID
			where l.UPDATE_MOMENT > DateAdd(day, (-1)*@day_5, GetDate()) 
				and v.TYPE_GP = @type_gp_5 and l.NUM_MONTH<>13 
				and (m.POS_CODE = @pos_code_5 or @pos_code_5 is null)

			exec GET_PIVOT @tbl_name='#tmp', @row_name = '[Год], [Месяц], [Артикул бренда], [Наименование бренда], [Пользователь], [Направление], [Было]', @col_name = 'UPDATE_DAY', @col_data = 'VAL', @operation = 'max', @order_name = '[Год], [Месяц], [Артикул бренда], [Наименование бренда], UPDATE_MOMENT desc'

			drop table #tmp
			drop table #max_update
			drop table #prev_update
			drop table #past_price
		end
  end