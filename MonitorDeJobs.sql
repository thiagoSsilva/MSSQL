use master
go
-- =============================================
-- Author:		thiago_ssbh@hotmail.com
-- Create date: 2017-06-12
-- Description:	Esta consulta tem o objetivo de retornar os status de todas as jobs ativas em um servidor MSSQL.
--				A job/step deve aparecer apenas uma vez, e o status da ultima execução é exibido junto com a previsão da proxima execução.
-- =============================================
set dateformat ymd
SELECT
	TJob.job_id AS IDJob
   ,TJob.name AS NomeJob
   ,CASE TJob.[enabled]
		WHEN 1 THEN 'Sim'
		WHEN 0 THEN 'Não' END AS JobHabilitada
	,TStep.step_id
	,TStep.step_name
	,TSche.ProximaExecucao
	,isnull(emExecucao.start_execution_date,TUH.DataExec) as UltimaExecucao
	,CASE	when emExecucao.job_id is not null then 'Em execução'
			WHEN THist.run_status = 0 THEN 'Falha ao Executar'
			WHEN THist.run_status = 1 THEN 'Sucesso'
			WHEN THist.run_status = 2 THEN 'Tente Novamente'
			WHEN THist.run_status = 3 THEN 'Cancelado'
			WHEN THist.run_status = 4 THEN 'Em execução'
			else 'Não Identificado ('+cast(THist.run_status as varchar)+')' END [UE_Status]
	,THist.[message] as UE_Message
	,THist.run_duration as UE_Duracao
	--A coluna abaixo deve ser utilizada caso tenha consulta em vário servidores. Assim no relatório é possivel identificar o servidor.
	,'SERVER X' as SERVIDOR 

FROM msdb.dbo.sysjobs AS TJob WITH(NOLOCK)

left join msdb.dbo.sysjobsteps as TStep WITH(NOLOCK)
on TJob.job_id = TStep.job_id

left join	(
				select TSche.job_id
					,min(CAST(cast(TSche.next_run_date as varchar)
					+' '
					+ left(right('0'+CAST(TSche.next_run_time as varchar),6),2)+':'+left(RIGHT(TSche.next_run_time,4),2)+':'+RIGHT(TSche.next_run_time,2) AS DATETIME)) as ProximaExecucao
				from msdb.dbo.sysjobschedules as TSche with(nolock)

				where CAST(cast(TSche.next_run_date as varchar)
					+' '
					+ left(right('0'+CAST(TSche.next_run_time as varchar),6),2)+':'+left(RIGHT(TSche.next_run_time,4),2)+':'+RIGHT(TSche.next_run_time,2) AS DATETIME) >= getdate()
					AND TSche.next_run_date not in ('0')

				group by TSche.job_id
			)  as TSche
on  TJob.job_id = TSche.job_id

left join	(
				select job_id
					,step_id
					,MAX (
							CAST(cast(run_date as varchar)
						+' '
						+case when len(run_time)<=3 then '00:00:00'
						else left(right('0'+CAST(run_time as varchar),6),2)+':'+left(RIGHT(run_time,4),2)+':'+RIGHT(run_time,2) end AS DATETIME)
					) as DataExec     
				from msdb.dbo.sysjobhistory WITH(NOLOCK)
				group by job_id
					,step_id
			) as TUH
on TJob.job_id = TUH.job_id
and TStep.step_id = TUH.step_id
left join msdb.dbo.sysjobhistory as THist WITH(NOLOCK)
on TUH.job_id = THist.job_id
and TUH.step_id = THist.step_id
and TUH.DataExec = CAST(cast(THist.run_date as varchar) +' ' + case when len(THist.run_time)<=3 then '00:00:00' else left(right('0'+CAST(THist.run_time as varchar),6),2)+':'+left(RIGHT(THist.run_time,4),2)+':'+RIGHT(THist.run_time,2) end as DATEtime)

left join	(
				SELECT
				ja.job_id
				,ISNULL(last_executed_step_id,0)+1 AS step_id
				,ja.start_execution_date


				FROM msdb.dbo.sysjobactivity ja 

				WHERE ja.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions   ORDER BY agent_start_date DESC)
				AND start_execution_date is not null
				AND stop_execution_date is null
			) as emExecucao
on TJob.job_id = emExecucao.job_id
and TStep.step_id = emExecucao.step_id


where TJob.[enabled] = '1' --Filtra apenas jobs ativas.
AND Tjob.name not like '________-____-____-____-____________' --Remove jobs criadas com codigo pelo proprio SQL