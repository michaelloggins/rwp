SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[RASCLIENTS](
	[ORIGREC] [int] IDENTITY(12,1) NOT NULL,
	[ADRESS] [nvarchar](255) NULL,
	[ADRESS_A] [nvarchar](255) NULL,
	[CATEGORY] [nvarchar](255) NULL,
	[CITY] [nvarchar](200) NULL,
	[COMPNAME] [varchar](255) NOT NULL,
	[COUNTRY] [nvarchar](80) NULL,
	[COUNTY] [nvarchar](50) NULL,
	[DEFAULTCONTACT] [nvarchar](20) NULL,
	[EXTERNALCLIENTID] [nvarchar](15) NULL,
	[HL7_ID] [nvarchar](50) NULL,
	[ORIGSTS] [nchar](1) NOT NULL,
	[POB] [nvarchar](8) NULL,
	[PRIMARYFAX] [nvarchar](100) NULL,
	[PRIMARYPHONE] [nvarchar](100) NULL,
	[RASCLIENTID] [nvarchar](30) NOT NULL,
	[STATE] [nvarchar](80) NULL,
	[UDPARAM0] [nvarchar](510) NULL,
	[UDPARAM1] [nvarchar](255) NULL,
	[UDPARAM2] [nvarchar](255) NULL,
	[UDPARAM3] [nvarchar](255) NULL,
	[UDPARAM4] [nvarchar](50) NULL,
	[URL] [nvarchar](50) NULL,
	[VMDPATH] [nvarchar](255) NULL,
	[ZIP] [nvarchar](15) NULL,
	[OWNER] [nvarchar](2) NULL,
	[EMAIL] [nvarchar](60) NULL,
	[ACCOUNT_NAME] [nvarchar](288) NULL,
	[DELINQUENT] [nchar](1) NOT NULL,
	[ORGANIZATIONAL_OID] [nvarchar](100) NULL,
	[APPLICATION_OID_PROD] [nvarchar](100) NULL,
	[DEV_INBOUND_RESULTS] [nvarchar](254) NULL,
	[DEV_OUTBOUND_ORDERS] [nvarchar](254) NULL,
	[DEV_OUTBOUND_RESULTS] [nvarchar](254) NULL,
	[DEV_INBOUND_ORDERS] [nvarchar](254) NULL,
	[APPLICATION_OID_DEV] [nvarchar](100) NULL,
	[PROD_INBOUND_ORDERS] [nvarchar](254) NULL,
	[PROD_INBOUND_RESULTS] [nvarchar](254) NULL,
	[PROD_OUTBOUND_ORDERS] [nvarchar](254) NULL,
	[PROD_OUTBOUND_RESULTS] [nvarchar](254) NULL,
	[HL7_CONTACT] [nvarchar](100) NULL,
	[HL7_CONTACT_PHONE] [nvarchar](100) NULL,
	[HL7_CONTACT_EMAIL] [nvarchar](100) NULL,
	[DEV_APPLICATION_NAME] [nvarchar](254) NULL,
	[PROD_APPLICATION_NAME] [nvarchar](254) NULL,
	[STATUS] [nvarchar](20) NULL,
	[START_DATE] [datetime] NULL,
	[PRICELISTID] [nvarchar](15) NULL,
	[JURISDICTION_TYPE] [nvarchar](10) NULL,
	[JURISDICTION_CODE] [nvarchar](10) NULL,
	[CLIENT_USAGE] [nvarchar](30) NOT NULL,
	[NETWORK_SHARED_PATH] [nvarchar](255) NULL,
	[SECONDARYPHONE] [nvarchar](100) NULL,
	[PHONEEXTENSION1] [nvarchar](15) NULL,
	[PHONEEXTENSION2] [nvarchar](15) NULL,
	[PAGERCELL] [nvarchar](15) NULL,
	[FAXCOUNTRYCODE] [nvarchar](4) NULL,
	[FAXAREACODE] [nvarchar](7) NULL,
	[FAXLOCALNUMBER] [nvarchar](15) NULL,
	[PHONECOUNTRYCODE] [nvarchar](4) NULL,
	[PHONEAREACODE] [nvarchar](7) NULL,
	[PHONELOCALNUMBER] [nvarchar](15) NULL,
	[LABDIRECTORDEGREE] [nvarchar](25) NULL,
	[IS_PRIMARY] [nchar](1) NULL,
	[DEPARTMENT] [nvarchar](510) NULL,
	[INTERFACE_ID] [nvarchar](50) NULL,
	[PANEL_PRELIMINARY] [nchar](1) NULL,
 CONSTRAINT [PK_RASCLIENTS] PRIMARY KEY CLUSTERED 
(
	[RASCLIENTID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[RASCLIENTS] ADD  CONSTRAINT [df_RASCLIENTS_ORIGSTS]  DEFAULT (N'N') FOR [ORIGSTS]
GO
ALTER TABLE [dbo].[RASCLIENTS] ADD  CONSTRAINT [df_RASCLIENTS_DELINQUENT]  DEFAULT (N'N') FOR [DELINQUENT]
GO
ALTER TABLE [dbo].[RASCLIENTS] ADD  CONSTRAINT [df_RASCLIENTS_STATUS]  DEFAULT (N'Active') FOR [STATUS]
GO
ALTER TABLE [dbo].[RASCLIENTS] ADD  CONSTRAINT [df_RASCLIENTS_CLIENT_USAGE]  DEFAULT (N'Both') FOR [CLIENT_USAGE]
GO
ALTER TABLE [dbo].[RASCLIENTS] ADD  CONSTRAINT [df_RASCLIENTS_IS_PRIMARY]  DEFAULT (N'N') FOR [IS_PRIMARY]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TRIGGER [dbo].[AUDIT_26_DEL_TRG] 
ON [dbo].[RASCLIENTS] 
AFTER DELETE
AS
BEGIN 

	DECLARE 
		@tmpId int,
		@tmpAction VARCHAR(6),
		@tmpOrigrec int,
		@sXML varchar(8000)

    if dbo.IsExternalSession(GETDATE()) > 0 
	begin
	
		set @tmpId = @@SPID
		
		if @@rowcount = 0
			return
			
		set nocount on
		
		if exists(select * from deleted)

        insert into AUDITTRL (ORIGINAL_ORIGREC, DB_USER, APP_NAME, APP_USERNAME,
								AUDIT_DT, AUDIT_DT_OFFSET, DB_SID,
								TABLENAME, EVENT_TYPE, EVENTCODE, ROW_DATA) 
        select ORIGREC, SYSTEM_USER,  N'SQLSERVER', SYSTEM_USER,
			GetDate(), DATEDIFF(hh, GetUtcDate(), GetDate()) * 60, @tmpId,
			 N'RASCLIENTS',  N'Delete',  N'N/A',          N'<?xml version = ''1.0''?>' + CHAR(13) + CHAR(10)
        +  N'<ROWSET>' + CHAR(13) + CHAR(10)
        +  N' <ROW>' + CHAR(13) + CHAR(10)
        +  N'  <ACCOUNT_NAME>' + dbo.EscapeXML(n."ACCOUNT_NAME") +  N'</ACCOUNT_NAME>' + CHAR(13) + CHAR(10)
        +  N'  <ADRESS>' + dbo.EscapeXML(n."ADRESS") +  N'</ADRESS>' + CHAR(13) + CHAR(10)
        +  N'  <ADRESS_A>' + dbo.EscapeXML(n."ADRESS_A") +  N'</ADRESS_A>' + CHAR(13) + CHAR(10)
        +  N'  <APPLICATION_OID_DEV>' + dbo.EscapeXML(n."APPLICATION_OID_DEV") +  N'</APPLICATION_OID_DEV>' + CHAR(13) + CHAR(10)
        +  N'  <APPLICATION_OID_PROD>' + dbo.EscapeXML(n."APPLICATION_OID_PROD") +  N'</APPLICATION_OID_PROD>' + CHAR(13) + CHAR(10)
        +  N'  <CATEGORY>' + dbo.EscapeXML(n."CATEGORY") +  N'</CATEGORY>' + CHAR(13) + CHAR(10)
        +  N'  <CITY>' + dbo.EscapeXML(n."CITY") +  N'</CITY>' + CHAR(13) + CHAR(10)
        +  N'  <CLIENT_USAGE>' + dbo.EscapeXML(n."CLIENT_USAGE") +  N'</CLIENT_USAGE>' + CHAR(13) + CHAR(10)
        +  N'  <COMPNAME>' + dbo.EscapeXML(n."COMPNAME") +  N'</COMPNAME>' + CHAR(13) + CHAR(10)
        +  N'  <COUNTRY>' + dbo.EscapeXML(n."COUNTRY") +  N'</COUNTRY>' + CHAR(13) + CHAR(10)
        +  N'  <COUNTY>' + dbo.EscapeXML(n."COUNTY") +  N'</COUNTY>' + CHAR(13) + CHAR(10)
        +  N'  <DEFAULTCONTACT>' + dbo.EscapeXML(n."DEFAULTCONTACT") +  N'</DEFAULTCONTACT>' + CHAR(13) + CHAR(10)
        +  N'  <DELINQUENT>' + dbo.EscapeXML(n."DELINQUENT") +  N'</DELINQUENT>' + CHAR(13) + CHAR(10)
        +  N'  <DEPARTMENT>' + dbo.EscapeXML(n."DEPARTMENT") +  N'</DEPARTMENT>' + CHAR(13) + CHAR(10)
        +  N'  <DEV_APPLICATION_NAME>' + dbo.EscapeXML(n."DEV_APPLICATION_NAME") +  N'</DEV_APPLICATION_NAME>' + CHAR(13) + CHAR(10)
        +  N'  <DEV_INBOUND_ORDERS>' + dbo.EscapeXML(n."DEV_INBOUND_ORDERS") +  N'</DEV_INBOUND_ORDERS>' + CHAR(13) + CHAR(10)
        +  N'  <DEV_INBOUND_RESULTS>' + dbo.EscapeXML(n."DEV_INBOUND_RESULTS") +  N'</DEV_INBOUND_RESULTS>' + CHAR(13) + CHAR(10)
        +  N'  <DEV_OUTBOUND_ORDERS>' + dbo.EscapeXML(n."DEV_OUTBOUND_ORDERS") +  N'</DEV_OUTBOUND_ORDERS>' + CHAR(13) + CHAR(10)
        +  N'  <DEV_OUTBOUND_RESULTS>' + dbo.EscapeXML(n."DEV_OUTBOUND_RESULTS") +  N'</DEV_OUTBOUND_RESULTS>' + CHAR(13) + CHAR(10)
        +  N'  <EMAIL>' + dbo.EscapeXML(n."EMAIL") +  N'</EMAIL>' + CHAR(13) + CHAR(10)
        +  N'  <EXTERNALCLIENTID>' + dbo.EscapeXML(n."EXTERNALCLIENTID") +  N'</EXTERNALCLIENTID>' + CHAR(13) + CHAR(10)
        +  N'  <FAXAREACODE>' + dbo.EscapeXML(n."FAXAREACODE") +  N'</FAXAREACODE>' + CHAR(13) + CHAR(10)
        +  N'  <FAXCOUNTRYCODE>' + dbo.EscapeXML(n."FAXCOUNTRYCODE") +  N'</FAXCOUNTRYCODE>' + CHAR(13) + CHAR(10)
        +  N'  <FAXLOCALNUMBER>' + dbo.EscapeXML(n."FAXLOCALNUMBER") +  N'</FAXLOCALNUMBER>' + CHAR(13) + CHAR(10)
        +  N'  <HL7_CONTACT>' + dbo.EscapeXML(n."HL7_CONTACT") +  N'</HL7_CONTACT>' + CHAR(13) + CHAR(10)
        +  N'  <HL7_CONTACT_EMAIL>' + dbo.EscapeXML(n."HL7_CONTACT_EMAIL") +  N'</HL7_CONTACT_EMAIL>' + CHAR(13) + CHAR(10)
        +  N'  <HL7_CONTACT_PHONE>' + dbo.EscapeXML(n."HL7_CONTACT_PHONE") +  N'</HL7_CONTACT_PHONE>' + CHAR(13) + CHAR(10)
        +  N'  <HL7_ID>' + dbo.EscapeXML(n."HL7_ID") +  N'</HL7_ID>' + CHAR(13) + CHAR(10)
        +  N'  <INTERFACE_ID>' + dbo.EscapeXML(n."INTERFACE_ID") +  N'</INTERFACE_ID>' + CHAR(13) + CHAR(10)
        +  N'  <IS_PRIMARY>' + dbo.EscapeXML(n."IS_PRIMARY") +  N'</IS_PRIMARY>' + CHAR(13) + CHAR(10)
        +  N'  <JURISDICTION_CODE>' + dbo.EscapeXML(n."JURISDICTION_CODE") +  N'</JURISDICTION_CODE>' + CHAR(13) + CHAR(10)
        +  N'  <JURISDICTION_TYPE>' + dbo.EscapeXML(n."JURISDICTION_TYPE") +  N'</JURISDICTION_TYPE>' + CHAR(13) + CHAR(10)
        +  N'  <LABDIRECTORDEGREE>' + dbo.EscapeXML(n."LABDIRECTORDEGREE") +  N'</LABDIRECTORDEGREE>' + CHAR(13) + CHAR(10)
        +  N'  <NETWORK_SHARED_PATH>' + dbo.EscapeXML(n."NETWORK_SHARED_PATH") +  N'</NETWORK_SHARED_PATH>' + CHAR(13) + CHAR(10)
        +  N'  <ORGANIZATIONAL_OID>' + dbo.EscapeXML(n."ORGANIZATIONAL_OID") +  N'</ORGANIZATIONAL_OID>' + CHAR(13) + CHAR(10)
        +  N'  <ORIGREC>' + dbo.EscapeXML(n."ORIGREC") +  N'</ORIGREC>' + CHAR(13) + CHAR(10)
        +  N'  <ORIGSTS>' + dbo.EscapeXML(n."ORIGSTS") +  N'</ORIGSTS>' + CHAR(13) + CHAR(10)
        +  N'  <OWNER>' + dbo.EscapeXML(n."OWNER") +  N'</OWNER>' + CHAR(13) + CHAR(10)
        +  N'  <PAGERCELL>' + dbo.EscapeXML(n."PAGERCELL") +  N'</PAGERCELL>' + CHAR(13) + CHAR(10)
        +  N'  <PANEL_PRELIMINARY>' + dbo.EscapeXML(n."PANEL_PRELIMINARY") +  N'</PANEL_PRELIMINARY>' + CHAR(13) + CHAR(10)
        +  N'  <PHONEAREACODE>' + dbo.EscapeXML(n."PHONEAREACODE") +  N'</PHONEAREACODE>' + CHAR(13) + CHAR(10)
        +  N'  <PHONECOUNTRYCODE>' + dbo.EscapeXML(n."PHONECOUNTRYCODE") +  N'</PHONECOUNTRYCODE>' + CHAR(13) + CHAR(10)
        +  N'  <PHONEEXTENSION1>' + dbo.EscapeXML(n."PHONEEXTENSION1") +  N'</PHONEEXTENSION1>' + CHAR(13) + CHAR(10)
        +  N'  <PHONEEXTENSION2>' + dbo.EscapeXML(n."PHONEEXTENSION2") +  N'</PHONEEXTENSION2>' + CHAR(13) + CHAR(10)
        +  N'  <PHONELOCALNUMBER>' + dbo.EscapeXML(n."PHONELOCALNUMBER") +  N'</PHONELOCALNUMBER>' + CHAR(13) + CHAR(10)
        +  N'  <POB>' + dbo.EscapeXML(n."POB") +  N'</POB>' + CHAR(13) + CHAR(10)
        +  N'  <PRICELISTID>' + dbo.EscapeXML(n."PRICELISTID") +  N'</PRICELISTID>' + CHAR(13) + CHAR(10)
        +  N'  <PRIMARYFAX>' + dbo.EscapeXML(n."PRIMARYFAX") +  N'</PRIMARYFAX>' + CHAR(13) + CHAR(10)
        +  N'  <PRIMARYPHONE>' + dbo.EscapeXML(n."PRIMARYPHONE") +  N'</PRIMARYPHONE>' + CHAR(13) + CHAR(10)
        +  N'  <PROD_APPLICATION_NAME>' + dbo.EscapeXML(n."PROD_APPLICATION_NAME") +  N'</PROD_APPLICATION_NAME>' + CHAR(13) + CHAR(10)
        +  N'  <PROD_INBOUND_ORDERS>' + dbo.EscapeXML(n."PROD_INBOUND_ORDERS") +  N'</PROD_INBOUND_ORDERS>' + CHAR(13) + CHAR(10)
        +  N'  <PROD_INBOUND_RESULTS>' + dbo.EscapeXML(n."PROD_INBOUND_RESULTS") +  N'</PROD_INBOUND_RESULTS>' + CHAR(13) + CHAR(10)
        +  N'  <PROD_OUTBOUND_ORDERS>' + dbo.EscapeXML(n."PROD_OUTBOUND_ORDERS") +  N'</PROD_OUTBOUND_ORDERS>' + CHAR(13) + CHAR(10)
        +  N'  <PROD_OUTBOUND_RESULTS>' + dbo.EscapeXML(n."PROD_OUTBOUND_RESULTS") +  N'</PROD_OUTBOUND_RESULTS>' + CHAR(13) + CHAR(10)
        +  N'  <RASCLIENTID>' + dbo.EscapeXML(n."RASCLIENTID") +  N'</RASCLIENTID>' + CHAR(13) + CHAR(10)
        +  N'  <SECONDARYPHONE>' + dbo.EscapeXML(n."SECONDARYPHONE") +  N'</SECONDARYPHONE>' + CHAR(13) + CHAR(10)
        +  N'  <START_DATE>' + dbo.EscapeXML((case when n."START_DATE" is null then  N''
							else 
								convert(varchar(50), n."START_DATE", 121) + convert(varchar(50), DATEDIFF(hh, GetUtcDate(), GetDate())) +	 N':00'
						end)) +  N'</START_DATE>' + CHAR(13) + CHAR(10)
        +  N'  <STATE>' + dbo.EscapeXML(n."STATE") +  N'</STATE>' + CHAR(13) + CHAR(10)
        +  N'  <STATUS>' + dbo.EscapeXML(n."STATUS") +  N'</STATUS>' + CHAR(13) + CHAR(10)
        +  N'  <UDPARAM0>' + dbo.EscapeXML(n."UDPARAM0") +  N'</UDPARAM0>' + CHAR(13) + CHAR(10)
        +  N'  <UDPARAM1>' + dbo.EscapeXML(n."UDPARAM1") +  N'</UDPARAM1>' + CHAR(13) + CHAR(10)
        +  N'  <UDPARAM2>' + dbo.EscapeXML(n."UDPARAM2") +  N'</UDPARAM2>' + CHAR(13) + CHAR(10)
        +  N'  <UDPARAM3>' + dbo.EscapeXML(n."UDPARAM3") +  N'</UDPARAM3>' + CHAR(13) + CHAR(10)
        +  N'  <UDPARAM4>' + dbo.EscapeXML(n."UDPARAM4") +  N'</UDPARAM4>' + CHAR(13) + CHAR(10)
        +  N'  <URL>' + dbo.EscapeXML(n."URL") +  N'</URL>' + CHAR(13) + CHAR(10)
        +  N'  <VMDPATH>' + dbo.EscapeXML(n."VMDPATH") +  N'</VMDPATH>' + CHAR(13) + CHAR(10)
        +  N'  <ZIP>' + dbo.EscapeXML(n."ZIP") +  N'</ZIP>' + CHAR(13) + CHAR(10)
        +  N' </ROW>' + CHAR(13) + CHAR(10)
        +  N'</ROWSET>' + CHAR(13) + CHAR(10)
 as ROW_DATA
		from deleted n
 
 
       end
 
END
GO
ALTER TABLE [dbo].[RASCLIENTS] ENABLE TRIGGER [AUDIT_26_DEL_TRG]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TRIGGER [dbo].[AUDIT_26_INS_TRG] 
ON [dbo].[RASCLIENTS] 
AFTER INSERT
AS
BEGIN 

	DECLARE 
		@tmpId int,
		@tmpAction VARCHAR(6),
		@tmpOrigrec int,
		@sXML varchar(8000)

    if dbo.IsExternalSession(GETDATE()) > 0 
	begin
	
		set @tmpId = @@SPID
		
		if @@rowcount = 0
			return
			
		set nocount on
		
		if exists(select * from inserted)

        insert into AUDITTRL (ORIGINAL_ORIGREC, DB_USER, APP_NAME, APP_USERNAME,
								AUDIT_DT, AUDIT_DT_OFFSET, DB_SID,
								TABLENAME, EVENT_TYPE, EVENTCODE, ROW_DATA) 
        select ORIGREC, SYSTEM_USER,  N'SQLSERVER', SYSTEM_USER,
			GetDate(), DATEDIFF(hh, GetUtcDate(), GetDate()) * 60, @tmpId,
			 N'RASCLIENTS',  N'Create',  N'N/A',          N'<?xml version = ''1.0''?>' + CHAR(13) + CHAR(10)
        +  N'<ROWSET>' + CHAR(13) + CHAR(10)
        +  N' <ROW>' + CHAR(13) + CHAR(10)
        +  N'  <ACCOUNT_NAME>' + dbo.EscapeXML(n."ACCOUNT_NAME") +  N'</ACCOUNT_NAME>' + CHAR(13) + CHAR(10)
        +  N'  <ADRESS>' + dbo.EscapeXML(n."ADRESS") +  N'</ADRESS>' + CHAR(13) + CHAR(10)
        +  N'  <ADRESS_A>' + dbo.EscapeXML(n."ADRESS_A") +  N'</ADRESS_A>' + CHAR(13) + CHAR(10)
        +  N'  <APPLICATION_OID_DEV>' + dbo.EscapeXML(n."APPLICATION_OID_DEV") +  N'</APPLICATION_OID_DEV>' + CHAR(13) + CHAR(10)
        +  N'  <APPLICATION_OID_PROD>' + dbo.EscapeXML(n."APPLICATION_OID_PROD") +  N'</APPLICATION_OID_PROD>' + CHAR(13) + CHAR(10)
        +  N'  <CATEGORY>' + dbo.EscapeXML(n."CATEGORY") +  N'</CATEGORY>' + CHAR(13) + CHAR(10)
        +  N'  <CITY>' + dbo.EscapeXML(n."CITY") +  N'</CITY>' + CHAR(13) + CHAR(10)
        +  N'  <CLIENT_USAGE>' + dbo.EscapeXML(n."CLIENT_USAGE") +  N'</CLIENT_USAGE>' + CHAR(13) + CHAR(10)
        +  N'  <COMPNAME>' + dbo.EscapeXML(n."COMPNAME") +  N'</COMPNAME>' + CHAR(13) + CHAR(10)
        +  N'  <COUNTRY>' + dbo.EscapeXML(n."COUNTRY") +  N'</COUNTRY>' + CHAR(13) + CHAR(10)
        +  N'  <COUNTY>' + dbo.EscapeXML(n."COUNTY") +  N'</COUNTY>' + CHAR(13) + CHAR(10)
        +  N'  <DEFAULTCONTACT>' + dbo.EscapeXML(n."DEFAULTCONTACT") +  N'</DEFAULTCONTACT>' + CHAR(13) + CHAR(10)
        +  N'  <DELINQUENT>' + dbo.EscapeXML(n."DELINQUENT") +  N'</DELINQUENT>' + CHAR(13) + CHAR(10)
        +  N'  <DEPARTMENT>' + dbo.EscapeXML(n."DEPARTMENT") +  N'</DEPARTMENT>' + CHAR(13) + CHAR(10)
        +  N'  <DEV_APPLICATION_NAME>' + dbo.EscapeXML(n."DEV_APPLICATION_NAME") +  N'</DEV_APPLICATION_NAME>' + CHAR(13) + CHAR(10)
        +  N'  <DEV_INBOUND_ORDERS>' + dbo.EscapeXML(n."DEV_INBOUND_ORDERS") +  N'</DEV_INBOUND_ORDERS>' + CHAR(13) + CHAR(10)
        +  N'  <DEV_INBOUND_RESULTS>' + dbo.EscapeXML(n."DEV_INBOUND_RESULTS") +  N'</DEV_INBOUND_RESULTS>' + CHAR(13) + CHAR(10)
        +  N'  <DEV_OUTBOUND_ORDERS>' + dbo.EscapeXML(n."DEV_OUTBOUND_ORDERS") +  N'</DEV_OUTBOUND_ORDERS>' + CHAR(13) + CHAR(10)
        +  N'  <DEV_OUTBOUND_RESULTS>' + dbo.EscapeXML(n."DEV_OUTBOUND_RESULTS") +  N'</DEV_OUTBOUND_RESULTS>' + CHAR(13) + CHAR(10)
        +  N'  <EMAIL>' + dbo.EscapeXML(n."EMAIL") +  N'</EMAIL>' + CHAR(13) + CHAR(10)
        +  N'  <EXTERNALCLIENTID>' + dbo.EscapeXML(n."EXTERNALCLIENTID") +  N'</EXTERNALCLIENTID>' + CHAR(13) + CHAR(10)
        +  N'  <FAXAREACODE>' + dbo.EscapeXML(n."FAXAREACODE") +  N'</FAXAREACODE>' + CHAR(13) + CHAR(10)
        +  N'  <FAXCOUNTRYCODE>' + dbo.EscapeXML(n."FAXCOUNTRYCODE") +  N'</FAXCOUNTRYCODE>' + CHAR(13) + CHAR(10)
        +  N'  <FAXLOCALNUMBER>' + dbo.EscapeXML(n."FAXLOCALNUMBER") +  N'</FAXLOCALNUMBER>' + CHAR(13) + CHAR(10)
        +  N'  <HL7_CONTACT>' + dbo.EscapeXML(n."HL7_CONTACT") +  N'</HL7_CONTACT>' + CHAR(13) + CHAR(10)
        +  N'  <HL7_CONTACT_EMAIL>' + dbo.EscapeXML(n."HL7_CONTACT_EMAIL") +  N'</HL7_CONTACT_EMAIL>' + CHAR(13) + CHAR(10)
        +  N'  <HL7_CONTACT_PHONE>' + dbo.EscapeXML(n."HL7_CONTACT_PHONE") +  N'</HL7_CONTACT_PHONE>' + CHAR(13) + CHAR(10)
        +  N'  <HL7_ID>' + dbo.EscapeXML(n."HL7_ID") +  N'</HL7_ID>' + CHAR(13) + CHAR(10)
        +  N'  <INTERFACE_ID>' + dbo.EscapeXML(n."INTERFACE_ID") +  N'</INTERFACE_ID>' + CHAR(13) + CHAR(10)
        +  N'  <IS_PRIMARY>' + dbo.EscapeXML(n."IS_PRIMARY") +  N'</IS_PRIMARY>' + CHAR(13) + CHAR(10)
        +  N'  <JURISDICTION_CODE>' + dbo.EscapeXML(n."JURISDICTION_CODE") +  N'</JURISDICTION_CODE>' + CHAR(13) + CHAR(10)
        +  N'  <JURISDICTION_TYPE>' + dbo.EscapeXML(n."JURISDICTION_TYPE") +  N'</JURISDICTION_TYPE>' + CHAR(13) + CHAR(10)
        +  N'  <LABDIRECTORDEGREE>' + dbo.EscapeXML(n."LABDIRECTORDEGREE") +  N'</LABDIRECTORDEGREE>' + CHAR(13) + CHAR(10)
        +  N'  <NETWORK_SHARED_PATH>' + dbo.EscapeXML(n."NETWORK_SHARED_PATH") +  N'</NETWORK_SHARED_PATH>' + CHAR(13) + CHAR(10)
        +  N'  <ORGANIZATIONAL_OID>' + dbo.EscapeXML(n."ORGANIZATIONAL_OID") +  N'</ORGANIZATIONAL_OID>' + CHAR(13) + CHAR(10)
        +  N'  <ORIGREC>' + dbo.EscapeXML(n."ORIGREC") +  N'</ORIGREC>' + CHAR(13) + CHAR(10)
        +  N'  <ORIGSTS>' + dbo.EscapeXML(n."ORIGSTS") +  N'</ORIGSTS>' + CHAR(13) + CHAR(10)
        +  N'  <OWNER>' + dbo.EscapeXML(n."OWNER") +  N'</OWNER>' + CHAR(13) + CHAR(10)
        +  N'  <PAGERCELL>' + dbo.EscapeXML(n."PAGERCELL") +  N'</PAGERCELL>' + CHAR(13) + CHAR(10)
        +  N'  <PANEL_PRELIMINARY>' + dbo.EscapeXML(n."PANEL_PRELIMINARY") +  N'</PANEL_PRELIMINARY>' + CHAR(13) + CHAR(10)
        +  N'  <PHONEAREACODE>' + dbo.EscapeXML(n."PHONEAREACODE") +  N'</PHONEAREACODE>' + CHAR(13) + CHAR(10)
        +  N'  <PHONECOUNTRYCODE>' + dbo.EscapeXML(n."PHONECOUNTRYCODE") +  N'</PHONECOUNTRYCODE>' + CHAR(13) + CHAR(10)
        +  N'  <PHONEEXTENSION1>' + dbo.EscapeXML(n."PHONEEXTENSION1") +  N'</PHONEEXTENSION1>' + CHAR(13) + CHAR(10)
        +  N'  <PHONEEXTENSION2>' + dbo.EscapeXML(n."PHONEEXTENSION2") +  N'</PHONEEXTENSION2>' + CHAR(13) + CHAR(10)
        +  N'  <PHONELOCALNUMBER>' + dbo.EscapeXML(n."PHONELOCALNUMBER") +  N'</PHONELOCALNUMBER>' + CHAR(13) + CHAR(10)
        +  N'  <POB>' + dbo.EscapeXML(n."POB") +  N'</POB>' + CHAR(13) + CHAR(10)
        +  N'  <PRICELISTID>' + dbo.EscapeXML(n."PRICELISTID") +  N'</PRICELISTID>' + CHAR(13) + CHAR(10)
        +  N'  <PRIMARYFAX>' + dbo.EscapeXML(n."PRIMARYFAX") +  N'</PRIMARYFAX>' + CHAR(13) + CHAR(10)
        +  N'  <PRIMARYPHONE>' + dbo.EscapeXML(n."PRIMARYPHONE") +  N'</PRIMARYPHONE>' + CHAR(13) + CHAR(10)
        +  N'  <PROD_APPLICATION_NAME>' + dbo.EscapeXML(n."PROD_APPLICATION_NAME") +  N'</PROD_APPLICATION_NAME>' + CHAR(13) + CHAR(10)
        +  N'  <PROD_INBOUND_ORDERS>' + dbo.EscapeXML(n."PROD_INBOUND_ORDERS") +  N'</PROD_INBOUND_ORDERS>' + CHAR(13) + CHAR(10)
        +  N'  <PROD_INBOUND_RESULTS>' + dbo.EscapeXML(n."PROD_INBOUND_RESULTS") +  N'</PROD_INBOUND_RESULTS>' + CHAR(13) + CHAR(10)
        +  N'  <PROD_OUTBOUND_ORDERS>' + dbo.EscapeXML(n."PROD_OUTBOUND_ORDERS") +  N'</PROD_OUTBOUND_ORDERS>' + CHAR(13) + CHAR(10)
        +  N'  <PROD_OUTBOUND_RESULTS>' + dbo.EscapeXML(n."PROD_OUTBOUND_RESULTS") +  N'</PROD_OUTBOUND_RESULTS>' + CHAR(13) + CHAR(10)
        +  N'  <RASCLIENTID>' + dbo.EscapeXML(n."RASCLIENTID") +  N'</RASCLIENTID>' + CHAR(13) + CHAR(10)
        +  N'  <SECONDARYPHONE>' + dbo.EscapeXML(n."SECONDARYPHONE") +  N'</SECONDARYPHONE>' + CHAR(13) + CHAR(10)
        +  N'  <START_DATE>' + dbo.EscapeXML((case when n."START_DATE" is null then  N''
							else 
								convert(varchar(50), n."START_DATE", 121) + convert(varchar(50), DATEDIFF(hh, GetUtcDate(), GetDate())) +	 N':00'
						end)) +  N'</START_DATE>' + CHAR(13) + CHAR(10)
        +  N'  <STATE>' + dbo.EscapeXML(n."STATE") +  N'</STATE>' + CHAR(13) + CHAR(10)
        +  N'  <STATUS>' + dbo.EscapeXML(n."STATUS") +  N'</STATUS>' + CHAR(13) + CHAR(10)
        +  N'  <UDPARAM0>' + dbo.EscapeXML(n."UDPARAM0") +  N'</UDPARAM0>' + CHAR(13) + CHAR(10)
        +  N'  <UDPARAM1>' + dbo.EscapeXML(n."UDPARAM1") +  N'</UDPARAM1>' + CHAR(13) + CHAR(10)
        +  N'  <UDPARAM2>' + dbo.EscapeXML(n."UDPARAM2") +  N'</UDPARAM2>' + CHAR(13) + CHAR(10)
        +  N'  <UDPARAM3>' + dbo.EscapeXML(n."UDPARAM3") +  N'</UDPARAM3>' + CHAR(13) + CHAR(10)
        +  N'  <UDPARAM4>' + dbo.EscapeXML(n."UDPARAM4") +  N'</UDPARAM4>' + CHAR(13) + CHAR(10)
        +  N'  <URL>' + dbo.EscapeXML(n."URL") +  N'</URL>' + CHAR(13) + CHAR(10)
        +  N'  <VMDPATH>' + dbo.EscapeXML(n."VMDPATH") +  N'</VMDPATH>' + CHAR(13) + CHAR(10)
        +  N'  <ZIP>' + dbo.EscapeXML(n."ZIP") +  N'</ZIP>' + CHAR(13) + CHAR(10)
        +  N' </ROW>' + CHAR(13) + CHAR(10)
        +  N'</ROWSET>' + CHAR(13) + CHAR(10)
 as ROW_DATA
		from inserted n
 
 
       end
 
END
GO
ALTER TABLE [dbo].[RASCLIENTS] ENABLE TRIGGER [AUDIT_26_INS_TRG]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TRIGGER [dbo].[AUDIT_26_UPD_TRG] 
ON [dbo].[RASCLIENTS] 
AFTER UPDATE
AS
BEGIN 

	DECLARE 
		@tmpId int,
		@tmpAction VARCHAR(6),
		@tmpOrigrec int,
		@sXML varchar(8000)

    if dbo.IsExternalSession(GETDATE()) > 0 
	begin
	
		set @tmpId = @@SPID
		
		if @@rowcount = 0
			return
			
		set nocount on
		
		if exists(select * from inserted) and exists(select * from deleted)

        insert into AUDITTRL (ORIGINAL_ORIGREC, DB_USER, APP_NAME, APP_USERNAME,
								AUDIT_DT, AUDIT_DT_OFFSET, DB_SID,
								TABLENAME, EVENT_TYPE, EVENTCODE, ROW_DATA) 
        select ORIGREC, SYSTEM_USER,  N'SQLSERVER', SYSTEM_USER,
			GetDate(), DATEDIFF(hh, GetUtcDate(), GetDate()) * 60, @tmpId,
			 N'RASCLIENTS',  N'Edit',  N'N/A',          N'<?xml version = ''1.0''?>' + CHAR(13) + CHAR(10)
        +  N'<ROWSET>' + CHAR(13) + CHAR(10)
        +  N' <ROW>' + CHAR(13) + CHAR(10)
        +  N'  <ACCOUNT_NAME>' + dbo.EscapeXML(n."ACCOUNT_NAME") +  N'</ACCOUNT_NAME>' + CHAR(13) + CHAR(10)
        +  N'  <ADRESS>' + dbo.EscapeXML(n."ADRESS") +  N'</ADRESS>' + CHAR(13) + CHAR(10)
        +  N'  <ADRESS_A>' + dbo.EscapeXML(n."ADRESS_A") +  N'</ADRESS_A>' + CHAR(13) + CHAR(10)
        +  N'  <APPLICATION_OID_DEV>' + dbo.EscapeXML(n."APPLICATION_OID_DEV") +  N'</APPLICATION_OID_DEV>' + CHAR(13) + CHAR(10)
        +  N'  <APPLICATION_OID_PROD>' + dbo.EscapeXML(n."APPLICATION_OID_PROD") +  N'</APPLICATION_OID_PROD>' + CHAR(13) + CHAR(10)
        +  N'  <CATEGORY>' + dbo.EscapeXML(n."CATEGORY") +  N'</CATEGORY>' + CHAR(13) + CHAR(10)
        +  N'  <CITY>' + dbo.EscapeXML(n."CITY") +  N'</CITY>' + CHAR(13) + CHAR(10)
        +  N'  <CLIENT_USAGE>' + dbo.EscapeXML(n."CLIENT_USAGE") +  N'</CLIENT_USAGE>' + CHAR(13) + CHAR(10)
        +  N'  <COMPNAME>' + dbo.EscapeXML(n."COMPNAME") +  N'</COMPNAME>' + CHAR(13) + CHAR(10)
        +  N'  <COUNTRY>' + dbo.EscapeXML(n."COUNTRY") +  N'</COUNTRY>' + CHAR(13) + CHAR(10)
        +  N'  <COUNTY>' + dbo.EscapeXML(n."COUNTY") +  N'</COUNTY>' + CHAR(13) + CHAR(10)
        +  N'  <DEFAULTCONTACT>' + dbo.EscapeXML(n."DEFAULTCONTACT") +  N'</DEFAULTCONTACT>' + CHAR(13) + CHAR(10)
        +  N'  <DELINQUENT>' + dbo.EscapeXML(n."DELINQUENT") +  N'</DELINQUENT>' + CHAR(13) + CHAR(10)
        +  N'  <DEPARTMENT>' + dbo.EscapeXML(n."DEPARTMENT") +  N'</DEPARTMENT>' + CHAR(13) + CHAR(10)
        +  N'  <DEV_APPLICATION_NAME>' + dbo.EscapeXML(n."DEV_APPLICATION_NAME") +  N'</DEV_APPLICATION_NAME>' + CHAR(13) + CHAR(10)
        +  N'  <DEV_INBOUND_ORDERS>' + dbo.EscapeXML(n."DEV_INBOUND_ORDERS") +  N'</DEV_INBOUND_ORDERS>' + CHAR(13) + CHAR(10)
        +  N'  <DEV_INBOUND_RESULTS>' + dbo.EscapeXML(n."DEV_INBOUND_RESULTS") +  N'</DEV_INBOUND_RESULTS>' + CHAR(13) + CHAR(10)
        +  N'  <DEV_OUTBOUND_ORDERS>' + dbo.EscapeXML(n."DEV_OUTBOUND_ORDERS") +  N'</DEV_OUTBOUND_ORDERS>' + CHAR(13) + CHAR(10)
        +  N'  <DEV_OUTBOUND_RESULTS>' + dbo.EscapeXML(n."DEV_OUTBOUND_RESULTS") +  N'</DEV_OUTBOUND_RESULTS>' + CHAR(13) + CHAR(10)
        +  N'  <EMAIL>' + dbo.EscapeXML(n."EMAIL") +  N'</EMAIL>' + CHAR(13) + CHAR(10)
        +  N'  <EXTERNALCLIENTID>' + dbo.EscapeXML(n."EXTERNALCLIENTID") +  N'</EXTERNALCLIENTID>' + CHAR(13) + CHAR(10)
        +  N'  <FAXAREACODE>' + dbo.EscapeXML(n."FAXAREACODE") +  N'</FAXAREACODE>' + CHAR(13) + CHAR(10)
        +  N'  <FAXCOUNTRYCODE>' + dbo.EscapeXML(n."FAXCOUNTRYCODE") +  N'</FAXCOUNTRYCODE>' + CHAR(13) + CHAR(10)
        +  N'  <FAXLOCALNUMBER>' + dbo.EscapeXML(n."FAXLOCALNUMBER") +  N'</FAXLOCALNUMBER>' + CHAR(13) + CHAR(10)
        +  N'  <HL7_CONTACT>' + dbo.EscapeXML(n."HL7_CONTACT") +  N'</HL7_CONTACT>' + CHAR(13) + CHAR(10)
        +  N'  <HL7_CONTACT_EMAIL>' + dbo.EscapeXML(n."HL7_CONTACT_EMAIL") +  N'</HL7_CONTACT_EMAIL>' + CHAR(13) + CHAR(10)
        +  N'  <HL7_CONTACT_PHONE>' + dbo.EscapeXML(n."HL7_CONTACT_PHONE") +  N'</HL7_CONTACT_PHONE>' + CHAR(13) + CHAR(10)
        +  N'  <HL7_ID>' + dbo.EscapeXML(n."HL7_ID") +  N'</HL7_ID>' + CHAR(13) + CHAR(10)
        +  N'  <INTERFACE_ID>' + dbo.EscapeXML(n."INTERFACE_ID") +  N'</INTERFACE_ID>' + CHAR(13) + CHAR(10)
        +  N'  <IS_PRIMARY>' + dbo.EscapeXML(n."IS_PRIMARY") +  N'</IS_PRIMARY>' + CHAR(13) + CHAR(10)
        +  N'  <JURISDICTION_CODE>' + dbo.EscapeXML(n."JURISDICTION_CODE") +  N'</JURISDICTION_CODE>' + CHAR(13) + CHAR(10)
        +  N'  <JURISDICTION_TYPE>' + dbo.EscapeXML(n."JURISDICTION_TYPE") +  N'</JURISDICTION_TYPE>' + CHAR(13) + CHAR(10)
        +  N'  <LABDIRECTORDEGREE>' + dbo.EscapeXML(n."LABDIRECTORDEGREE") +  N'</LABDIRECTORDEGREE>' + CHAR(13) + CHAR(10)
        +  N'  <NETWORK_SHARED_PATH>' + dbo.EscapeXML(n."NETWORK_SHARED_PATH") +  N'</NETWORK_SHARED_PATH>' + CHAR(13) + CHAR(10)
        +  N'  <ORGANIZATIONAL_OID>' + dbo.EscapeXML(n."ORGANIZATIONAL_OID") +  N'</ORGANIZATIONAL_OID>' + CHAR(13) + CHAR(10)
        +  N'  <ORIGREC>' + dbo.EscapeXML(n."ORIGREC") +  N'</ORIGREC>' + CHAR(13) + CHAR(10)
        +  N'  <ORIGSTS>' + dbo.EscapeXML(n."ORIGSTS") +  N'</ORIGSTS>' + CHAR(13) + CHAR(10)
        +  N'  <OWNER>' + dbo.EscapeXML(n."OWNER") +  N'</OWNER>' + CHAR(13) + CHAR(10)
        +  N'  <PAGERCELL>' + dbo.EscapeXML(n."PAGERCELL") +  N'</PAGERCELL>' + CHAR(13) + CHAR(10)
        +  N'  <PANEL_PRELIMINARY>' + dbo.EscapeXML(n."PANEL_PRELIMINARY") +  N'</PANEL_PRELIMINARY>' + CHAR(13) + CHAR(10)
        +  N'  <PHONEAREACODE>' + dbo.EscapeXML(n."PHONEAREACODE") +  N'</PHONEAREACODE>' + CHAR(13) + CHAR(10)
        +  N'  <PHONECOUNTRYCODE>' + dbo.EscapeXML(n."PHONECOUNTRYCODE") +  N'</PHONECOUNTRYCODE>' + CHAR(13) + CHAR(10)
        +  N'  <PHONEEXTENSION1>' + dbo.EscapeXML(n."PHONEEXTENSION1") +  N'</PHONEEXTENSION1>' + CHAR(13) + CHAR(10)
        +  N'  <PHONEEXTENSION2>' + dbo.EscapeXML(n."PHONEEXTENSION2") +  N'</PHONEEXTENSION2>' + CHAR(13) + CHAR(10)
        +  N'  <PHONELOCALNUMBER>' + dbo.EscapeXML(n."PHONELOCALNUMBER") +  N'</PHONELOCALNUMBER>' + CHAR(13) + CHAR(10)
        +  N'  <POB>' + dbo.EscapeXML(n."POB") +  N'</POB>' + CHAR(13) + CHAR(10)
        +  N'  <PRICELISTID>' + dbo.EscapeXML(n."PRICELISTID") +  N'</PRICELISTID>' + CHAR(13) + CHAR(10)
        +  N'  <PRIMARYFAX>' + dbo.EscapeXML(n."PRIMARYFAX") +  N'</PRIMARYFAX>' + CHAR(13) + CHAR(10)
        +  N'  <PRIMARYPHONE>' + dbo.EscapeXML(n."PRIMARYPHONE") +  N'</PRIMARYPHONE>' + CHAR(13) + CHAR(10)
        +  N'  <PROD_APPLICATION_NAME>' + dbo.EscapeXML(n."PROD_APPLICATION_NAME") +  N'</PROD_APPLICATION_NAME>' + CHAR(13) + CHAR(10)
        +  N'  <PROD_INBOUND_ORDERS>' + dbo.EscapeXML(n."PROD_INBOUND_ORDERS") +  N'</PROD_INBOUND_ORDERS>' + CHAR(13) + CHAR(10)
        +  N'  <PROD_INBOUND_RESULTS>' + dbo.EscapeXML(n."PROD_INBOUND_RESULTS") +  N'</PROD_INBOUND_RESULTS>' + CHAR(13) + CHAR(10)
        +  N'  <PROD_OUTBOUND_ORDERS>' + dbo.EscapeXML(n."PROD_OUTBOUND_ORDERS") +  N'</PROD_OUTBOUND_ORDERS>' + CHAR(13) + CHAR(10)
        +  N'  <PROD_OUTBOUND_RESULTS>' + dbo.EscapeXML(n."PROD_OUTBOUND_RESULTS") +  N'</PROD_OUTBOUND_RESULTS>' + CHAR(13) + CHAR(10)
        +  N'  <RASCLIENTID>' + dbo.EscapeXML(n."RASCLIENTID") +  N'</RASCLIENTID>' + CHAR(13) + CHAR(10)
        +  N'  <SECONDARYPHONE>' + dbo.EscapeXML(n."SECONDARYPHONE") +  N'</SECONDARYPHONE>' + CHAR(13) + CHAR(10)
        +  N'  <START_DATE>' + dbo.EscapeXML((case when n."START_DATE" is null then  N''
							else 
								convert(varchar(50), n."START_DATE", 121) + convert(varchar(50), DATEDIFF(hh, GetUtcDate(), GetDate())) +	 N':00'
						end)) +  N'</START_DATE>' + CHAR(13) + CHAR(10)
        +  N'  <STATE>' + dbo.EscapeXML(n."STATE") +  N'</STATE>' + CHAR(13) + CHAR(10)
        +  N'  <STATUS>' + dbo.EscapeXML(n."STATUS") +  N'</STATUS>' + CHAR(13) + CHAR(10)
        +  N'  <UDPARAM0>' + dbo.EscapeXML(n."UDPARAM0") +  N'</UDPARAM0>' + CHAR(13) + CHAR(10)
        +  N'  <UDPARAM1>' + dbo.EscapeXML(n."UDPARAM1") +  N'</UDPARAM1>' + CHAR(13) + CHAR(10)
        +  N'  <UDPARAM2>' + dbo.EscapeXML(n."UDPARAM2") +  N'</UDPARAM2>' + CHAR(13) + CHAR(10)
        +  N'  <UDPARAM3>' + dbo.EscapeXML(n."UDPARAM3") +  N'</UDPARAM3>' + CHAR(13) + CHAR(10)
        +  N'  <UDPARAM4>' + dbo.EscapeXML(n."UDPARAM4") +  N'</UDPARAM4>' + CHAR(13) + CHAR(10)
        +  N'  <URL>' + dbo.EscapeXML(n."URL") +  N'</URL>' + CHAR(13) + CHAR(10)
        +  N'  <VMDPATH>' + dbo.EscapeXML(n."VMDPATH") +  N'</VMDPATH>' + CHAR(13) + CHAR(10)
        +  N'  <ZIP>' + dbo.EscapeXML(n."ZIP") +  N'</ZIP>' + CHAR(13) + CHAR(10)
        +  N' </ROW>' + CHAR(13) + CHAR(10)
        +  N'</ROWSET>' + CHAR(13) + CHAR(10)
 as ROW_DATA
		from
			(select "ACCOUNT_NAME", "ADRESS", "ADRESS_A", "APPLICATION_OID_DEV", "APPLICATION_OID_PROD", "CATEGORY", "CITY", "CLIENT_USAGE", "COMPNAME", "COUNTRY", "COUNTY", "DEFAULTCONTACT", "DELINQUENT", "DEPARTMENT", "DEV_APPLICATION_NAME", "DEV_INBOUND_ORDERS", "DEV_INBOUND_RESULTS", "DEV_OUTBOUND_ORDERS", "DEV_OUTBOUND_RESULTS", "EMAIL", "EXTERNALCLIENTID", "FAXAREACODE", "FAXCOUNTRYCODE", "FAXLOCALNUMBER", "HL7_CONTACT", "HL7_CONTACT_EMAIL", "HL7_CONTACT_PHONE", "HL7_ID", "INTERFACE_ID", "IS_PRIMARY", "JURISDICTION_CODE", "JURISDICTION_TYPE", "LABDIRECTORDEGREE", "NETWORK_SHARED_PATH", "ORGANIZATIONAL_OID", "ORIGREC", "ORIGSTS", "OWNER", "PAGERCELL", "PANEL_PRELIMINARY", "PHONEAREACODE", "PHONECOUNTRYCODE", "PHONEEXTENSION1", "PHONEEXTENSION2", "PHONELOCALNUMBER", "POB", "PRICELISTID", "PRIMARYFAX", "PRIMARYPHONE", "PROD_APPLICATION_NAME", "PROD_INBOUND_ORDERS", "PROD_INBOUND_RESULTS", "PROD_OUTBOUND_ORDERS", "PROD_OUTBOUND_RESULTS", "RASCLIENTID", "SECONDARYPHONE", "START_DATE", "STATE", "STATUS", "UDPARAM0", "UDPARAM1", "UDPARAM2", "UDPARAM3", "UDPARAM4", "URL", "VMDPATH", "ZIP" from inserted
				except
			select "ACCOUNT_NAME", "ADRESS", "ADRESS_A", "APPLICATION_OID_DEV", "APPLICATION_OID_PROD", "CATEGORY", "CITY", "CLIENT_USAGE", "COMPNAME", "COUNTRY", "COUNTY", "DEFAULTCONTACT", "DELINQUENT", "DEPARTMENT", "DEV_APPLICATION_NAME", "DEV_INBOUND_ORDERS", "DEV_INBOUND_RESULTS", "DEV_OUTBOUND_ORDERS", "DEV_OUTBOUND_RESULTS", "EMAIL", "EXTERNALCLIENTID", "FAXAREACODE", "FAXCOUNTRYCODE", "FAXLOCALNUMBER", "HL7_CONTACT", "HL7_CONTACT_EMAIL", "HL7_CONTACT_PHONE", "HL7_ID", "INTERFACE_ID", "IS_PRIMARY", "JURISDICTION_CODE", "JURISDICTION_TYPE", "LABDIRECTORDEGREE", "NETWORK_SHARED_PATH", "ORGANIZATIONAL_OID", "ORIGREC", "ORIGSTS", "OWNER", "PAGERCELL", "PANEL_PRELIMINARY", "PHONEAREACODE", "PHONECOUNTRYCODE", "PHONEEXTENSION1", "PHONEEXTENSION2", "PHONELOCALNUMBER", "POB", "PRICELISTID", "PRIMARYFAX", "PRIMARYPHONE", "PROD_APPLICATION_NAME", "PROD_INBOUND_ORDERS", "PROD_INBOUND_RESULTS", "PROD_OUTBOUND_ORDERS", "PROD_OUTBOUND_RESULTS", "RASCLIENTID", "SECONDARYPHONE", "START_DATE", "STATE", "STATUS", "UDPARAM0", "UDPARAM1", "UDPARAM2", "UDPARAM3", "UDPARAM4", "URL", "VMDPATH", "ZIP" from deleted) n

 
 
       end
 
END
GO
ALTER TABLE [dbo].[RASCLIENTS] ENABLE TRIGGER [AUDIT_26_UPD_TRG]
GO
