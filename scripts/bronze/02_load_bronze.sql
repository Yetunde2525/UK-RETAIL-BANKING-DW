/*
===============================================================================
Stored Procedure: bronze.load_bronze
===============================================================================
Script Purpose:
    Loads the six raw CSV extracts into their corresponding bronze tables.
    Each table is truncated before reload, so this procedure can be re-run
    safely as many times as needed.

WARNING:
    - This procedure TRUNCATES every bronze table before reloading it. Any
      data already in bronze will be lost and replaced with whatever is in
      the CSVs at the paths below.
    - BULK INSERT requires the CSV files to be visible to the SQL Server
      *service account*, not just your own machine. Update every file path
      below to match where the CSVs live relative to your SQL Server
      instance. If you're on a managed/cloud SQL Server that can't see local
      files, use SSMS's "Import Flat File" wizard for each CSV instead and
      skip this procedure.

Usage:
    EXEC bronze.load_bronze;
===============================================================================
*/

USE UKRetailBankingDW;
GO

CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start DATETIME;

    BEGIN TRY
        SET @batch_start = GETDATE();
        PRINT '===============================================';
        PRINT 'Loading Bronze Layer';
        PRINT '===============================================';

        -- customers ------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating: bronze.customers';
        TRUNCATE TABLE bronze.customers;
        PRINT '>> Loading:    bronze.customers';
        BULK INSERT bronze.customers
        FROM 'C:\Users\yetun\OneDrive\UK Retail Banking Customer Analytics Data Warehouse\uk BRD\customers.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK, CODEPAGE = '65001');
        PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND, @start_time, GETDATE()) AS NVARCHAR) + ' sec';

        -- accounts --------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating: bronze.accounts';
        TRUNCATE TABLE bronze.accounts;
        PRINT '>> Loading:    bronze.accounts';
        BULK INSERT bronze.accounts
        FROM 'C:\Users\yetun\OneDrive\UK Retail Banking Customer Analytics Data Warehouse\uk BRD\accounts.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK, CODEPAGE = '65001');
        PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND, @start_time, GETDATE()) AS NVARCHAR) + ' sec';

        -- transactions ------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating: bronze.transactions';
        TRUNCATE TABLE bronze.transactions;
        PRINT '>> Loading:    bronze.transactions';
        BULK INSERT bronze.transactions
        FROM 'C:\Users\yetun\OneDrive\UK Retail Banking Customer Analytics Data Warehouse\uk BRD\transactions.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK, CODEPAGE = '65001');
        PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND, @start_time, GETDATE()) AS NVARCHAR) + ' sec';

        -- loans ------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating: bronze.loans';
        TRUNCATE TABLE bronze.loans;
        PRINT '>> Loading:    bronze.loans';
        BULK INSERT bronze.loans
        FROM 'C:\Users\yetun\OneDrive\UK Retail Banking Customer Analytics Data Warehouse\uk BRD\loans.csv'     
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK, CODEPAGE = '65001');
        PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND, @start_time, GETDATE()) AS NVARCHAR) + ' sec';

        -- complaints ---------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating: bronze.complaints';
        TRUNCATE TABLE bronze.complaints;
        PRINT '>> Loading:    bronze.complaints';
        BULK INSERT bronze.complaints
        FROM 'C:\Users\yetun\OneDrive\UK Retail Banking Customer Analytics Data Warehouse\uk BRD\complaints.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK, CODEPAGE = '65001');
        PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND, @start_time, GETDATE()) AS NVARCHAR) + ' sec';

        -- branches ------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating: bronze.branches';
        TRUNCATE TABLE bronze.branches;
        PRINT '>> Loading:    bronze.branches';
        BULK INSERT bronze.branches
        FROM 'C:\Users\yetun\OneDrive\UK Retail Banking Customer Analytics Data Warehouse\uk BRD\branches.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK, CODEPAGE = '65001');
        PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND, @start_time, GETDATE()) AS NVARCHAR) + ' sec';

        PRINT '===============================================';
        PRINT 'Bronze Layer Load Complete. Total duration: '
              + CAST(DATEDIFF(SECOND, @batch_start, GETDATE()) AS NVARCHAR) + ' sec';
        PRINT '===============================================';
    END TRY
    BEGIN CATCH
        PRINT '===============================================';
        PRINT 'ERROR OCCURRED DURING BRONZE LAYER LOAD';
        PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(50));
		PRINT 'Error Message: ' + ERROR_MESSAGE();
		PRINT 'Error Line: ' + CAST(ERROR_LINE() AS NVARCHAR(50));
		PRINT 'Error Procedure: ' + ISNULL(ERROR_PROCEDURE(), 'N/A');
        PRINT '===============================================';
    END CATCH
END
GO
