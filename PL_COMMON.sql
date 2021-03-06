USE [CBTrade]
GO
/****** Object:  StoredProcedure [dbo].[PL_COMMON]    Script Date: 22.12.2020 14:53:38 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--------------------------------------------------------------------------------------------------------------------
-- Author:      A.Tsvetkov
-- Create date: 21.02.2019
-- Процедура получения разных наборов данных по коду
-- Test:        exec PL_COMMON 101, '10::723,817'
--------------------------------------------------------------------------------------------------------------------

ALTER procedure [dbo].[PL_COMMON]
	@ID int,                             -- код набора данных
	@P1 varchar(1000) = null,            -- параметр 1
	@MAP nvarchar(1000) = null output    -- карта представления полей
as
	set nocount on

-- #################################################################################################################
-- исчезли бренды ##################################################################################################
if @ID=1	
	begin
		-- параметр визуального представления полей
		set @MAP = '[№]:WIDTH=50;[Наименование бренда]:WIDTH=400;' 
		-- набор данных
		select m.ID_GROUP, m.POS_NUM as '№', m.POS_NAME as 'Наименование бренда', m.ID_GP
		from PL_MATRIX m 
		left join (select ID_GROUP from SP_GOOD_BRAND where IS_IMPORT = cast(dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT) as int) ) sgb on m.ID_GROUP = sgb.ID_GROUP
		where sgb.ID_GROUP is null and m.ID_VER = cast(dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) as int)
		order by m.POS_NUM
	end
-- #################################################################################################################
-- появились новые бренды ##########################################################################################
else if @ID=2	
	begin
		-- параметр визуального представления полей
		set @MAP = '[№]:WIDTH=50;[Наименование бренда]:WIDTH=400;' 
		-- набор данных
		select sgb.ID_GROUP, sgb.ORDER_BY as '№', sgb.NAME_GROUP as 'Наименование бренда' 
		from SP_GOOD_BRAND sgb 
		left join (select ID_GROUP from PL_MATRIX where ID_VER = cast(dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) as int)) m on sgb.ID_GROUP = m.ID_GROUP
		where sgb.IS_IMPORT = cast(dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT) as int) and m.ID_GROUP is null 
		order by sgb.ORDER_BY
	end 
-- #################################################################################################################
-- изменились названия #############################################################################################
else if @ID=3	
	begin
		-- параметр визуального представления полей
		set @MAP = '[№, было]:WIDTH=100;[Наименование бренда, было]:WIDTH=400;[№, стало]:WIDTH=100;[Наименование бренда, стало]:WIDTH=400;' 
		-- набор данных				
		select m.ID_GP, m.POS_NUM as '№, было', m.POS_NAME as 'Наименование бренда, было', sgb.ORDER_BY as '№, стало', sgb.NAME_GROUP as 'Наименование бренда, стало' 
		from PL_MATRIX m 
		left join (select ID_GROUP, ORDER_BY, NAME_GROUP from CBTrade.dbo.SP_GOOD_BRAND where IS_IMPORT = cast(dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT) as int) ) sgb on m.ID_GROUP = sgb.ID_GROUP
		where sgb.NAME_GROUP <> m.POS_NAME and m.ID_VER = cast(dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) as int)
		order by m.POS_NUM
	end
-- #################################################################################################################
-- департаменты и их менеджеры #####################################################################################
else if @ID=4
	begin
		-- параметр визуального представления полей
		set @MAP = '[Выбрано]:TYPE=CHECKBOX,WIDTH=30;[Департамент]:WIDTH=230;[Менеджер]:WIDTH=130' 
		-- набор данных		   
	    declare @user_4 varchar(20)
		set @user_4=dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT)

		select N_SP_DEPART.ID_DEPART, 
			case when Not a.DEPART is null then 1 else 0 end as 'Выбрано', 
			PL_DEPART.NAME_AD_DEPART as 'Департамент', N_SP_DEPART.NAME_DEPART, SP_PERS.LAST_NAME, SP_PERS.ID_PERS 
		from PL_DEPART 
		left join N_SP_DEPART on PL_DEPART.ID_DEPART=N_SP_DEPART.ID_DEPART
		left join SP_PERS on N_SP_DEPART.ID_MANAGER = SP_PERS.ID_PERS 
		left join ( select distinct DEPART 
					from PL_AFFIX pa 
					where charindex(@user_4, pa.USERS_FOR_EDIT)>0) a on N_SP_DEPART.ID_DEPART = a.DEPART
		order by PL_DEPART.NAME_AD_DEPART
		/*select N_SP_DEPART.ID_DEPART, 0 as 'Выбрано', PL_DEPART.NAME_AD_DEPART as 'Департамент', N_SP_DEPART.NAME_DEPART, SP_PERS.LAST_NAME, SP_PERS.ID_PERS 
		from PL_DEPART 
		left join N_SP_DEPART on PL_DEPART.ID_DEPART=N_SP_DEPART.ID_DEPART
		left join SP_PERS on N_SP_DEPART.ID_MANAGER = SP_PERS.ID_PERS 
		order by PL_DEPART.NAME_AD_DEPART */
		
		/*select N_SP_DEPART.ID_DEPART, 0 as 'Выбрано', N_SP_DEPART.NAME_DEPART as 'Департамент', SP_PERS.LAST_NAME as [Менеджер], SP_PERS.ID_PERS 
	    from N_SP_DEPART
	    left join SP_PERS on N_SP_DEPART.ID_MANAGER = SP_PERS.ID_PERS 
		where SP_PERS.ID_PERS in (  select spp1.ID_PERS
									from SP_REL_PERS_ACTIVE srp  
									join SP_PERS spp1 on spp1.ID_PERS = srp.ID_PERS_MAN  
									join SP_PERS spp on spp.ID_PERS = srp.ID_PERS_AGENT  
									where spp.PROF = 'агн'
									group by spp1.ID_PERS )*/
	    --order by N_SP_DEPART.NAME_DEPART  -- сортировка нарушает порядок: "как в ЛиС"
	end
-- #################################################################################################################
-- список агентов в департаменте или список покупателей (должно быть только одно) ##################################
else if @ID=5
	begin
		-- параметр визуального представления полей
		set @MAP = '[Выбрано]:TYPE=CHECKBOX,WIDTH=30;[Агент]:WIDTH=180;' 
		-- набор данных		   
	    declare @id_agents_list nvarchar(100) 
		select @id_agents_list = AGENTS 
		from PL_LISTS pl
		where pl.ID_DEPART = @P1
		-- временная таблица с кодами агентов
		select v as ID_PERS
		into #pers
		from (select cast('<r><c>'+replace(@id_agents_list,',','</c><c>')+'</c></r>' as xml) s ) t
		cross apply (select x.z.value('.', 'char(18)') v from s.nodes('/r/c') x(z)) tt
        -- xml - описание покупателей: название и список ID
		declare @x xml
        select @x=l.CUSTOMERSXML from PL_LISTS l where ID_DEPART = cast(@P1 as int)
		-- таблица со списком агентов
		select p.ID_PERS, 0 as 'Выбрано', sp.LAST_NAME +  ' ' + sp.FIRST_NAME as 'Наименование', ' ' as ID, 'AGENTS' as SOURCE
		from #pers p
		join SP_PERS sp on p.ID_PERS = sp.ID_PERS
		union
        -- список покупателей
		select 0, 0, Tbl.Col.value('@NAIM', 'varchar(100)'), Tbl.Col.value('@ID', 'varchar(1000)'), 'CUSTOMERS' as SOURCE
        from @x.nodes('//Row') Tbl(Col)
		drop table #pers
	end
-- #################################################################################################################
-- список всех агентов или покупателей (здесь покупатель - это общее название группы) ##############################
else if @ID=6
	begin
		if @P1='AGENTS'
		  begin
			-- параметр визуального представления полей
			set @MAP = '[Код]:WIDTH=50;[Агент]:WIDTH=180;' 
			-- список агентов
			select sp.ID_PERS as 'Код', sp.LAST_NAME + ' ' + sp.FIRST_NAME + ' ' + sp.MIDDLE_NAME as 'Наименование' 
			from SP_PERS sp
			join SP_REL_PERS_ACTIVE a on sp.ID_PERS = a.ID_PERS_AGENT
			where PROF = 'агн' and not sp.LAST_NAME + sp.FIRST_NAME + sp.MIDDLE_NAME is null
			order by LAST_NAME
		  end
		if @P1='CUSTOMERS'
		  begin		
			-- параметр визуального представления полей
			set @MAP = '[Наименование]:WIDTH=180;[ИНН]:WIDTH=100;' 
			-- список покупателей
			select f.ID_FIRM, f.NAME_FIRM+'('+isnull(rtrim(ltrim(f.NAME_FIRM_FACT)), dog.NOM_DOGOVOR)+')' as 'Наименование', f.INN as 'ИНН'--, f.NOM_LICEN as 'Номер лицензии', f.DAT_LICEN as 'Дата лицензии', f.CITY as 'Город', f.F_ADDRESS as 'Адрес' 			
			from SP_FIRM f
			join R_DOGOVOR dog on dog.ID_POST = f.ID_FIRM 
			where f.TYPE_FIRM=5 and PR_CUSTOMER=1 
			order by f.NAME_FIRM
		  end
    end
-- #################################################################################################################
-- список покупателей по выбранной группе (параметр - это список ID) ###############################################
else if @ID=7
	begin
		-- параметр визуального представления полей
		set @MAP = '[Наименование]:WIDTH=180;' 
		declare @firms table (ID_FIRM int)
		insert into @firms
		select v as ID_FIRM
		from (select cast('<r><c>'+replace(@P1,',','</c><c>')+'</c></r>' as xml) s ) t
		cross apply (select x.z.value('.', 'char(18)') v from s.nodes('/r/c') x(z)) tt
		-- список выбранных покупателей
		select sf.ID_FIRM, sf.NAME_FIRM as 'Наименование'
		from SP_FIRM sf
		join @firms f on sf.ID_FIRM=f.ID_FIRM
	end
-- #################################################################################################################
-- доступ пользователей к изменению конкретного среза + даты обновления факта ######################################
else if @ID=8
	begin
		-- параметр визуального представления полей
		set @MAP = '[По типу поставки]:WIDTH=100;[Департамент]:WIDTH=200;[Разреш.изм.план]:TYPE=CHECKBOX,WIDTH=32;[Разреш.инд.]:WIDTH=65;[Агент]:WIDTH=80;[Покупатели]:WIDTH=80;' 
		-- доступы пользователей и пр.
		declare @lists table (ID_DEPART int, AGENTS nvarchar(200), CUSTOMERS varchar(1000), CUSTNAME nvarchar(30))
		declare @depart int, @xc xml
		declare fld_cur5 cursor for select ID_DEPART, CUSTOMERSXML from PL_LISTS where AGENTS is null 
		open fld_cur5	  
		fetch next from fld_cur5 into @depart, @xc
		while @@FETCH_STATUS = 0   
   			begin  
				select @xc=l.CUSTOMERSXML from PL_LISTS l where ID_DEPART = @depart  
				-- заполнение по одному департаменту
				insert into @lists (ID_DEPART, AGENTS, CUSTOMERS, CUSTNAME)
				select p.ID_DEPART, p.AGENTS, r.cids as CUSTOMERS, cname as CUSTNAME 
				from PL_LISTS p
				left join (select Tbl.Col.value('@ID', 'varchar(1000)') as cids, Tbl.Col.value('@NAIM', 'varchar(30)') as cname
							from @xc.nodes('//Row') Tbl(Col) ) r on 1=1
				where p.ID_DEPART = @depart		
				fetch next from fld_cur5 into @depart, @xc
  			end  
		close fld_cur5 
		deallocate fld_cur5
		-- разрешения на год: текущий/следующий
		declare @edit_one_year int, @one_year varchar(4)
		select @edit_one_year = CBTrade.dbo.GET_GLOBAL_VAR('EDIT_ONE_YEAR_ONLY')
		if @edit_one_year=2
		  set @one_year = cast(Year(GetDate()) as varchar)
		else if @edit_one_year=3
		  set @one_year = cast(Year(GetDate())+1 as varchar)
		else
		  set @one_year = ''     
		-- раскрытие всех агентов, объединение с покупателями
		select case when a.TYPE_GP=1 then 'импортный' else 'привлечённый' end as 'По типу поставки',
			a.DEPART as ID_DEPART, d.NAME_AD_DEPART as 'Департамент', a.EDITABLE as 'Разреш.изм.план', 
			case when (a.EDITABLE=1 and a.TYPE_GP=1) then @one_year end + case when Not ind_lock.DEPART is Null then 'по нек.' else '' end as 'Разреш.инд.', 
			a.AGENT as ID_AGENT, sp.LAST_NAME + ' ' + sp.FIRST_NAME as 'Агент',  t.CUSTNAME as 'Наименование фирмы покупателя', 
			a.CUSTOMERS as 'Покупатели', a.USERS_FOR_EDIT as 'Доступ на редактирование', a.LAST_FACT_UPDATE as 'Актуальность данных по факт.',
			a.TYPE_GP 
		from PL_AFFIX a
		left join
			(select t.ID_DEPART, v as AGENTS, cast(null as varchar(1000)) as CUSTOMERS, cast(null as varchar(100)) as CUSTNAME
			from (select c.ID_DEPART, cast('<r><c>'+replace(c.AGENTS,',','</c><c>')+'</c></r>' as xml) s from (select * from PL_LISTS where CUSTOMERSXML is null) as c ) t
			cross apply (select x.z.value('.', 'int') as v from s.nodes('/r/c') x(z)) tt 
			union all
			select * from @lists) t on a.DEPART =  t.ID_DEPART and IsNull(a.AGENT,'0') = IsNull(t.AGENTS,'0') and IsNull(a.CUSTOMERS,'0') = IsNull(t.CUSTOMERS,'0')  
		left join N_SP_DEPART nsd on IsNull(a.DEPART, t.ID_DEPART) = nsd.ID_DEPART
		left join SP_PERS sp on a.AGENT = sp.ID_PERS
		left join PL_DEPART d on a.DEPART = d.ID_DEPART
		left join 
			(select p.DEPART 
			from PL_LOCKED_BRAND l 
			left join PL_PLAN p on l.ID_ROW = p.ID_ROW
			where l.LOCK = 0
			group by p.DEPART) ind_lock on a.DEPART = ind_lock.DEPART
		where not a.DEPART is null
		order by a.TYPE_GP, d.NAME_AD_DEPART, a.AGENT, t.CUSTNAME
	end
-- #################################################################################################################
-- доступ пользователей к форматированию строк в матрице ###########################################################
else if @ID=9
	begin
		-- параметр визуального представления полей
		set @MAP = '[Доступ на форматирование]:WIDTH=180;' 
		-- пользователи
		select v as [Доступ на форматирование]
		from (select cast('<r><c>'+replace(CBTrade.dbo.GET_GLOBAL_VAR('ACCESS_FORMAT'),';','</c><c>')+'</c></r>' as xml) s ) t
		cross apply (select x.z.value('.', 'char(18)') v from s.nodes('/r/c') x(z)) tt
	end
-- #################################################################################################################
-- журнал изменений по guid позиции в плане ########################################################################
else if @ID=10
	begin
		-- параметр визуального представления полей
		set @MAP = '[Пользователь]:WIDTH=150;[Изменён план на месяц]:WIDTH=150;[Год]:WIDTH=80;[Новое значение]:WIDTH=150;[Когда изменено]:WIDTH=150;' 
		-- преобразование guid в нужный формат
		declare @guid_10 varchar(50)
		set @guid_10 = replace(replace(dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT),'0x',''),'-','')
		set @guid_10 = stuff(stuff(stuff(stuff(@guid_10,21,0,'-'),17,0,'-'),13,0,'-'),9,0,'-')
		-- журнал изменений
		select pl.USER_LOGIN as [Пользователь], 
		  case when pl.NUM_MONTH<=12 then cast(pl.NUM_MONTH as varchar(18)) else 'цена' end as [Изменён план на месяц/цена], 
		  p.NUM_YEAR as [Год], pl.ID_ROW, pl.VAL as [Новое значение], 
		  pl.UPDATE_MOMENT as [Когда изменено]
		from PL_LOG pl 
		left join PL_PLAN p on pl.ID_ROW = p.ID_ROW
		where pl.ID_ROW = @guid_10 
		order by pl.NUM_MONTH,  pl.UPDATE_MOMENT desc
	end
-- #################################################################################################################
-- список торговых сетей ###########################################################################################
else if @ID=11
	begin
		-- параметр визуального представления полей
		set @MAP = '[Код сети]:WIDTH=60;[Название сети]:WIDTH=180;[Условное обозначение]:WIDTH=180;[Выбрано]:TYPE=CHECKBOX,WIDTH=100;' 
		declare @abbr table (l nvarchar(3))
		-- выбранные сети
		insert into @abbr
		select v as [Сети]
		from (select cast('<r><c>'+replace(@P1,', ','</c><c>')+'</c></r>' as xml) s ) t
		cross apply (select x.z.value('.', 'char(18)') v from s.nodes('/r/c') x(z)) tt
		-- список сетей с выбранными
		select pr.ID_RETAIL 'Код сети', pr.RETAIL_NAME as 'Название сети', pr.ABBREV as 'Условное обозначение', case when a.l is null then 0 else 1 end as [Выбрано] 
		from PL_RETAILNET pr
		left join @abbr a on pr.ABBREV = a.l
		order by pr.ID_RETAIL
	end
-- #################################################################################################################
-- подробная детализация по департаменту, типу поставки за месяц, основано на процедуре ERU_BRAND_FOR_PLAN #########
else if (@ID=12) or (@ID=14)
	begin
		-- параметр визуального представления полей
		set @MAP = '[Дата]:WIDTH=60;[Код товара]:WIDTH=80;[Наименование товара]:WIDTH=200;[Менеджер]:WIDTH=90;[Агент]:WIDTH=90;[Покупатель]:WIDTH=90;[Факт (бут)]:WIDTH=80;[Факт (руб)]:WIDTH=80;' 
		declare @date1 datetime, @date2 datetime, @imp_brand int, @id_manager int, @name_depart varchar(50), @agent nvarchar(50), @art_brend varchar(7), @depart_12 varchar(200)
		-- превращение параметра в департамент, тип поставки, дата нач., дата кон. 
		set @name_depart = dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT)
		set @imp_brand = dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT)
		set @date1 = convert(datetime, dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT), 104)
		set @date2 = convert(datetime, dbo.GET_PARAM_FROM_LIST(@P1, 4, DEFAULT), 104) -- convert(datetime, substring(@P1, 1, @pos7-1), 104)
		set @agent = dbo.GET_PARAM_FROM_LIST(@P1, 5, DEFAULT)
		set @art_brend = dbo.GET_PARAM_FROM_LIST(@P1, 6, DEFAULT)
		set @depart_12 = dbo.GET_PARAM_FROM_LIST(@P1, 7, DEFAULT)
		-- выбранный список департаментов
		declare @sel_dep table (NAME_DEPART varchar(100)) 
		if @depart_12<>'ООО Центробалт'
			insert into @sel_dep
			select v 
			from (select cast('<r><c>'+replace(@depart_12,',','</c><c>')+'</c></r>' as xml) s ) t
            cross apply (select x.z.value('.', 'varchar(200)') v from s.nodes('/r/c') x(z)) tt
		else
		   insert into @sel_dep
		   select NAME_AD_DEPART from PL_DEPART 		
		-- менеджер департамента
		if (IsNumeric(@name_depart)=1) and (IsNumeric(@agent)=1)
			select top 1 @id_manager=z.ID_MANAGER 
			from R_HD_ZAK z
			left join SP_PERS p on z.ID_AGENT = p.ID_PERS
			where (p.LAST_NAME + ' ' + p.FIRST_NAME = @agent) or p.ID_PERS = cast(@agent as int) 
		else if (@name_depart<>'ООО Центробалт') and (@agent is null)
			select top 1 @id_manager=ID_MANAGER from N_SP_DEPART where NAME_DEPART=@name_depart
		else if (@name_depart<>'ООО Центробалт') and (not @agent is null)
			select top 1 @id_manager=z.ID_MANAGER 
			from R_HD_ZAK z
			left join SP_PERS p on z.ID_AGENT = p.ID_PERS
			where (p.LAST_NAME + ' ' + p.FIRST_NAME = @agent) or (p.ID_PERS = case when IsNumeric(@agent)=1 then cast(@agent as int) else -1 end)
		else
			set @id_manager=null 
		-- если таблицы есть, то их нужно почистить
		if object_id(N'tempdb..#good') is not null drop table #good
		-- товары по типу поставки
		create table #good (ID_GROUP int,       
							NAME_GROUP varchar(200),       
							ORDER_BY int,       
							ID_GOOD int) 
		if @art_brend='null' set @art_brend = null					     
		-- набор данных
		if @ID=12
			begin
				insert into #good      
				select b.ID_GROUP,      
						NAME_GROUP,      
						ORDER_BY,      
						l.ID_GOOD      
				from SP_GOOD_BRAND b with(nolock)  
				join SP_GOOD_BRAND_LINKS l with(nolock) on b.ID_GROUP = l.ID_GROUP and b.ID_GROUP <> 344 -- коробки исключаем т.к.они никому не интересны  
				--where b.IS_IMPORT = @imp_brand and (b.CODE_GROUP = @art_brend or @art_brend is null)
				where b.IS_IMPORT = 2 - @imp_brand and ((case when len(b.CODE_GROUP)<7 then cast(b.ORDER_BY as varchar(7)) else b.CODE_GROUP end) = @art_brend or @art_brend is null)
				-- непосредственно, набор
				select DAT_NAKL as 'Дата',           
					rgn.ID_GOOD as 'Код товара', 
					sg.GOOD_NAME_SPB as 'Наименование товара',  
					p.LAST_NAME as 'Менеджер', 
					p2.LAST_NAME as 'Агент', 
					c.NAME_FIRM as 'Покупатель',
					sum((isnull(spo.VID_OPER*(rgn.KOL_GOOD_U_C+rgn.KOL_GOOD_R_C),0))) as 'Факт (бут)',          
					sum(isnull(case rhn.ID_VAL when 2 then      
								spo.VID_OPER*rgn.STO_GOOD_FULL_C      
							else       
								spo.VID_OPER*rhn.COURSE*rgn.STO_GOOD_FULL_C      
							end ,0)) as 'Факт (руб)',
					p.ID_PERS,
					IsNull(pd.NAME_AD_DEPART, fd.NAME_AD_DEPART) as 'Департамент'		    
				from R_HD_NAKL_ALL rhn with(nolock)      
					join R_GOOD_NAKL_ALL rgn with(nolock) on rgn.ID_HD_NAKL = rhn.ID_HD_NAKL and (KOL_GOOD_U_C+KOL_GOOD_R_C) <> 0      
					join #good good on rgn.ID_GOOD = good.ID_GOOD      
					join SP_OPER spo with(nolock) on spo.ID_OPER=rhn.ID_OPER      
					join SP_GOOD sg with(nolock) on sg.GOOD_COD = rgn.ID_GOOD      
					join R_HD_ZAK_ALL zak with(nolock) on rhn.ID_HD_ZAK = zak.ID_HD_ZAK 
					left join SP_PERS p with(nolock) on zak.ID_MANAGER = p.ID_PERS 
					left join SP_FIRM c with(nolock) on rhn.ID_POST = c.ID_FIRM 
					left join SP_PERS p2 with(nolock) on zak.ID_AGENT = p2.ID_PERS
					left join N_SP_DEPART nsd on p.ID_PERS = nsd.ID_MANAGER
					left join PL_DEPART pd on nsd.ID_DEPART = pd.ID_DEPART 
					left join ( select ID_DEPART, NAME_AD_DEPART, cast(v as int) as ID_DEPART2
								from (select ID_DEPART, NAME_AD_DEPART, cast('<r><c>'+replace(DEPART_UNION,',','</c><c>')+'</c></r>' as xml) s from PL_DEPART) t
	        					cross apply (select x.z.value('.', 'int') v from s.nodes('/r/c') x(z)) tt ) fd on nsd.ID_DEPART = fd.ID_DEPART2             
				where (rhn.DAT_NAKL >= @date1 and rhn.DAT_NAKL <= @date2)      
						--and zak.ID_AGENT = case when @agent = 0 then zak.ID_AGENT else @agent end       
						and ((spo.IS_MAIN in (0,1)))  
						and rhn.NOM_NAKL not like '%*%'
						and (zak.ID_MANAGER = @id_manager or @id_manager is NULL)
						and ( IsNull(pd.NAME_AD_DEPART, fd.NAME_AD_DEPART) in (select NAME_DEPART from @sel_dep) or @depart_12 is null ) 
				group by rgn.ID_GOOD, sg.GOOD_NAME_SPB, DAT_NAKL, p.LAST_NAME, p.FIRST_NAME, p.ID_PERS, p2.LAST_NAME, c.NAME_FIRM, pd.NAME_AD_DEPART, fd.NAME_AD_DEPART
				--order by DAT_NAKL, sg.GOOD_NAME_SPB		
				union all            
				select DAT_NAKL,
					get_sto.ID_GOOD,      
					sg.GOOD_NAME_SPB, 
					sp.LAST_NAME as 'Менеджер',
					'',
					'',    
					KOL=SUM(isnull(SUM_KOL,0)),          
					SUMM =SUM(isnull(SUM_SALE,0)),
					sp.ID_PERS,
					dep.NAME_DEPART as 'Департамент'   		    
				from  GET_SCTEST_STO (@date1, @date2, 0, 0, 0, 0, 1) get_sto        
					join #good good on get_sto.ID_GOOD = good.ID_GOOD      
					join SP_GOOD sg with(nolock) on sg.GOOD_COD = get_sto.ID_GOOD      
					--join #t_manager m on m.ID_MANAGER = get_sto.ID_MANAGER      
					--join #t_customer cust on cust.ID_SALE = get_sto.ID_CUSTOMER      
					left join SP_PERS sp with(nolock) on get_sto.ID_AGENT = sp.ID_PERS
					left join ( select distinct sp2.ID_PERS_RELATE, pd.NAME_AD_DEPART as NAME_DEPART
								from SP_REL_PERS sp2
								join N_SP_DEPART nsd on sp2.ID_PERS_MAIN = nsd.ID_MANAGER
								join PL_DEPART pd on nsd.ID_DEPART = pd.ID_DEPART ) dep on get_sto.ID_AGENT = dep.ID_PERS_RELATE	 
				--where get_sto.ID_MANAGER = @id_manager
				where get_sto.ID_MANAGER = @id_manager or @id_manager is NULL    	        
				group by get_sto.ID_GOOD, sg.GOOD_NAME_SPB, DAT_NAKL, sp.LAST_NAME, sp.ID_PERS, dep.NAME_DEPART
			end
		else if @ID=14
			begin
				declare @id_good_14 int, @DAT_NAKL_14 datetime, @id_pers_14 int
				select @id_good_14 = dbo.GET_PARAM_FROM_LIST(@P1, 7, DEFAULT), @DAT_NAKL_14 = convert(datetime, dbo.GET_PARAM_FROM_LIST(@P1, 8, DEFAULT), 104), @id_pers_14 = dbo.GET_PARAM_FROM_LIST(@P1, 9, DEFAULT)  
				insert into #good (ID_GOOD)     
				select @id_good_14
				-- непосредственно, набор
				select rgn.ID_GOOD as 'Код товара', 
					sg.GOOD_NAME_SPB as 'Наименование товара',  
					sum((isnull(spo.VID_OPER*(rgn.KOL_GOOD_U_C+rgn.KOL_GOOD_R_C),0))) as 'Факт (бут)',          
					sum(isnull(case rhn.ID_VAL when 2 then      
								spo.VID_OPER*rgn.STO_GOOD_FULL_C      
							else       
								spo.VID_OPER*rhn.COURSE*rgn.STO_GOOD_FULL_C      
							end ,0)) as 'Факт (руб)',
					c.NAME_FIRM	as 'Покупатель'	         
				from R_HD_NAKL_ALL rhn with(nolock)      
					join R_GOOD_NAKL_ALL rgn with(nolock) on rgn.ID_HD_NAKL = rhn.ID_HD_NAKL and (KOL_GOOD_U_C+KOL_GOOD_R_C) <> 0      
					join #good good on rgn.ID_GOOD = good.ID_GOOD      
					join SP_OPER spo with(nolock) on spo.ID_OPER=rhn.ID_OPER      
					join SP_GOOD sg with(nolock) on sg.GOOD_COD = rgn.ID_GOOD      
					join R_HD_ZAK_ALL zak with(nolock) on rhn.ID_HD_ZAK = zak.ID_HD_ZAK 
					left join SP_PERS p with(nolock) on zak.ID_MANAGER = p.ID_PERS 
					left join SP_FIRM c with(nolock) on rhn.ID_POST = c.ID_FIRM            
				where (rhn.DAT_NAKL >= @date1 and rhn.DAT_NAKL <= @date2)      
					   --and zak.ID_AGENT = case when @agent = 0 then zak.ID_AGENT else @agent end       
					   and ((spo.IS_MAIN in (0,1)))  
					   and rhn.NOM_NAKL not like '%*%'
					   and (zak.ID_MANAGER = @id_manager or @id_manager is NULL)  
					   and rgn.ID_GOOD = @id_good_14
					   and rhn.DAT_NAKL = @DAT_NAKL_14
					   and p.ID_PERS = @id_pers_14
				group by rgn.ID_GOOD, sg.GOOD_NAME_SPB, DAT_NAKL, c.NAME_FIRM
				union all            
				select get_sto.ID_GOOD,      
					sg.GOOD_NAME_SPB,  
					KOL=SUM(isnull(SUM_KOL,0)),          
					SUMM =SUM(isnull(SUM_SALE,0)),
					'Розничный покупатель' as 'Покупатель'	      			    
				from  GET_SCTEST_STO (@date1, @date2, 0, 0, 0, 0, 1) get_sto        
					join #good good on get_sto.ID_GOOD = good.ID_GOOD      
					join SP_GOOD sg with(nolock) on sg.GOOD_COD = get_sto.ID_GOOD         
					left join SP_PERS sp with(nolock) on get_sto.ID_AGENT = sp.ID_PERS 
				where (get_sto.ID_MANAGER = @id_manager or @id_manager is NULL) 
					and get_sto.ID_GOOD = @id_good_14
					and get_sto.DAT_NAKL = @DAT_NAKL_14
					and sp.ID_PERS = @id_pers_14  	        
				group by get_sto.ID_GOOD, sg.GOOD_NAME_SPB, DAT_NAKL, sp.LAST_NAME 
			end
	end
-- #################################################################################################################
-- доступ пользователей к созданию матриц ##########################################################################
else if @ID=13
	begin
		-- параметр визуального представления полей
		set @MAP = '[Доступ на создание]:WIDTH=180;' 
		-- пользователи
		select v as [Доступ на создание]
		from (select cast('<r><c>'+replace(CBTrade.dbo.GET_GLOBAL_VAR('ACCESS_CREATE_MATRIX'),';','</c><c>')+'</c></r>' as xml) s ) t
		cross apply (select x.z.value('.', 'char(18)') v from s.nodes('/r/c') x(z)) tt
		where v<>''
	end
-- #####################################################################################################################
-- журнал изменений полный #############################################################################################
else if @ID=15
	begin
		-- параметр визуального представления полей
		set @MAP = '[Пользователь]:WIDTH=150;[Изменён план на месяц]:WIDTH=150;[Новое значение]:WIDTH=150;[Когда изменено]:WIDTH=150;[Департамент]:150;' 
		-- журнал изменений
		declare @year_15 int
		set @year_15 = cast(dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) as int)
		select pl.USER_LOGIN as [Пользователь], pm.POS_CODE as [Артикул бренда], pm.POS_NAME as [Наименование бренда], 
			case when pl.NUM_MONTH<=12 then case pl.NUM_MONTH
				when 1 then 'январь'
				when 2 then 'февраль'
				when 3 then 'март'
				when 4 then 'апрель'
				when 5 then 'май'
				when 6 then 'июнь'
				when 7 then 'июль'
				when 8 then 'август'
				when 9 then 'сентябрь'
				when 10 then 'октябрь'
				when 11 then 'ноябрь'
				when 12 then 'декабрь' end else 'цена' end as [Изменён план на месяц/цена], 
			pl.ID_ROW, pl.VAL as [Новое значение], 
			pl.UPDATE_MOMENT as [Когда изменено], pd.NAME_AD_DEPART as [Департамент], pm.ID_VER AS [Матрица], p.NUM_YEAR as [Год]
		from PL_LOG pl
		left join PL_PLAN p on pl.ID_ROW = p.ID_ROW
		left join N_SP_DEPART nsd on p.DEPART = nsd.ID_DEPART 
		left join PL_DEPART pd on nsd.ID_DEPART = pd.ID_DEPART
		left join PL_MATRIX pm on p.ID_GP = pm.ID_GP
		where p.NUM_YEAR = @year_15
		order by pl.UPDATE_MOMENT desc
	end
-- #################################################################################################################
-- факт по всем департаментам для историч. справки, пример: @P1='1::01.04.2015::30.04.2015' ########################
else if @ID=16
	begin
		-- параметр визуального представления полей
		set @MAP = '[Департамент]:WIDTH=100;[Артикул бренда]:WIDTH=120;[Наименование бренда]:WIDTH=200;[Факт (бут)]:WIDTH=80;[Факт (руб)]:WIDTH=80;' 
		declare @date1_fa datetime, @date2_fa datetime, @imp_brand_fa int
		select @imp_brand_fa = cast(dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) as int), @date1_fa = convert(datetime, dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT), 104), @date2_fa = convert(datetime, dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT), 104)
		create table #good_fa (ID_GOOD int)       
		insert into #good_fa      
		select l.ID_GOOD      
		from SP_GOOD_BRAND b with(nolock)  
		join SP_GOOD_BRAND_LINKS l with(nolock) on b.ID_GROUP = l.ID_GROUP and b.ID_GROUP <> 344 -- коробки исключаем т.к.они никому не интересны  
		where b.IS_IMPORT = @imp_brand_fa 

		-- непосредственно, набор
		select 
			IsNull(pd.NAME_AD_DEPART, p.LAST_NAME) as 'Департамент',		
			IsNull(sgb.CODE_GROUP, sgb.ORDER_BY) as 'Артикул бренда',
			sgb.NAME_GROUP as 'Наименование бренда',           
			sum((isnull(spo.VID_OPER*(rgn.KOL_GOOD_U_C+rgn.KOL_GOOD_R_C),0))) as 'Факт (бут)',          
			sum(isnull(case rhn.ID_VAL when 2 then      
						spo.VID_OPER*rgn.STO_GOOD_FULL_C      
					else       
						spo.VID_OPER*rhn.COURSE*rgn.STO_GOOD_FULL_C      
					end ,0)) as 'Факт (руб)'			    
		from R_HD_NAKL_ALL rhn with(nolock)      
			join R_GOOD_NAKL_ALL rgn with(nolock) on rgn.ID_HD_NAKL = rhn.ID_HD_NAKL and (KOL_GOOD_U_C+KOL_GOOD_R_C) <> 0      
			join #good_fa good on rgn.ID_GOOD = good.ID_GOOD      
			join SP_OPER spo with(nolock) on spo.ID_OPER=rhn.ID_OPER      
			join SP_GOOD sg with(nolock) on sg.GOOD_COD = rgn.ID_GOOD      
			join R_HD_ZAK_ALL zak with(nolock) on rhn.ID_HD_ZAK = zak.ID_HD_ZAK 
			left join SP_PERS p with(nolock) on zak.ID_MANAGER = p.ID_PERS 
			left join SP_GOOD_BRAND_LINKS sgbl with(nolock) on rgn.ID_GOOD = sgbl.ID_GOOD 
			left join SP_GOOD_BRAND sgb with(nolock) on sgbl.ID_GROUP = sgb.ID_GROUP
			left join N_SP_DEPART nsd with(nolock) on zak.ID_MANAGER = nsd.ID_MANAGER
			left join PL_DEPART pd with(nolock) on nsd.ID_DEPART = pd.ID_DEPART       
		where (rhn.DAT_NAKL >= @date1_fa and rhn.DAT_NAKL <= @date2_fa)          
				and ((spo.IS_MAIN in (0,1)))  
				and rhn.NOM_NAKL not like '%*%'
		group by sgb.CODE_GROUP, sgb.NAME_GROUP, sgb.ORDER_BY, pd.NAME_AD_DEPART, p.LAST_NAME	
		union all            
		select IsNull(pd.NAME_AD_DEPART, sp.LAST_NAME), 
			IsNull(sgb.CODE_GROUP, sgb.ORDER_BY),
			sgb.NAME_GROUP, 
			KOL=SUM(isnull(SUM_KOL,0)),          
			SUMM =SUM(isnull(SUM_SALE,0))				    
		from GET_SCTEST_STO (@date1_fa, @date2_fa, 0, 0, 0, 0, 1) get_sto        
			join #good_fa good on get_sto.ID_GOOD = good.ID_GOOD      
			join SP_GOOD sg with(nolock) on sg.GOOD_COD = get_sto.ID_GOOD            
			left join SP_PERS sp with(nolock) on get_sto.ID_AGENT = sp.ID_PERS
			left join SP_GOOD_BRAND_LINKS sgbl with(nolock) on get_sto.ID_GOOD = sgbl.ID_GOOD 
			left join SP_GOOD_BRAND sgb with(nolock) on sgbl.ID_GROUP = sgb.ID_GROUP 
			left join N_SP_DEPART nsd with(nolock) on get_sto.ID_MANAGER = nsd.ID_MANAGER
			left join PL_DEPART pd with(nolock) on nsd.ID_DEPART = pd.ID_DEPART   	        
		group by sp.LAST_NAME, sp.ID_PERS, sgb.CODE_GROUP, sgb.ORDER_BY, sgb.NAME_GROUP, pd.NAME_AD_DEPART, sp.LAST_NAME	   

		if object_id(N'tempdb..#good_fa') is not null drop table #good_fa
	end
	-- #################################################################################################################
	-- доступ пользователей к изм. плана; полная информация ############################################################
	else if @ID=17
		begin
			-- параметр визуального представления полей
			set @MAP = '[Артикул бренда]:WIDTH=120;[Наименование бренда]:WIDTH=180;[Департамент]:WIDTH=80;[Агент]:WIDTH=80;[Наименование фирмы покупателя]:WIDTH=200;' 
			declare @spr_lists table (ID_DEPART int, AGENTS nvarchar(200), CUSTOMERS varchar(1000), CUSTNAME nvarchar(30))
			declare @spr_depart int, @xc_5 xml
			declare fld_cur5 cursor for select ID_DEPART, CUSTOMERSXML from PL_LISTS where AGENTS is null 
			open fld_cur5	  
			fetch next from fld_cur5 into @spr_depart, @xc_5
			while @@FETCH_STATUS = 0   
   				begin  
					select @xc_5=l.CUSTOMERSXML from PL_LISTS l where ID_DEPART = @spr_depart  
					-- заполнение по одному департаменту
					insert into @spr_lists (ID_DEPART, AGENTS, CUSTOMERS, CUSTNAME)
					select p.ID_DEPART, p.AGENTS, r.cids as CUSTOMERS, cname as CUSTNAME 
					from PL_LISTS p
					left join (select Tbl.Col.value('@ID', 'varchar(1000)') as cids, Tbl.Col.value('@NAIM', 'varchar(30)') as cname
								from @xc_5.nodes('//Row') Tbl(Col) ) r on 1=1
					where p.ID_DEPART = @spr_depart		
					fetch next from fld_cur5 into @spr_depart, @xc_5
  				end  
			close fld_cur5 
			deallocate fld_cur5
			-- раскрытие всех агентов, объединение с покупателями
			select a.DEPART as ID_DEPART, a.EDITABLE as 'Частн.разреш.изм.', a.AGENT as ID_AGENT, sp.LAST_NAME + ' ' + sp.FIRST_NAME as 'Агент',  t.CUSTNAME as 'Наименование фирмы покупателя', 
				a.CUSTOMERS as 'Покупатели', 
				case when a.TYPE_GP=1 then 'импортный' else 'привлечённый' end as 'По типу поставки', a.TYPE_GP 
			into #spr_dep_agn_cust
			from PL_AFFIX a
			left join
				(select t.ID_DEPART, v as AGENTS, cast(null as varchar(1000)) as CUSTOMERS, cast(null as nvarchar(30)) as CUSTNAME
				from (select c.ID_DEPART, cast('<r><c>'+replace(c.AGENTS,',','</c><c>')+'</c></r>' as xml) s from (select * from PL_LISTS where CUSTOMERSXML is null) as c ) t
				cross apply (select x.z.value('.', 'int') as v from s.nodes('/r/c') x(z)) tt 
				union all
				select * from @spr_lists) t on a.DEPART =  t.ID_DEPART and IsNull(a.AGENT,'0') = IsNull(t.AGENTS,'0') and IsNull(a.CUSTOMERS,'0') = IsNull(t.CUSTOMERS,'0')  
			left join N_SP_DEPART nsd on IsNull(a.DEPART, t.ID_DEPART) = nsd.ID_DEPART
			left join SP_PERS sp on a.AGENT = sp.ID_PERS
			left join PL_DEPART d on a.DEPART = d.ID_DEPART
			where not a.DEPART is null
			-- непосредственно, набор данных; сначало по конкретным направлениям
			select m.POS_CODE as 'Артикул бренда', 
			  m.POS_NAME as 'Наименование бренда', 
			  d.NAME_AD_DEPART as 'Департамент', 
			  s.[Агент], s.[Наименование фирмы покупателя], s.[По типу поставки],
			  case when CBTrade.dbo.GET_GLOBAL_VAR('EDIT_ALLOW')=1 then 'Разрешение' else 'Запрет' end as 'Общ.разреш.изм.',
			  case when s.[Частн.разреш.изм.]=1 then 'Разрешение' else 'Запрет' end as [Частн.разреш.изм.],
			  case when l.LOCK=1 then 'Запрет по напр.планирования' when l.LOCK=0 then 'Разрешение по напр.планирования' end as 'Индив.разреш.изм.'
			from PL_LOCKED_BRAND l
			left join PL_PLAN p on l.ID_ROW=p.ID_ROW
			left join PL_MATRIX m on p.ID_GP = m.ID_GP
			left join PL_DEPART d on p.DEPART = d.ID_DEPART
			left join #spr_dep_agn_cust s on p.DEPART = s.ID_DEPART and ((p.AGENT = s.ID_AGENT or p.AGENT is Null) or (p.CUSTOMERS = s.[Покупатели] or p.CUSTOMERS is null))
			where Not m.POS_CODE is Null
			union all -- объединение с общими запретами
			select m.POS_CODE as 'Артикул бренда', 
			  m.POS_NAME as 'Наименование бренда', 
			  '' as 'Департамент', '' as [Агент], '' as [Наименование фирмы покупателя], case when v.TYPE_GP=1 then 'импортный' else 'привлечённый' end as [По типу поставки], 
			  case when CBTrade.dbo.GET_GLOBAL_VAR('EDIT_ALLOW')=1 then 'Разрешение' else 'Запрет' end as 'Общ.разреш.изм.',
			  '' as [Частн.разреш.изм.],
			  case when l.LOCK=1 then 'Запрет для всех' when l.LOCK=0 then 'Разрешение для всех' end as 'Индив.разреш.изм.'
			from PL_LOCKED_BRAND l
			left join PL_PLAN p on l.ID_ROW=p.ID_GP
			left join PL_MATRIX m on p.ID_GP = m.ID_GP
			left join PL_VER v on m.ID_VER = v.ID_VER
			where Not m.POS_CODE is null
			group by m.POS_CODE, m.POS_NAME, l.LOCK, v.TYPE_GP	
			-- чистка таблиц		
			if object_id(N'tempdb..#spr_dep_agn_cust') is not null drop table #spr_dep_agn_cust	
		end
-- #################################################################################################################
-- планы других департаментов (формат параметра: "Артикул_бренда::Версия_матрицы::Номер_месяца", пример: 02.0200::50::1) 
else if @ID=18
	begin
		-- параметр визуального представления полей
		set @MAP = '[Департамент]:WIDTH=180;[Агент]:WIDTH=120;[Покупатель]:WIDTH=120;[План (бут)]:80;' 
		declare @lists9 table (ID_DEPART int, AGENTS nvarchar(200), CUSTOMERS varchar(1000), CUSTNAME nvarchar(30))
		declare @depart9 int, @xc9 xml, @ren_str9 varchar(1000)
		declare fld_cur9 cursor for select ID_DEPART, CUSTOMERSXML from PL_LISTS where AGENTS is null 
		open fld_cur9	  
		fetch next from fld_cur9 into @depart9, @xc9
		while @@FETCH_STATUS = 0   
   			begin  
				select @xc9=l.CUSTOMERSXML from PL_LISTS l where ID_DEPART = @depart9  
				-- заполнение по одному департаменту
				insert into @lists9 (ID_DEPART, AGENTS, CUSTOMERS, CUSTNAME)
				select p.ID_DEPART, p.AGENTS, r.cids as CUSTOMERS, cname as CUSTNAME 
				from PL_LISTS p
				left join (select Tbl.Col.value('@ID', 'varchar(1000)') as cids, Tbl.Col.value('@NAIM', 'varchar(30)') as cname
							from @xc9.nodes('//Row') Tbl(Col) ) r on 1=1
				where p.ID_DEPART = @depart9		
				fetch next from fld_cur9 into @depart9, @xc9
  			end  
		close fld_cur9 
		deallocate fld_cur9
		-- агенты и департаменты
		select a.DEPART as ID_DEPART, d.NAME_AD_DEPART as 'Департамент', 
			a.AGENT as ID_AGENT, sp.LAST_NAME + ' ' + sp.FIRST_NAME as 'Агент',  
			a.CUSTOMERS as CUSTOMERS, t.CUSTNAME as 'Наименование фирмы покупателя', 	
			case when a.TYPE_GP=1 then 'импортный' else 'привлечённый' end as 'По типу поставки'
		into #spr9
		from PL_AFFIX a
		left join
			(select t.ID_DEPART, v as AGENTS, cast(null as varchar(1000)) as CUSTOMERS, cast(null as varchar(100)) as CUSTNAME
			from (select c.ID_DEPART, cast('<r><c>'+replace(c.AGENTS,',','</c><c>')+'</c></r>' as xml) s from (select * from PL_LISTS where CUSTOMERSXML is null) as c ) t
			cross apply (select x.z.value('.', 'int') as v from s.nodes('/r/c') x(z)) tt 
			union all
			select * from @lists9) t on a.DEPART =  t.ID_DEPART and IsNull(a.AGENT,'0') = IsNull(t.AGENTS,'0') and IsNull(a.CUSTOMERS,'0') = IsNull(t.CUSTOMERS,'0')  
		left join N_SP_DEPART nsd on IsNull(a.DEPART, t.ID_DEPART) = nsd.ID_DEPART
		left join SP_PERS sp on a.AGENT = sp.ID_PERS
		left join PL_DEPART d on a.DEPART = d.ID_DEPART
		where not a.DEPART is null
		-- непосредственно, набор данных
		set @ren_str9 = 'select s.[Департамент], s.[Агент], s.[Наименование фирмы покупателя] as [Покупатель],
						   p.M' + dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT) + ' as [План (бут)] 
						 from PL_PLAN p
						 left join #spr9 s on (p.DEPART = s.ID_DEPART) and (p.AGENT = s.ID_AGENT or s.ID_AGENT is null) and (p.CUSTOMERS = s.CUSTOMERS or (p.CUSTOMERS is null or s.CUSTOMERS is null ))
						 where p.ID_GP = (select ID_GP from PL_MATRIX pm where POS_CODE = ''' + dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) +''' and ID_VER = ' + dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT) + ') 
						   and not s.ID_DEPART is null
						   and (select TYPE_GP from PL_VER where ID_VER= ' + dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT) + ') = (case when s.[По типу поставки]=''импортный'' then 1 else 2 end)'
		exec (@ren_str9)
		-- убираем временную таблицу
		if object_id(N'tempdb..#spr9') is not null drop table #spr9		
	end
-- #################################################################################################################
-- сообщения пользователям #########################################################################################
else if @ID=19
	begin
		if @P1 is null
		  begin
			-- параметр визуального представления полей
			set @MAP = '[Сообщение]:WIDTH=350;' 
			select top 100 ID_MES, MESSAGE_TEXT as [Сообщение] from PL_MESSAGE order by ID_MES desc
		  end
		else
		  begin
			insert into PL_MESSAGE select @P1
			select 1
		  end
	end
-- #################################################################################################################
-- определение самой последней матрицы в году из тех, что можно видеть  (формат параметра "Год::Тип_поставки") #####
else if @ID=20
	begin
		declare @num_year_20 int, @type_gp_20 int
		select @num_year_20 = cast(dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) as int), @type_gp_20 = cast(dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT) as int)

		declare @v table (ID_VER int)
		insert into @v select ID_VER from PL_VER where TYPE_GP = @type_gp_20 and IS_SHOWING = 1 

		select max(v.ID_VER) as ID_VER 
		from @v v
		left join PL_MATRIX m on v.ID_VER = m.ID_VER
		left join PL_PLAN p on p.ID_GP = m.ID_GP
		where p.NUM_YEAR = @num_year_20 
	end
-- #################################################################################################################
-- история изменений плана по месяцам  #############################################################################
else if @ID=21
	begin
		-- параметр визуального представления полей
		set @MAP = '[Месяц]:WIDTH=50;[Было]:WIDTH=50;[Сейчас]:WIDTH=50;[Разница]:WIDTH=50;' 
		declare @MonList table (NUM_MONTH int) 
		declare @guid_21 varchar(50), @d1 datetime 
		declare @i int
		set @i=1
		while @i<13
		   begin
			 insert into @MonList select @i
			 set @i=@i+1
		   end
		if object_id(N'tempdb..#p2') is not null drop table #p2
		set @d1 =  convert(datetime, dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT), 102)
		-- преобразование guid в нужный формат
		set @guid_21 = replace(replace(dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT),'0x',''),'-','')
		set @guid_21 = stuff(stuff(stuff(stuff(@guid_21,21,0,'-'),17,0,'-'),13,0,'-'),9,0,'-')
		-- месяцы года  
		select t.*
		into #p2
		from
		(select 1 as NUM_MONTH, M1 as K from PL_PLAN where ID_ROW = cast(@guid_21 as uniqueidentifier)
		union all
		select 2, M2 from PL_PLAN where ID_ROW = @guid_21
		union all
		select 3, M3 from PL_PLAN where ID_ROW = @guid_21
		union all
		select 4, M4 from PL_PLAN where ID_ROW = @guid_21
		union all
		select 5, M5 from PL_PLAN where ID_ROW = @guid_21
		union all
		select 6, M6 from PL_PLAN where ID_ROW = @guid_21
		union all
		select 7, M7 from PL_PLAN where ID_ROW = @guid_21
		union all
		select 8, M8 from PL_PLAN where ID_ROW = @guid_21
		union all
		select 9, M9 from PL_PLAN where ID_ROW = @guid_21
		union all
		select 10, M10 from PL_PLAN where ID_ROW = @guid_21
		union all
		select 11, M11 from PL_PLAN where ID_ROW = @guid_21
		union all
		select 12, M12 from PL_PLAN where ID_ROW = @guid_21) t
		order by t.K
		-- непосредственно набор данных
		select mo.NUM_MONTH as 'Месяц', coalesce(p1.HISTORIC_VAL, p2.K, 0) as 'Было', p2.K as 'Сейчас',  IsNull(p1.HISTORIC_VAL, p2.K) - IsNull(p2.K, 0) as 'Разница'
		from @MonList mo
		left join
			(select distinct t.* 
			from
				(select ID_ROW, NUM_MONTH, 
				max(VAL) over (partition by NUM_MONTH) as HISTORIC_VAL
				from PL_LOG 
				where ID_ROW=@guid_21 and CONVERT(varchar(10), UPDATE_MOMENT, 102)<=@d1 and NUM_MONTH < 13) t ) p1 on mo.NUM_MONTH = p1.NUM_MONTH
		left join #p2 p2 on mo.NUM_MONTH = p2.NUM_MONTH
		order by mo.NUM_MONTH
	end
-- #################################################################################################################
-- кто менял план и когда в этом департаменте (формат параметра "guid") ############################################
else if @ID=22
	begin
		-- параметр визуального представления полей
		set @MAP = '[Кем менялось]:WIDTH=100;[На месяц]:WIDTH=50;[Значение]:WIDTH=50;[Когда менялось]:WIDTH=150;' 		
		declare @guid_22 varchar(50)
		set @guid_22 = replace(replace(@P1,'0x',''),'-','')
		set @guid_22 = stuff(stuff(stuff(stuff(@guid_22,21,0,'-'),17,0,'-'),13,0,'-'),9,0,'-')
		-- непосредственно набор данных
		select l.USER_LOGIN 'Кем менялось', l.NUM_MONTH 'На месяц', l.VAL 'Значение', l.UPDATE_MOMENT 'Когда менялось' from PL_LOG l where l.ID_ROW=@guid_22 order by l.NUM_MONTH, l.UPDATE_MOMENT 
	end
-- #################################################################################################################
-- кто менял план и когда в других департаментах (формат параметра "Артикул_бренда::Номер_матрицы::Тип_поставки") ##
else if @ID=23
	begin
		-- параметр визуального представления полей
		set @MAP = '[Департамент]:WIDTH=150;[Агент]:WIDTH=150;[Наименование фирмы покупателя]:WIDTH=100;[Месяц]:WIDTH=50;[Год]:WIDTH=50;[Когда менялось]:WIDTH=150;' 	
		-- департаменты, агенты, покупатели. тип поставки - как справочник
		declare @lists23 table (ID_DEPART int, AGENTS nvarchar(200), CUSTOMERS varchar(1000), CUSTNAME nvarchar(30))
		declare @depart23 int, @xc23 xml
		declare fld_cur23 cursor for select ID_DEPART, CUSTOMERSXML from PL_LISTS where AGENTS is null 
		open fld_cur23	  
		fetch next from fld_cur23 into @depart23, @xc23
		while @@FETCH_STATUS = 0   
   			begin  
				select @xc23=l.CUSTOMERSXML from PL_LISTS l where ID_DEPART = @depart23  
				-- заполнение по одному департаменту
				insert into @lists23 (ID_DEPART, AGENTS, CUSTOMERS, CUSTNAME)
				select p.ID_DEPART, p.AGENTS, r.cids as CUSTOMERS, cname as CUSTNAME 
				from PL_LISTS p
				left join (select Tbl.Col.value('@ID', 'varchar(1000)') as cids, Tbl.Col.value('@NAIM', 'varchar(30)') as cname
							from @xc23.nodes('//Row') Tbl(Col) ) r on 1=1
				where p.ID_DEPART = @depart23		
				fetch next from fld_cur23 into @depart23, @xc23
  			end  
		close fld_cur23 
		deallocate fld_cur23
		select a.DEPART as ID_DEPART, d.NAME_AD_DEPART as 'Департамент', 
			a.AGENT as ID_AGENT, sp.LAST_NAME + ' ' + sp.FIRST_NAME as 'Агент',  t.CUSTNAME as 'Наименование фирмы покупателя', 
			a.CUSTOMERS as 'Покупатели', case when a.TYPE_GP=1 then 'импортный' else 'привлечённый' end as 'По типу поставки', a.TYPE_GP 
		into #spr23
		from PL_AFFIX a
		left join
			(select t.ID_DEPART, v as AGENTS, cast(null as varchar(1000)) as CUSTOMERS, cast(null as varchar(100)) as CUSTNAME
			from (select c.ID_DEPART, cast('<r><c>'+replace(c.AGENTS,',','</c><c>')+'</c></r>' as xml) s from (select * from PL_LISTS where CUSTOMERSXML is null) as c ) t
			cross apply (select x.z.value('.', 'int') as v from s.nodes('/r/c') x(z)) tt 
			union all
			select * from @lists23) t on a.DEPART = t.ID_DEPART and IsNull(a.AGENT,'0') = IsNull(t.AGENTS,'0') and IsNull(a.CUSTOMERS,'0') = IsNull(t.CUSTOMERS,'0')  
		left join N_SP_DEPART nsd on IsNull(a.DEPART, t.ID_DEPART) = nsd.ID_DEPART
		left join SP_PERS sp on a.AGENT = sp.ID_PERS
		left join PL_DEPART d on a.DEPART = d.ID_DEPART
		where not a.DEPART is null
		-- по каким менялся план в LOG
		select distinct  s.[Департамент], cast(s.[Агент] as varchar(100)) as [Агент], cast(s.[Наименование фирмы покупателя] as varchar(100)) as [Наименование фирмы покупателя], 
			cast(pl.NUM_MONTH as int) as 'Месяц', cast(pp.NUM_YEAR as int) as 'Год', cast(pl.USER_LOGIN as varchar(100)) as 'Кем менялось', cast(pp.ID_ROW as varchar(100)) as ID_ROW
		from PL_LOG pl
		left join PL_PLAN pp on pl.ID_ROW = pp.ID_ROW
		left join #spr23 s on pp.DEPART = s.ID_DEPART and (pp.AGENT=s.ID_AGENT or (pp.AGENT is null and s.ID_AGENT is null) or (pp.AGENT = 728 and s.ID_AGENT is null)) and (pp.CUSTOMERS=s.[Покупатели] or (pp.CUSTOMERS is null and s.[Покупатели] is null))
		where pp.ID_GP = (select top 1 ID_GP from PL_MATRIX where POS_CODE= dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) and ID_VER = cast(dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT) as int)) and s.TYPE_GP = cast(dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT) as int)
	end
-- #################################################################################################################
-- изменились артикулы #############################################################################################
else if @ID=24	
	begin
		-- параметр визуального представления полей
		set @MAP = '[№, было]:WIDTH=100;[Артикул, был]:WIDTH=90;[Наименование бренда, было]:WIDTH=350;[№, стало]:WIDTH=100;[Артикул, стал]:WIDTH=90;[Наименование бренда, стало]:WIDTH=350;' 
		-- набор данных				
		select m.ID_GP, m.POS_NUM as '№, было', m.POS_CODE as 'Артикул, был', m.POS_NAME as 'Наименование бренда, было', sgb.ORDER_BY as '№, стало', sgb.CODE_GROUP as 'Артикул, стал', sgb.NAME_GROUP as 'Наименование бренда, стало' 
		from PL_MATRIX m 
		left join (select ID_GROUP, ORDER_BY, CODE_GROUP, NAME_GROUP from CBTrade.dbo.SP_GOOD_BRAND where IS_IMPORT = cast(dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT) as int) ) sgb on m.ID_GROUP = sgb.ID_GROUP
		where sgb.CODE_GROUP <> m.POS_CODE and m.ID_VER = cast(dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) as int)
		order by m.POS_NUM
	end
-- #################################################################################################################
-- показ товаров для выбранного бренда (связанные с брендом товары) ################################################
else if @ID=25	
	begin
		-- параметр визуального представления полей
		set @MAP = '[Код товара]:WIDTH=100;[Код товара, производителя]:WIDTH=170;[Код товара, внутренний]:WIDTH=170;[Наименование товара, краткое]:WIDTH=250;[Наименование товара, полное]:WIDTH=250;[Страна]:WIDTH=100;' 
		-- набор данных				
		select sg.GOOD_COD as 'Код товара', sg.GOOD_NUMBER_SPB as 'Код товара, производителя', sg.GOOD_NUMBER_MSK as 'Код товара, внутренний', sg.GOOD_NAME_SHORT as 'Наименование товара, краткое', sg.GOOD_NAME_SPB as 'Наименование товара, полное', 
		  sc.NAME_RUS as 'Страна'
		from SP_GOOD_BRAND b
		left join SP_GOOD_BRAND_LINKS l on b.ID_GROUP = l.ID_GROUP
		left join SP_GOOD sg on l.ID_GOOD = sg.GOOD_COD
		left join SP_COUNTRY sc on sg.ID_COUNTRY = sc.ID_COUNTRY 
		where b.CODE_GROUP = dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) or 
		 (cast(b.ORDER_BY as varchar(8)) = dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) and len(dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT))<7 and b.IS_IMPORT=0)
	end
-- #################################################################################################################
-- показ приходов товаров для выбранного бренда (формат параметра "Тип_поставки::Артикул_бренда", например: 1::02.0222)
else if @ID=26	
	begin
		-- параметр визуального представления полей
		set @MAP = '[Код товара]:WIDTH=100;[Код товара, внутренний]:WIDTH=170;[Наименование товара, полное]:WIDTH=250;[Количество (бут)]:WIDTH=120;[Дата поставки]:WIDTH=90;'
		-- преобразование параметра
		declare @TYPE_GP_26 int, @CODE_GROUP_26 varchar(10)
		select @TYPE_GP_26=cast(dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) as int), @CODE_GROUP_26 =  dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT)
		-- набор данных	
		select l.ID_GOOD as 'Код товара', 
			g.GOOD_NUMBER_MSK as 'Код товара, внутренний', 
			g.GOOD_NAME_SPB as 'Наименование товара, полное',
			fg.KOL as 'Количество (бут)',
			convert(varchar(10), fg.DAT_PLAN_IN, 104) as 'Дата поставки'
		from SP_GOOD_BRAND b
		left join SP_GOOD_BRAND_LINKS l on b.ID_GROUP = l.ID_GROUP
		left join SP_GOOD g on l.ID_GOOD = g.GOOD_COD
		left join CBTrade.dbo.F_GOOD_ZAK_PLAN() fg on l.ID_GOOD = fg.ID_GOOD
		left join ( select pgn.ID_GOOD, 
						SUM(CASE WHEN spo.IS_MAIN = 0 THEN isnull(pgn.KOL_GOOD_U, 0) ELSE 0 END) AS PLAN_POST_U, 
						SUM(CASE WHEN spo.IS_MAIN = 0 THEN isnull(pgn.KOL_GOOD_R, 0) ELSE 0 END) AS PLAN_POST_R, 
						SUM(CASE WHEN spo.IS_MAIN = 0 THEN isnull(pgn.KOL_GOOD_NETTO, 0) ELSE 0 END) AS PLAN_POST_N, 
						SUM(CASE WHEN spo.IS_MAIN = 1 THEN isnull(pgn.KOL_GOOD_U, 0) ELSE 0 END) AS PLAN_RETURN_U, 
						SUM(CASE WHEN spo.IS_MAIN = 1 THEN isnull(pgn.KOL_GOOD_R, 0) ELSE 0 END) AS PLAN_RETURN_R, 
						SUM(CASE WHEN spo.IS_MAIN = 1 THEN isnull(pgn.KOL_GOOD_NETTO, 0) ELSE 0 END) AS PLAN_RETURN_N
					from P_HD_ZAK AS phz (nolock) 
					join P_HD_NAKL AS phn (nolock) ON phz.ID_HD_ZAK = phn.ID_HD_ZAK AND phn.ID_HD_NAKL = phn.ID_HD_NAKL_MAIN 
					join P_GOOD_NAKL AS pgn (nolock) ON phn.ID_HD_NAKL = pgn.ID_HD_NAKL 
					join SP_SOST AS sps (nolock) ON phz.ID_SOST = sps.ID_SOST 
					join SP_OPER AS spo (nolock) ON phn.ID_OPER = spo.ID_OPER AND spo.IS_MAIN IN (0, 1)
					where (phn.ID_SOST IN (500, 600, 800))
					group by pgn.ID_GOOD ) op on l.ID_GOOD = op.ID_GOOD
		where fg.KOL>0 and b.IS_IMPORT = 2 - @TYPE_GP_26 and b.CODE_GROUP = @CODE_GROUP_26
		order by fg.DAT_PLAN_IN desc
	end
-- #################################################################################################################
-- показ сообщений, имеющих индекс больше параметра (формат параметра "ID", например: 2) ###########################
else if @ID=27	
	begin
		declare @MES_ID_27 int
		select @MES_ID_27=cast(dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) as int)
		-- все "непрочитанные" сообщения
		select * from PL_MESSAGE pm where pm.ID_MES>@MES_ID_27 order by ID_MES
	end
-- #################################################################################################################
-- изменение списка покупателей по группе (формат параметра "Департамент::Фирма::Список::Тип_поставки", например: 10::ОКей::26,100,128)
else if @ID=100 
	begin
		declare @xc2 xml, @cur_year int, @s nvarchar(1000), @old_list varchar(1000)
		select @xc2 = CUSTOMERSXML from PL_LISTS where ID_DEPART = dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT)
		-- запомним старый список покупателей, который до изменений  
		select top 1 @old_list = Tbl.Col.value('@ID', 'varchar(1000)') 
		from @xc2.nodes('//Row') Tbl(Col) 
		where Tbl.Col.value('@NAIM', 'varchar(30)') = dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT)		
		-- изменение списка
		set @s = 'update PL_LISTS set CUSTOMERSXML.modify(''' + 'replace value of (//Row[@NAIM=("' + dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT) + '")]/@ID)[1] with "' + dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT) + '"'') where ID_DEPART=' + dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) 
		exec sp_executesql @s
		-- изменения списков по активной матрице в таблице матрицы планирования; запоминаем по какому году было обновление, чтобы по нему же обновить факты 
		update pp
		set pp.CUSTOMERS = dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT) 
		from PL_PLAN pp 
		left join PL_MATRIX pm on pp.ID_GP = pm.ID_GP
		left join dbo.PL_VER pv on pm.ID_VER = pv.ID_VER
		where pv.IS_ACTIVE=1 and pp.DEPART=dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) and pp.CUSTOMERS = @old_list --and @cur_year = pp.NUM_YEAR 
		-- изменения в таблице фактов по году активной матрицы
		update PL_FACT
		set CUSTOMERS = dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT)
		where DEPART = dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) and CUSTOMERS = @old_list --and NUM_YEAR=@cur_year
		-- изменение в таблице обновления фактов
		update pa
		set pa.CUSTOMERS = dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT)
		from PL_AFFIX pa
		where pa.CUSTOMERS = @old_list 
	end
-- #################################################################################################################
-- изменение списка агентов по департаменту (формат параметра "Департамент::Список", например: 10::723,817) ########
else if @ID=101 
	begin
		declare @pos1 int, @id_dep1 varchar(10), @idl varchar(250)
		-- превращение параметра в департамент и список кодов агентов
		set @pos1 = charindex('::', @P1)
		select @id_dep1 = substring(@P1, 1, @pos1-1), @idl=substring(@P1, @pos1+2, len(@P1)-@pos1+2)
		-- изменение списка
		update PL_LISTS set AGENTS = @idl where ID_DEPART = @id_dep1
	end
-- #################################################################################################################
-- изменение списка логинов (формат параметра "Департамент::Агент::Покупатели::Логины::Тип поставки", например: 10::724::null::a.tsvetkov;a.ivanova::1 )
else if @ID=102
	begin
		-- изменение списка
		if (dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT) is null) and (dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT) is null)
			update PL_AFFIX set USERS_FOR_EDIT = dbo.GET_PARAM_FROM_LIST(@P1, 4, DEFAULT) 
			where DEPART = dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) and AGENT is null 
			  and CUSTOMERS is null and (TYPE_GP = dbo.GET_PARAM_FROM_LIST(@P1, 5, DEFAULT))
		else
			update PL_AFFIX set USERS_FOR_EDIT = dbo.GET_PARAM_FROM_LIST(@P1, 4, DEFAULT) 
			where DEPART = dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) and (AGENT = dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT) or AGENT is null) 
			  and (CUSTOMERS = dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT) or CUSTOMERS is null) and (TYPE_GP = dbo.GET_PARAM_FROM_LIST(@P1, 5, DEFAULT))
    end
-- #################################################################################################################
-- изменение формата ячейки (формат параметра "Номер позиции::Версия матрицы::Новый формат") #######################
else if @ID=103
	begin
		-- изменение формата ячейки в матрице брендов
		update PL_MATRIX
		set POS_FORMAT = replace(dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT), ' ', '')
		where POS_NUM = dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) and ID_VER = dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT)
    end
-- #################################################################################################################
-- изменение списка сетей по выбранному бренду (формат параметра: "Номер позиции::Версия матрицы::Новый список") ###
else if @ID=104
	begin
		-- изменение списка сетей по позиции в матрице брендов
		update PL_MATRIX
		set POS_RETAILNET = dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT)
		where POS_NUM = dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) and ID_VER = dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT)	 
    end
-- #################################################################################################################
-- добавление новой сети в таблицу справочник сетей ################################################################
else if @ID=105
	begin		
		declare @pos5 int
		-- поиск разделителя для отделения наименования и условного обозначения
		set @pos5 = charindex('::', @P1)
		insert into PL_RETAILNET (ID_RETAIL, RETAIL_NAME, ABBREV)
		select (select max(ID_RETAIL) + 1 from PL_RETAILNET), substring(@P1, 1, @pos5-1), substring(@P1, @pos5+2, len(@P1)-@pos5+2) 	 
    end
-- #################################################################################################################
-- изменение в таблице справочник сетей ############################################################################
else if @ID=106
	begin		
		declare @pos6 int, @id_retail int
		-- поиск разделителя для отделения кода, наименования и условного обозначения
		set @pos6 = charindex('::', @P1)
		set @id_retail = substring(@P1, 1, @pos6-1)
		set @P1 = substring(@P1, @pos6+2, len(@P1)-@pos6+2)
		set @pos6 = charindex('::', @P1)
		-- изменение по коду торговой сети
		update PL_RETAILNET
		set RETAIL_NAME = substring(@P1, 1, @pos6-1), ABBREV = substring(@P1, @pos6+2, len(@P1)-@pos6+2)
		where ID_RETAIL = @id_retail	 
    end
-- #################################################################################################################
-- создание новых матриц: брендов, планирования после изм. в "ЛиС" #################################################
else if @ID=107
	begin
		-- определение типа поставки исходя из версии матрицы брендов
		declare @TYPE_POST int, @new_id_ver int, @ren_str nvarchar(128)
		select @TYPE_POST = TYPE_GP  from PL_VER where ID_VER = @P1
		--BEGIN TRANSACTION;
		-- создание новой версии с этим типом поставки в реестре версий
		insert into PL_VER (VER, TYPE_GP, IS_ACTIVE, DATE_VER)
		values (cast(@TYPE_POST as varchar(2)), @TYPE_POST, 0, GetDate() )
		-- получаем код ID новой матрицы
		select @new_id_ver = max(ID_VER) from PL_VER where TYPE_GP = @TYPE_POST
		-- создаём заготовку для новой матрицы брендов на основе текущей
		if object_id(N'tempdb..#new_matrix') is not null drop table #new_matrix
		select * 
		into #new_matrix
		from PL_MATRIX pm 
		where pm.ID_VER = @P1
		-- заполняем новыми guid заготовку матрицы брендов
		declare fld_cur cursor for select ID_GP from #new_matrix
		declare @return_value int, @TmpId uniqueidentifier, @NewId uniqueidentifier
		-- перебор заготовки с присвоением нового guid и кода ID версии		
		open fld_cur	  
		fetch next from fld_cur into @TmpId
		while @@FETCH_STATUS = 0   
   			begin  
				exec @return_value = GET_GUID @NewId = @NewId output 
				update #new_matrix set ID_GP = @NewId, ID_VER = @new_id_ver where ID_GP = @TmpId			
				fetch next from fld_cur into @TmpId
  			end  
		close fld_cur 
		deallocate fld_cur
		-- ================================= преобразование заготовки матрицы брендов ======================================
		-- бренды, которые удалили в ЛиС и их нужно удалить из новой матрицы брендов 
		delete m
		from #new_matrix m 
		left join SP_GOOD_BRAND sgb on m.ID_GROUP = sgb.ID_GROUP and sgb.IS_IMPORT = (2 - @TYPE_POST)
		where sgb.ID_GROUP is null 
		-- бренды которые нужно добавить, их раньше не было
		if object_id(N'tempdb..#add_to_matrix') is not null drop table #add_to_matrix
		select NEWID() as ID_GP, sgb.ORDER_BY as POS_NUM, sgb.NAME_GROUP as POS_NAME, null as POS_FORMAT, @new_id_ver as ID_VER, sgb.ID_GROUP, null as POS_RETAILNET 
		into #add_to_matrix 
		from SP_GOOD_BRAND sgb 
		left join #new_matrix m on sgb.ID_GROUP = m.ID_GROUP
		where sgb.IS_IMPORT = (2 - @TYPE_POST) and m.ID_GROUP is null 
		order by sgb.ORDER_BY 
		-- нужно присвоить свои последовательные guid
		declare fld_cur3 cursor for select ID_GP from #add_to_matrix
		-- перебор заготовки с присвоением нового guid
		open fld_cur3	  
		fetch next from fld_cur3 into @TmpId
		while @@FETCH_STATUS = 0   
   			begin  
				exec @return_value = GET_GUID @NewId = @NewId output 
				update #add_to_matrix set ID_GP = @NewId where ID_GP = @TmpId			
				fetch next from fld_cur3 into @TmpId
  			end  
		close fld_cur3 
		deallocate fld_cur3
		-- само добавление новых брендов в матрицу брендов
		insert into #new_matrix 
		select * from #add_to_matrix
		-- бренды которые переименовали в ЛиС
		update m 
		set m.POS_NAME = sgb.NAME_GROUP, m.POS_CODE = m.POS_CODE
		from #new_matrix m 
		left join SP_GOOD_BRAND sgb on m.ID_GROUP = sgb.ID_GROUP and IS_IMPORT = (2 - @TYPE_POST)
		where sgb.NAME_GROUP <> m.POS_NAME 
		-- по всем ставим новые номера по порядку, исходя из группы бренда
		update m 
		set POS_NUM = gb.ORDER_BY, POS_CODE = m.POS_CODE
		from #new_matrix m
		left join SP_GOOD_BRAND gb on m.ID_GROUP=gb.ID_GROUP and gb.IS_IMPORT = (2 - @TYPE_POST)
		-- ========================= закончено преобразование заготовки матрицы брендов ====================================
		-- заготовка готова; из неё добавляем строки в саму матрицу брендов
		insert into PL_MATRIX ( ID_GP, POS_NUM, POS_CODE, POS_NAME,
								POS_FORMAT, ID_VER, ID_GROUP, POS_RETAILNET )
		select m.ID_GP, m.POS_NUM, m.POS_CODE, m.POS_NAME, 
			   m.POS_FORMAT, m.ID_VER, m.ID_GROUP, m.POS_RETAILNET
		from #new_matrix m
		-- создаём заготовку для новой матрицы планирования: все поля и ещё POS_NUM, для того, чтобы по нему подставить ID_GP
		if object_id(N'tempdb..#new_plan') is not null drop table #new_plan
		select pm.POS_NUM, pm.ID_GROUP, pp.* 
		into #new_plan
		from PL_PLAN pp
		left join PL_MATRIX pm on pp.ID_GP = pm.ID_GP
		left join PL_VER pv on pm.ID_VER = pv.ID_VER
		where pv.ID_VER = @P1
		-- заполняем новыми guid заготовку матрицы планирования, 
		declare fld_cur2 cursor for select ID_ROW from #new_plan
		-- перебор заготовки матрицы планирования с присвоением нового guid 	
		open fld_cur2	  
		fetch next from fld_cur2 into @TmpId
		while @@FETCH_STATUS = 0   
   			begin  
				exec @return_value = GET_GUID @NewId = @NewId output 
				update #new_plan set ID_ROW = @NewId where ID_ROW = @TmpId			
				fetch next from fld_cur2 into @TmpId
  			end  
		close fld_cur2 
		deallocate fld_cur2
		-- ========================= преобразование заготовки матрицы планирования =========================================
		-- бренды, которые удалили в ЛиС и их нужно удалить из новой матрицы планирования 
		declare @total_year numeric(18, 2)
		-- есть ли итоговые суммы по удаляемым брендам, если есть, их нужно перенести в "разное"
		select @total_year = sum(p.TOTAL_YEAR)
		from #new_plan p 
		left join #new_matrix m on p.ID_GP = m.ID_GP
		where m.ID_GP is null
		-- если есть игого за год по удаляемым, значит есть в каком-то месяце и все суммы придётся переносить
		if @total_year>0 
		  begin
			update p
			set p.M1=p.M1+t.M1, p.M2=p.M2+t.M2, p.M3=p.M3+t.M3, p.M4=p.M4+t.M4, p.M5=p.M5+t.M5, p.M6=p.M6+t.M6, 
				p.M7=p.M7+t.M7, p.M8=p.M8+t.M8, p.M9=p.M9+t.M9, p.M10=p.M10+t.M10, p.M11=p.M11+t.M11, p.M12=p.M12+t.M12, p.TOTAL_YEAR=p.TOTAL_YEAR+t.TOTAL_YEAR, p.CALC_PRICE=p.CALC_PRICE+t.CALC_PRICE
			from #new_plan p 
			left join ( select p.DEPART, p.AGENT, p.CUSTOMERS, sum(p.M1) as M1, sum(p.M2) as M2, sum(p.M3) as M3, sum(p.M4) as M4, sum(p.M5) as M5, sum(p.M6) as M6, 
						  sum(p.M7) as M7, sum(p.M8) as M8, sum(p.M9) as M9, sum(p.M10) as M10, sum(p.M11) as M11, sum(p.M12) as M12, sum(p.TOTAL_YEAR) as TOTAL_YEAR, max(p.CALC_PRICE) as CALC_PRICE
						from #new_plan p 
						left join #new_matrix m on p.ID_GROUP = m.ID_GROUP
						where m.ID_GROUP is null
						group by p.DEPART, p.AGENT, p.CUSTOMERS ) t on p.DEPART=t.DEPART and isNull(p.AGENT, 1)=IsNull(t.AGENT, 1) and IsNull(p.CUSTOMERS, 1)=IsNull(t.CUSTOMERS, 1)
			where p.POS_NUM = (select max(POS_NUM) from #new_plan)
		  end
		-- суммы перенесли, можно удалять из матрицы планирования
		delete p
		from #new_plan p 
		left join #new_matrix m on p.ID_GROUP = m.ID_GROUP
		where m.ID_GROUP is null
		-- бренды, которые нужно добавить; их раньше не было
		if object_id(N'tempdb..#add_to_plan') is not null drop table #add_to_plan
		select m.POS_NUM as POS_NUM, m.ID_GROUP as ID_GROUP, NEWID() as ID_ROW, m.ID_GP, a.DEPART, a.AGENT, a.CUSTOMERS, 0 as NUM_YEAR, p.M1, p.M2, p.M3, p.M4, p.M5, p.M6, p.M7, p.M8, p.M9, p.M10, p.M11, p.M12, p.TOTAL_YEAR, p.CALC_PRICE
		into #add_to_plan
		from #new_matrix m 
		left join #new_plan p on m.ID_GROUP = p.ID_GROUP
		left join PL_AFFIX a on 1=1
		where p.ID_GROUP is null
		-- нужно проставить год по новым брендам, а то он у нас 0
		update #add_to_plan set NUM_YEAR = (select top 1 NUM_YEAR from #new_plan) where NUM_YEAR = 0
		-- заполняем новыми guid заготовку матрицы планирования, 
		declare fld_cur4 cursor for select ID_ROW from #add_to_plan
		-- перебор заготовки по новым брендам с присвоением нового, последовательного guid 	
		open fld_cur4	  
		fetch next from fld_cur4 into @TmpId
		while @@FETCH_STATUS = 0   
   			begin  
				exec @return_value = GET_GUID @NewId = @NewId output 
				update #add_to_plan set ID_ROW = @NewId where ID_ROW = @TmpId			
				fetch next from fld_cur4 into @TmpId
  			end  
		close fld_cur4 
		deallocate fld_cur4
		-- теперь необходимо подставить новые номера по порядку
		update p
		set p.POS_NUM = m.POS_NUM
		from #new_plan p
		left join #new_matrix m on p.ID_GROUP = m.ID_GROUP
		-- нужно подставить guid-ы в матрице планирования на бренды, как в новой матрице планирования 
		update #new_plan 
		set #new_plan.ID_GP = m.ID_GP
		from #new_plan
		left join #new_matrix m on #new_plan.POS_NUM = m.POS_NUM
		where not m.ID_GP is null 
		-- заготовка с новыми брендами готова, добавляем в заготовку для новой матрицы планирования
		set @ren_str = 'insert into #new_plan select * from #add_to_plan'
		exec sp_executesql @ren_str		
		-- ======================= закончено преобразование заготовки матрицы планирования =================================
		-- теперь поле с порядковым номером больше не нужно и чтобы иметь заготовку схожую по составу полей с матрицей, удалим это поле
		set @ren_str = 'alter table #new_plan drop column POS_NUM'
		exec sp_executesql @ren_str
		-- аналогично с номером группы
		set @ren_str = 'alter table #new_plan drop column ID_GROUP'
		exec sp_executesql @ren_str
		-- заготовка готова; добавляем из неё в матрицу планирования
		set @ren_str = 'insert into PL_PLAN select * from #new_plan'
		exec sp_executesql @ren_str
		--делаем новую матрицу активной, а все старые, этого типа поставки - не активными, сохраняем первый ID матрицы планирования в таблице версий, чтобы легче искать, так как guid у нас упорядочены
		update PL_VER set IS_ACTIVE = 0 where TYPE_GP = @TYPE_POST
		update PL_VER set IS_ACTIVE = 1, FIRST_ID_ROW=(select top 1 ID_ROW from #new_plan order by ID_ROW) where ID_VER = @new_id_ver and TYPE_GP = @TYPE_POST
		--COMMIT;
		-- удаляем временные таблицы
		drop table #new_matrix
		drop table #new_plan
		drop table #add_to_matrix
		drop table #add_to_plan
		
	end
-- #################################################################################################################
-- создание направления делализации (формат параметра: "Департамент::Фирма")########################################
else if @ID=108
	begin		
		if dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT)='null'
			-- по агентам
			begin
				declare @agn_code nvarchar(10)
				-- агент "по-умолчанию" для департамента
				select top 1 @agn_code = sp.ID_PERS
				from SP_PERS sp
				join SP_REL_PERS_ACTIVE a on sp.ID_PERS = a.ID_PERS_AGENT
				left join N_SP_DEPART nsd on a.ID_PERS_MAN=nsd.ID_MANAGER
				where PROF = 'агн' and not sp.LAST_NAME + sp.FIRST_NAME + sp.MIDDLE_NAME is null and nsd.ID_DEPART = 2
				order by LAST_NAME				
				-- создание делализации по агентам
				insert into PL_LISTS
					(ID_DEPART, AGENTS)
				values
					(dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT), @agn_code)
			end
		else
			-- по покупателям
			begin								
				-- если уже есть по этому департаменту набор покупателей
				if exists (select top 1 * from PL_LISTS where ID_DEPART = cast(dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) as int) )
				  begin
				    -- добавление фирмы-покупателя к имеющимся 
					declare @x_108 as varchar(max), @id_firm_108 varchar(50)
					select top 1 @x_108 = cast(CUSTOMERSXML as varchar(max)) from PL_LISTS where ID_DEPART = cast( dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) as int)
					select top 1 @id_firm_108= IsNull(sf.ID_FIRM, '')  from SP_FIRM sf where sf.NAME_FIRM = dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT)
					-- дополненное значение
					set @x_108 = @x_108 + '<Row NAIM="' + dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT) + '" ID="' + @id_firm_108 + '" />'
					update PL_LISTS
					set
						CUSTOMERSXML=cast(@x_108 as xml)
					where PL_LISTS.ID_DEPART=cast( dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) as int)
				  end
				else
				  begin
					-- создание фирмы-покупателя
					declare @firm_name nvarchar(30)
				    set @firm_name = '<Row NAIM="' + dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT) + '" ID=" " />'
					insert into PL_LISTS
					  (ID_DEPART, CUSTOMERSXML)
					values
					  (dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT), cast(@firm_name as xml))
				  end
			end 
    end
-- #################################################################################################################
-- создание матрицы планирования (формат параметров, не все нужны: "Версия::Тип_поставки::Агент::Департамент::Покупатели::Тип_набора_данных::Год::Обновлять_факт::Логин")
else if @ID=109
	begin		
		if object_id(N'tempdb..#add_to_plan6') is not null drop table #add_to_plan6
		-- создание таблицы-заготовки; нельзя сразу в общую таблицу сливать - будут guid не последовательные
		select
			NEWID() as ID_ROW, m.ID_GP as ID_GP, 
			cast(dbo.GET_PARAM_FROM_LIST(@P1, 4, DEFAULT) as int) as DEPART, 
			case when dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT)='null' then null else cast(dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT) as int) end as AGENT, 
			case when dbo.GET_PARAM_FROM_LIST(@P1, 5, DEFAULT)='null' then null else dbo.GET_PARAM_FROM_LIST(@P1, 5, DEFAULT) end as CUSTOMERS,              
			cast(dbo.GET_PARAM_FROM_LIST(@P1, 7, DEFAULT) as int) as NUM_YEAR, 
			0 as M1, 0 as M2, 0 as M3, 0 as M4, 0 as M5, 0 as M6, 0 as M7, 0 as M8, 0 as M9, 0 as M10, 0 as M11, 0 as M12, 0 as TOTAL_YEAR, 0 as CALC_PRICE
		into #add_to_plan6 
		from PL_MATRIX m 
		where m.ID_VER=dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT)
		-- проставляем уникальные последовательные значения для guid, чтобы не нарушить "кучу" 
		declare fld_cur6 cursor for select ID_ROW from #add_to_plan6
		declare @return_value6 int, @TmpId6 uniqueidentifier, @NewId6 uniqueidentifier		
		open fld_cur6	  
		fetch next from fld_cur6 into @TmpId6
		while @@FETCH_STATUS = 0   
   			begin  
				exec @return_value6 = GET_GUID @NewId = @NewId6 output 
				update #add_to_plan6 set ID_ROW = @NewId6 where ID_ROW = @TmpId6			
				fetch next from fld_cur6 into @TmpId6
  			end  
		close fld_cur6 
		deallocate fld_cur6
		-- полученную матрицу-заготовку добавляем в таблицу со всеми матрицами планирования, так как поля совпадают
		insert into PL_PLAN
		select * from #add_to_plan6
		-- убираем временную таблицу-заготовку
		drop table #add_to_plan6
		-- создаём запись о матрице в списке матриц и доступов пользователей, 17.02.2020 добавлено Not exists                                                     - И НЕ ПРОВЕРЯЛОСЬ !!!
		if Not exists(select * from PL_AFFIX
					  where
						DEPART = cast(dbo.GET_PARAM_FROM_LIST(@P1, 4, DEFAULT) as int) and                                                                              
						IsNull(AGENT, '') = case when dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT)='null' then '' else cast(dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT) as int) end and
						IsNull(CUSTOMERS, '') = case when dbo.GET_PARAM_FROM_LIST(@P1, 5, DEFAULT)='null' then '' else dbo.GET_PARAM_FROM_LIST(@P1, 5, DEFAULT) end and              
						TYPE_GP = dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT) )
			insert into PL_AFFIX
			(
				DEPART,
				AGENT,
				CUSTOMERS,
				USERS_FOR_EDIT,	LAST_FACT_UPDATE, TYPE_GP, EDITABLE
			)
			values
			(
				cast(dbo.GET_PARAM_FROM_LIST(@P1, 4, DEFAULT) as int),                                                                              
				case when dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT)='null' then null else cast(dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT) as int) end, 
				case when dbo.GET_PARAM_FROM_LIST(@P1, 5, DEFAULT)='null' then null else dbo.GET_PARAM_FROM_LIST(@P1, 5, DEFAULT) end,              
				dbo.GET_PARAM_FROM_LIST(@P1, 11, DEFAULT), null, dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT), 1                                                                                              
		)		
    end
-- #################################################################################################################
-- запрет или разрешение на редактирование плана в настоящий момент  ###############################################
else if @ID=110
	begin		
		if @P1 is null
		  begin
			  if ( (select count(*) from PL_AFFIX where Not DEPART is Null) = (select count(*) from PL_AFFIX where EDITABLE=1 and Not DEPART is Null) )
				select 1 as 'EDIT_ALLOW'
			  else if ( (select count(*) from PL_AFFIX where Not DEPART is Null) = (select count(*) from PL_AFFIX where EDITABLE=0 and Not DEPART is Null) )
				begin
					if ( (select count(*) from PL_LOCKED_BRAND where LOCK=0) > 0)
						select 2 as 'EDIT_ALLOW'
					else
						select 0 as 'EDIT_ALLOW'
				end		
			  else
				select 2 as 'EDIT_ALLOW' -- частичное редактирование: кому-то открыто, куму-то нет
		  end
		else
		  begin
			declare @a int
			execute SET_GLOBAL_VAR 'EDIT_ALLOW', @P1,  '', @res=@a output 
			update PL_AFFIX set EDITABLE=cast(@P1 as int)
			select @a  -- если 1, то успешно изменено	
		  end
    end
-- #################################################################################################################
-- создание матриц на следующий год  ###############################################################################
else if @ID=111
	begin
		declare @tp int
		select @tp = TYPE_GP from PL_VER where ID_VER = @P1
		-- создание новой версии с этим типом поставки в реестре версий
		insert into PL_VER (VER, TYPE_GP, IS_ACTIVE, DATE_VER)
		values (@tp, cast(@tp as int), 0, GetDate() )
		-- получаем ID новой матрицы этого типа поставки
		declare @new_id_ver7 int
		select @new_id_ver7 = max(ID_VER) from PL_VER where TYPE_GP = cast(@tp as int)
		-- создаём заготовку для новой матрицы брендов на основе текущей
		if object_id(N'tempdb..#new_matrix7') is not null drop table #new_matrix7
		select pm.*, pm.ID_GP as 'ID_GP_OLD'
		into #new_matrix7
		from PL_MATRIX pm 
		where pm.ID_VER = @P1
		-- заполняем новыми guid заготовку матрицы брендов
		declare fld_cur7 cursor for select ID_GP from #new_matrix7
		declare @return_value7 int, @TmpId7 uniqueidentifier, @NewId7 uniqueidentifier
		-- перебор заготовки с присвоением нового guid и кода ID версии		
		open fld_cur7	  
		fetch next from fld_cur7 into @TmpId7
		while @@FETCH_STATUS = 0   
   			begin  
				exec @return_value7 = GET_GUID @NewId = @NewId7 output 
				update #new_matrix7 set ID_GP = @NewId7, ID_VER = @new_id_ver7 where ID_GP = @TmpId7			
				fetch next from fld_cur7 into @TmpId7
  			end  
		close fld_cur7 
		deallocate fld_cur7
		-- сохранение первой guid для новой версии 
		update PL_VER set FIRST_ID_ROW=(select top 1 ID_GP from #new_matrix7) where ID_VER = @new_id_ver7
		-- заготовку матрицы в матрицу брендов
		insert into PL_MATRIX (ID_GP, POS_NUM, POS_NAME, POS_FORMAT, ID_VER, ID_GROUP, POS_RETAILNET)
		select ID_GP, POS_NUM, POS_NAME, POS_FORMAT, ID_VER, ID_GROUP, POS_RETAILNET
		from #new_matrix7
		-- заготовка для новой матрицы планирования
		if object_id(N'tempdb..#tmp') is not null drop table #tmp
		select t.*
		into #tmp from
			(select p.* 
			from PL_PLAN p  
			left join PL_MATRIX m on p.ID_GP = m.ID_GP
			left join PL_VER v on m.ID_VER = v.ID_VER
			where v.ID_VER = @P1) t
		-- проставляем уникальные последовательные значения для guid, чтобы не нарушить "кучу" 
		declare fld_cur8 cursor for select ID_ROW from #tmp
		declare @return_value8 int, @TmpId8 uniqueidentifier, @NewId8 uniqueidentifier		
		open fld_cur8	  
		fetch next from fld_cur8 into @TmpId8
		while @@FETCH_STATUS = 0   
   			begin  
				exec @return_value8 = GET_GUID @NewId = @NewId8 output 
				update t  
				set t.ID_ROW = @NewId8, t.ID_GP = m.ID_GP 
				from #tmp t
				left join #new_matrix7 m on t.ID_GP = m.ID_GP_OLD
				where ID_ROW = @TmpId8			
				fetch next from fld_cur8 into @TmpId8
  			end  
		close fld_cur8 
		deallocate fld_cur8
		select * from #tmp
		-- чистим следующий год
		--delete from PL_PLAN where NUM_YEAR = DATEPART(YY, GetDate())+1
		-- добавляем в матрицу планирования на новый, следующий год 
		insert into PL_PLAN
		(   ID_ROW, ID_GP, DEPART, AGENT, CUSTOMERS,
			NUM_YEAR,
			M1, M2, M3, M4, M5, M6, M7, M8, M9, M10, M11, M12,
			TOTAL_YEAR,
			CALC_PRICE  )
		select ID_ROW, ID_GP, DEPART, AGENT, CUSTOMERS, 
			cast(DATEPART(YY, GetDate())+1 as int) as 'NUM_YEAR', 
			--0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -- если чистую матрицу хотим
			M1, M2, M3, M4, M5, M6, M7, M8, M9, M10, M11, M12, 
			TOTAL_YEAR, 
			CALC_PRICE 
		from #tmp
		-- временная таблица больше не нужна
		drop table #tmp
	end
-- #################################################################################################################
-- делаем активной матрицу #########################################################################################
else if @ID=112
	begin
		begin try
			begin tran;
				-- определим тип поставки матрицы
				declare @tgp int
				select top 1 @tgp=TYPE_GP from PL_VER v where ID_VER = cast(@P1 as int)
				-- сделаем  все матрицы данного типа поставки не активными
				update PL_VER set IS_ACTIVE = 0 where TYPE_GP = @tgp
				-- сделаем нужную матрицу активной
				update PL_VER set IS_ACTIVE = 1 where ID_VER = cast(@P1 as int)
				select 1 
			commit tran;
		end try
		begin catch
			rollback tran;
			select 0 
		end catch
	end
-- #################################################################################################################
-- переприсвоение порядковых номеров имп. брендов ##################################################################
else if @ID=113
	begin
		-- проверка, все ли артикулы бренда заполнены для импортного товара
		declare @c int
		select @c=count(*) 
		from SP_GOOD_BRAND 
		where IS_IMPORT=1 and CODE_GROUP is null 
		-- если все заполнены, то нужно перенумеровать порядковые номера, основываясь на сортировке по артикулу бренда
		if @c=0
		  begin
			-- заготовка с новыми порядковыми номерами
			if object_id(N'tempdb..#new_code') is not null drop table #new_code
			select ORDER_BY, CODE_GROUP, ROW_NUMBER() OVER (ORDER BY CODE_GROUP asc) AS NEW_ORDER_BY 
			into #new_code
			from SP_GOOD_BRAND
			where IS_IMPORT = 1 and not CODE_GROUP is null 
			order by CODE_GROUP
			-- проставляем новые порядковые номера
			update b 
			set
			  b.ORDER_BY = c.NEW_ORDER_BY 
			from SP_GOOD_BRAND b
			join #new_code c on b.CODE_GROUP = c.CODE_GROUP
			where b.IS_IMPORT = 1 and not c.NEW_ORDER_BY is null 
			-- временная больше не нужна
			drop table #new_code
		end
	end
-- #################################################################################################################
-- управление разрешением редактирования по департаментам ##########################################################
else if @ID=114
	begin
		if dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) is null
			update PL_AFFIX set EDITABLE=0 
		else
			update PL_AFFIX set EDITABLE=1 where DEPART=cast(dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) AS INT) and TYPE_GP=cast(dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT) AS INT)
	end
-- #################################################################################################################
-- сохранение формата ячейки "в плане" по guid строки ##############################################################
else if @ID=115
	begin
		declare @s_guid varchar(50), @guid_cnt int
		set @s_guid = replace(replace(dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT),'0x',''),'-','')
		set @s_guid = stuff(stuff(stuff(stuff(@s_guid,21,0,'-'),17,0,'-'),13,0,'-'),9,0,'-')		
		-- есть ли уже по такой строке что-то
		select @guid_cnt=count(*) from PL_NOTE where ID_ROW = cast(@s_guid as uniqueidentifier)		
		begin try
			if @guid_cnt>0
				update PL_NOTE set NOTE = cast(stuff(@P1, 1, charindex('::', @P1)+1, '') as xml) where ID_ROW = cast(@s_guid as uniqueidentifier)
			else
				insert into PL_NOTE (ID_ROW, NOTE) values (cast(@s_guid as uniqueidentifier), cast(stuff(@P1, 1, charindex('::', @P1)+1, '') as xml))
			select 1
		end try
		begin catch
			select 0 
		end catch
	end
-- #################################################################################################################
-- сохранение суммы "в плане" по guid строки если сумма не равна кол*цена (пример: '360F6381-20B9-E911-9C3D-AD89C1CB43D1::1::450')
else if @ID=116
	begin
		declare @s_guid_2 varchar(50), @guid_cnt_2 int
		set @s_guid_2 = replace(replace(dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT),'0x',''),'-','')
		set @s_guid_2 = stuff(stuff(stuff(stuff(@s_guid_2,21,0,'-'),17,0,'-'),13,0,'-'),9,0,'-')		
		select @guid_cnt_2=count(*) from PL_CH_AMOUNT where ID_ROW = cast(@s_guid_2 as uniqueidentifier)		
		declare @suq varchar(1000), @suq1 varchar(100), @suq2 varchar(100), @suq3 varchar(100)
		-- нужно вставить если нет и обновить если есть
		if @guid_cnt_2=0
			insert into PL_CH_AMOUNT (ID_ROW) values (cast(@s_guid_2 as uniqueidentifier))
		-- обновление суммы за нужный месяц
		select @suq1 = dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT), @suq2 = dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT), @suq3 = cast(@s_guid_2 as uniqueidentifier)
		set @suq = 'update PL_CH_AMOUNT set A' + @suq1 + ' = ' + @suq2 + ' where ID_ROW = cast(''' + @suq3 +''' as uniqueidentifier)'
		exec (@suq)	
	    -- итого за год по бренду с учётом коррекций сумм
		select isnull(a.A1, p.M1 * p.CALC_PRICE) + isnull(a.A2, p.M2 * p.CALC_PRICE) + isnull(a.A3, p.M3 * p.CALC_PRICE) + 
				isnull(a.A4, p.M4 * p.CALC_PRICE) + isnull(a.A5, p.M5 * p.CALC_PRICE) + isnull(a.A6, p.M6 * p.CALC_PRICE) + 
				isnull(a.A7, p.M7 * p.CALC_PRICE) + isnull(a.A8, p.M8 * p.CALC_PRICE) + isnull(a.A9, p.M9 * p.CALC_PRICE) + 
				isnull(a.A10, p.M10 * p.CALC_PRICE) + isnull(a.A11, p.M11 * p.CALC_PRICE) + isnull(a.A12, p.M12 * p.CALC_PRICE) as TOTAL_YEAR 		      
		from PL_PLAN p
		left join PL_CH_AMOUNT a on p.ID_ROW = a.ID_ROW  
		where p.ID_ROW = cast(@s_guid_2 as uniqueidentifier)
	end
-- #################################################################################################################
-- сохранение индивидуального запрета/разрешения редактирования "в плане" бренда по одному направлению или все департаменту  (пример: '350F6381-20B9-E911-9C3D-AD89C1CB43D1::1::1')
else if @ID=117
	begin
		declare @s_guid_3 varchar(50), @guid_cnt_3 int, @lock_val int, @lock_base int
		select @lock_val = cast(dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT) as int), @lock_base = cast(dbo.GET_PARAM_FROM_LIST(@P1, 3, DEFAULT) as int)
		-- приводим формат guid
		set @s_guid_3 = replace(replace(dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT),'0x',''),'-','')
		set @s_guid_3 = stuff(stuff(stuff(stuff(@s_guid_3,21,0,'-'),17,0,'-'),13,0,'-'),9,0,'-')	
		-- если нужно запретить/разрешить на весь департамент, то guid нужно подменить
		if @lock_base=1	
			select @s_guid_3 = ID_GP from PL_PLAN pp where pp.ID_ROW = cast(@s_guid_3 as uniqueidentifier)
		select @guid_cnt_3=count(*) from PL_LOCKED_BRAND where ID_ROW = cast(@s_guid_3 as uniqueidentifier)
		-- нужно вставить если нет и обновить если есть, или удалить
		begin try
			-- вставка
			if @guid_cnt_3=0
				insert into PL_LOCKED_BRAND (ID_ROW, LOCK) values (cast(@s_guid_3 as uniqueidentifier), @lock_val)
			-- обновление 
			else if @lock_val<>2  
				update PL_LOCKED_BRAND set LOCK = @lock_val where ID_ROW = cast(@s_guid_3 as uniqueidentifier)
			-- удаление 
			else if @lock_val=2  
				delete from PL_LOCKED_BRAND --where ID_ROW = cast(@s_guid_3 as uniqueidentifier)
			select 1
		end try
		begin catch
			select 0 
		end catch		
	end
-- #################################################################################################################
-- применение изменений в наименованиях брендов (формат параметров: "Версия::Тип_поставки", пример: '50::1') #######
else if @ID=118
	begin		
		update m
		set m.POS_NAME=sgb.NAME_GROUP
		from PL_MATRIX m 
		left join (select ID_GROUP, ORDER_BY, NAME_GROUP from CBTrade.dbo.SP_GOOD_BRAND where IS_IMPORT = cast(dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT) as int) ) sgb on m.ID_GROUP = sgb.ID_GROUP
		where sgb.NAME_GROUP <> m.POS_NAME and m.ID_VER = cast(dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) as int) 
	end
-- #################################################################################################################
-- применение добавлений брендов (формат параметров: "Версия::Тип_поставки", пример: '50::1') #######
else if @ID=119
	begin		
		declare @ID_VER_119 int, @TYPE_GP_119 int, @TYPE_GP_119b int, @TmpId_119 uniqueidentifier, @return_value_119 int, @NewId_119 uniqueidentifier
		select @ID_VER_119 = cast(dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) as int), @TYPE_GP_119 = cast(dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT) as int)

		if object_id(N'tempdb..#new_119') is not null drop table #new_119
		if object_id(N'tempdb..#plan_119') is not null drop table #plan_119

		-- создание заготовки для добавление в матрицу брендов 
		select newid() as ID_GP, sgb.ORDER_BY as POS_NUM, sgb.NAME_GROUP as POS_NAME, null as POS_FORMAT, @ID_VER_119 as ID_VER, sgb.ID_GROUP, null as POS_RETAILNET, sgb.CODE_GROUP as POS_CODE
		into #new_119
		from SP_GOOD_BRAND sgb 
		left join (select ID_GROUP from PL_MATRIX where ID_VER = @ID_VER_119) m on sgb.ID_GROUP = m.ID_GROUP
		where sgb.IS_IMPORT = @TYPE_GP_119 and m.ID_GROUP is null 
		-- перебор заготовки с присвоением нового guid
		declare fld_cur_119 cursor for select ID_GP from #new_119
		open fld_cur_119	  
		fetch next from fld_cur_119 into @TmpId_119
		while @@FETCH_STATUS = 0   
   			begin  
				exec @return_value_119 = GET_GUID @NewId = @NewId_119 output 
				update #new_119 set ID_GP = @NewId_119 where ID_GP = @TmpId_119			
				fetch next from fld_cur_119 into @TmpId_119
  			end  
		close fld_cur_119 
		deallocate fld_cur_119

		-- тип поставки в правильной кодировке
		if @TYPE_GP_119=0 set @TYPE_GP_119b=2 else set @TYPE_GP_119b = @TYPE_GP_119
		-- создание заготовки для добавление в матрицу планов 
		select newid() as ID_ROW, n.ID_GP, a.DEPART, a.AGENT, a.CUSTOMERS, y.NUM_YEAR as NUM_YEAR, 0 as M1, 0 as M2, 0 as M3, 0 as M4, 0 as M5, 0 as M6, 0 as M7, 0 as M8, 0 as M9, 0 as M10, 0 as M11, 0 as M12, 0 as TOTAL_YEAR, 0 as CALC_PRICE 
		into #plan_119
		from #new_119 n
		left join PL_AFFIX a on 1=1
		left join ( select max(pl.NUM_YEAR ) as NUM_YEAR
					from PL_MATRIX pm 
					join PL_PLAN pl on pl.ID_GP = pm.ID_GP
					where pm.ID_VER = @ID_VER_119 ) y on 1=1
		where TYPE_GP=@TYPE_GP_119b and Not DEPART is null
		order by y.NUM_YEAR, ID_GP, a.DEPART, a.AGENT, a.CUSTOMERS
		-- перебор заготовки с присвоением нового guid
		declare fld_cur_119b cursor for select ID_GP from #plan_119
		open fld_cur_119b	  
		fetch next from fld_cur_119b into @TmpId_119
		while @@FETCH_STATUS = 0   
   			begin  
				exec @return_value_119 = GET_GUID @NewId = @NewId_119 output 
				update #plan_119 set ID_ROW = @NewId_119 where ID_ROW = @TmpId_119			
				fetch next from fld_cur_119b into @TmpId_119
  			end  
		close fld_cur_119b 
		deallocate fld_cur_119b

		-- заготовки готовы - можно добавлять данные в таблицы хранения
		insert into PL_MATRIX 
		select * from #new_119
		insert into PL_PLAN 
		select * from #plan_119
		-- удаление временных таблиц
		drop table #new_119
		drop table #plan_119
	end
-- #################################################################################################################
-- применение удаления брендов с переносом планов (формат параметров: "Версия::Тип_поставки", пример: '50::1') #####
else if @ID=120
	begin		
		declare @ID_VER_120 int, @NUM_YEAR_120 int, @TYPE_GP_120 int
		select @ID_VER_120 = cast(dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) as int), @TYPE_GP_120 = cast(dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT) as int)
        -- какой год у матрицы ?
		select @NUM_YEAR_120 = max(pl.NUM_YEAR )
		from PL_MATRIX pm 
		join PL_PLAN pl on pl.ID_GP = pm.ID_GP
		where pm.ID_VER = @ID_VER_120 
		-- итоги по удалённым из плана перенесём в отдельную таблицу
		if object_id(N'tempdb..#del_120') is not null drop table #del_120
		select p.DEPART, p.AGENT, p.CUSTOMERS, p.NUM_YEAR, 
		  sum(M1) as M1, sum(M2) as M2, sum(M3) as M3, sum(M4) as M4, sum(M5) as M5, sum(M6) as M6, sum(M7) as M7, sum(M8) as M8, sum(M9) as M9, sum(M10) as M10, sum(M11) as M11, sum(M12) as M12, sum(TOTAL_YEAR) as TOTAL_YEAR 
		into #del_120
		from PL_PLAN p
		left join PL_MATRIX m on p.ID_GP = m.ID_GP
		left join PL_VER v on m.ID_VER = v.ID_VER
		where v.ID_VER = @ID_VER_120 and p.NUM_YEAR = @NUM_YEAR_120 and
		  m.POS_CODE Not in (select CODE_GROUP from SP_GOOD_BRAND where IS_IMPORT=1)
		group by  p.DEPART, p.AGENT, p.CUSTOMERS, p.NUM_YEAR
		-- в какую строку нужно добавить все суммы по удалённым? в строку с артикулом бренда 99.0001		
		-- обновление бренда 99.0001
		-- c 07.02.2020 отменён перенос сумм на 99.0001
		/*update p 
		set p.M1=p.M1+t.M1, p.M2=p.M2+t.M2, p.M3=p.M3+t.M3, p.M4=p.M4+t.M4, p.M5=p.M5+t.M5, p.M6=p.M6+t.M6, 
			p.M7=p.M7+t.M7, p.M8=p.M8+t.M8, p.M9=p.M9+t.M9, p.M10=p.M10+t.M10, p.M11=p.M11+t.M11, p.M12=p.M12+t.M12, p.TOTAL_YEAR=p.TOTAL_YEAR+t.TOTAL_YEAR
		from PL_PLAN p
		left join PL_MATRIX m on p.ID_GP = m.ID_GP
		left join PL_VER v on m.ID_VER = v.ID_VER
		left join #del_120 t on p.DEPART=t.DEPART and isNull(p.AGENT, 1)=IsNull(t.AGENT, 1) and IsNull(p.CUSTOMERS, 1)=IsNull(t.CUSTOMERS, 1)
		where v.ID_VER = @ID_VER_120 and p.NUM_YEAR = @NUM_YEAR_120 and
			m.POS_CODE = '99.0001'  */
		-- само удаление "удалённых из списка брендов" в матрице плана
		delete p
		from PL_PLAN p  
		left join PL_MATRIX m on p.ID_GP = m.ID_GP
		left join PL_VER v on m.ID_VER = v.ID_VER
		where v.ID_VER = @ID_VER_120 and p.NUM_YEAR = @NUM_YEAR_120 and
		  m.POS_CODE Not in (select CODE_GROUP from SP_GOOD_BRAND where IS_IMPORT=1)
		-- теперь можно уже удалить из матрицы брендов
		delete pm
		from PL_MATRIX pm
		where pm.ID_VER = @ID_VER_120 and pm.POS_CODE Not in (select CODE_GROUP from SP_GOOD_BRAND where IS_IMPORT=1)
		-- остаётся обновить факт, но лучше это сделать через интерфейс "Planning" или Job-ом, просто стираем факт
		delete from PL_FACT where NUM_YEAR = @NUM_YEAR_120
		-- удаление временных таблиц
		drop table #del_120
	end
-- #################################################################################################################
-- применение изменений в артикулах брендов (формат параметров: "Версия::Тип_поставки", пример: '50::1') ###########
else if @ID=121
	begin		
		update m
		set m.POS_CODE = sgb.CODE_GROUP
		from PL_MATRIX m 
		left join (select ID_GROUP, ORDER_BY, CODE_GROUP, NAME_GROUP from CBTrade.dbo.SP_GOOD_BRAND where IS_IMPORT = cast(dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT) as int) ) sgb on m.ID_GROUP = sgb.ID_GROUP
		where sgb.CODE_GROUP <> m.POS_CODE and m.ID_VER = cast(dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) as int) 
	end
-- #################################################################################################################
-- синхронизация номеров брендов как в "ЛиС" (формат параметров: "Версия::Тип_поставки", пример: '50::1') ##########
else if @ID=122
	begin		
		update m
		set m.POS_NUM = b.ORDER_BY
		from SP_GOOD_BRAND b
		left join PL_MATRIX m on b.ID_GROUP = m.ID_GROUP
		where b.IS_IMPORT=cast(dbo.GET_PARAM_FROM_LIST(@P1, 2, DEFAULT) as int) and m.ID_VER=cast(dbo.GET_PARAM_FROM_LIST(@P1, 1, DEFAULT) as int) and m.POS_NUM<>b.ORDER_BY 
	end
-- #################################################################################################################
-- инверсирование доступа по департаменту (формат параметров: "Наименование_департамента", пример: 'Регионы') ######
else if @ID=123	
	begin
		declare @editable123 int, @depart123 int		
		if exists (select top 1 ID_DEPART from PL_DEPART where NAME_AD_DEPART = @P1)
		    begin
			  select top 1 @editable123 = EDITABLE, @depart123 = DEPART from PL_AFFIX where TYPE_GP = 1 and DEPART = (select top 1 ID_DEPART from PL_DEPART where NAME_AD_DEPART = @P1)
			  update PL_AFFIX set EDITABLE = 1 - @editable123 where TYPE_GP = 1 and DEPART = @depart123
		      select 1 
			end
		else	
			select 2
	end
-- #################################################################################################################
-- #################################################################################################################




