-- =============================================
-- Author:		thiago_ssbh@hotmail.com
-- Create date: 15/10/2018
-- Description:	Esta consulta roda em loop dentro de uma database especifica.
--				Tenha cuidado com leitura de bases de dados grandes. Apesar da consulta utilizar "Nolock" ela pode afetar a perfomance da base.
--				Consulta testada no SQL 2008, 2014 e 2016.
--				A procedure sp_MSforeachtable só pode ser executada por usuários com permissões especiais conforme documentação Microsoft.
-- =============================================


/*Criar tabela temporaria para inserir os resultados de cada execução do sp_MSforeachtable*/
create table #Temp(Qtd int,Base varchar(150), Tabela varchar(5000))

/*O comando abaixo é executado uma vez para cada tabela. Se a database possui 10 tabelas el irá rodar 10 vezes*/
exec sp_MSforeachtable 'insert into #Temp select count(1) as Qtd, db_name() as Base ,''?'' as Tabela  from ? with(nolock)'

/*Gera resultado final*/
select
	linhas.Base
	,linhas.Tabela
	,linhas.Qtd as QtdLinhas
	,qtdColunas.QtdColunas
	,linhas.Qtd * qtdColunas.QtdColunas as QtdRegistros
from #Temp as linhas with(nolock)

left join	(
				SELECT 
					TABLE_CATALOG AS Base
					,'[' + TABLE_SCHEMA + '].[' + TABLE_NAME + ']' as Tabela
					,COUNT(COLUMN_NAME) as QtdColunas
				FROM INFORMATION_SCHEMA.COLUMNS 

				group by TABLE_CATALOG
						,TABLE_SCHEMA
						,TABLE_NAME
			) as qtdColunas
on linhas.Base = QtdColunas.Base
and linhas.Tabela = qtdColunas.Tabela

order by 5 desc

drop table #temp