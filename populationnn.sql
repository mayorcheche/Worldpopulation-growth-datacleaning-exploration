
----TO JOIN THE POPULATION DEMOGRAPHY TABLE AND THE DEATH DEMOGRAPHY TABLE
SELECT *
FROM AS POPDEM
JOIN PopulationGrowth..DeathsDemography AS DEADEM
      ON POPDEM.Countryname = DEADEM.Countryname
	  AND POPDEM.year = DEADEM.year


---TO CALCULATE THE DEATH RATE 
SELECT DEADEM.Countryname, DEADEM.Year, DEADEM.DeathsOfChildrenUnder1, POPDEM.Total_Population,
CASE
     WHEN ISNUMERIC(DEADEM.DeathsOfChildrenUnder1) = 1 AND ISNUMERIC(POPDEM.Total_Population) = 1
            THEN (CONVERT(FLOAT, DEADEM.DeathsOfChildrenUnder1) / CONVERT(FLOAT, POPDEM.Total_Population)) * 1000
        ELSE 0
    END AS DeathRate
FROM PopulationGrowth..populationDemography AS POPDEM
JOIN PopulationGrowth..DeathsDemography AS DEADEM
      ON POPDEM.Countryname = DEADEM.Countryname
	  AND POPDEM.year = DEADEM.year
 
  

-- Add the DeathRate column to the DeathsDemography table
ALTER TABLE PopulationGrowth..DeathsDemography
ADD DeathRate FLOAT; 



--THEN WE UPDATE THE VALUES BELOW INTO THE ALTERED TABLE
UPDATE DeathsDemography
SET DeathRate = (
  CASE
    WHEN ISNUMERIC(DeathsOfChildrenUnder1) = 1
      THEN (CONVERT(FLOAT, DeathsOfChildrenUnder1) / 
            (SELECT TOP 1 CONVERT(FLOAT, Total_Population) 
             FROM PopulationGrowth..populationDemography AS POPDEM
             WHERE POPDEM.Countryname = DeathsDemography.Countryname
             AND POPDEM.year = DeathsDemography.year)
            ) * 1000
 ELSE 0
END
);


SELECT *
FROM PopulationGrowth..DeathsDemography



---TO CALCULATE POPULATION GROWTH RATE I NEED TO JOIN LIFE EXPECTANCY TABLE WITH DEATH DEMOGRAPHY TABLE FIRST
SELECT *
FROM PopulationGrowth..LifeExpectanyFertilityNetMigration AS LIFEMIG
JOIN PopulationGrowth..DeathsDemography AS DEADEM
      ON LIFEMIG.Countryname = DEADEM.Countryname
	  AND LIFEMIG.year = DEADEM.year
	


SELECT DEADEM.Countryname, DEADEM.Year, LIFEMIG.BirthRate, DEADEM.DeathRate, LIFEMIG.NetMigration,
CASE
     WHEN ISNUMERIC(LIFEMIG.BirthRate) = 1 AND ISNUMERIC(DEADEM.DeathRate) = 1 AND ISNUMERIC(LIFEMIG.NetMigration) = 1
            THEN (CONVERT(FLOAT, LIFEMIG.BirthRate) - CONVERT(FLOAT, DEADEM.DeathRate) + LIFEMIG.NetMigration)
        ELSE 0
    END AS PopulationGrowthRatee
FROM PopulationGrowth..LifeExpectanyFertilityNetMigration AS LIFEMIG
JOIN PopulationGrowth..DeathsDemography AS DEADEM
      ON LIFEMIG.Countryname = DEADEM.Countryname
	  AND LIFEMIG.year = DEADEM.year
ORDER BY DEADEM.Countryname;



--WE ADDING THE POPULATION GROWTH RATE TO THE DEATHS DEMOGRAPHY TABLE
ALTER TABLE PopulationGrowth..DeathsDemography
ADD PopulationGrowthRatee FLOAT;



UPDATE PopulationGrowth..DeathsDemography
SET PopulationGrowthRatee = 
    CASE
        WHEN ISNUMERIC(LIFEMIG.BirthRate) = 1 AND ISNUMERIC(DEADEM.DeathRate) = 1 AND ISNUMERIC(LIFEMIG.NetMigration) = 1
            THEN (CONVERT(FLOAT, LIFEMIG.BirthRate) - CONVERT(FLOAT, DEADEM.DeathRate) + LIFEMIG.NetMigration)
        ELSE 0
    END
FROM PopulationGrowth..LifeExpectanyFertilityNetMigration AS LIFEMIG
JOIN PopulationGrowth..DeathsDemography AS DEADEM
      ON LIFEMIG.Countryname = DEADEM.Countryname
	  AND LIFEMIG.year = DEADEM.year


SELECT *
FROM PopulationGrowth..DeathsDemography
 

ALTER TABLE PopulationGrowth..DeathsDemography
DROP COLUMN PopulationGrowthRate;


ALTER TABLE PopulationGrowth..DeathsDemography
ADD PopulationGrowthImplicationn NVARCHAR(50);


ALTER TABLE PopulationGrowth..DeathsDemography
DROP COLUMN PopulationGrowthImplication;


-- Update PopulationGrowthRateImplication based on PopulationGrowthRate
UPDATE PopulationGrowth..DeathsDemography
SET PopulationGrowthImplicationn = 
    CASE
        WHEN PopulationGrowthRatee < 0 THEN 'DECLINE'
        ELSE 'GROWTH'
    END
FROM PopulationGrowth..DeathsDemography

---TO CALCULATE THE TOTAL DEATHS IN EACH COUNTRY OVER THE PERIOD OF 50 YEARS
SELECT Countryname, SUM(CAST(Total_Deaths AS FLOAT )) as TotalDecadeDeaths
FROM DeathsDemography
GROUP BY Countryname
ORDER BY Countryname;


--TO CALCULATE THE BIRTHRATE IN EACH COUNTRY OVER THE LAST 50 YEARS 
SELECT Countryname, SUM(CAST(BirthRate AS FLOAT )) as CumutativeBirthrate
FROM LifeExpectanyFertilityNetMigration
GROUP BY Countryname
ORDER BY Countryname;


--TO CALCULATE THE DEATHRATE IN EACH COUNTRY OVER THE LAST 50 YEARS 
SELECT Countryname, SUM(CAST(DeathRate AS FLOAT )) as CumutativeBirthrate
FROM DeathsDemography
GROUP BY Countryname
ORDER BY Countryname;


---TO CALCULATE THE PEARSON CORRELATION COEFFICIENT BETWEEN TOTAL DEATHS AND TOTAL POPULATION IN EACH COUNTRY
SELECT POPDEM.Countryname, ROUND( 
(COUNT(*) * SUM(POPDEM.Total_Population * DEADEM.Total_Deaths) - SUM(POPDEM.Total_Population) * SUM(DEADEM.Total_Deaths)) /
    SQRT(
        (COUNT(*) * SUM(POPDEM.Total_Population * POPDEM.Total_Population) - SUM(POPDEM.Total_Population) * SUM(POPDEM.Total_Population)) *
        (COUNT(*) * SUM(DEADEM.Total_Deaths * DEADEM.Total_Deaths) - SUM(DEADEM.Total_Deaths) * SUM(DEADEM.Total_Deaths))
   ), 2 ) AS PearsonCorrelationCoefficient
FROM PopulationGrowth..populationDemography AS POPDEM
JOIN PopulationGrowth..DeathsDemography AS DEADEM
      ON POPDEM.Countryname = DEADEM.Countryname
GROUP BY POPDEM.Countryname
ORDER BY POPDEM.Countryname;



---TO CALCULATE THE 95% CONFIDENCE INTERVAL ON LIFE EXPECTANCY AT BIRTH --- I USED THE CTE TO GET THIS
WITH ConfidenceInterval AS (
    SELECT
        Countryname,
        ROUND(AVG(LifeExpectancyAtBirth), 2) AS MeanLifeExpectancy,
        ROUND(STDEV(LifeExpectancyAtBirth), 2) AS StandardDeviation,
        ROUND(COUNT(LifeExpectancyAtBirth), 2) AS SampleSize
    FROM LifeExpectanyFertilityNetMigration   
    GROUP BY Countryname
)
SELECT
    Countryname,
    MeanLifeExpectancy,
    StandardDeviation,
    SampleSize,
    ROUND(MeanLifeExpectancy - 1.96  *  StandardDeviation / SQRT(SampleSize), 2) AS LowerCiExpectancy,
    ROUND(MeanLifeExpectancy + 1.96  *  StandardDeviation / SQRT(SampleSize), 2) AS UpperCiExpectancy
FROM ConfidenceInterval
ORDER BY Countryname


---TO CALCULATE % CHANGE IN POPULATION
SELECT Countryname, Year, Total_Population, LAG(Total_Population) OVER (PARTITION BY Countryname ORDER BY Countryname) AS earlier_populationn,
    CASE
        WHEN LAG(Total_Population) OVER (PARTITION BY Countryname ORDER BY Countryname) IS NOT NULL
            THEN ((Total_Population - LAG(Total_Population) OVER (PARTITION BY Countryname ORDER BY Countryname)) / LAG(Total_Population) OVER (PARTITION BY Countryname ORDER BY Countryname)) * 100
        ELSE NULL
    END AS Percentage_Change
FROM populationDemography;

---UPDATE PERCENTAGE CHANGE INTO THE POPULATION TABLE
ALTER TABLE PopulationGrowth..populationDemography
ADD Percentage_Change FLOAT;


---UPDATE ConfidenceInterval INTO THE POPULATION TABLE
ALTER TABLE PopulationGrowth..LifeExpectanyFertilityNetMigration
ADD ConfidenceInterval NVARCHAR(50);


---UPDATE PEARSON COEFFICIENT INTO THE DEATH TABLE
ALTER TABLE PopulationGrowth..DeathsDemography
ADD PearsonCorrelationCoefficient FLOAT;

ALTER TABLE PopulationGrowth..DeathsDemography
DROP COLUMN PearsonCorrelation

---UPDATE DeathsPercentageChange INTO THE DEATH TABLE
ALTER TABLE PopulationGrowth..DeathsDemography
ADD DeathsPercentageChange FLOAT;

---UPDATE ELASTICITY INTO THE DEATH TABLE
ALTER TABLE PopulationGrowth..DeathsDemography
ADD Elasticity FLOAT;


-- Step 1: Create a temporary table to store the CTE results
SELECT
    Countryname,
    Year,
    Total_Population,
    LAG(Total_Population) OVER (PARTITION BY Countryname ORDER BY Year) AS earlier_population,
    CASE
        WHEN LAG(Total_Population) OVER (PARTITION BY Countryname ORDER BY Year) IS NOT NULL
            THEN ((Total_Population - LAG(Total_Population) OVER (PARTITION BY Countryname ORDER BY Year)) / LAG(Total_Population) OVER (PARTITION BY Countryname ORDER BY Year)) * 100
        ELSE NULL
    END AS Percentage_Change
INTO #TempCTE
FROM PopulationGrowth..populationDemography;

-- Step 2: Update the original table using the temporary table
UPDATE PopulationGrowth..populationDemography
SET
    Percentage_Change = t.Percentage_Change
FROM #TempCTE t
WHERE
    PopulationGrowth..populationDemography.Countryname = t.Countryname
    AND PopulationGrowth..populationDemography.Year = t.Year;

-- Step 3: Drop the temporary table
DROP TABLE #TempCTE;

-- Step 4: Select the updated table
SELECT *
FROM PopulationGrowth..populationDemography;



---UPDATE CONFIENCE INTERVAL INTO THE LIFEEXPECTANCY TABLE
-- Step 1: Create a temporary table to store the ConfidenceInterval results
WITH ConfidenceInterval AS (
    SELECT
        Countryname,
        ROUND(AVG(LifeExpectancyAtBirth), 2) AS MeanLifeExpectancy,
        ROUND(STDEV(LifeExpectancyAtBirth), 2) AS StandardDeviation,
        ROUND(COUNT(LifeExpectancyAtBirth), 2) AS SampleSize
    FROM PopulationGrowth..LifeExpectanyFertilityNetMigration   
    GROUP BY Countryname
)

-- Step 2: Update the original table using the temporary table
UPDATE PopulationGrowth..LifeExpectanyFertilityNetMigration
SET
    ConfidenceInterval = 
        CASE
            WHEN c.SampleSize > 1
                THEN 
                    CAST(
                        ROUND(c.MeanLifeExpectancy - 1.96 * c.StandardDeviation / SQRT(c.SampleSize), 2) 
                        AS NVARCHAR(50))
                    + ' to ' +
                    CAST(
                        ROUND(c.MeanLifeExpectancy + 1.96 * c.StandardDeviation / SQRT(c.SampleSize), 2) 
                        AS NVARCHAR(50))
            ELSE NULL
        END
FROM ConfidenceInterval c
WHERE
    PopulationGrowth..LifeExpectanyFertilityNetMigration.Countryname = c.Countryname;

-- Step 3: Select the updated table
SELECT *
FROM PopulationGrowth..LifeExpectanyFertilityNetMigration;


---UPDATE PEARSON COEFFICIENT INTO THE DEATH TABLE
-- Step 1: Create a temporary table to store the PearsonCorrelationCoefficient results
WITH PearsonCorrelation AS (
    SELECT
        POPDEM.Countryname,
        CAST(
            ROUND(
                (COUNT(*) * SUM(POPDEM.Total_Population * DEADEM.Total_Deaths) - SUM(POPDEM.Total_Population) * SUM(DEADEM.Total_Deaths)) /
                SQRT(
                    (COUNT(*) * SUM(POPDEM.Total_Population * POPDEM.Total_Population) - SUM(POPDEM.Total_Population) * SUM(POPDEM.Total_Population)) *
                    (COUNT(*) * SUM(DEADEM.Total_Deaths * DEADEM.Total_Deaths) - SUM(DEADEM.Total_Deaths) * SUM(DEADEM.Total_Deaths))
                ), 2
            ) AS FLOAT
        ) AS PearsonCorrelationCoefficient
    FROM PopulationGrowth..populationDemography AS POPDEM
    JOIN PopulationGrowth..DeathsDemography AS DEADEM ON POPDEM.Countryname = DEADEM.Countryname
    GROUP BY POPDEM.Countryname
)

-- Step 2: Update the original table using the temporary table
UPDATE PopulationGrowth..DeathsDemography
SET
    PearsonCorrelationCoefficient = PC.PearsonCorrelationCoefficient
FROM PearsonCorrelation PC
WHERE
    PopulationGrowth..DeathsDemography.Countryname = PC.Countryname;

-- Step 3: Select the updated table
SELECT *
FROM PopulationGrowth..DeathsDemography;



--TO CALCULATE ELASTICITY OF POPULATION GROWTH
---TO CALCULATE % CHANGE IN DEATHS
SELECT Countryname, Year, Total_Deaths, LAG(Total_Deaths) OVER (PARTITION BY Countryname ORDER BY Countryname) AS earlier_deaths,
    CASE
        WHEN LAG(Total_Deaths) OVER (PARTITION BY Countryname ORDER BY Countryname) IS NOT NULL
            THEN ((Total_Deaths - LAG(Total_Deaths) OVER (PARTITION BY Countryname ORDER BY Countryname)) / LAG(Total_Deaths) OVER (PARTITION BY Countryname ORDER BY Countryname)) * 100
        ELSE NULL
    END AS DeathsPercentageChange
FROM DeathsDemography;

---UPDATE DEATHSPERCENTAGE INTO THE POPULATION DEMOGRAPHY TABLE
-- Step 1: Create a temporary table to store the DeathsPercentageChange results
WITH DeathsPercentageChange AS (
    SELECT
        Countryname,
        Year,
        Total_Deaths,
        LAG(Total_Deaths) OVER (PARTITION BY Countryname ORDER BY Countryname) AS earlier_deaths,
        CASE
            WHEN LAG(Total_Deaths) OVER (PARTITION BY Countryname ORDER BY Countryname) IS NOT NULL
                THEN CAST(
                    ((Total_Deaths - LAG(Total_Deaths) OVER (PARTITION BY Countryname ORDER BY Countryname)) / LAG(Total_Deaths) OVER (PARTITION BY Countryname ORDER BY Countryname)) * 100
                    AS FLOAT
                )
            ELSE NULL
        END AS DeathsPercentageChange
    FROM PopulationGrowth..DeathsDemography
)

-- Step 2: Update the original table using the temporary table
UPDATE PopulationGrowth..DeathsDemography
SET
    DeathsPercentageChange = DPC.DeathsPercentageChange
FROM DeathsPercentageChange DPC
WHERE
    PopulationGrowth..DeathsDemography.Countryname = DPC.Countryname
    AND PopulationGrowth..DeathsDemography.Year = DPC.Year;

-- Step 3: Select the updated table
SELECT *
FROM PopulationGrowth..DeathsDemography;


---JOIN POPULATION DEMOGRAPHY AND DEATHS DEMOGRAPHY TOGETHER TO GET ELASTICITY VALUES
SELECT DEADEM.DeathsPercentageChange, POPDEM.Percentage_Change, POPDEM.Countryname, DEADEM.Countryname, POPDEM.year, DEADEM.year,
CASE
     WHEN ISNUMERIC(DEADEM.DeathsPercentageChange) = 1 AND ISNUMERIC(POPDEM.Percentage_Change) = 1 AND DEADEM.DeathsPercentageChange <> 0
            THEN (CONVERT(FLOAT, POPDEM.Percentage_Change) / CONVERT(FLOAT, DEADEM.DeathsPercentageChange))
        ELSE 0
    END AS Elasticity
FROM PopulationGrowth..populationDemography AS POPDEM
JOIN PopulationGrowth..DeathsDemography AS DEADEM
      ON POPDEM.Countryname = DEADEM.Countryname
	  AND POPDEM.year = DEADEM.year

---UPDATE THE ELASTICITY COLUMN INTO THE DEATHS DEMOGRAPHY TABLE
-- Step 1: Create a temporary table to store the Elasticity results
WITH ElasticityCalculation AS (
    SELECT
        DEADEM.DeathsPercentageChange,
        POPDEM.Percentage_Change,
        POPDEM.Countryname,
        DEADEM.Countryname AS DeathsCountryname,
        POPDEM.year,
        DEADEM.year AS DeathsYear,
        CASE
            WHEN ISNUMERIC(DEADEM.DeathsPercentageChange) = 1 AND ISNUMERIC(POPDEM.Percentage_Change) = 1 AND DEADEM.DeathsPercentageChange <> 0
                THEN CAST(
                    (CONVERT(FLOAT, POPDEM.Percentage_Change) / CONVERT(FLOAT, DEADEM.DeathsPercentageChange))
                    AS FLOAT
                )
            ELSE 0
        END AS Elasticity
    FROM
        PopulationGrowth..populationDemography AS POPDEM
    JOIN
        PopulationGrowth..DeathsDemography AS DEADEM
    ON
        POPDEM.Countryname = DEADEM.Countryname
        AND POPDEM.year = DEADEM.year
)

-- Step 2: Update the original table using the temporary table
UPDATE PopulationGrowth..DeathsDemography
SET
    Elasticity = EC.Elasticity
FROM ElasticityCalculation EC
WHERE
    PopulationGrowth..DeathsDemography.Countryname = EC.DeathsCountryname
    AND PopulationGrowth..DeathsDemography.year = EC.DeathsYear;

-- Step 3: Select the updated table
SELECT *
FROM PopulationGrowth..DeathsDemography;

