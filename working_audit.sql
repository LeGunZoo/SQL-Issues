CREATE TRIGGER WORKING_AUDIT
ON DATABASE
    FOR 
  CREATE_TABLE, ALTER_TABLE, DROP_TABLE,
	CREATE_VIEW, ALTER_VIEW, DROP_VIEW,
	CREATE_FUNCTION, ALTER_FUNCTION, DROP_FUNCTION,
	CREATE_PROCEDURE, ALTER_PROCEDURE, DROP_PROCEDURE,
	CREATE_ASSEMBLY, ALTER_ASSEMBLY, DROP_ASSEMBLY,
	CREATE_INDEX, ALTER_INDEX, DROP_INDEX,
	CREATE_TRIGGER, ALTER_TRIGGER, DROP_TRIGGER,
	RENAME
AS
/*INTERNAL*/
  SET DATEFORMAT ymd;
     DECLARE
        @event xml; 
     SET
     @event = EVENTDATA();

     DECLARE @descriptions NVARCHAR(MAX),
             @TEXT_FOR_PARSING NVARCHAR(MAX),
             @OBJECT NVARCHAR(500),
             @OBJECT_NAME NVARCHAR(MAX),
             @COMMAND_TEXT NVARCHAR(MAX),
             @PRETTIFY_COMMAND_TEXT NVARCHAR(MAX)
      
      
     SET @OBJECT_NAME=
     CONVERT(nvarchar(150),
     @event.query('data(/EVENT_INSTANCE/ObjectName)'))
     
     SET @OBJECT = CONVERT(nvarchar(150),
     @event.query('data(/EVENT_INSTANCE/ObjectType)'))
     
     SET @COMMAND_TEXT = CONVERT(nvarchar(max),
     @event.query('data(/EVENT_INSTANCE/TSQLCommand/CommandText)'))

     IF @OBJECT = 'PROCEDURE' OR @OBJECT = 'TRIGGER'
     BEGIN
     SET @PRETTIFY_COMMAND_TEXT = REPLACE(@COMMAND_TEXT,'''','''''''')
     SET @TEXT_FOR_PARSING = SUBSTRING(@PRETTIFY_COMMAND_TEXT,PATINDEX('%/*%',@PRETTIFY_COMMAND_TEXT)+2,PATINDEX('%*/%',@PRETTIFY_COMMAND_TEXT)-(PATINDEX('%/*%',@PRETTIFY_COMMAND_TEXT)+2))
     END
     ELSE 
     SET @TEXT_FOR_PARSING = NULL

      SET @descriptions= CONVERT(NVARCHAR(max),(SELECT 
          s.value AS descr
          FROM 
              INFORMATION_SCHEMA.TABLES  i_s 
          LEFT OUTER JOIN 
              sys.extended_properties s 
          ON 
              s.major_id = OBJECT_ID(i_s.TABLE_SCHEMA+'.'+i_s.TABLE_NAME) 
              AND s.minor_id = 0
              AND s.name = 'MS_Description' 
          WHERE i_s.TABLE_NAME = CAST(@OBJECT_NAME AS SYSNAME)))  
       
     IF @OBJECT = 'TABLE' OR @OBJECT = 'VIEW'
      BEGIN
     INSERT INTO ADMSUP.AT_WORKING_PROCESS (WWP_PROJECT, WWP_NAME, WWP_OBJECT, WWP_CODE_TEXT)
       SELECT  T.value
              ,@OBJECT_NAME
              ,@OBJECT
              ,@COMMAND_TEXT
      FROM dbo.SplitString(@descriptions,char(13) + char(10)) AS T
      END
     
      IF @OBJECT = 'PROCEDURE' OR @OBJECT = 'TRIGGER'
      BEGIN
        INSERT INTO ADMSUP.AT_WORKING_PROCESS (WWP_PROJECT, WWP_NAME, WWP_OBJECT, WWP_CODE_TEXT)
        SELECT SS.Value
              ,@OBJECT_NAME
              ,@OBJECT
              ,@COMMAND_TEXT
          FROM dbo.SplitString(@TEXT_FOR_PARSING,char(13) + char(10)) ss
      END
GO
