USE [CBTrade]
GO
/****** Object:  StoredProcedure [dbo].[GET_PIVOT]    Script Date: 22.12.2020 13:52:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--============================================================================================================================================================= 
-- Author:		Tsvetkov Alexander
-- Create date: 05.02.2020
-- Description:	Процедура возвращает универсальный PIVOT по таблице
-- Test:        exec GET_PIVOT @tbl_name='SP_PERS', @row_name = 'LAST_NAME, FIRST_NAME', @col_name = 'ID_DEPART', @col_data = 'ID_PERS', @operation = 'Count', @order_name = 'LAST_NAME, FIRST_NAME desc'	
--              exec GET_PIVOT @tbl_name='#t1', @row_name = 'POS_CODE', @col_name = 'DEPART', @col_data = 'K1', @operation = 'sum', @order_name = 'POS_CODE'
--============================================================================================================================================================= 
ALTER procedure [dbo].[GET_PIVOT]
	@tbl_name sysname,               -- имя таблицы (если нет таблицы, то придётся создать временную)
	@row_name nvarchar(max),         -- имя поля, которое будет строками (если нужно по нескольким полям, то поля перечисляются через запятую)
	@col_name sysname,               -- имя поля, которое будет столбцами (значение в поле будет использовано как заголовки для столбцов)
	@col_data sysname,               -- имя поля по которому будут считаться итоги   
	@operation varchar(10),          -- имя операции (Sum, Min, Max, Count)
	@order_name nvarchar(max) = null,-- имя поля по которому необходимо отсортировать (опционально и если нужно по нескольким полям, то поля перечисляются через запятую, можно дописывать DESC)
	@order_col_asc int = null        -- имена столбцов в алфавитном порядке (null - значит да, 1 - не сортировать, 2 - в обратном алфивитном порядке столбцы представить)
as
	set nocount on 

declare @col_tbl table (FLD_NAMES nvarchar(max))
declare @cols nvarchar(max), @query nvarchar(max), @order_by nvarchar(20)

-- порядок сортировки столбцов
if @order_col_asc is null 
  set @order_by = ' order by 1'
else if @order_col_asc = 1  
  set @order_by = ''
else if @order_col_asc = 2
  set @order_by = ' order by 1 desc'
else
  set @order_by = ''

-- определаем список столбцов
set @query = 'create procedure #temp as declare @cols nvarchar(max); 
              select @cols = STUFF((select distinct '','' + QUOTENAME(' + @col_name +') 
									from ' + @tbl_name + @order_by + '									 
                                    for xml path(''''), TYPE).value(''.'', ''NVARCHAR(MAX)'') 
                             ,1,1,'''');
			  select @cols'

execute(@query)
-- для краткости кода, получим в таблицу с одной строкой
insert into @col_tbl
exec #temp
-- список столбцов через запятую получили
select top 1 @cols = FLD_NAMES from @col_tbl 
drop procedure #temp
-- формирование, собственно, универсального PIVOTа
set @query = 'SELECT ' + @row_name + ', ' + @cols + ' from 
              (
                select ' + @row_name + ', ' + @col_name + ', ' + @col_data + '
                from ' + @tbl_name + '
              ) x
              pivot 
              (
                ' + @operation + '(' + @col_data + ')
                for ' + @col_name + ' in (' + @cols + ')
              ) p '

if @order_name <> null set @query = @query + 'order by ' + @order_name

execute(@query)





